defmodule Kantele.Character.HideCommand do
  @moduledoc """
  隐藏物品命令：`hide <物品ID>`

  对应 LPC cmds/usr/hide.c。
  将玩家身上的物品隐藏（遁去），需要 can_summon 登记和精力 >= 100。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Damage
  alias Kantele.World.Items

  @jingli_cost 100

  def run(conn, %{"item" => item_name}) do
    character = conn.character

    cond do
      character.attributes["ghost"] == true ->
        conn
        |> render(CommandView, "text", %{text: "等你还了阳再说吧。\n"})
        |> prompt(CommandView, "prompt", %{})

      !has_can_summon?(character, item_name) ->
        conn
        |> render(CommandView, "text", %{text: "你不知道如何隐藏这个物品。\n"})
        |> prompt(CommandView, "prompt", %{})

      insufficient_energy?(character) ->
        conn
        |> render(CommandView, "text", %{text: "你试图令#{item_name}遁去，可是精力不济，难以发挥它的能力。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        hide_item(conn, character, item_name)
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要隐藏什么物品？\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp has_can_summon?(character, item_name) do
    can_summon = character.attributes["can_summon"] || %{}
    Map.has_key?(can_summon, item_name)
  end

  defp insufficient_energy?(character) do
    vitals = character.meta.vitals
    jing = is_map(vitals) && Map.get(vitals, :jing, 0) || 0
    jing < @jingli_cost
  end

  defp hide_item(conn, character, item_name) do
    case find_item(character.inventory, item_name) do
      nil ->
        conn
        |> render(CommandView, "text", %{text: "你身上没有这样东西。\n"})
        |> prompt(CommandView, "prompt", %{})

      item_instance ->
        item = Items.get!(item_instance.item_id)

        {:ok, character} = Damage.receive_damage(character, :jing, @jingli_cost)

        character
        |> put_character(conn)
        |> event("item/hide", %{
          item_instance: item_instance,
          item: item,
          item_name: item.name
        })
        |> assign(:prompt, false)
    end
  end

  defp find_item(inventory, item_name) do
    Enum.find_value(inventory, fn item_instance ->
      item = Items.get!(item_instance.item_id)
      if Kantele.World.Item.matches?(item, item_name), do: item_instance
    end)
  end
end
