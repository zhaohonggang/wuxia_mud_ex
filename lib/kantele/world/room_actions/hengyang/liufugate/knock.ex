defmodule Kantele.World.RoomActions.Hengyang.Liufugate.Knock do
  @moduledoc """
  `d/hengyang/liufugate.c` 的 `do_knock`（`add_action("do_knock", "knock")`）。

  LPC 原文：

      int do_knock(string arg)
      {
              object me = this_player();

              message_vision(HIW "\\n$N“咚，咚，咚……。”地敲着门，可里面"
                             "却一点动静都没有。\\n\\n" NOR, me);

              me->set_temp("marks/liufu",1);

              return 1;
      }

  ## 移植要点

  - **不校验 `arg`**（LPC 就没有 arg 判断，`knock` 任何宾语都敲门）。
  - `me->set_temp("marks/liufu", 1)` → 扁平键 `meta.temp["marks/liufu"] = 1`
    （同 `player_temp_branch` 的 `marks/辟1` 约定）。
  - 该标记正是同房 `Hengyang.Liufugate.Push` 的开门条件：LPC `do_push` 判的是
    `query_temp("marks")`——marks **映射**整体非空。所以 Push 侧按「任一
    `marks/` 前缀键存在」判定（见该模块 `has_marks?/1` 的说明）；本次补齐 knock
    后，`push gate` 才真正可达（此前无人写 `marks`，门永远「关得牢牢的」）。
  - `knock` 非全局命令，遮蔽不损失既有功能。
  """
  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.PlayerMeta
  alias Kantele.World.RoomActions.Helpers

  @temp_key "marks/liufu"
  @vision "\n$N“咚，咚，咚……。”地敲着门，可里面却一点动静都没有。\n\n"

  @impl true
  def run(conn, %{room_id: room_id}) do
    conn
    |> put_player_temp(@temp_key, 1)
    |> Helpers.broadcast_vision(room_id, @vision)
  end

  defp put_player_temp(conn, key, value) do
    character = conn.private.update_character || conn.character
    put_character(conn, %{character | meta: PlayerMeta.put_temp(character.meta, key, value)})
  end
end
