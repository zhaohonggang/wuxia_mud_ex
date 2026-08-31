defmodule Kantele.Character.ReleaseCommand do
  @moduledoc """
  放生命令：`release`

  对应 LPC cmds/std/release.c
  放生宠物。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "放生系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
