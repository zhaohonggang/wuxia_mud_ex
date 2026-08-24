defmodule Kantele.Character.DrinkCommand do
  @moduledoc """
  喝药水回血：`drink 药水` / `drink potion` / 简写 `heal`

  消耗背包里的一瓶药水，恢复气血与内力。
  """

  use Kalevala.Character.Command

  alias Kalevala.World.Item
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.Vitals
  alias Kantele.World.Items

  def run(conn, params) do
    character = conn.character

    case find_potion(character.inventory) do
      nil ->
        render(conn, CommandView, "text", %{text: "你身上没有药水了。\n"})

      instance ->
        drink(conn, character, instance, params)
    end
  end

  defp find_potion(inventory) do
    Enum.find(inventory, fn instance ->
      instance.item_id == "global:potion"
    end)
  end

  defp drink(conn, character, instance, _params) do
    heal_qi = 80
    heal_neili = 50

    vitals =
      character.meta.vitals
      |> Map.put(:qi, min(character.meta.vitals.qi + heal_qi, character.meta.vitals.max_qi))
      |> Map.put(
        :neili,
        min(character.meta.vitals.neili + heal_neili, character.meta.vitals.max_neili)
      )

    inventory = Enum.reject(character.inventory, &(&1.id == instance.id))
    character = %{character | inventory: inventory} |> put_vitals(vitals)

    item = Items.get!(instance.item_id)

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{
      text: "你仰头喝下#{item.name}，一股暖流涌遍全身，伤势顿时好转。(气血+#{heal_qi} 内力+#{heal_neili})"
    })
    |> prompt(CommandView, "prompt")
    |> tap_save()
  end

  defp put_vitals(character, vitals),
    do: %{character | meta: Map.put(character.meta, :vitals, vitals)}

  defp tap_save(conn) do
    Kantele.Character.Records.save(current_character(conn))
    conn
  end

  defp current_character(conn), do: conn.private.update_character || conn.character
end
