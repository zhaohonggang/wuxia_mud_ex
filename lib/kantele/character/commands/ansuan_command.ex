defmodule Kantele.Character.AnsuanCommand do
  @moduledoc """
  暗算命令：`ansuan`

  对应 LPC cmds/std/ansuan.c
  暗中袭击他人。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"rest" => _rest}) do
    conn
    |> render(CommandView, "text", %{text: "暗算系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "暗算系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
