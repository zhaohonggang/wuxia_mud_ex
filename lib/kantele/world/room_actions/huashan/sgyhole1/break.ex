defmodule Kantele.World.RoomActions.Huashan.Sgyhole1.Break do
  @moduledoc """
  `d/huashan/sgyhole1.c` 的 `do_break`（无需参数，但**必须持武器**）。

  - 未持武器（`query_temp("weapon")` 守卫）→ 提示「你一掌打在石壁，满手都是鲜血。」
  - 内力 < 200 → 内力清零 + 昏厥（被反弹力震黑）。
  - 否则 → 开 enter→huashan:sgyhole、扣 200、5 秒后自动关（崖上巨石封洞）。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Break
  alias Kantele.World.RoomActions.Helpers

  @impl true
  def run(conn, %{room_id: room_id}) do
    char = Break.current(conn)

    if is_nil(Break.wielded_weapon(char)) do
      Helpers.render_to_player(conn, "你一掌打在石壁，满手都是鲜血。\n")
    else
      name = Break.weapon_name(char)
      conn = Break.broadcast(conn, room_id, "$N走到石壁前，拿起#{name}，随手向石壁刺了过去！\n")

      if Break.neili(char) < 200 do
        conn
        |> Break.broadcast(room_id, "结果只听一声闷哼，$N被石壁的反弹力震得眼前一黑....\n")
        |> Break.pass_out()
      else
        conn
        |> Break.broadcast(room_id, "$N只听一声轰响，石壁竟然被捅穿了，原来里面有一个大洞！\n")
        |> Break.reveal(room_id, "enter", "huashan:sgyhole", "",
          {5, "崖上忽然掉下来一块巨石，将洞口封了个严严实实。\n"}
        )
        |> Break.deduct_neili(200)
      end
    end
  end
end
