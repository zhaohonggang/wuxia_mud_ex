defmodule Kantele.World.RoomActions.Xiakedao.Midao4.Break do
  @moduledoc """
  `d/xiakedao/midao4.c` 的 `do_break`（LPC 目标词 `men`）。

  - 参数非 `men` → 提示「不要随意打破别人的东西。」
  - 内力 > 200 → 开 west→xiakedao:midao5、扣 200、5 秒后自动关（石门自动合上）。
    （LPC 用 `n > 200`，严格大于。）
  - 内力 ≤ 200 → 内力清零 + 播报「石门却丝毫没动」。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Break
  alias Kantele.World.RoomActions.Helpers

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    if String.trim(arg) != "men" do
      Helpers.render_to_player(conn, "不要随意打破别人的东西。\n")
    else
      conn = Break.broadcast(conn, room_id, "$N在石门前站定，深吸一口气，两掌同时拍出。\n")

      if Break.neili(Break.current(conn)) > 200 do
        conn
        |> Break.broadcast(room_id, "$N丹田一运气，猛的一拍，石门慢慢的开了。\n")
        |> Break.reveal(room_id, "west", "xiakedao:midao5", "",
          {5, "石门自动的合上了。\n"}
        )
        |> Break.deduct_neili(200)
      else
        conn
        |> Break.broadcast(room_id, "$N丹田一运气，猛的一拍，石门却丝毫没动。\n")
        |> Break.set_neili(0)
      end
    end
  end
end
