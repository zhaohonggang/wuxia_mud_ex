defmodule Kantele.Character.ComeCommand do
  @moduledoc """
  驯兽跟随命令：`come`

  对应 LPC cmds/std/come.c
  让动物跟随。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"target" => _target}) do
    conn
    |> render(CommandView, "text", %{text: "驯兽系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要让什么野兽跟随你？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
