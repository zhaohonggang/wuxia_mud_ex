defmodule Kantele.Character.FeedCommand do
  @moduledoc """
  喂养命令：`feed <NPC>`

  对应 LPC cmds/usr/feed.c 的简化版。
  用食物喂养房间内的NPC，需要消耗背包中的食物道具。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.World.Items

  def run(conn, %{"name" => name}) do
    character = conn.character

    cond do
      character.attributes["ghost"] == true ->
        conn
        |> render(CommandView, "text", %{text: "你这个样子还是先照顾好自己吧。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        conn
        |> event("room/feed", %{name: name})
        |> assign(:prompt, false)
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要喂养谁？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
