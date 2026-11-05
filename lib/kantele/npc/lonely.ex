defmodule Kantele.NPC.Lonely do
  @moduledoc """
  高处不胜寒（lonely）NPC 问询处理器（对应 LPC `d/death/sky/npc/lonely.c`）。

  `ask 精元丹` 先过 LPC `accept_kill(object me)` 的硬门：

      if (me->query("combat_exp") < 20000000)
      {
          message_vision(... "无名小辈捣什么乱？给我滚！..." ...);
          me->unconcious();
          return -1;
      }

  即经验不足时**拒绝发起生死斗**，并当场把玩家击晕。Ex 里 `unconcious()`
  由 `Kantele.Feature.Damage.unconcious/1` 落地（qi=0 / ghost / 预约复活），
  更新后的角色通过 `{:error, msg, character}` 回给 AskCommand 的
  `dispatch_ask_specs/4`，由它 `put_character` 后再显示拒绝语。

  经验达标才 `NpcAttack.kill_ob/2` 发起生死斗；玩家胜后（P4-D `enemy_died`
  钩子）置位 `SkyPass=1`，赠予精元丹，传送阎罗殿，广播江湖传闻。
  """

  @behaviour Kantele.NPC.AskHandler

  alias Kantele.Communication
  alias Kantele.Feature.Damage
  alias Kantele.World.NpcActions.NpcAttack

  @combat_exp_min 20_000_000

  @reject_text "高处不胜寒大怒道：“无名小辈捣什么乱？给我滚！”说罢一掌把你劈倒在地。\n"

  @impl true
  def ask_specs do
    %{
      "精元丹" => %{
        check: fn asker, _npc ->
          case gate_error(asker) do
            nil -> :ok
            msg -> {:error, msg, knock_out(asker)}
          end
        end,
        execute: fn asker, npc ->
          case gate_error(asker) do
            nil -> start_duel(asker, npc)
            msg -> {:error, msg, knock_out(asker)}
          end
        end,
        effects: []
      }
    }
  end

  @doc "LPC `accept_kill` 的 `combat_exp < 20000000` 门（公开便于定向测试）"
  def combat_exp_min, do: @combat_exp_min

  @impl true
  def check(asker, npc, keyword), do: dispatch(:check, asker, npc, keyword)

  @impl true
  def execute(asker, npc, keyword), do: dispatch(:execute, asker, npc, keyword)

  @impl true
  def effects(asker, npc, keyword), do: dispatch(:effects, asker, npc, keyword)

  defp start_duel(asker, npc) do
    rumor_text = "#{asker.name}向高处不胜寒请要精元丹，高处不胜寒怒而与之决一死战！"
    Communication.announce("rumor", rumor_text)

    case NpcAttack.kill_ob(npc, asker) do
      :ok ->
        if pid = asker.pid, do:
          send(
            pid,
            {:room_message, "高处不胜寒冷笑道：要精元丹？先接我几招再说！\n"}
          )

        :ok

      {:error, _reason} ->
        {:error, "高处不胜寒似乎不愿与你交手。\n"}
    end
  end

  defp gate_error(asker) do
    stats = Map.get(Map.get(asker, :meta) || %{}, :stats) || %{}
    exp = Map.get(stats, :combat_exp) || 0

    if exp < @combat_exp_min, do: @reject_text, else: nil
  end

  # unconcious() 会广播并预约复活；边缘数据（如 con >= 100）不应让命令崩溃。
  defp knock_out(asker) do
    try do
      case Damage.unconcious(asker) do
        {:ok, updated} when is_map(updated) -> updated
        _ -> asker
      end
    rescue
      _ -> asker
    end
  end

  defp dispatch(fn_name, asker, npc, keyword) do
    case ask_specs()[keyword] do
      nil ->
        if fn_name == :check do
          {:error, "高处不胜寒闭目不语。"}
        else
          {:error, "无此问询。"}
        end

      spec ->
        spec[fn_name].(asker, npc)
    end
  end
end
