defmodule Kantele.Character.BeepCommand do
  @moduledoc """
  呼叫命令：`beep <玩家>`

  对应 LPC cmds/usr/beep.c
  发送呼叫音给其他玩家。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"target" => target}) do
    character = conn.character

    conn
    |> render(CommandView, "text", %{text: "你向#{target}发出呼叫。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
