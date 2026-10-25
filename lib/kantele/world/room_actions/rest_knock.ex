defmodule Kantele.World.RoomActions.RestKnock do
  @moduledoc """
  休息室门外 `do_knock` 共享原语（P5-6 门/容器第三批：5 处 `do_knock` 之一）。

  `d/guanwai/jingxiu.c` 与 `d/huashan/xiaolu2.c` 的 `do_knock` **逐字相同**，仅
  「本房出口方向」与「邻居休息室」不同，故抽共享原语，各房只留薄封装：

      LPC（jingxiu 版，xiaolu2 仅 `exits/east` 与邻居不同）：

          int do_knock(string arg)
          {
                  object room;

                  if (!arg || (arg != "door" && arg != "men"))
                          return notify_fail("你要敲什么？\\n");

                  if (query("exits/south"))
                          return notify_fail("大门已经是开着了。\\n");

                  if(!( room = find_object(__DIR__"xiuxishi")) )
                          room = load_object(__DIR__"xiuxishi");

                  if(objectp(room))
                  {
                          if ((int)room->query_temp("sleeping_person") > 0)
                          {
                                  message_vision("$N刚轻轻地敲了一下门，就听见里面传出一阵雷鸣般的鼾声，\\n"
                                                 "显然里面的人睡得跟死猪似的，怎么敲都没用了\\n",
                                                 this_player());
                          } else
                          if ((int)room->query_temp("person_inside") > 0)
                          {
                                  switch( random(2) )
                                  {
                                  case 0:
                                          message_vision("$N轻轻地敲了敲门，只听见里面有人很不耐烦地吼到：\\n"
                                                         "刚躺下就来敲门！我睡着了，听不见！！！\\n",
                                                         this_player());
                                          break;
                                  case 1:
                                          message_vision("$N轻轻地敲了敲门，只听见里面有些响动，\\n"
                                                         "好象有人在踱来踱去，拿不定主意是否开门。\\n",
                                                         this_player());
                                          break;
                                  }
                          } else
                          {
                                  room->delete_temp("sleeping_person");
                                  message_vision("$N轻轻地敲了敲门：咚、咚、咚．．．咚、咚、咚．．．\\n",
                                                 this_player());
                          }
                  }

                  if(objectp(room))
                          message("vision",
                                  "外面传来一阵敲门声，你从门缝往外一瞧，是" +
                                  this_player()->name() + "一脸焦急地站在门外，\\n"
                                  "看样子也想进来休息。\\n", room);
          }

  ## 移植要点

  - **判「门已开」用的是本房自己的出口**（`jingxiu` 的 `south` / `xiaolu2` 的
    `east`），不是邻居房——照抄，不「修正」。门开着时敲门只提示、不播文案。
  - `sleeping_person`：**全语料零处 `set_temp`**（只有这两处读 + 一处
    `delete_temp`）→ 恒不成立，第一分支当前不可达（KNOWN_LPC_DEAD，同
    `wudu:mishi` 的 `can_learn/...`）。仍按 `Room.get_state_by_id/2` 读邻居房
    状态，数据若补 setter 即自动生效；同时忠实移植 else 分支的
    `delete_temp("sleeping_person")` 读后即清副作用（`put_state_by_id(..., nil)`）。
  - `person_inside`：等价判定沿用 P5-4aj 既定口径 `Push.neighbor_occupied?/1`
    （邻居房 `Room.snapshot/1` 的 `private.characters` 非空），与 `item_desc` 的
    `room_occupancy` 同源。
  - `random(2)` → `:rand.uniform(2)`（两条文案都由 `message_vision` 播出，
    `Helpers.broadcast_vision/3` 内部把 `$N` 换成 `{npc}`）。
  - 末尾 `message("vision", ...)` 发给**邻居房间**的纯文本（行动者不在那个房，
    没有 `VisionView` 可渲染）：走 `Room.tell_room/2`，`%{name}` 由本模块替换，
    与 `Guanwai.Xiuxishi.Open` 同一套路。
  - `knock` 非全局命令，遮蔽不损失既有功能。
  """

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.Push

  @args ["door", "men"]
  @sleeping_key "sleeping_person"

  @snoring "$N刚轻轻地敲了一下门，就听见里面传出一阵雷鸣般的鼾声，\n显然里面的人睡得跟死猪似的，怎么敲都没用了\n"
  @impatient "$N轻轻地敲了敲门，只听见里面有人很不耐烦地吼到：\n刚躺下就来敲门！我睡着了，听不见！！！\n"
  @pacing "$N轻轻地敲了敲门，只听见里面有些响动，\n好象有人在踱来踱去，拿不定主意是否开门。\n"
  @knocking "$N轻轻地敲了敲门：咚、咚、咚．．．咚、咚、咚．．．\n"
  @neighbor_heard "外面传来一阵敲门声，你从门缝往外一瞧，是%{name}一脸焦急地站在门外，\n看样子也想进来休息。\n"

  @doc """
  `dir`：本房通往休息室的出口方向；`neighbor`：邻居休息室 room_id。
  """
  def knock(conn, room_id, dir, neighbor, arg) do
    arg = String.trim(arg)

    cond do
      arg not in @args ->
        Helpers.render_to_player(conn, "你要敲什么？\n")

      Push.open?(room_id, dir) ->
        Helpers.render_to_player(conn, "大门已经是开着了。\n")

      true ->
        knock_door(conn, room_id, neighbor)
    end
  end

  defp knock_door(conn, room_id, neighbor) do
    conn =
      cond do
        sleeping?(neighbor) ->
          Helpers.broadcast_vision(conn, room_id, @snoring)

        Push.neighbor_occupied?(neighbor) ->
          Helpers.broadcast_vision(conn, room_id, pick(:rand.uniform(2)))

        true ->
          # LPC else 分支：`room->delete_temp("sleeping_person")` 读完即清
          Room.put_state_by_id(neighbor, @sleeping_key, nil)
          Helpers.broadcast_vision(conn, room_id, @knocking)
      end

    tell_neighbor(conn, neighbor)
    conn
  end

  # LPC `room->query_temp("sleeping_person") > 0`
  defp sleeping?(neighbor) do
    case Room.get_state_by_id(neighbor, @sleeping_key) do
      value when is_integer(value) -> value > 0
      _other -> false
    end
  end

  defp pick(1), do: @impatient
  defp pick(2), do: @pacing

  # LPC `message("vision", ...)`：纯文本发给邻居房间（行动者不在其中）。
  defp tell_neighbor(conn, neighbor) do
    name = Push.current(conn) |> actor_name()
    Room.tell_room(%Room{id: neighbor}, String.replace(@neighbor_heard, "%{name}", name))
  end

  defp actor_name(%{name: name}) when is_binary(name), do: name
  defp actor_name(_character), do: "某人"
end
