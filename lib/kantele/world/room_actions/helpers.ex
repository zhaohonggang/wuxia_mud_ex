defmodule Kantele.World.RoomActions.Helpers do
  @moduledoc """
  P5-1b-3 handler 共享 helper：把 LPC `message_vision` / `write` 语义桥接到
  Elixir 世界模型（房间广播 / 玩家私发）。各房间移植的 `do_*` 模块复用本模块，
  避免每个 handler 重复实现广播/输出细节。

  ## 与 LPC 的对应
  - `message_vision(msg, this_player())` → `broadcast_vision/3`：向房间频道
    `rooms:\#{room_id}` 广播 `type: "vision"` 消息，房间内每人（含行动者）都收到，
    由 `Kantele.Character.VisionEvent` 按 `from_pid` 分流 echo/listen 渲染。
  - `write(msg)` → `render_to_player/2`：只把文本推给当前玩家，不广播。
  """
  alias Kalevala.Character.Conn

  @doc """
  `message_vision(msg, this_player())` 等价。

  把 `template` 里 LPC 的 `$N`（行动者名字）替换为当前玩家名字后，向房间频道
  `rooms:\#{room_id}` 广播 `type: "vision"` 消息。房间内每个订阅者（含行动者
  自己）都会收到；`VisionEvent` 用 `from_pid == self()` 区分 echo（行动者）/
  listen（旁观者）渲染。

  返回更新后的 `conn`（`private.channel_changes` 增加一条 publish）。
  """
  def broadcast_vision(conn, room_id, template)
      when is_binary(room_id) and is_binary(template) do
    text = String.replace(template, "$N", actor_name(conn))

    Conn.publish_message(
      conn,
      "rooms:#{room_id}",
      text,
      [type: "vision"],
      &__MODULE__.publish_error/1
    )
  end

  @doc """
  `write(msg)` 等价：只把文本推给当前玩家（不广播）。

  返回更新后的 `conn`（`output` 增加一条 `Conn.Text`）。
  """
  def render_to_player(conn, text) when is_binary(text) do
    entry = %Conn.Text{data: text, newline: true}
    Map.put(conn, :output, conn.output ++ [entry])
  end

  defp actor_name(conn) do
    case Map.get(conn, :character) do
      %{name: name} when is_binary(name) and name != "" -> name
      _ -> "某人"
    end
  end

  @doc false
  def publish_error(conn, _error), do: conn
end
