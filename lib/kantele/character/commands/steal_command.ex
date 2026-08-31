defmodule Kantele.Character.StealCommand do
  @moduledoc """
  偷窃命令：`steal`

  对应 LPC cmds/std/steal.c
  偷取他人财物。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"rest" => _rest}) do
    conn
    |> render(CommandView, "text", %{text: "偷窃系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：steal <物品> from <人物>\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
