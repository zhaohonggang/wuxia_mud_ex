defmodule Kantele.Character.CasinoPayoutEvent do
  @moduledoc """
  赌场赢钱落地（房间进程判定 → 角色进程加币）。

  `RoomActions.City.Bet.finish_round` 对每位赢家发 `casino/payout` 事件
  （见 pig_room 的 `pig/seat` 同款跨进程模式：`meta` 只有本进程能安全修改，
  且 `Kantele.Character.Records` 仅在本进程落盘）。

  - `event("casino/payout", %{amount: n})` → `meta.coins += n`
  """
  import Kalevala.Character.Conn, only: [put_character: 2]

  @doc "topic: casino/payout -> credit/1"
  def credit(conn, %{data: %{amount: amount}}) when is_integer(amount) do
    character = conn.private.update_character || conn.character
    meta = %{character.meta | coins: (character.meta.coins || 0) + amount}
    put_character(conn, %{character | meta: meta})
  end

  def credit(conn, _data), do: conn
end
