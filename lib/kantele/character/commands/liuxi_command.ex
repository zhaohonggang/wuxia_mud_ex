defmodule Kantele.Character.LiuxiCommand do
  @moduledoc """
  柳溪命令：`liuxi`

  对应 LPC cmds/std/liuxi.c
  前往柳溪镇。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "柳溪系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
