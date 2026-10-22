defmodule Kantele.World.RoomActions.Huashan.Jianzhong.Jump do
  @moduledoc """
  `d/huashan/jianzhong.c` 的 `do_jump`（`add_action("do_jump", "jump")`）。

  LPC 原文：

      int do_jump(string arg)
      {
          if (! arg || arg != "lianhua")
              return notify_fail("你要往哪儿跳？\n");
          if (me->query("qi") < 300)
              return notify_fail("你力气不加。\n");
          if (me->is_busy() || me->is_fighting())
              return notify_fail("等你忙完了再说。\n");
          me->start_busy(1 + random(3));
          message_sort(HIG "\n$N纵身跳下 ……\n" NOR, me);
          me->move(__DIR__"lianhua");
          return 1;
      }

  跳莲花峰：目标房间为 `huashan:lianhua`，状态走房间忙/战斗与 `stats.qi`。
  """

  use Kantele.World.RoomAction

  alias Kantele.Character.Combat
  import Kalevala.Character.Conn, only: [put_character: 2]
  alias Kantele.World.RoomActions.Helpers

  @target "huashan:lianhua"
  @invalid "你要往哪儿跳？\n"
  @qi_low "你力气不加。\n"
  @busy "等你忙完了再说。\n"
  @jump_text "$N纵身跳下 ……\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    case String.trim(arg) do
      "lianhua" ->
        character = current(conn)

        cond do
          character.meta.vitals.qi < 300 ->
            Helpers.render_to_player(conn, @qi_low)

          Combat.busy?(character.meta.combat) or Combat.fighting?(character.meta.combat) ->
            Helpers.render_to_player(conn, @busy)

          true ->
            character = current(conn)
            meta = %{character.meta | combat: Combat.start_busy(character.meta.combat, 1 + :rand.uniform(3))}
            character = %{character | meta: meta}
            conn = put_character(conn, character)
            Helpers.render_to_player(conn, @jump_text)
            Helpers.broadcast_vision(conn, room_id, @jump_text)
            Helpers.move_to(conn, @target)
        end

      _ ->
        Helpers.render_to_player(conn, @invalid)
    end

    conn
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character
  defp current(%{character: character}), do: character
end
