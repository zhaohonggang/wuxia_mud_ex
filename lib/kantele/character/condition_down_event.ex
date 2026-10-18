defmodule Kantele.Character.ConditionDownEvent do
  @moduledoc """
  条件致倒事件宿主（P5-1c，full `bi`）。

  由 `Kantele.Character.ConditionEvent.tick/2` 在 NPC 气/精被条件拖到 0 时经
  `send(self(), %Event{topic: "condition/down", ...})` 自投递（对应 LPC
  `receive_wound` 归零 → `unconcious()`/`die()`）。

  处理：
  1. 按 `DownHandlers.lookup/1` 查 NPC 专属处决函数，命中则执行
     `fun(conn, %{cause: cause})`（由 handler 负责播报、通知对手、落死）。
  2. 清掉自身条件（`session.conditions`），停止 `condition/tick` 心跳，避免
     归零后继续掉血/反复触发。

  未登记处决函数的宿主（玩家 / 其它 NPC）**不在此处理**，保持既有语义（P7）。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn, only: [put_session: 3]

  alias Kantele.World.NpcActions.DownHandlers

  def run(conn, event) do
    cause = Map.get(event.data, :cause, :qi)

    case DownHandlers.lookup(conn.character) do
      {:ok, {module, function}} ->
        conn = apply(module, function, [conn, %{cause: cause}])
        clear_conditions(conn)

      :not_handled ->
        conn
    end
  end

  defp clear_conditions(conn), do: put_session(conn, "conditions", nil)
end
