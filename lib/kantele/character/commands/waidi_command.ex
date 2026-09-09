defmodule Kantele.Character.WaidiCommand do
  @moduledoc """
  外族频道命令：`waidi on|off|<message>`

  - `waidi on`  ：订阅外族频道，接收入侵广播
  - `waidi off` ：取消订阅外族频道
  - `waidi <消息>` ：向外族频道发送消息（跨服喊话）
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"action" => action}) do
    case action do
      "on" -> on(conn, %{})
      "off" -> off(conn, {})
      nil -> render_help(conn)
      _ -> render_help(conn)
    end
  end

  def on(conn, _params) do
    conn
    |> subscribe("waidi", [], &subscribe_error/2)
    |> render(CommandView, "text", %{text: "你开始收听外族频道（waidi）。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def off(conn, _params) do
    conn
    |> unsubscribe("waidi", [], &unsubscribe_error/2)
    |> render(CommandView, "text", %{text: "你关闭了外族频道（waidi）。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def waidi(conn, %{"text" => text}) do
    conn
    |> publish_message("waidi", text, [], &publish_error/2)
    |> prompt(CommandView, "prompt", %{})
  end

  def waidi(conn, _params) do
    render_help(conn)
  end

  defp subscribe_error(conn, _error) do
    conn
    |> render(CommandView, "text", %{text: "你已经在收听外族频道了。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp unsubscribe_error(conn, _error) do
    conn
    |> render(CommandView, "text", %{text: "你没有收听外族频道。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp publish_error(conn, _error) do
    conn
    |> render(CommandView, "text", %{text: "发送失败。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp render_help(conn) do
    conn
    |> render(CommandView, "text", %{text: "用法：waidi on | waidi off | waidi <消息>\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end