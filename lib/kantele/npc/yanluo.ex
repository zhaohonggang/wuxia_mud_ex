defmodule Kantele.NPC.Yanluo do
  @moduledoc """
  十殿阎罗 NPC 问询处理器（对应 LPC `d/death/npc/yanluo.c` 的 `ask_zhuan`）。

  `ask 阎罗 转世` 不再无条件置位 `HellZhenPass`，而是按 LPC 真正**开启十八层
  地狱试炼**：

  1. `check/3` 走 `Kantele.World.HellZhen.gate_error/1` 的九道前置门
     （combat_exp / ultrap / animaout / couple / bunch / brothers / league /
     HellZhenPass / SomeonePassing）；
  2. `execute/3` 置全局 `SomeonePassing` 锁、把玩家送进 `death:emptyroom`、
     发「十八层地狱」传闻，并按 `call_out(message_ob, 2)` +
     `call_out(round_1, 3)` 起两条定时节拍；
  3. 后续 18 层由 `Kantele.Character.HellZhenEvent` 逐层推进；只有
     `winning` 才置位 `HellZhenPass`，失败则 `failed` + 落回武庙。

  ## 尚未移植的 LPC 前置

  `over_quest/hell_quest/锁阳丹`（四味药引任务）在 Ex 尚无任务链，故
  `gate_error/1` 不把它当硬门，否则这道关卡会成为永远进不去的死内容。
  详见 `Kantele.World.HellZhen` 的 moduledoc。
  """

  @behaviour Kantele.NPC.AskHandler

  alias Kalevala.Event
  alias Kantele.Communication
  alias Kantele.World.HellZhen

  @impl true
  def ask_specs do
    %{
      "转世" => %{
        check: fn asker, _npc ->
          case HellZhen.gate_error(asker) do
            nil -> :ok
            msg -> {:error, msg}
          end
        end,
        execute: fn asker, _npc ->
          case HellZhen.gate_error(asker) do
            nil -> start_trial(asker)
            msg -> {:error, msg}
          end
        end,
        effects: []
      }
    }
  end

  @impl true
  def check(asker, npc, keyword), do: dispatch(:check, asker, npc, keyword)

  @impl true
  def execute(asker, npc, keyword), do: dispatch(:execute, asker, npc, keyword)

  @impl true
  def effects(asker, npc, keyword), do: dispatch(:effects, asker, npc, keyword)

  # LPC ask_zhuan()：set_temp("SomeonePassing") → rumor → who->move(emptyroom)
  # → call_out(message_ob, 2) / call_out(round_1, 3)。
  defp start_trial(asker) do
    token = HellZhen.new_token()
    character = HellZhen.put_token(asker, token)

    HellZhen.set_someone_passing(character.id, token)

    if is_pid(character.pid) do
      # 位移必须走玩家进程的 TeleportEvent（NPC/命令进程没有玩家 conn）。
      # 与 TeleportEvent / EnterWorldEvent 的跨进程约定一致。
      send(
        character.pid,
        %Event{
          from_pid: self(),
          topic: "character/teleport",
          data: %{room_id: HellZhen.empty_room_id()}
        }
      )

      send(
        character.pid,
        {:room_message, "十殿阎罗双手拍了一下，你脚下突然陷了下去。。。\n"}
      )
    end

    Communication.announce(
      "rumor",
      "【阴曹地府】#{character.name}要闯俺幽冥地府十八层地狱，哼！等着收尸吧！\n"
    )

    %{message_ob_s: message_ob_s, round_1_s: round_1_s} = HellZhen.opening_timings()

    if is_pid(character.pid) do
      HellZhen.schedule_step(
        character.pid,
        HellZhen.step_data(token, "opening"),
        message_ob_s
      )

      HellZhen.schedule_step(
        character.pid,
        HellZhen.step_data(token, "round", %{round: 1}),
        round_1_s
      )
    end

    # 令牌落进 meta.temp；dispatch_ask_specs/4 会把这个角色 put_character 回 conn
    {:ok, character}
  end

  defp dispatch(fn_name, asker, npc, keyword) do
    case ask_specs()[keyword] do
      nil ->
        if fn_name == :check do
          {:error, "十殿阎罗闭目不语。"}
        else
          {:error, "无此问询。"}
        end

      spec ->
        spec[fn_name].(asker, npc)
    end
  end
end
