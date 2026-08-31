defmodule Kantele.Character.DrugCommand do
  @moduledoc """
  下毒命令：`drug <毒药> in <食物>`

  对应 LPC cmds/std/drug.c。
  向食物中下毒，需要毒药具备 can_drug 属性。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kalevala.Verb
  alias Kantele.World.Items
  alias Kantele.Poison

  def run(conn, %{"poison" => poison_name, "target" => target_name}) do
    character = conn.character

    if poison_name == "" or target_name == "" do
      conn
      |> render(CommandView, "text", %{text: "指令格式：drug <毒药> in <食物>\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      case find_poison_item(character, poison_name) do
        {:ok, poison_item, poison_instance} ->
          case find_food_item(character, target_name) do
            {:ok, food_item, food_instance} ->
              drug_food(conn, character, poison_item, poison_instance, food_item, food_instance)
            {:error, reason} ->
              conn
              |> render(CommandView, "text", %{text: reason <> "\n"})
              |> prompt(CommandView, "prompt", %{})
          end

        {:error, reason} ->
          conn
          |> render(CommandView, "text", %{text: reason <> "\n"})
          |> prompt(CommandView, "prompt", %{})
      end
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：drug <毒药> in <食物>\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp find_poison_item(character, name) do
    Enum.find(character.inventory, fn instance ->
      item = Items.get!(instance.item_id)
      item.callback_module.matches?(item, name)
    end)
    |> case do
      nil -> {:error, "你身上没有这样毒药。"}
      instance ->
        item = Items.get!(instance.item_id)
        attrs = item.attrs || %{}
        if attrs["can_drug"] == true && attrs["poison_type"] do
          {:ok, item, instance}
        else
          {:error, "这不是可用于下毒的药物。"}
        end
    end
  end

  defp find_food_item(character, name) do
    Enum.find(character.inventory, fn instance ->
      item = Items.get!(instance.item_id)
      item.callback_module.matches?(item, name)
    end)
    |> case do
      nil -> {:error, "你身上没有这样食物。"}
      instance ->
        item = Items.get!(instance.item_id)
        if Verb.has_matching_verb?(item.verbs, :eat, %Verb.Context{location: "inventory/self"}) do
          {:ok, item, instance}
        else
          {:error, "这不是可食用的食物。"}
        end
    end
  end

  defp drug_food(conn, character, poison_item, poison_instance, food_item, food_instance) do
    food_meta = food_item.meta || %{}
    food_attrs = food_item.attrs || %{}

    if food_meta[:poison] do
      conn
      |> render(CommandView, "text", %{text: "这食物里已经有毒了。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      # 构建毒药数据
      poison_data = %{
        "level" => poison_item.attrs["poison_level"] || 100,
        "duration" => poison_item.attrs["poison_duration"] || 300,
        "remain" => poison_item.attrs["poison_remain"] || 10,
        "id" => poison_item.id,
        "name" => poison_item.name
      }

      # 将毒药效果加入食物 meta
      new_food_meta = Map.put(food_meta, :poison, poison_data)
      new_food_attrs = Map.put(food_attrs, "poisoned", true)

      # 更新物品实例
      updated_food = %{
        food_item
        | meta: new_food_meta,
        attrs: new_food_attrs
      }

      # 从背包移除毒药
      new_inventory = Enum.reject(character.inventory, &(&1.id == poison_instance.id))
      new_inventory = Enum.map(new_inventory, fn inst ->
        if inst.id == food_instance.id, do: updated_food, else: inst
      end)

      # 扣除毒药使用次数或直接移除
      poison_attrs = poison_item.attrs || %{}
      if poison_attrs["remaining_uses"] && poison_attrs["remaining_uses"] > 1 do
        new_poison = %{poison_item | attrs: Map.put(poison_attrs, "remaining_uses", poison_attrs["remaining_uses"] - 1)}
        new_inventory = Enum.map(new_inventory, fn inst ->
          if inst.id == poison_instance.id, do: new_poison, else: inst
        end)
      end

      new_character = %{character | inventory: new_inventory}
      new_conn = put_character(conn, new_character)

      new_conn
      |> render(CommandView, "text", %{text: "你把#{poison_item.name}倒在了#{food_item.name}里。\n"})
      |> prompt(CommandView, "prompt", %{})
      |> save()
    end
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end