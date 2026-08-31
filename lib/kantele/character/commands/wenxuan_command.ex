defmodule Kantele.Character.WenxuanCommand do
  @moduledoc """
  文选命令：`wenxuan`

  对应 LPC cmds/std/wenxuan.c
  查看文选。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "文选系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
