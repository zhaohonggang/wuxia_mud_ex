defmodule Kantele.Character.ToppCommand do
  @moduledoc """
  排行榜p命令：`topp`

  对应 LPC cmds/usr/topp.c
  显示个人排行榜。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "排行榜暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
