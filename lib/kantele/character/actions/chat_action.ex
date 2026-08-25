defmodule Kantele.Character.ChatAction do
  @moduledoc """
  NPC 闲聊动作（A10/N3，对应 LPC chat_chance）

  brain 节点 `actions/chat`：从 `lines` 台词池随机挑一条，
  以普通说话（type: "speech"）发到所在房间频道。
  """

  use Kalevala.Character.Action

  @impl true
  def run(conn, params) do
    lines = Map.get(params, "lines", [])

    case lines do
      [] ->
        conn

      lines ->
        line = Enum.random(lines)

        publish_message(
          conn,
          "rooms:#{conn.character.room_id}",
          line,
          [],
          &publish_error/2
        )
    end
  end

  def publish_error(conn, _error), do: conn
end

defmodule Kantele.Brain.Conditions.Random do
  @moduledoc """
  概率条件（A10/N3）：data %{chance: n}，n 为百分比（1-100）

  每次节点求值独立掷骰，命中即放行后续 action。
  """

  @behaviour Kalevala.Brain.Condition

  @impl true
  def match?(_event, _conn, %{chance: chance}) when is_integer(chance) and chance > 0 do
    :rand.uniform(100) <= chance
  end

  def match?(_event, _conn, _data), do: false
end
