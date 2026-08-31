defmodule Kantele.Character.SearchCommand do
  @moduledoc """
  搜寻命令：`search`

  对应 LPC cmds/std/search.c
  在房间中搜寻物品。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "搜寻系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
