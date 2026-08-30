defmodule Kantele.Character.ClsCommand do
  @moduledoc """
  清屏命令：`cls`

  对应 LPC cmds/usr/cls.c
  清除屏幕。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "\e[2J\e[H"})
    |> prompt(CommandView, "prompt", %{})
  end
end
