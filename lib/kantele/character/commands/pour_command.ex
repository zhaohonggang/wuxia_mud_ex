defmodule Kantele.Character.PourCommand do
  @moduledoc """
  下毒命令：`pour <毒药> in <容器>`

  对应 LPC cmds/std/pour.c。
  向液体容器中下毒，需要毒药具备 can_pour 属性。
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
      |> render(CommandView, "text", %{text: "指令格式：pour <毒药> in <容器>\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      case find_poison_item(character, poison_name) do
        {:ok, poison_item, poison_instance} ->
          case find_liquid_container(character, target_name) do
            {:ok, container_item, container_instance} ->
              pour_liquid(conn, character, poison_item, poison_instance, container_item, container_instance)
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
    |> render(CommandView, "text", %{text: "指令格式：pour <毒药> in <容器>\n"})
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
        attrs = Map.get(item, :attrs, %{}) || %{}
        if attrs["can_pour"] == true && attrs["poison_type"] do
          {:ok, item, instance}
        else
          {:error, "这不是可用于投毒的药物。"}
        end
    end
  end

  defp find_liquid_container(character, name) do
    Enum.find(character.inventory, fn instance ->
      item = Items.get!(instance.item_id)
      item.callback_module.matches?(item, name)
    end)
    |> case do
      nil -> {:error, "你身上没有这样容器。"}
      instance ->
        item = Items.get!(instance.item_id)
        attrs = Map.get(item, :attrs, %{}) || %{}
        if attrs["liquid"] == true && is_integer(attrs["liquid/remaining"]) && attrs["liquid/remaining"] > 0 do
          {:ok, item, instance}
        else
          {:error, "这不是装有液体的容器。"}
        end
    end
  end

  defp pour_liquid(conn, character, poison_item, poison_instance, container_item, container_instance) do
    container_meta = container_item.meta || %{}
    container_attrs = Map.get(container_item, :attrs, %{}) || %{}

    if Kalevala.Meta.get(container_meta, :poison) do
      conn
      |> render(CommandView, "text", %{text: "这容器里的液体已经有毒了。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      # 构建毒药数据
      poison_data = %{
        "level" => Kalevala.Meta.get(poison_item.meta, "poison_level") || 100,
        "duration" => Kalevala.Meta.get(poison_item.meta, "poison_duration") || 300,
        "remain" => Kalevala.Meta.get(poison_item.meta, "poison_remain") || 10,
        "id" => poison_item.id,
        "name" => poison_item.name
      }

      # 将毒药效果加入容器 meta
      new_container_meta = Map.put(container_meta, :poison, poison_data)
      new_container_attrs = Map.put(container_attrs, "poisoned", true)

      # 更新物品实例
      updated_container = Map.put(container_item, :attrs, new_container_attrs)

      # 从背包移除毒药
      new_inventory = Enum.reject(character.inventory, &(&1.id == poison_instance.id))
      new_inventory = Enum.map(new_inventory, fn inst ->
        if inst.id == container_instance.id, do: updated_container, else: inst
      end)

      # 扣除毒药使用次数或直接移除
      poison_attrs = Map.get(poison_item, :attrs, %{}) || %{}
      if poison_attrs["remaining_uses"] && poison_attrs["remaining_uses"] > 1 do
        new_poison = Map.put(poison_item, :attrs, Map.put(poison_attrs, "remaining_uses", poison_attrs["remaining_uses"] - 1))
        new_inventory = Enum.map(new_inventory, fn inst ->
          if inst.id == poison_instance.id, do: new_poison, else: inst
        end)
      end

      new_character = %{character | inventory: new_inventory}
      new_conn = put_character(conn, new_character)

      new_conn
      |> render(CommandView, "text", %{text: "你把#{poison_item.name}倒进了#{container_item.name}里。\n"})
      |> prompt(CommandView, "prompt", %{})
      |> save()
    end
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end