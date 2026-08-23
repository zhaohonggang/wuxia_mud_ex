defmodule Kantele.Combat.Broadcast do
  @moduledoc """
  战斗文案广播

  走房间频道 `rooms:<id>`，消息 `type: "combat"`；所有订阅者（含发起者）
  通过 `Kantele.Character.CombatEvent` 的 echo 渲染。
  """

  import Kalevala.Character.Conn

  @doc "替换占位符后向房间广播战斗文案"
  def publish(conn, text, bindings \\ %{}) do
    bindings = Enum.into(bindings, %{})

    publish_message(
      conn,
      "rooms:#{conn.character.room_id}",
      Kantele.Combat.Messages.interpolate(text, bindings),
      [type: "combat"],
      &publish_error/2
    )
  end

  def publish_error(conn, _error), do: conn
end
