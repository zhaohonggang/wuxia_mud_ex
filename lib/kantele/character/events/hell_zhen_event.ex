defmodule Kantele.Character.HellZhenEvent do
  @moduledoc """
  十八层地狱试炼的玩家侧定时步进（LPC `yanluo.c` 的 `call_out` 链）。

  `Kantele.NPC.Yanluo.execute/3` 在 t=0 起链后，所有后续节拍都由
  `Kantele.World.HellZhen.schedule_step/4` 以
  `Process.send_after(character.pid, %Event{topic: "character/hell_zhen_step"})`
  投递到玩家进程，经 `Kantele.Character.Events` 路由到本模块的 `step/2`。

  之所以必须在玩家进程执行：`meta`（vitals / temp / env）只有本进程能安全修改，
  房间/NPC 进程拿不到玩家的 `conn`，也改不了 `private.update_character`。
  这与 `EnterWorldEvent` / `TeleportEvent` 的跨进程约定一致。

  ## phase 与 LPC 的对应

  | phase | LPC |
  |---|---|
  | `"opening"` | `call_out("message_ob", 2, who)` |
  | `"round"` | `round_N(who)`：黑牌横幅 + N 只鬼 `invocation` + 排后续三跳 |
  | `"check"` | `check_status(who)`：`qi/eff_qi < 500` → 作废令牌 + `call_out("failed", 1)` |
  | `"interlude"` | `message_ob(who)`（房间广播五选一） |
  | `"winning"` | `winning(who)`：`HellZhenPass=1` + 回阎罗殿 + 清锁 |
  | `"failed"` | `failed(who)`：`unconcious()` + 落武庙 + 清锁 |
  | `"remove_all"` | `remove_all()`：阴风播报（Ex 无 `all_inventory`，清场由各角色自己的 teleport 完成） |

  LPC 用 `remove_call_out("round_*")` 撤掉失败后的所有待执行节拍；Ex 的定时器
  不能按名字取消，改由 `HellZhen.cancel/1` 写「作废标记」（角色 temp + 房间
  state 双写）。除 `"failed"` / `"remove_all"` 外，每个 phase 先过
  `HellZhen.valid_step?/2`，作废即静默丢弃。
  """

  use Kalevala.Character.Event

  alias Kantele.Character.Records
  alias Kantele.Character.Teleport
  alias Kantele.Communication
  alias Kantele.Feature.Damage
  alias Kantele.World.HellZhen
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  # 这两个 phase 是本轮试炼的收尾，必须在「已作废」状态下仍可执行
  @final_phases ["failed", "remove_all"]

  @doc "topic: character/hell_zhen_step -> step/2"
  def step(conn, %{data: %{phase: phase, token: token} = data}) do
    character = current(conn)

    allowed? =
      if phase in @final_phases do
        HellZhen.token_matches?(character, token)
      else
        HellZhen.valid_step?(character, data)
      end

    if allowed?, do: do_phase(conn, character, phase, data), else: conn
  end

  def step(conn, _event), do: conn

  # ---------------------------------------------------------------------------
  # 各节拍
  # ---------------------------------------------------------------------------

  # t=2s，LPC message_ob()：五选一的「不断下降」文案（tell_room，非 tell_object）
  defp do_phase(conn, _character, "opening", _data) do
    tell_room(HellZhen.interlude())
    conn
  end

  defp do_phase(conn, _character, "interlude", _data) do
    tell_room(HellZhen.interlude())
    conn
  end

  defp do_phase(conn, character, "round", data) do
    round = Map.get(data, :round, 1)
    tell_room(HellZhen.banner(round))

    # LPC：ghost = new(HellZhen/N); ghost->invocation(who); destruct(ghost)
    # 11-18 层有两只鬼，各自独立做一次 ap/dp 判定并扣 qi。
    {hit_texts, character} =
      Enum.map_reduce(HellZhen.ghost_ids(round), character, fn _ghost_id, acc ->
        result = HellZhen.invocation(acc)
        {HellZhen.hit_text(result), HellZhen.apply_damage(acc, result)}
      end)

    conn =
      put_character(conn, character)
      |> then(fn conn ->
        Enum.reduce(hit_texts, conn, fn text, acc -> Helpers.render_to_player(acc, text) end)
      end)

    t = HellZhen.timings(round)

    schedule(character, data, "check", %{}, t.check_s)

    if round < HellZhen.layer_count() do
      schedule(character, data, "interlude", %{}, t.interlude_s)
      schedule(character, data, "round", %{round: round + 1}, t.next_s)
    else
      # round_18 不排 message_ob，直接 winning（yanluo.c:1138-1142）
      schedule(character, data, "winning", %{}, t.winning_s)
    end

    conn
  end

  defp do_phase(conn, character, "check", data) do
    case HellZhen.check_status(character) do
      :failed ->
        # LPC remove_call_out(...) + call_out("failed", 1, who)
        character = HellZhen.cancel(character)
        conn = put_character(conn, character)
        schedule(character, data, "failed", %{}, HellZhen.timings(1).failed_s)
        conn

      :ok ->
        conn
    end
  end

  defp do_phase(conn, character, "winning", data) do
    meta = character.meta
    env = Map.put(meta.env || %{}, :HellZhenPass, true)

    character =
      %{character | meta: %{meta | env: env}}
      |> HellZhen.clear_trial()

    Records.save(character)
    HellZhen.clear_someone_passing()

    conn =
      conn
      |> put_character(character)
      |> Teleport.teleport(HellZhen.yanluodian_id())
      |> Helpers.render_to_player("你闯过十八层地狱，一道阴风将你送回阎罗殿。\n")

    Communication.announce(
      "rumor",
      "【阴曹地府】恭喜#{character.name}闯过幽冥地府十八层地狱，不过更危险的在后面！\n"
    )

    schedule(character, data, "remove_all", %{}, HellZhen.timings(1).remove_all_s)
    conn
  end

  defp do_phase(conn, character, "failed", data) do
    # LPC who->unconcious()：Ex 由伤害子系统落地（qi=0 / ghost / 预约复活）
    character =
      character
      |> knock_out()
      |> HellZhen.clear_trial()

    HellZhen.clear_someone_passing()

    conn =
      conn
      |> put_character(character)
      |> Teleport.teleport(HellZhen.wumiao_id())
      |> Helpers.render_to_player("你眼前一黑，被一阵阴风卷出了十八层地狱……\n")

    Communication.announce(
      "rumor",
      "【阴曹地府】果真有不怕死的，可惜还是逃不出俺的手掌心！\n"
    )

    schedule(character, data, "remove_all", %{}, HellZhen.timings(1).remove_all_s)
    conn
  end

  defp do_phase(conn, _character, "remove_all", _data) do
    # LPC remove_all() 的 write()：Ex 没有房间 all_inventory 的可写句柄，
    # 玩家已在 winning/failed 里自行位移，这里只补阴风播报。
    tell_room("四周刮起一阵阴风。。。\n")
    conn
  end

  defp do_phase(conn, _character, _phase, _data), do: conn

  # ---------------------------------------------------------------------------
  # 内部
  # ---------------------------------------------------------------------------

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  defp schedule(%{pid: pid} = _character, data, phase, extra, seconds) when is_pid(pid) do
    HellZhen.schedule_step(
      pid,
      HellZhen.step_data(Map.get(data, :token), phase, extra),
      seconds,
      Map.get(data, :scale, 1)
    )
  end

  defp schedule(_character, _data, _phase, _extra, _seconds), do: nil

  defp tell_room(text) do
    try do
      Room.tell_room(%{id: HellZhen.empty_room_id()}, text)
    rescue
      _ -> :ok
    end
  end

  # unconcious() 内部会广播 + 预约复活；试炼失败不该因为伤害子系统的边缘数据
  # （如 con >= 100 时 :rand.uniform(0)）而中断，故兜底回原角色。
  defp knock_out(character) do
    try do
      case Damage.unconcious(character) do
        {:ok, updated} when is_map(updated) -> updated
        _ -> character
      end
    rescue
      _ -> character
    end
  end
end
