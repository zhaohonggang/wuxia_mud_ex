defmodule Kantele.Character.BegDebitEvent do
  @moduledoc """
  乞讨成功：victim 角色进程扣币（对应 LPC `ob->set_amount(amount - bcount)`）。

  `event("beg/debit", %{amount: n})` → `meta.coins -= min(n, current)`（不低于 0）。
  房间进程裁定并转发的跨进程事件，本进程落地并 `Records.save`
  （房间事件不回写 `context.characters`，跨角色改币必须在角色进程落盘，
  与 casino/payout 同款跨进程模式）。
  """
  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.Records

  def run(conn, %{data: %{amount: amount}}) when is_integer(amount) and amount > 0 do
    character = conn.private.update_character || conn.character
    current = character.meta.coins || 0
    deducted = min(amount, current)
    meta = %{character.meta | coins: current - deducted}
    character = %{character | meta: meta}
    conn = put_character(conn, character)
    Records.save(character)
    conn
  end

  def run(conn, _data), do: conn
end
