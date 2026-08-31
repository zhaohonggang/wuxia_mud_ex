defmodule Kantele.Character.MissCommand do
  @moduledoc """
  追寻命令：`miss <物品ID>`

  对应 LPC cmds/usr/miss.c。
  追寻玩家炼制的物品，需要 can_summon 登记和 magic/blood >= 3。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"item" => item}) do
    character = conn.character

    cond do
      character.attributes["ghost"] == true ->
        conn
        |> render(CommandView, "text", %{text: "等你还了阳再追寻吧。\n"})
        |> prompt(CommandView, "prompt", %{})

      character.meta.combat.enemies != [] ->
        conn
        |> render(CommandView, "text", %{text: "等你忙完了再说吧！\n"})
        |> prompt(CommandView, "prompt", %{})

      is_nil(character.attributes["can_summon"]) ||
          is_nil(character.attributes["can_summon"][item]) ->
        conn
        |> render(CommandView, "text", %{text: "你不知道如何追寻这个物品。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        conn
        |> event("miss/attempt", %{item_id: item})
        |> assign(:prompt, false)
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要追寻什么物品？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
