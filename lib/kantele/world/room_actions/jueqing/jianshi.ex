defmodule Kantele.World.RoomActions.Jueqing.Jianshi do
  @moduledoc """
  `d/jueqing/jianshi.c` 的 `do_pull`（`add_action("do_pull", ({"pull"}))`）
  与 `do_pick`（`add_action("do_pick", ({"pick"}))`）。

  ## do_pull "hua"
  - arg 须为 `hua`，否则 `notify_fail("你要做什么？\\n")`（**无** busy/fighting 守卫，与
    do_turn/do_jump 不同）。
  - 机关状态 `marks/拉` 存房间 state（LPC `ob->set_temp("marks/拉")` 写在房间单例）。
  - 已拉 → `write("画已经被拉破了。\\n")` 仅私发给行动者。
  - 未拉 → 房间广播「咔嚓一声，$N 将墙上的画拉破了。」+ 置 `marks/拉`。

  ## do_pick "junzi jian"/"shunv jian"
  - arg 须为 `junzi jian` / `shunv jian`，否则 `notify_fail("你要拿什么？\\n")`。
  - LPC 门控 `(marks/君 && marks/女) || !marks/拉`：其中 `marks/君`/`marks/女` 是
    **死代码**（全文件从未 `set_temp`），永远为假，故等价于「未拉画则不可取」。
  - 君子剑/淑女剑是两件 **单例物品**（LPC `/clone/lonely/junzijian`/`shunvjian`），
    用 `environment(junzi)` 是否为 nil 判定是否已被取走。引擎无单例，改以房间 state
    `marks/junzi_taken` / `marks/shunv_taken` 记录「已被取走」，防重复取。
  - 取剑：`Items.get/1` + `Helpers.give_item/3` 把实例放入背包 + 房间广播
    「$N 将墙上的「君子剑/淑女剑」取了下来。」+ 置 taken 标记。
  - 已取过 → `notify_fail("君子剑/淑女剑已被拿走。\\n")`。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @pull_key "marks/拉"
  @junzi_item "junzijian"
  @shunv_item "shunvjian"
  @junzi_taken "marks/junzi_taken"
  @shunv_taken "marks/shunv_taken"

  @impl true
  def run(conn, %{verb: verb, trailing: arg, room_id: room_id}) do
    case verb do
      "pull" -> do_pull(conn, room_id, String.trim(arg))
      "pick" -> do_pick(conn, room_id, String.trim(arg))
      _ -> conn
    end
  end

  # ---------- do_pull ----------
  defp do_pull(conn, room_id, arg) do
    if arg != "hua" do
      Helpers.render_to_player(conn, "你要做什么？\n")
    else
      if Room.get_state_by_id(room_id, @pull_key) do
        Helpers.render_to_player(conn, "画已经被拉破了。\n")
      else
        Room.put_state_by_id(room_id, @pull_key, 1)

        Helpers.broadcast_vision(
          conn,
          room_id,
          "只听见“咔嚓”一声，$N 将墙上的画拉破了。\n"
        )
      end
    end
  end

  # ---------- do_pick ----------
  defp do_pick(conn, room_id, arg) do
    {item, taken_key, label} =
      case String.trim(arg) do
        "junzi jian" -> {@junzi_item, @junzi_taken, "君子剑"}
        "shunv jian" -> {@shunv_item, @shunv_taken, "淑女剑"}
        _ -> {nil, nil, nil}
      end

    if is_nil(item) do
      Helpers.render_to_player(conn, "你要拿什么？\n")
    else
      # LPC 门控 `(marks/君 && marks/女) || !marks/拉`：君/女 永假，等价于 !marks/拉
      unless Room.get_state_by_id(room_id, @pull_key) do
        Helpers.render_to_player(conn, "你要拿什么？\n")
      else
        if Room.get_state_by_id(room_id, taken_key) do
          Helpers.render_to_player(conn, "#{label}已被拿走。\n")
        else
          Room.put_state_by_id(room_id, taken_key, 1)

          conn = Helpers.broadcast_vision(conn, room_id, "$N 将墙上的「#{label}」取了下来。\n")
          Helpers.give_item(conn, item)
        end
      end
    end
  end
end
