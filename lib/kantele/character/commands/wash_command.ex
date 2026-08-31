defmodule Kantele.Character.WashCommand do
  @moduledoc """
  清洗命令：`wash`

  对应 LPC cmds/std/wash.c
  清洗武器或防具上的毒。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"target" => _target}) do
    conn
    |> render(CommandView, "text", %{text: "清洗系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要洗什么？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
