defmodule Kantele.Character.SpecialCommand do
  @moduledoc """
  特技命令：`special`

  对应 LPC cmds/std/special.c
  查看或使用特技。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"skill" => _skill}) do
    conn
    |> render(CommandView, "text", %{text: "特技系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "特技系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
