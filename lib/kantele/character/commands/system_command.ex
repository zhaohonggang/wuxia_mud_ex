defmodule Kantele.Character.SystemCommand do
  @moduledoc """
  系统命令：`system`

  对应 LPC cmds/usr/system.c
  显示系统资源使用情况。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "系统信息暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
