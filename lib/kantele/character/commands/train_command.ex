defmodule Kantele.Character.TrainCommand do
  @moduledoc """
  驯兽命令：`train`

  对应 LPC cmds/std/train.c
  驯化野兽。
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
    |> render(CommandView, "text", %{text: "你要训练什么野兽？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
