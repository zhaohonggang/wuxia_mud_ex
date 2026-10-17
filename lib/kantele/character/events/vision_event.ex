defmodule Kantele.Character.VisionEvent do
  @moduledoc """
  房间 vision 广播（对应 LPC `message_vision`）

  发布方（命令/动作）调用：

      publish_message(conn, "rooms:\#{room_id}", template, [type: "vision"], &publish_error/2)

  频道总线把消息投递给房间内每个订阅者（含行动者自己），本事件按
  `from_pid == self()` 分流 echo/listen 渲染（与 `SayEvent.echo`
  同模式）。`template` 中的 `{name}` 由发布方预先替换，`{npc}` 保留
  交给 `VisionView` 按接收者替换。

  选择新起 `type: "vision"` 而不是复用 `"speech"`：后者会命中
  `SayEvent` 并被套上「说」的框架（`SayView`），与 vision 的无框架
  房间文案语义不符。
  """

  use Kalevala.Character.Event

  alias Kantele.Character.CommandView
  alias Kantele.Character.VisionView

  def interested?(event) do
    event.data.type == "vision" && match?("rooms:" <> _, event.data.channel_name)
  end

  def echo(conn, event) do
    conn
    |> assign(:character, event.data.character)
    |> assign(:text, event.data.text)
    |> render(VisionView, template(event))
    |> prompt(CommandView, "prompt", %{})
  end

  defp template(event) do
    case event.from_pid == self() do
      true -> "echo"
      false -> "listen"
    end
  end

  def subscribe_error(conn, _error), do: conn
end
