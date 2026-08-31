defmodule Kantele.Character.ToCommand do
  @moduledoc """
  to命令：`to`

  对应 LPC cmds/std/to.c
  多行信息发布。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"rest" => _rest}) do
    conn
    |> render(CommandView, "text", %{text: "to命令暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：to say | tell | chat ...\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
