defmodule Kantele.World.RoomActions.Hangzhou.Loveroom.Close do
  @moduledoc """
  `d/hangzhou/loveroom.c` 的 `do_close`（`add_action("do_close", "close")`）。

  LPC 原文：

      int do_close(string arg)
      {
              object me=this_player();
              object room;
              if(arg!="door") return notify_fail("你要干什么？\\n");
              room=this_object();
              room->delete("exits/down");
              (int)me->query_temp("plugin");
              me->set_temp("plugin",1);
              message("channel:chat", HIR+"【江湖通告】"+me->name()+"连门都关上啦 !!!!\n"NOR, users() );
              return 1;
      }

  ## 移植要点

  - 只认 `door`；否则渲染「你要干什么？」并结束。
  - 删 `down` 出口（关上门后不能再下到酒楼）。
  - `me->set_temp("plugin", 1)` → 写 `meta.temp["plugin"] = 1`（与 `do_open`
    的 `delete_temp` 配对：开门清标记、关门置标记）。
  - `message("channel:chat", ...)` 同 `Open`：全服江湖通告，这里用 `broadcast_vision`
    投给本房作可观测反馈。
  - 没有「门已经关着」的守卫（LPC 原样）。
  """
  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @temp_key "plugin"

  @what "你要干什么？\n"
  @closed "$N连门都关上啦 !!!!"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    if String.trim(arg) != "door" do
      Helpers.render_to_player(conn, @what)
    else
      close(conn, room_id)
    end
  end

  defp close(conn, room_id) do
    Room.delete_exit(room_id, "down")
    conn = set_plugin(conn)
    Helpers.broadcast_vision(conn, room_id, @closed)
  end

  # `me->set_temp("plugin", 1)`：写 `meta.temp["plugin"] = 1`（关门置标记）。
  defp set_plugin(conn) do
    character = current(conn)
    temp = Map.put(character.meta.temp, @temp_key, 1)
    put_character(conn, %{character | meta: %{character.meta | temp: temp}})
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
