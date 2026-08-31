defmodule Kantele.Character.SemoteCommand do
  @moduledoc """
  表情列表命令：`semote`

  对应 LPC cmds/std/semote.c
  查看表情动词列表。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "表情系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
