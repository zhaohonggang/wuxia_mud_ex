defmodule Kantele.Character.StealCommand do
  @moduledoc """
  偷窃命令：`steal <物品> from <人物>`

  对应 LPC cmds/std/steal.c 的移植。
  使用 stealing 技能判定，成功则转移物品，失败可能被发觉并触发战斗。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"item" => item, "target" => target}) do
    if item == "" or target == "" do
      conn
      |> render(CommandView, "text", %{text: "指令格式：steal <物品> from <人物>\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
      |> event("steal/attempt", %{item: item, target: target})
      |> assign(:prompt, false)
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：steal <物品> from <人物>\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
