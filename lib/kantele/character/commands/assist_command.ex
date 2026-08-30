defmodule Kantele.Character.AssistCommand do
  @moduledoc """
  协助命令：`assist`

  对应 LPC cmds/usr/assist.c
  帮助其他玩家完成任务。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"target" => _target}) do
    conn
    |> render(CommandView, "text", %{text: "协助系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "协助系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
