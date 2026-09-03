defmodule Kantele.Character.DestCommand do
  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView

  def run(conn, %{"target" => target}) do
    character = conn.character

    unless Access.wizardp(character) do
      return_error(conn, "你没有巫师的权限。")
    end

    conn
    |> render(CommandView, "text", %{text: "对象 #{target} 已被删除。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, _params) do
    character = conn.character

    unless Access.wizardp(character) do
      return_error(conn, "你没有巫师的权限。")
    end

    conn
    |> render(CommandView, "text", %{text: "用法: dest <对象ID>\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
