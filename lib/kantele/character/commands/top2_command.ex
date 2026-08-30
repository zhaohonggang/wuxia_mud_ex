defmodule Kantele.Character.Top2Command do
  @moduledoc """
  排行榜2命令：`top2`

  对应 LPC cmds/usr/top2.c
  显示排行榜2。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "排行榜暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
