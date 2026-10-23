defmodule Kantele.World.RoomActions.Guanwai.Jingxiu.Push do
  @moduledoc """
  `d/guanwai/jingxiu.c` 的 `do_push`（LPC 目标词 `men`/`door`）。

  - 出口已开（south） → 提示「门已经是开着了。」
  - 参数非 `men`/`door` → :not_handled（放行全局 push）
  - 邻居 guanwai:xiuxishi 有人（person_inside 等价）→ 「门被人从里面闩上了。」
  - 否则开 south→guanwai:xiuxishi、邻居 north→jingxiu、播报、10 秒后双向自关。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Push

  @self_room "guanwai:jingxiu"
  @neighbor_room "guanwai:xiuxishi"
  @args ["men", "door"]
  @opened "$N轻轻地把门推开。\n"
  @neighbor_msg "有人从外面把门推开了。\n"
  @already_open "门已经是开着了。\n"
  @barred "$N想把门推开，却发觉门被人从里面闩上了。\n"
  @closed_self "门咿咿呀呀地自己合上了。\n"
  @closed_neighbor "门咿咿呀呀地自己合上了。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    arg = String.trim(arg)

    cond do
      Push.open?(@self_room, "south") ->
        Push.render(conn, @already_open)

      arg not in @args ->
        :not_handled

      Push.neighbor_occupied?(@neighbor_room) ->
        Push.broadcast(conn, room_id, @barred)

      true ->
        open_door(conn, room_id)
    end
  end

  defp open_door(conn, room_id) do
    conn =
      Push.reveal(
        conn,
        room_id,
        "south",
        @neighbor_room,
        @opened,
        [{room_id, "south", @closed_self}, {@neighbor_room, "north", @closed_neighbor}],
        10
      )

    Push.set_neighbor_exit(@neighbor_room, "north", @self_room, @neighbor_msg)
    conn
  end
end
