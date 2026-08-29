defmodule Kantele.Character.DrinkCommand do
  @moduledoc """
  喝药水：`drink <物品>`（别名 `喝`、`heal`）

  消耗背包里一件可喝物品（verbs 含 drink），效果来自 Item.Meta.medicine，
  经 `Kantele.Item.Effect.consume/3` 数据驱动解读（恢复气血/精力/内力等）。
  与 `eat` 共用同一效果层；未来液体容器（Liquid fill level）可扩展于此。
  """

  use Kalevala.Character.Command

  alias Kalevala.Verb
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Item.Effect
  alias Kantele.World.Items

  def run(conn, %{"item_name" => item_name}) do
    character = conn.character

    case find_instance(character.inventory, item_name) do
      nil ->
        conn
        |> render(CommandView, "text", %{text: "你身上没有这样东西。\n"})
        |> prompt(CommandView, "prompt", %{})

      instance ->
        item = Items.get!(instance.item_id)

        if drinkable?(item) do
          drink(conn, character, instance, item)
        else
          conn
          |> render(CommandView, "text", %{text: "#{item.name} 可没法往嘴里灌。\n"})
          |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  defp find_instance(inventory, item_name) do
    Enum.find(inventory, fn instance ->
      item = Items.get!(instance.item_id)
      instance.id == item_name || item.callback_module.matches?(item, item_name)
    end)
  end

  defp drinkable?(item) do
    Verb.has_matching_verb?(item.verbs, :drink, %Verb.Context{location: "inventory/self"})
  end

  defp drink(conn, character, instance, item) do
    meta = item.meta || %{}
    vitals = character.meta.vitals || %{}
    stats = character.meta.stats || %{}

    case Effect.consume(vitals, stats, meta) do
      {:reject, reason} ->
        conn
        |> render(CommandView, "text", %{text: "#{reason}\n"})
        |> prompt(CommandView, "prompt", %{})

      {:ok, effect} ->
        new_meta = character.meta |> Map.put(:vitals, effect.vitals) |> Map.put(:stats, effect.stats)
        character =
          %{character | inventory: drop_instance(character.inventory, instance), meta: new_meta}

        text =
          if effect.parts == [] do
            "你仰头喝下#{item.name}，顿觉神清气爽。\n"
          else
            "你仰头喝下#{item.name}，一股暖流涌遍全身，伤势顿时好转。（#{Enum.join(
              effect.parts,
              " "
            )}）\n"
          end

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{text: text})
        |> prompt(CommandView, "prompt", %{})
        |> save()
    end
  end

  defp drop_instance(inventory, instance) do
    Enum.reject(inventory, &(&1.id == instance.id))
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end
