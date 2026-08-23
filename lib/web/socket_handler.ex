defmodule Web.SocketHandler do
  @moduledoc """
  包装 Kalevala 的 WebSocket 处理器

  唯一职责：把 cowboy 的 websocket 空闲超时设为无限。
  浏览器会对后台标签页节流定时器，5 秒心跳可能被推迟到分钟级，
  默认 60 秒 idle_timeout 会把挂机玩家踢下线。
  """

  @behaviour :cowboy_websocket

  @impl true
  def init(req, opts), do: Kalevala.Websocket.Handler.init(req, opts)

  @impl true
  def websocket_init(state) do
    case Kalevala.Websocket.Handler.websocket_init(state) do
      {:ok, state} -> {:ok, state, %{idle_timeout: :infinity}}
      other -> other
    end
  end

  @impl true
  def websocket_handle(frame, state),
    do: Kalevala.Websocket.Handler.websocket_handle(frame, state)

  @impl true
  def websocket_info(message, state),
    do: Kalevala.Websocket.Handler.websocket_info(message, state)

  @impl true
  def terminate(reason, req, state),
    do: Kalevala.Websocket.Handler.terminate(reason, req, state)
end
