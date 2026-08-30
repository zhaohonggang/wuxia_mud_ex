defmodule Kantele.Character.PkdCommand do
  @moduledoc """
  屠人场命令：`pkd`

  对应 LPC cmds/usr/pkd.c
  查看屠人场参与者。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "屠人场暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
