defmodule Kantele.Character.AcceptCommand do
  @moduledoc """
  接受命令：`accept`

  对应 LPC cmds/std/accept.c
  接受挑战者的挑战。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "现在没有人来挑战。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
