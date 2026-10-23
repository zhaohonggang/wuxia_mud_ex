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
            meta =
              %{character.meta | combat: Combat.start_busy(character.meta.combat, 1 + :rand.uniform(3))}

            conn = put_character(conn, %{character | meta: meta})

            # LPC 只有 `message_sort`（行动者也在接收列表里），没有单独的 `write`；
            # 两处副作用必须串起来，否则移动会覆盖掉播报。
            conn
            |> Helpers.broadcast_vision(room_id, @jump_text)
            |> Helpers.move_to(@target)
        end

      _ ->
        Helpers.render_to_player(conn, @invalid)
    end
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character
  defp current(%{character: character}), do: character
end
