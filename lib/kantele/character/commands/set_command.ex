defmodule Kantele.Character.SetCommand do
  @moduledoc """
  环境变量命令：`set`

  对应 LPC cmds/usr/set.c
  设置环境变量。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "环境变量系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
