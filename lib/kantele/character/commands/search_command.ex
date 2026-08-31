defmodule Kantele.Character.SearchCommand do
  @moduledoc """
  搜寻命令：`search`

  对应 LPC cmds/std/search.c。
  在房间中搜寻可获取的物品，消耗精和气。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character

    qi = Map.get(character.attributes, "qi", 0)
    jing = Map.get(character.attributes, "jing", 0)

    if qi < 30 do
      conn
      |> render(CommandView, "text", %{text: "你的气不足，无法进行搜寻。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
      |> event("search/attempt", %{})
      |> assign(:prompt, false)
    end
  end
end
