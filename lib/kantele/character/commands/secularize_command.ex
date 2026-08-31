defmodule Kantele.Character.SecularizeCommand do
  @moduledoc """
  还俗命令：`secularize`

  对应 LPC cmds/std/secularize.c
  放弃出家生活。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "还俗系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
