defmodule Kantele.Character.PasswdCommand do
  @moduledoc """
  密码命令：`passwd`

  对应 LPC cmds/usr/passwd.c
  修改密码（简化版：不验证旧密码）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    if rest == "" do
      conn
      |> render(CommandView, "text", %{text: "指令格式：passwd <新密码>\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      set_password(conn, rest)
    end
  end

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：passwd <新密码>\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp set_password(conn, new_password) do
    if String.length(new_password) < 5 do
      conn
      |> render(CommandView, "text", %{text: "为了安全起见，密码长度必须大于五位。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      character = conn.character

      conn
      |> put_character(%{character | meta: %{character.meta | password: new_password}})
      |> save
      |> render(CommandView, "text", %{text: "密码变更成功。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp save(conn) do
    Records.save(current_character(conn))
    conn
  end

  defp current_character(conn), do: conn.private.update_character || conn.character
end
