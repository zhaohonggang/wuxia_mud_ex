defmodule Kantele.Character.SaveCommand do
  @moduledoc """
  储存命令：`save`

  对应 LPC cmds/usr/save.c
  储存游戏进度。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "储存系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
