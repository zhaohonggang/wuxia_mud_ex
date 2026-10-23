defmodule Kantele.World.RoomActions.Beijing.AofuShufang.Turn do
  @moduledoc """
  鳌拜书房（`d/beijing/aofu_shufang.c`）的 `do_turn`（`add_action("do_turn","turn")`）。

  转把手开暗门：`turn bashou`，前提是玩家已掀开北墙画卷拿到把手
  （`marks/画2`，由同房 `do_xian` 置位；画卷 `marks/画1` 由 UCL `item_desc` 的
  `score_tiers` 触发，数据层已完成）。已开则提示没什么作用；否则开
  `down`→`beijing:aofu_mishi`，8 秒后地面缩回自动关。

  LPC 原文：

      if (! arg || arg != "bashou") return 0;
      if (! me->query_temp("marks/画2")) return 0;
      if (query("exits/down")) return notify_fail("你拉了拉把手，但似乎没什么作用。\\n");
      message_vision("$N拉了拉把手，地面忽然「喀喀喀」现出一个洞口。\\n", me);
      set("exits/down", __DIR__"aofu_mishi");
      remove_call_out("close"); call_out("close", 8);

  前两个 `return 0`（静默放行全局 `turn`）→ 这里返回 `:not_handled`。

  另：LPC `valid_leave` 会在玩家离开时清掉 `marks/画1`/`marks/画2`；本引擎
  `Room.valid_leave/4` 是桩实现（`:ok`），该清理暂缺，记为保真度缺口。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Trigger

  @self_room "beijing:aofu_shufang"
  @target_room "beijing:aofu_mishi"
  @dir "down"
  @mark_key "marks/画2"
  @close_seconds 8

  @no_effect "你拉了拉把手，但似乎没什么作用。\n"
  @opened "$N拉了拉把手，地面忽然「喀喀喀」现出一个洞口。\n"
  @close_msg "地面忽然「喀喀喀」缩回原地，把密道的入口挡住了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    cond do
      String.trim(arg) != "bashou" -> :not_handled
      Trigger.temp(conn, @mark_key) in [nil, 0] -> :not_handled
      DynamicExit.open?(@self_room, @dir) -> Trigger.render(conn, @no_effect)
      true -> turn(conn)
    end
  end

  defp turn(conn) do
    Trigger.reveal(conn, @self_room, @dir, @target_room, @opened, @close_msg, @close_seconds)
  end
end
