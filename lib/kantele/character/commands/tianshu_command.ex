defmodule Kantele.Character.TianshuCommand do
  @moduledoc """
  天书任务命令：`tianshu`

  对应 LPC cmds/usr/tianshu.c
  天书任务系统。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character
    tianshu = Map.get(character.meta, :tianshu)

    if tianshu do
      conn
      |> render(CommandView, "text", %{text: "你目前该完成#{tianshu}！\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
      |> render(CommandView, "text", %{text: "你现在没有天书的任务！\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end
end
