defmodule Kantele.Character.PasswdCommand do
  @moduledoc """
  密码命令：`passwd`

  对应 LPC cmds/usr/passwd.c
  修改密码。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "密码系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
