defmodule Kantele.Character.StayCommand do
  @moduledoc """
  停留命令：`stay`

  对应 LPC cmds/std/stay.c
  让动物停止跟随。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "驯兽系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
