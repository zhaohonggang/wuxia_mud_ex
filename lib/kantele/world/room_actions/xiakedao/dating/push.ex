defmodule Kantele.World.RoomActions.Xiakedao.Dating.Push do
  @moduledoc """
  `d/xiakedao/dating.c` 的 `do_push`（LPC 目标词 `pingfeng`）。

  - 参数非 `pingfeng` → 仅提示「你要推什么呀。」，恒 handle（LPC `write` + return 1）
  - `neili` ≥ 100 → 开 south→xiakedao:yongdao3、扣 100 内力、5 秒后自关
  - `neili` < 100 → 内力清零、提示「屏风却丝毫没动」
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Push

  @room_id "xiakedao:dating"
  @grab "$N在屏风前站定，深吸一口气，两手紧握住屏风。\n"
  @opened "$N丹田一运气，猛的一推，只见屏风之后，露出一条长长的甬道。\n"
  @weak "$N丹田一运气，猛的一推，屏风却丝毫没动。\n"
  @what "你要推什么呀。\n"
  @closed "屏风又慢慢地合上了。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    char = Push.current(conn)

    if String.trim(arg) != "pingfeng" do
      Push.render(conn, @what)
    else
      conn = Push.broadcast(conn, room_id, @grab)

      if Push.neili(char) >= 100 do
        conn
        |> Push.reveal(room_id, "south", "xiakedao:yongdao3", @opened,
          [{room_id, "south", @closed}], 5)
        |> Push.deduct_neili(100)
      else
        conn = Push.set_neili(conn, 0)
        Push.broadcast(conn, room_id, @weak)
      end
    end
  end
end
