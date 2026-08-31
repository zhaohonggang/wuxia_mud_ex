defmodule Kantele.Character.AnswerCommand do
  @moduledoc """
  回答命令：`answer`

  对应 LPC cmds/std/answer.c
  回答其他玩家的询问。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"message" => message}) do
    conn
    |> render(CommandView, "text", %{text: "回答系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要回答什么？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
