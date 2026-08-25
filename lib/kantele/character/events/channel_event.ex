defmodule Kantele.Character.ChannelEvent do
  use Kalevala.Character.Event

  alias Kantele.Character.ChannelView
  alias Kantele.Character.CommandView

  def interested?(event) do
    # 系统公告（announcement）走任意频道都渲染；普通聊天仍限 general
    event.data.type == "announcement" || match?("general", event.data.channel_name)
  end

  def echo(conn, event) do
    # prompt 必须用接收者的 character 渲染（conn.character）：
    # 下面 assign(:character, ...) 会把 assigns 覆盖成消息发送者
    # （系统公告的虚拟角色没有 meta.vitals，会导致 prompt 崩溃）
    character = conn.character

    conn
    |> assign(:channel_name, event.data.channel_name)
    |> assign(:character, event.data.character)
    |> assign(:id, event.data.id)
    |> assign(:text, event.data.text)
    |> render(ChannelView, template(event))
    |> prompt(CommandView, "prompt", %{character: character})
  end

  # type 为 announcement 的是系统公告（如世界加载失败），无真实发言角色
  defp template(%{data: %{type: "announcement"}}), do: "system"
  defp template(_event), do: "listen"

  def subscribe_error(conn, _error), do: conn
end
