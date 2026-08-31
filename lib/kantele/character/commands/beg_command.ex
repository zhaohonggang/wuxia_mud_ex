defmodule Kantele.Character.BegCommand do
  @moduledoc """
  乞讨命令：`beg`

  对应 LPC cmds/std/beg.c
  向其他玩家乞讨财物。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"rest" => _rest}) do
    conn
    |> render(CommandView, "text", %{text: "乞讨系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：beg <物品> from <人物>\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
