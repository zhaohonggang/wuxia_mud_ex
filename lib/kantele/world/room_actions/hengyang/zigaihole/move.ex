defmodule Kantele.World.RoomActions.Hengyang.Zigaihole.Move do
  @moduledoc """
  `d/hengyang/zigaihole.c` 的 `do_move`（`add_action("do_move", "move")`）。

  LPC 原文：

      int do_move(string arg)
      {
          object here = find_object(__DIR__"zigaihole");

          if (! arg || (arg != "desk" && arg != "石桌"))
                  return notify_fail("你想移什么？\\n");

          if (here->query_temp("marks/移"))
          {
                  write(HIG "\\n你用力一推，将石桌移回了原处。\\n\\n" NOR);
                  here->delete_temp("marks/移");
                  return 1;
          }

          write(HIC "\\n你用力一推，石桌下面竟露出一个坑(keng)来。\\n\\n" NOR);
          here->set_temp("marks/移", 1);
          return 1;
      }

  石桌状态存在房间 temp `marks/移`；`look desk` 依据它显示是否已推开。
  `look keng` 还依赖坑里的经书对象，属于后续批次。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @key "marks/移"

  @moved "\n你用力一推，石桌下面竟露出一个坑(keng)来。\n\n"
  @restored "\n你用力一推，将石桌移回了原处。\n\n"
  @invalid "你想移什么？\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    case String.trim(arg) do
      target when target in ["desk", "石桌"] ->
        if Room.get_state_by_id(room_id, @key) do
          Room.delete_state_by_id(room_id, @key)
          Helpers.render_to_player(conn, @restored)
        else
          Room.put_state_by_id(room_id, @key, 1)
          Helpers.render_to_player(conn, @moved)
        end

      _ ->
        Helpers.render_to_player(conn, @invalid)
    end
  end
end
