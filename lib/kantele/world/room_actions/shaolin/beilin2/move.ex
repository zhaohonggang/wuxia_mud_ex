defmodule Kantele.World.RoomActions.Shaolin.Beilin2.Move do
  @moduledoc """
  少林北林（`d/shaolin/beilin2.c`）的 `do_move`（`add_action("do_move","move")`）。

  推佛塔：`move stone`，须**最大内力 ≥1000**（不足则播「纹丝不动」并把内力清零）。
  开 `down`→`shaolin:beilin3`，**无定时自关**（LPC 无 `call_out`），成功也把内力清零。

  LPC 原文：

      if (arg != "stone" || arg == "") return 0;    // 错词静默放行全局
      if (query("exits/down")) return notify_fail("佛塔已经被移开了，你还移它作甚？\\n");
      message_vision("$N走到佛塔前，运力双掌，使劲推动佛塔，打算将它移开。\\n", me);
      if (me->query("max_neili") < 1000) {
          message_vision("结果哪知$N内力不济，连吃奶的劲都用上了，佛塔还是纹丝不动。\\n", me);
          me->set("neili", 0); return 1;
      }
      message_vision("佛塔忽然发出轧轧的声音，向一侧缓缓移开，向下露出一个黑洞洞的入口。\\n", me);
      set("exits/down", __DIR__"beilin3");
      me->set("neili", 0);
      set("break", 1);      // LPC 全库只写不读的死标志，不移植

  注：本 verb `move` 会覆盖全局移动命令 `move`——与 LPC `add_action` 优先于全局
  命令的语义一致；错词时 `:not_handled` 放行，玩家仍可正常 `move <方向>`。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.MoveStone

  @self_room "shaolin:beilin2"
  @target_room "shaolin:beilin3"
  @dir "down"
  @max_neili_gate 1000

  @already_open "佛塔已经被移开了，你还移它作甚？\n"
  @trying "$N走到佛塔前，运力双掌，使劲推动佛塔，打算将它移开。\n"
  @too_weak "结果哪知$N内力不济，连吃奶的劲都用上了，佛塔还是纹丝不动。\n"
  @opened "佛塔忽然发出轧轧的声音，向一侧缓缓移开，向下露出一个黑洞洞的入口。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    cond do
      String.trim(arg) != "stone" -> :not_handled

      DynamicExit.open?(@self_room, @dir) ->
        MoveStone.render(conn, @already_open)

      true ->
        push(conn)
    end
  end

  defp push(conn) do
    conn = MoveStone.broadcast(conn, @self_room, @trying)
    char = MoveStone.current(conn)

    if MoveStone.max_neili(char) < @max_neili_gate do
      conn
      |> MoveStone.broadcast(@self_room, @too_weak)
      |> MoveStone.set_neili(0)
    else
      conn
      |> MoveStone.set_neili(0)
      |> MoveStone.reveal(@self_room, @dir, @target_room, @opened, [])
    end
  end
end
