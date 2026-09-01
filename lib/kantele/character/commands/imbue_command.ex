defmodule Kantele.Character.ImbueCommand do
  @moduledoc """
  浸入命令：`imbue <特殊物品> in <武器>` / `imbue <武器> with <特殊物品>`
  对应 LPC cmds/skill/imbue.c。
  向已圣化的自制武器浸入材料，消耗材料并提升武器威力。
  浸入数据落盘到物品实例 attrs["craft"]（运行时）。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Item.Craft
  alias Kantele.World.Items

  def run(conn, %{"arg" => arg}) do
    character = conn.character

    if is_nil(arg) or arg == "" do
      fail(conn, "你要往什么道具上浸入其他物品？\n")
    else
      case parse_args(arg) do
        {:ok, special_name, weapon_name} ->
          case find_items(character, special_name, weapon_name) do
            {:ok, special_item, special_instance, weapon_item, weapon_instance} ->
              check_and_imbue(conn, character, special_item, special_instance, weapon_item, weapon_instance)

            {:error, reason} ->
              fail(conn, reason <> "\n")
          end

        :error ->
          fail(conn, "你要往这上面浸入什么物品？\n格式：imbue <特殊物品> in <武器> 或 imbue <武器> with <特殊物品>\n")
      end
    end
  end

  def run(conn, %{}) do
    fail(conn, "你要往什么道具上浸入其他物品？\n格式：imbue <特殊物品> in <武器> 或 imbue <武器> with <特殊物品>\n")
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp parse_args(arg) do
    with [s, i, w] when i in ["in", "with"] <- String.split(arg, " ", parts: 3),
         special_name = String.trim(s),
         weapon_name = String.trim(w),
         true = special_name != "" and weapon_name != "" do
      {:ok, special_name, weapon_name}
    else
      _ -> :error
    end
  end

  defp find_items(character, special_name, weapon_name) do
    special_instance =
      Enum.find(character.inventory, fn inst ->
        item = Items.get!(inst.item_id)
        item.callback_module.matches?(item, special_name)
      end)

    weapon_instance =
      Enum.find(character.inventory, fn inst ->
        item = Items.get!(inst.item_id)
        item.callback_module.matches?(item, weapon_name)
      end)

    cond do
      is_nil(special_instance) ->
        {:error, "你身上没有这样东西可以用来浸入"}

      is_nil(weapon_instance) ->
        {:error, "你身上没有这样道具"}

      special_instance.id == weapon_instance.id ->
        {:error, "浸入的物品和目标不能是同一件"}

      true ->
        special_item = Items.get!(special_instance.item_id)
        weapon_item = Items.get!(weapon_instance.item_id)
        {:ok, special_item, special_instance, weapon_item, weapon_instance}
    end
  end

  defp check_and_imbue(conn, character, special_item, special_instance, weapon_item, weapon_instance) do
    weapon_meta = get_craft_meta(weapon_instance)
    special_meta = get_item_meta(special_instance)

    case Craft.can_imbue?(weapon_meta, %{}, special_meta) do
      :ok ->
        execute_imbue(conn, character, special_item, special_instance, weapon_item, weapon_instance, weapon_meta)

      {:error, reason} ->
        fail(conn, reason <> "\n")
    end
  end

  defp execute_imbue(conn, character, special_item, special_instance, weapon_item, weapon_instance, weapon_meta) do
    {:ok, new_meta} = Craft.do_imbue(weapon_meta)

    new_attrs = Map.put(instance_attrs(weapon_instance), "craft", new_meta)
    new_weapon_instance = %{weapon_instance | meta: new_attrs}

    new_inventory =
      character.inventory
      |> Enum.reject(&(&1.id == special_instance.id))
      |> Enum.map(fn i -> if i.id == weapon_instance.id, do: new_weapon_instance, else: i end)

    new_character = %{character | inventory: new_inventory}
    new_conn = put_character(conn, new_character)

    new_conn
    |> render(CommandView, "text", %{text: "你把#{special_item.name}浸入了#{weapon_item.name}，#{weapon_item.name}泛起了一阵微光。\n"})
    |> prompt(CommandView, "prompt", %{})
    |> Records.save(new_character)
  end

  defp get_craft_meta(instance) do
    (instance.meta || %{})["craft"] || %{}
  end

  defp get_item_meta(instance) do
    item = Items.get!(instance.item_id)
    item.meta || %{}
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