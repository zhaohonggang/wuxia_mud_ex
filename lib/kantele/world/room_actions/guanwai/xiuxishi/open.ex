defmodule Kantele.World.RoomActions.Guanwai.Xiuxishi.Open do
  @moduledoc """
  `d/guanwai/xiuxishi.c` 的 `do_open`（`add_action("do_open", "open")`）。

  LPC 原文：

      int do_open(string arg)
      {
              object room;
              object me = this_player();

              if (!arg || (arg != "men" && arg != "door" && arg != "south"))
                      return notify_fail("你要开什么？\\n");

              if (query("exits/north"))
                      return notify_fail("大门已经是开着了。\\n");

              if(!( room = find_object(__DIR__"jingxiu")) )
                      room = load_object(__DIR__"jingxiu");

              if(objectp(room))
              {
                      set("exits/north", __DIR__"jingxiu");
                      message_vision("$N轻手轻脚地把门打开。\\n", this_player());
                      room->set("exits/south", __FILE__);

                      if (me->query_temp("sleeped"))
                      {
                      message("vision", "吱地一声，"+me->query("name")+"精神焕发地从里
      面把门打开了。\\n", room);
                      } else
                      {
                      message("vision", "梆地一声，"+me->query("name")+"从里面把门打开
      ，一脸的不耐烦。\\n", room);
                      }

                      remove_call_out("close_men");
                      call_out("close_men", 10);
              }

              return 1;
      }

  ## 移植要点

  - **双向门**：本房 `north` ↔ `guanwai:jingxiu` 的 `south` 同时打开，两处都要
    `set_exit`；10 秒后 `close_men` 把两边一起关掉。
  - 邻居房的两句文案把 `me->query("name")` **拼进文本**（不是 `$N`）—— 那些话是
    说给隔壁房间的人听的，行动者本人不在那个房间，没有 `VisionView` 可渲染。
    所以这里用 `Room.tell_room/2` 直接发纯文本。
  - `me->query_temp("sleeped")` → `meta.temp["sleeped"]`（`sleep_command.ex` /
    `sleep_event.ex` 写入 `true`）。
  - `remove_call_out("close_men")` + `call_out("close_men", 10)` →
    `DynamicExit.close_after/4`（同一个 `timer_key` 只保留一个定时器）。
  - `open` 是全局命令；本房 UCL 没有 `doors` 配置，遮蔽不损失既有功能，且与
    LPC `add_action` 优先级一致。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @neighbor_room "guanwai:jingxiu"
  @self_room "guanwai:xiuxishi"
  @timer_key "exit_timer:close_men"
  @delay_ms 10_000

  @args ["men", "door", "south"]
  @opened "$N轻手轻脚地把门打开。\n"
  @awake_neighbor "吱地一声，%{name}精神焕发地从里面把门打开了。\n"
  @sleepy_neighbor "梆地一声，%{name}从里面把门打开，一脸的不耐烦。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    arg = String.trim(arg)

    cond do
      arg not in @args ->
        Helpers.render_to_player(conn, "你要开什么？\n")

      DynamicExit.open?(room_id, "north") ->
        Helpers.render_to_player(conn, "大门已经是开着了。\n")

      true ->
        open_door(conn, room_id)
    end
  end

  defp open_door(conn, room_id) do
    character = current(conn)

    conn
    |> DynamicExit.open(room_id, "north", @neighbor_room, @opened)
    |> put_neighbor_exit()
    |> tell_neighbor(character)
    |> schedule_close(room_id)
  end

  # 邻居房的 `south` 出口：`room->set("exits/south", __FILE__)`
  defp put_neighbor_exit(conn) do
    Room.set_exit(@neighbor_room, "south", @self_room)
    conn
  end

  # LPC 用 `me->query_temp("sleeped")` 二选一：睡过的人「精神焕发」，否则「一脸
  # 的不耐烦」。
  defp tell_neighbor(conn, character) do
    template =
      if sleeped?(character), do: @awake_neighbor, else: @sleepy_neighbor

    text = String.replace(template, "%{name}", name_of(character))
    Room.tell_room(%Room{id: @neighbor_room}, text)
    conn
  end

  defp schedule_close(conn, room_id) do
    DynamicExit.close_after(@delay_ms, room_id, @timer_key, [
      {room_id, "north", "门吱吱呀呀地自己合上了。\n"},
      {@neighbor_room, "south", "门吱吱呀呀地自己合上了。\n"}
    ])

    conn
  end

  defp sleeped?(%{meta: %{temp: temp}}) when is_map(temp), do: Map.get(temp, "sleeped") == true
  defp sleeped?(_character), do: false

  defp name_of(%{name: name}) when is_binary(name), do: name
  defp name_of(_character), do: "某人"

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
