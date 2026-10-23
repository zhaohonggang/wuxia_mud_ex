defmodule Kantele.World.RoomActions.Kaifeng.HhXiaozhu.Move do
  @moduledoc """
  开封花园小筑（`d/kaifeng/hh_xiaozhu.c`）的 `do_move`（`add_action("do_move","move")`）。

  推石桌：`move zhuo`，须**最大内力 ≥1000**；非红花会弟子且**余鱼同在场**时被
  喝退（余鱼同是该房常驻 NPC，`data/world/kaifeng.ucl` `room_characters`，
  这里用 `Room.npc_characters_by_id/1` 实时判在场）。开 `down`→`kaifeng:hh_mishi`，
  10 秒后石桌移回自动关（`close_passage` 有守卫）；**成功也会把内力清零**
  （LPC 原样，`set("neili", 0)` 在成功分支里）。

  LPC 原文：

      if (! arg || arg != "zhuo") return 0;      // 错词静默放行全局
      if (query("exits/down")) return notify_fail("石桌已经被移开了，你还移它作甚？\\n");
      if (me->query("family/family_name") != "红花会" &&
          objectp(present("yu yutong", environment(me)))) {
          write("余鱼同眉头一皱，喝道：阁下什么来头，居然敢在这里猖狂？\\n");
          return 1;
      }
      message_vision("$N走到石桌前，运力双掌，使劲推动石桌，打算将它移开。\\n", me);
      if (me->query("max_neili") < 1000) {
          message_vision("结果哪知$N内力不济，连吃奶的劲都用上了，石桌还是纹丝不动。\\n", me);
          me->set("neili", 0); return 1;
      }
      message_vision("石桌忽然发出轧轧的声音，向一侧缓缓移开，向下露出一个黑洞洞的入口。\\n", me);
      set("exits/down", __DIR__"hh_mishi");
      me->set("neili", 0);
      remove_call_out("close_passage"); call_out("close_passage", 10);
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.MoveStone

  @self_room "kaifeng:hh_xiaozhu"
  @target_room "kaifeng:hh_mishi"
  @dir "down"
  @npc_id "clone_lib:honghua_yu"
  @family "红花会"
  @max_neili_gate 1000
  @close_seconds 10

  @already_open "石桌已经被移开了，你还移它作甚？\n"
  @blocked "余鱼同眉头一皱，喝道：阁下什么来头，居然敢在这里猖狂？\n"
  @trying "$N走到石桌前，运力双掌，使劲推动石桌，打算将它移开。\n"
  @too_weak "结果哪知$N内力不济，连吃奶的劲都用上了，石桌还是纹丝不动。\n"
  @opened "石桌忽然发出轧轧的声音，向一侧缓缓移开，向下露出一个黑洞洞的入口。\n"
  @close_msg "\n石桌发出隆隆的声音，缓缓移回原处。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    cond do
      String.trim(arg) != "zhuo" -> :not_handled

      DynamicExit.open?(@self_room, @dir) ->
        MoveStone.render(conn, @already_open)

      blocked?(conn) ->
        MoveStone.render(conn, @blocked)

      true ->
        push(conn)
    end
  end

  defp blocked?(conn) do
    MoveStone.family_name(MoveStone.current(conn)) != @family and
      MoveStone.npc_present?(@self_room, @npc_id)
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
      |> MoveStone.reveal(@self_room, @dir, @target_room, @opened,
        seconds: @close_seconds,
        close_msg: @close_msg,
        only_if_open: true
      )
    end
  end
end
