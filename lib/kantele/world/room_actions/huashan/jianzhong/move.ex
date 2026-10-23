defmodule Kantele.World.RoomActions.Huashan.Jianzhong.Move do
  @moduledoc """
  `d/huashan/jianzhong.c` 的 `do_move`（`add_action("do_move", "move")`）。

  LPC 原文：

      int do_move(string arg)
      {
          object me = this_player();
          object ob;

          if (me->is_busy() || me->is_fighting())
                return notify_fail("你忙完了再说吧！\\n");

          if (! arg || arg != "big stone")
              return notify_fail("你要干什么？\\n");

          if (ob->query_temp("moved"))
              return notify_fail("上面的石头已经被移开了！\\n");

          message_vision(HIG "$N" HIG "用力将剑冢上面的石头一块块地移开 ……\\n", me);
          ob->set_temp("moved", 1);
          me->start_busy(1);
          return 1;
      }

  剑冢 `moved` 状态存在房间 state 里；`look fen`/`look 石` 及后续 `pick` 依赖它。

  ## P5-4ae 修掉的两个 bug

  1. `run/2` 末尾多了一句 `conn`，把 `cond`/`case` 算出来的新 conn 丢掉、返回入参
     原 conn —— 于是所有渲染与广播全部丢失（本 handler 在游戏里完全没反应）。
  2. 成功分支先 `render_to_player` 再 `broadcast_vision`，但两者的 conn 没串起来，
     行动者本人看不到那句 `message_vision`。LPC 这里只有 `message_vision`（行动者
     也在接收列表里），所以去掉多余的 `write`。
  另外补上了 LPC 开头漏移植的 `is_busy() || is_fighting()` 守卫。
  """

  use Kantele.World.RoomAction

  alias Kantele.Character.Combat
  import Kalevala.Character.Conn, only: [put_character: 2]
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @key "moved"
  @moved_text "$N用力将剑冢上面的石头一块块地移开 ……\n"
  @already_moved "上面的石头已经被移开了！\n"
  @busy "你忙完了再说吧！\n"
  @invalid "你要干什么？\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    character = current(conn)

    cond do
      Combat.busy?(character.meta.combat) or Combat.fighting?(character.meta.combat) ->
        Helpers.render_to_player(conn, @busy)

      String.trim(arg) != "big stone" ->
        Helpers.render_to_player(conn, @invalid)

      state(room_id) == 1 ->
        Helpers.render_to_player(conn, @already_moved)

      true ->
        Room.put_state_by_id(room_id, @key, 1)
        meta = %{character.meta | combat: Combat.start_busy(character.meta.combat, 1)}
        conn = put_character(conn, %{character | meta: meta})
        Helpers.broadcast_vision(conn, room_id, @moved_text)
    end
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
