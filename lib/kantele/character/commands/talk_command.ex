defmodule Kantele.Character.TalkCommand do
  @moduledoc """
  对话命令：`talk`

  对应 LPC cmds/std/talk.c
  与NPC对话。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"rest" => _rest}) do
    conn
    |> render(CommandView, "text", %{text: "对话系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：talk NPC [内容]\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
