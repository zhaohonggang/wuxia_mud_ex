defmodule Kantele.World.RoomActions.Huashan.Jianzhong.Move do
  @moduledoc """
  `d/huashan/jianzhong.c` 的 `do_move`（`add_action("do_move", "move")`）。

  LPC 原文：

      int do_move(string arg)
      {
          ...
          if (! arg || arg != "big stone")
              return notify_fail("你要干什么？\n");
          if (ob->query_temp("moved"))
              return notify_fail("上面的石头已经被移开了！\n");
          message_vision(HIG "$N用力将剑冢上面的石头一块块地移开 ……\n", me);
          ob->set_temp("moved", 1);
          me->start_busy(1);
          return 1;
      }

  剑冢 `moved` 状态存在房间 state 里；`look fen`/`look 石` 及后续 `pick` 依赖它。
  """

  use Kantele.World.RoomAction

  alias Kantele.Character.Combat
  import Kalevala.Character.Conn, only: [put_character: 2]
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @key "moved"
  @moved_text "$N用力将剑冢上面的石头一块块地移开 ……\n"
  @already_moved "上面的石头已经被移开了！\n"
  @invalid "你要干什么？\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    case String.trim(arg) do
      "big stone" ->
        case state(room_id) do
          1 ->
            Helpers.render_to_player(conn, @already_moved)

          _ ->
            Room.put_state_by_id(room_id, @key, 1)
            character = current(conn)
            meta = %{character.meta | combat: Combat.start_busy(character.meta.combat, 1)}
            character = %{character | meta: meta}
            conn = put_character(conn, character)
            Helpers.render_to_player(conn, @moved_text)
            Helpers.broadcast_vision(conn, room_id, @moved_text)
        end

      _ ->
        Helpers.render_to_player(conn, @invalid)
    end

    conn
  end

  defp state(room_id) do
    case Room.get_state_by_id(room_id, @key) do
      value when is_integer(value) -> value
      _ -> 0
    end
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
