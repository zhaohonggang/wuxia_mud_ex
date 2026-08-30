defmodule Kantele.Character.SchemeCommand do
  @moduledoc """
  计划命令：`scheme [show|set|cancel]`

  对应 LPC cmds/usr/scheme.c
  制订个人计划。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character
    scheme = Map.get(character.meta, :schedule)

    if scheme do
      conn
      |> render(CommandView, "text", %{text: "你目前制订的计划如下：\n#{scheme}\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
      |> render(CommandView, "text", %{text: "你目前并没有制订任何计划。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end
end
