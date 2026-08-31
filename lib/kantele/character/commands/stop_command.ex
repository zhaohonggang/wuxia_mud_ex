defmodule Kantele.Character.StopCommand do
  @moduledoc """
  停止命令：`stop`

  对应 LPC cmds/std/stop.c
  让动物停止攻击。
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
    |> render(CommandView, "text", %{text: "你要让什么野兽停止咬人？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
