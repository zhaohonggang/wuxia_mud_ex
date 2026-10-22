defmodule Kantele.World.RoomActions.Huashan.Jianzhong.Pick do
  @moduledoc """
  `d/huashan/jianzhong.c` 的 `do_pick`（`add_action("do_pick", "pick")`）。

  LPC 原文：

      int do_pick(string arg)
      {
          ...
          if (! ob->query_temp("moved"))
              return notify_fail("你要干什么？\n");

          switch(arg)
          {
              case "fir sword" :
                  return notify_fail(HIC "你将竹剑拿起来看了看，觉得普通之极，便又放了回去。\n" NOR);
              case "sec sword":
                  if (environment(xuantie))
                      return notify_fail("上面的东西已被人拿走了！\n");
                  if (me->query("str") < 34)
                      return notify_fail("...火花四溅...不禁吓了一跳。\n");
                  message_vision(HIM "$N将玄铁重剑提了起来。\n" NOR, me);
                  xuantie->move(me);
                  return 1;
              case "thi sword":
                  if (environment(noname))
                      return notify_fail("上面的东西已被人拿走了！\n");
                  message_vision(HIM "$N将无名剑提了起来。\n" NOR, me);
                  noname->move(me);
                  return 1;
          }
          me->start_busy(1);
      }

  `moved`、`xuantie_taken`、`noname_taken` 存在房间 state 里。玄铁重剑/无名剑为唯一
  对象，取走后在房间 state 中标记，避免重复发放。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.Items
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @moved_key "moved"
  @xuantie_key "xuantie_taken"
  @noname_key "noname_taken"

  @xuantie_item_id "clone_lib:xuantiejian"
  @noname_item_id "clone_lib:noname"

  @not_moved "你要干什么？\n"
  @what_pick "你要取什么？\n"
  @fir_text "你将竹剑拿起来看了看，觉得普通之极，便又放了回去。\n"
  @already_taken "上面的东西已被人拿走了！\n"
  @str_fail "你将铁剑只提起数尺，呛的一声，竟然脱手掉下，在石上一碰，火花四溅，不禁吓了一跳。\n"
  @took_xuantie "$N将玄铁重剑提了起来。\n"
  @took_noname "$N将无名剑提了起来。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    case String.trim(arg) do
      "fir sword" ->
        if moved?(room_id) do
          Helpers.render_to_player(conn, @fir_text)
        else
          Helpers.render_to_player(conn, @not_moved)
        end

      "sec sword" ->
        cond do
          not moved?(room_id) ->
            Helpers.render_to_player(conn, @not_moved)

          taken?(@xuantie_key, room_id) ->
            Helpers.render_to_player(conn, @already_taken)

          str?(room_id, conn) < 34 ->
            Helpers.render_to_player(conn, @str_fail)

          true ->
            take_item(conn, room_id, @xuantie_item_id, @xuantie_key, @took_xuantie)
        end

      "thi sword" ->
        cond do
          not moved?(room_id) ->
            Helpers.render_to_player(conn, @not_moved)

          taken?(@noname_key, room_id) ->
            Helpers.render_to_player(conn, @already_taken)

          true ->
            take_item(conn, room_id, @noname_item_id, @noname_key, @took_noname)
        end

      _ ->
        Helpers.render_to_player(conn, @what_pick)
    end

    conn
  end

  defp take_item(conn, room_id, item_id, key, vision) do
    case Items.get(item_id) do
      {:ok, _item} ->
        Room.put_state_by_id(room_id, key, 1)
        conn
        |> Helpers.give_item(item_id)
        |> Helpers.broadcast_vision(room_id, vision)

      _ ->
        Helpers.render_to_player(conn, @already_taken)
    end
  end

  defp moved?(room_id) do
    case Room.get_state_by_id(room_id, @moved_key) do
      value when is_integer(value) -> value == 1
      _ -> false
    end
  end

  defp taken?(key, room_id) do
    case Room.get_state_by_id(room_id, key) do
      value when is_integer(value) -> value == 1
      _ -> false
    end
  end

  defp str?(_room_id, conn) do
    character = current(conn)
    character.meta.stats.str
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character
  defp current(%{character: character}), do: character
end
