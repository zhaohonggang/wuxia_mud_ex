defmodule Kantele.Character.CheckCommand do
  @moduledoc """
  查探命令：`check`

  对应 LPC cmds/std/check.c
  查探其他玩家的技能。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"target" => _target}) do
    conn
    |> render(CommandView, "text", %{text: "查探系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：check|dating <某人>\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
