defmodule Kantele.Character.PushCommand do
  @moduledoc """
  推人命令：`push`

  对应 LPC cmds/std/push.c
  推开妨碍的人。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"rest" => _rest}) do
    conn
    |> render(CommandView, "text", %{text: "推人系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：push <人物> to <方向>\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
