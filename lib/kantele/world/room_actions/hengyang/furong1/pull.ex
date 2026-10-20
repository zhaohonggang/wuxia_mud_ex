defmodule Kantele.World.RoomActions.Hengyang.Furong1.Pull do
  @moduledoc """
  `d/hengyang/furong1.c` 的 `do_pull`（`add_action("do_pull", "pull")`）。

  LPC 原文：

      int do_pull(string arg)
      {
          object here = find_object(__DIR__"furong1");

          if (! arg || arg != "net")
          {
                  write("你要拉什么？\\n");
                  return 1;
          }

          if (here->query_temp("marks/拉"))
          {
                  write("蜘蛛网已经被拉破了。\\n");
                  return 1;
          }

          write(HIC "\\n你把蜘蛛网拉了下来。\\n" NOR);
          here->set_temp("marks/拉", 1);

          return 1;
      }

  拉开后设置房间 temp `marks/拉`，随后 `look net` 才显示「被拉破的蜘蛛网」。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @key "marks/拉"

  @already_pulled "蜘蛛网已经被拉破了。\n"
  @pulled "\n你把蜘蛛网拉了下来。\n"
  @invalid "你要拉什么？\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    case String.trim(arg) do
      "net" ->
        if Room.get_state_by_id(room_id, @key) do
          Helpers.render_to_player(conn, @already_pulled)
        else
          Room.put_state_by_id(room_id, @key, 1)
          Helpers.render_to_player(conn, @pulled)
        end

      _ ->
        Helpers.render_to_player(conn, @invalid)
    end
  end
end
