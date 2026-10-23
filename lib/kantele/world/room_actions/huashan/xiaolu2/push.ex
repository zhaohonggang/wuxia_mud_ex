defmodule Kantele.World.RoomActions.Huashan.Xiaolu2.Push do
  @moduledoc """
  `d/huashan/xiaolu2.c` 的 `do_push`（LPC 目标词 `men`/`door`）。

  与 guanwai:jingxiu 同构，只是方向（east）与邻居房（huashan:xiuxishi）不同：
  - 出口已开（east） → 提示「门已经是开着了。」
  - 参数非 `men`/`door` → :not_handled
  - 邻居 huashan:xiuxishi 有人 → 「门被人从里面闩上了。」
  - 否则开 east→huashan:xiuxishi、邻居 west→xiaolu2、播报、10 秒后双向自关。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Push

  @self_room "huashan:xiaolu2"
  @neighbor_room "huashan:xiuxishi"
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
      Push.open?(@self_room, "east") ->
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
        "east",
        @neighbor_room,
        @opened,
        [{room_id, "east", @closed_self}, {@neighbor_room, "west", @closed_neighbor}],
        10
      )

    Push.set_neighbor_exit(@neighbor_room, "west", @self_room, @neighbor_msg)
    conn
  end
end
