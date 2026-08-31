defmodule Kantele.Character.OptionCommand do
  @moduledoc """
  设置命令：`option`

  对应 LPC cmds/usr/option.c
  查看和设置用户选项。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "选项系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
