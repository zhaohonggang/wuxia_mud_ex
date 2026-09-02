defmodule Kantele.Character.EnchaseCommand do
  @moduledoc """
  镶嵌命令：`enchase <宝石> in <武器>` / `enchase <武器> with <宝石>`
  对应 LPC cmds/skill/enchase.c。
  向已浸透的自制武器镶嵌宝石，赋予魔力属性（cold/fire/magic/lighting）。
  镶嵌数据落盘到物品实例 attrs["craft"]（运行时）。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Item.Craft
  alias Kantele.World.Items

  def run(conn, %{"arg" => arg}) do
    character = conn.character

    if is_nil(arg) or arg == "" do
      fail(conn, "你要往什么道具上镶嵌物品？\n")
    else
      case parse_args(arg) do
        {:ok, tessera_name, weapon_name} ->
          case find_items(character, tessera_name, weapon_name) do
            {:ok, tessera_item, tessera_instance, weapon_item, weapon_instance} ->
              check_and_enchase(conn, character, tessera_item, tessera_instance, weapon_item, weapon_instance)

            {:error, reason} ->
              fail(conn, reason <> "\n")
          end

        :error ->
          fail(conn, "你要往这上面镶嵌什么物品？\n格式：enchase <宝石> in <武器> 或 enchase <武器> with <宝石>\n")
      end
    end
  end

  def run(conn, %{}) do
    fail(conn, "你要往什么道具上镶嵌物品？\n格式：enchase <宝石> in <武器> 或 enchase <武器> with <宝石>\n")
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp parse_args(arg) do
    with [t, i, w] when i in ["in", "with"] <- String.split(arg, " ", parts: 3),
         tessera_name = String.trim(t),
         weapon_name = String.trim(w),
         true = tessera_name != "" and weapon_name != "" do
      {:ok, tessera_name, weapon_name}
    else
      _ -> :error
    end
  end

  defp find_items(character, tessera_name, weapon_name) do
    tessera_instance =
      Enum.find(character.inventory, fn inst ->
        item = Items.get!(inst.item_id)
        item.callback_module.matches?(item, tessera_name)
      end)

    weapon_instance =
      Enum.find(character.inventory, fn inst ->
        item = Items.get!(inst.item_id)
        item.callback_module.matches?(item, weapon_name)
      end)

    cond do
      is_nil(tessera_instance) ->
        {:error, "你身上没有这样东西可以用来镶嵌"}

      is_nil(weapon_instance) ->
        {:error, "你身上没有这样道具"}

      tessera_instance.id == weapon_instance.id ->
        {:error, "镶嵌的物品和目标不能是同一件"}

      true ->
        tessera_item = Items.get!(tessera_instance.item_id)
        weapon_item = Items.get!(weapon_instance.item_id)
        {:ok, tessera_item, tessera_instance, weapon_item, weapon_instance}
    end
  end

  defp check_and_enchase(conn, character, tessera_item, tessera_instance, weapon_item, weapon_instance) do
    weapon_meta = get_craft_meta(weapon_instance)
    player_meta = player_meta_for_craft(character)
    tessera_meta = get_tessera_meta(tessera_instance)

    case Craft.can_enchase?(weapon_meta, player_meta, tessera_meta) do
      :ok ->
        execute_enchase(conn, character, tessera_item, tessera_instance, weapon_item, weapon_instance, weapon_meta)

      {:error, reason} ->
        fail(conn, reason <> "\n")
    end
  end

  defp execute_enchase(conn, character, tessera_item, tessera_instance, weapon_item, weapon_instance, weapon_meta) do
    new_meta = Craft.do_enchase(weapon_meta, get_tessera_meta(tessera_instance))

    new_attrs = Map.put(instance_attrs(weapon_instance), "craft", new_meta)
    new_weapon_instance = %{weapon_instance | meta: new_attrs}

    new_inventory =
      character.inventory
      |> Enum.reject(&(&1.id == tessera_instance.id))
      |> Enum.map(fn i -> if i.id == weapon_instance.id, do: new_weapon_instance, else: i end)

    new_character = %{character | inventory: new_inventory}
    new_conn = put_character(conn, new_character)

    new_conn
    |> render(CommandView, "text", %{text: "你把#{tessera_item.name}镶嵌到了#{weapon_item.name}上，#{weapon_item.name}泛起了一阵#{Craft.chinese_s(Map.get(new_meta, :type))}的光芒！\n"})
    |> prompt(CommandView, "prompt", %{})
    |> Records.save(new_character)
  end

  defp get_craft_meta(instance) do
    (instance.meta || %{})["craft"] || %{}
  end

  defp get_tessera_meta(instance) do
    item = Items.get!(instance.item_id)
    %{
      name: item.name,
      can_be_enchased: true,
      magic: Kalevala.Meta.get(item.meta, "magic") || %{}
    }
  end

  defp player_meta_for_craft(character) do
    %{
      skills: character.meta.stats.skills
    }
  end

  defp instance_attrs(instance) do
    instance.meta || %{}
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end