defmodule Web.SocketHandler do
  @moduledoc """
  包装 Kalevala 的 WebSocket 处理器

  唯一职责：把 cowboy 的 websocket 空闲超时设为无限。
  浏览器会对后台标签页节流定时器，5 秒心跳可能被推迟到分钟级，
  默认 60 秒 idle_timeout 会把挂机玩家踢下线。

  注意：idle_timeout 必须放在 init/2 的升级返回选项里；
  websocket_init 的第三元素只接受整数毫秒或 hibernate。
  """

  @behaviour :cowboy_websocket

  @ws_opts %{idle_timeout: :infinity}

  @impl true
  def init(req, opts) do
    case Kalevala.Websocket.Handler.init(req, opts) do
      {:cowboy_websocket, req, state} -> {:cowboy_websocket, req, state, @ws_opts}
      other -> other
    end
  end

  @impl true
  defdelegate websocket_init(state), to: Kalevala.Websocket.Handler

  @impl true
  defdelegate websocket_handle(frame, state), to: Kalevala.Websocket.Handler

  @impl true
  defdelegate websocket_info(message, state), to: Kalevala.Websocket.Handler

  @impl true
  defdelegate terminate(reason, req, state), to: Kalevala.Websocket.Handler
end
