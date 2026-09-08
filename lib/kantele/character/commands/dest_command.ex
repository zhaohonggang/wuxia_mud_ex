defmodule Kantele.Character.DestCommand do
  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView

  def run(conn, %{"target" => target} = _params) do
    character = conn.character

    case Access.wizardp(character) do
      false ->
        return_error(conn, "你没有巫师的权限。\n")

      true ->
        conn
        |> render(CommandView, "text", %{text: "对象 #{target} 已被删除。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def run(conn, _params) do
    character = conn.character

    case Access.wizardp(character) do
      false ->
        return_error(conn, "你没有巫师的权限。\n")

      true ->
        conn
        |> render(CommandView, "text", %{text: "用法: dest <对象ID>\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
