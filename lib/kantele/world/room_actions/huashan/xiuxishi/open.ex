defmodule Kantele.World.RoomActions.Huashan.Xiuxishi.Open do
  @moduledoc """
  `d/huashan/xiuxishi.c` 的 `do_open`（`add_action("do_open", "open")`）。

  LPC 原文：

      int do_open(string arg)
      {
              object room;
              object me = this_player();

              if (!arg || (arg != "men" && arg != "door" && arg != "west"))
                      return notify_fail("你要开什么？\\n");

              if (query("exits/west"))
                      return notify_fail("大门已经是开着了。\\n");

              if(!( room = find_object(__DIR__"xiaolu2")) )
                      room = load_object(__DIR__"xiaolu2");
              if(objectp(room))
              {
                  set("exits/west", __DIR__"xiaolu2");
                  message_vision("$N轻手轻脚地把门打开。\\n", this_player());
                  room->set("exits/east", __FILE__);

                  if (me->query_temp("sleeped"))
                  {
                  message("vision", "吱地一声，"+me->query("name") +
                                    "精神焕发地从里面把门打开了。\\n",
                  room);
                  } else
                  {
                  message("vision", "梆地一声，"+me->query("name") +
                                    "从里面把门打开，一脸的不耐烦。\\n",
                       room);
                  }

                  remove_call_out("close_men");
                  call_out("close_men", 10);
              }

              return 1;
      }

  ## 移植要点

  与 `guanwai:xiuxishi` 的 `do_open` 同构，只有方向（`west`/`east`）与邻居房
  （`huashan:xiaolu2`）不同。两处差异：

  - 参数接受 `west`（`guanwai` 那边接受的是 `south`）。
  - `close_men` 有 `if (objectp(room) && query("exits/west"))` 守卫，所以定时回调
    用 `only_if_open: true` —— 手动关门后残留的定时器**不会**再播「自己合上了」。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @neighbor_room "huashan:xiaolu2"
  @self_room "huashan:xiuxishi"
  @timer_key "exit_timer:close_men"
  @delay_ms 10_000

  @args ["men", "door", "west"]
  @opened "$N轻手轻脚地把门打开。\n"
  @awake_neighbor "吱地一声，%{name}精神焕发地从里面把门打开了。\n"
  @sleepy_neighbor "梆地一声，%{name}从里面把门打开，一脸的不耐烦。\n"
  @closed_message "门咿咿呀呀地自己合上了。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    arg = String.trim(arg)

    cond do
      arg not in @args ->
        Helpers.render_to_player(conn, "你要开什么？\n")

      DynamicExit.open?(room_id, "west") ->
        Helpers.render_to_player(conn, "大门已经是开着了。\n")

      true ->
        open_door(conn, room_id)
    end
  end

  defp open_door(conn, room_id) do
    character = current(conn)

    conn
    |> DynamicExit.open(room_id, "west", @neighbor_room, @opened)
    |> put_neighbor_exit()
    |> tell_neighbor(character)
    |> schedule_close(room_id)
  end

  defp put_neighbor_exit(conn) do
    Room.set_exit(@neighbor_room, "east", @self_room)
    conn
  end

  defp tell_neighbor(conn, character) do
    template =
      if sleeped?(character), do: @awake_neighbor, else: @sleepy_neighbor

    text = String.replace(template, "%{name}", name_of(character))
    Room.tell_room(%Room{id: @neighbor_room}, text)
    conn
  end

  defp schedule_close(conn, room_id) do
    DynamicExit.close_after(
      @delay_ms,
      room_id,
      @timer_key,
      [
        {room_id, "west", @closed_message},
        {@neighbor_room, "east", @closed_message}
      ],
      only_if_open: true
    )

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
