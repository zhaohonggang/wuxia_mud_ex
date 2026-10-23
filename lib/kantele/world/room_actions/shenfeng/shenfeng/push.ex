defmodule Kantele.World.RoomActions.Shenfeng.Shenfeng.Push do
  @moduledoc """
  `d/shenfeng/shenfeng.c` 的 `do_push`（`add_action("do_push", "push")`）。

  `push gate` 的失败分支会把玩家震落到山脚、扣 200 气血并昏厥：

      if (! arg || arg != "gate") return notify_fail("你要推什么？\\n");
      if (query("exits/enter")) return notify_fail("石门已经是开着的了，还推什么？\\n");
      message_vision("\\n$N凝神聚气，双臂陡然向石门猛击而去。\\n", me);
      if (query_skill("force") < 300 || query("mark/sand") < 5 || query("neili") < 1500) {
          write("结果「轰」的一声闷响，你被石壁的反弹力震得飞了出去。\\n\\n");
          message("vision", "却见" + me->name() + "身体突然一晃，被震得飞了出去，坠到了山脚下。\\n\\n",
                  environment(me), ({me}));
          me->move(__DIR__"shanjiao");
          me->receive_wound("qi", 200);
          me->unconcious();
          message("vision", "\\n突然听得「砰」的一声，只见一个人从上面的山峰上坠了下来，真是壮观。\\n",
                  environment(me));
          return 1;
      }

  成功分支开 `enter`↔`shenfeng:yongdao1` 双向出口（无定时关）并扣 1000 内力；
  前提 `move sand` 已把 `mark/sand` 清到 6。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Break
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.MoveStone

  @target "shenfeng:yongdao1"
  @fall_room "shenfeng:shanjiao"
  @mark_key "mark/sand"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    cond do
      String.trim(arg) != "gate" ->
        Helpers.render_to_player(conn, "你要推什么？\n")

      DynamicExit.open?(room_id, "enter") ->
        Helpers.render_to_player(conn, "石门已经是开着的了，还推什么？\n")

      true ->
        push(conn, room_id)
    end
  end

  defp push(conn, room_id) do
    conn = MoveStone.broadcast(conn, room_id, "\n$N凝神聚气，双臂陡然向石门猛击而去。\n")
    char = MoveStone.current(conn)

    if Break.force_level(char) < 300 or MoveStone.room_temp(room_id, @mark_key, 0) < 5 or
         Break.neili(char) < 1500 do
      fall(conn, room_id, char.name)
    else
      open(conn, room_id)
    end
  end

  defp fall(conn, room_id, name) do
    conn
    |> Helpers.render_to_player("\n结果「轰」的一声闷响，你被石壁的反弹力震得飞了出去。\n\n")
    |> Helpers.broadcast_vision(
      room_id,
      "\n却见#{name}身体突然一晃，被震得飞了出去，坠到了山脚下。\n\n",
      exclude_actor: true
    )
    |> Helpers.move_to(@fall_room)
    |> Break.wound_qi(200)
    |> Break.unconcious()
    |> Helpers.broadcast_vision(
      @fall_room,
      "\n突然听得「砰」的一声，只见一个人从上面的山峰上坠了下来，真是壮观。\n"
    )
  end

  defp open(conn, room_id) do
    conn
    |> MoveStone.reveal_both(
      room_id,
      "enter",
      @target,
      @target,
      "out",
      "\n$N将石门震到一边，露出一个洞口，可是洞内一片漆黑，甚么也瞧不见。\n",
      "\n只听外面传来一阵移动石门的隆隆的响声。\n"
    )
    |> Break.deduct_neili(1000)
  end
end
