defmodule Kantele.Character.DaubCommand do
  @moduledoc """
  涂毒命令：`daub <毒药> on <武器/防具/hand>`

  对应 LPC cmds/std/daub.c。
  向武器、防具或手上涂毒，需要毒药具备 can_daub 属性。
  包含技能判定（force + poison vs poison level），混毒逻辑，自毒检测。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kalevala.Verb
  alias Kantele.World.Items
  alias Kantele.Poison

  def run(conn, %{"poison" => poison_name, "target" => target_name}) do
    character = conn.character

    if poison_name == "" or target_name == "" do
      conn
      |> render(CommandView, "text", %{text: "指令格式：daub <毒药> on <武器/防具/hand>\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      case find_poison_item(character, poison_name) do
        {:ok, poison_item, poison_instance} ->
          case find_daub_target(character, target_name) do
            {:ok, target_type, target_item, target_instance} ->
              daub_target(conn, character, poison_item, poison_instance, target_type, target_item, target_instance)
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
    |> render(CommandView, "text", %{text: "指令格式：daub <毒药> on <武器/防具/hand>\n"})
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
        attrs = item.meta || %{}
        if attrs["can_daub"] == true && attrs["poison_type"] do
          {:ok, item, instance}
        else
          {:error, "这不是可用于涂毒的药物。"}
        end
    end
  end

  defp find_daub_target(character, name) do
    name_lower = String.downcase(name)

    # 先检查 hand
    if name_lower in ["hand", "手"] do
      {:ok, :hand, nil, nil}
    else
      # 在背包中查找装备
      Enum.find(character.inventory, fn instance ->
        item = Items.get!(instance.item_id)
        item.callback_module.matches?(item, name)
      end)
      |> case do
        nil -> {:error, "你身上没有这样武器或防具。"}
        instance ->
          item = Items.get!(instance.item_id)
          attrs = item.meta || %{}
          type = Kalevala.Meta.get(attrs, "type")

          cond do
            type in ["weapon", "sword", "blade", "axe", "hammer", "staff"] ->
              {:ok, :weapon, item, instance}
            type in ["armor", "cloth", "surcoat", "boots"] ->
              {:ok, :armor, item, instance}
            true ->
              {:error, "这不是可涂毒的武器或防具。"}
          end
      end
    end
  end

  defp daub_target(conn, character, poison_item, poison_instance, :hand, _item, _instance) do
    # 涂毒手部 - 检查技能
    if can_apply_poison_to_hand?(character, poison_item) do
      apply_poison_to_hand(conn, character, poison_item, poison_instance)
    else
      conn
      |> render(CommandView, "text", %{text: "你的毒技不够纯熟，无法涂毒手部。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp daub_target(conn, character, poison_item, poison_instance, :weapon, weapon_item, weapon_instance) do
    if can_apply_poison_to_weapon?(character, poison_item, weapon_item) do
      apply_poison_to_equipment(conn, character, poison_item, poison_instance, weapon_item, weapon_instance, :weapon)
    else
      conn
      |> render(CommandView, "text", %{text: "你的毒技不够纯熟，无法给武器涂毒。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp daub_target(conn, character, poison_item, poison_instance, :armor, armor_item, armor_instance) do
    if can_apply_poison_to_armor?(character, poison_item, armor_item) do
      apply_poison_to_equipment(conn, character, poison_item, poison_instance, armor_item, armor_instance, :armor)
    else
      conn
      |> render(CommandView, "text", %{text: "你的毒技不够纯熟，无法给防具涂毒。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp can_apply_poison_to_hand?(character, poison_item) do
    force_skill = character.meta.stats.skills["force"] || 0
    poison_skill = character.meta.stats.skills["poison"] || 0
    poison_level = Kalevala.Meta.get(poison_item.meta, "poison_level") || 100

    # 需要 force + poison >= poison_level
    force_skill + poison_skill >= poison_level
  end

  defp can_apply_poison_to_weapon?(character, poison_item, weapon_item) do
    force_skill = character.meta.stats.skills["force"] || 0
    poison_skill = character.meta.stats.skills["poison"] || 0
    poison_level = Kalevala.Meta.get(poison_item.meta, "poison_level") || 100

    force_skill + poison_skill >= div(poison_level, 2)
  end

  defp can_apply_poison_to_armor?(character, poison_item, armor_item) do
    force_skill = character.meta.stats.skills["force"] || 0
    poison_skill = character.meta.stats.skills["poison"] || 0
    poison_level = Kalevala.Meta.get(poison_item.meta, "poison_level") || 100

    force_skill + poison_skill >= div(poison_level, 3)
  end

  defp apply_poison_to_hand(conn, character, poison_item, poison_instance) do
    # 检查手上是否已有毒
    existing_daub = character.meta.temp["daub/hand"]

    merged =
      if existing_daub do
        # 混毒
        new_poison = %{
          "level" => Kalevala.Meta.get(poison_item.meta, "poison_level") || 100,
          "duration" => Kalevala.Meta.get(poison_item.meta, "poison_duration") || 300,
          "remain" => Kalevala.Meta.get(poison_item.meta, "poison_remain") || 10,
          "id" => poison_item.id,
          "name" => poison_item.name
        }

        existing = character.meta.temp["daub/hand"]
        Kantele.Poison.mixed_poison(existing, new_poison)
      else
        %{
          "level" => Kalevala.Meta.get(poison_item.meta, "poison_level") || 100,
          "duration" => Kalevala.Meta.get(poison_item.meta, "poison_duration") || 300,
          "remain" => Kalevala.Meta.get(poison_item.meta, "poison_remain") || 10,
          "id" => poison_item.id,
          "name" => poison_item.name
        }
      end

    # 自毒检测
    if check_self_poison(character, merged) do
      conn
      |> render(CommandView, "text", %{text: "你一不小心弄到自己手上了！\n"})
      |> event("poison/apply", %{target: "self", poison: merged})
      |> prompt(CommandView, "prompt", %{})
    else
      new_temp = Map.put(character.meta.temp, "daub/hand", merged)
      new_meta = Map.put(character.meta, :temp, new_temp)
      new_character = %{character | meta: new_meta}
      new_conn = put_character(conn, new_character)

      new_conn
      |> render(CommandView, "text", %{text: "你把#{poison_item.name}抹在了手上。\n"})
      |> prompt(CommandView, "prompt", %{})
      |> save()
    end
  end

  defp apply_poison_to_equipment(conn, character, poison_item, poison_instance, equip_item, equip_instance, equip_type) do
    instance_meta = equip_instance.meta || %{}

    merged =
      if instance_meta["daub"] do
        # 混毒
        new_poison = %{
          "level" => Kalevala.Meta.get(poison_item.meta, "poison_level") || 100,
          "duration" => Kalevala.Meta.get(poison_item.meta, "poison_duration") || 300,
          "remain" => Kalevala.Meta.get(poison_item.meta, "poison_remain") || 10,
          "id" => poison_item.id,
          "name" => poison_item.name
        }

        existing = instance_meta["daub"]
        Kantele.Poison.mixed_poison(existing, new_poison)
      else
        %{
          "level" => Kalevala.Meta.get(poison_item.meta, "poison_level") || 100,
          "duration" => Kalevala.Meta.get(poison_item.meta, "poison_duration") || 300,
          "remain" => Kalevala.Meta.get(poison_item.meta, "poison_remain") || 10,
          "id" => poison_item.id,
          "name" => poison_item.name
        }
      end

    # 更新装备实例的 meta
    new_instance_meta = Map.put(instance_meta, "daub", merged)
    new_equip_instance = %{equip_instance | meta: new_instance_meta}

    # 更新背包
    new_inventory = Enum.map(character.inventory, fn inst ->
      if inst.id == equip_instance.id, do: new_equip_instance, else: inst
    end)

    # 移除毒药
    new_inventory = Enum.reject(new_inventory, &(&1.id == poison_instance.id))

    new_character = %{character | inventory: new_inventory}
    new_conn = put_character(conn, new_character)

    new_conn
    |> render(CommandView, "text", %{text: "你把#{poison_item.name}抹在了#{equip_item.name}上。\n"})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  defp check_self_poison(character, poison) do
    # 自毒概率：基于 poison skill
    poison_skill = character.meta.stats.skills["poison"] || 0
    chance = div(100, max(div(poison_skill, 10), 1))
    :rand.uniform(100) <= chance
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end