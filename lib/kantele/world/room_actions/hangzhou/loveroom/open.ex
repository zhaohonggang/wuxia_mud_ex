defmodule Kantele.World.RoomActions.Hangzhou.Loveroom.Open do
  @moduledoc """
  `d/hangzhou/loveroom.c` 的 `do_open`（`add_action("do_open", "open")`）。

  LPC 原文：

      int do_open(string arg)
      {
              object me=this_player();
              object room;
              if(arg!="door") return notify_fail("你要干什么？\\n");
              room=this_object();
              room->set("exits/down",__DIR__"jiulou");
              (int)me->query_temp("plugin");
              me->delete_temp("plugin",1);
              message("channel:chat", HIR+"【江湖通告】"+me->name()+"终于打开门啦 !!!!\n"NOR, users() );
              return 1;
      }

  ## 移植要点

  - 只认 `door`；否则渲染「你要干什么？」并结束（LPC `notify_fail`：命令被消费，
    不回落到全局 `open`）。
  - 开 `down` → `hangzhou:jiulou`（**单向**出口，LPC 没给 jiulou 回填 `up`）。
  - `me->delete_temp("plugin", 1)` → 删 `meta.temp["plugin"]`（LPC 里 `plugin`
    临时标记由 order 流程后续查询；本引擎无消费者，照样写入保持状态可观测）。
  - `message("channel:chat", ...)` 是发给 `users()`（全服聊天频道）的江湖通告；
    房间动作层没有全服聊天 helper，这里用 `broadcast_vision` 把同义文案投给本房
    作为可观测反馈（语义近似，非逐字等价）。
  - 没有「门已经开了」的守卫（LPC 原样）：可反复开，重复 `set` 出口幂等。
  """
  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @target_room "hangzhou:jiulou"
  @temp_key "plugin"

  @what "你要干什么？\n"
  @opened "$N终于打开门啦 !!!!"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    if String.trim(arg) != "door" do
      Helpers.render_to_player(conn, @what)
    else
      open(conn, room_id)
    end
  end

  defp open(conn, room_id) do
    Room.set_exit(room_id, "down", @target_room)
    conn = delete_plugin(conn)
    Helpers.broadcast_vision(conn, room_id, @opened)
  end

  # `me->delete_temp("plugin", 1)`：删 `meta.temp["plugin"]`（开门清标记）。
  defp delete_plugin(conn) do
    character = current(conn)
    temp = Map.delete(character.meta.temp, @temp_key)
    put_character(conn, %{character | meta: %{character.meta | temp: temp}})
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
