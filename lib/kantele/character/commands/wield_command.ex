defmodule Kantele.Character.WieldCommand do
  @moduledoc """
  装备命令：`wield <武器>` / `wear <护甲>` / `unwield <武器>` / `remove <护甲>`

  使用 Kantele.Item.Equip 纯层决策：
  - two_handed?/secondary? 判定武器类型（flag 位掩码）
  - wield_decision 决定装备槽位（主手/副手/交换/报错）
  - wield_state/unequip_state 累加/扣减武器 prop 到 temp_applies
  - wear_state/unequip_state 累加/扣减护甲 + prop

  装备文案（P3-a，激活 B5a/B5b 回填的 `Item.Meta.messages`）：
  物品带自定义文案（LPC `wield_msg`/`unwield_msg`/`wear_msg`/`remove_msg`/
  `unequip_msg` 的转换产物，占位符 `{npc}`/`{name}`）时，按 LPC
  `message_vision` 语义走房间广播（`VisionEvent`，自己收到时 `{npc}`→"你"）；
  无自定义文案的路径保持原硬编码默认文案（只给自己看）不变。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Item.Equip
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  def wield(conn, %{"item_name" => item_name}) do
    equip_weapon(conn, item_name)
  end

  def wear(conn, %{"item_name" => item_name}) do
    equip_armor(conn, item_name)
  end

  def unwield(conn, %{"item_name" => item_name} = _params) do
    character = conn.character
    weapon_snap = Combat.weapon(character.meta.combat)

    cond do
      weapon_snap != nil && snapshot_matches?(weapon_snap, item_name) ->
        # 卸下主手武器：扣减 prop，清空槽位
        combat =
          character.meta.combat
          |> Combat.unequip(:weapon)
          |> subtract_weapon_prop(weapon_snap)

        conn
        |> put_character(%{character | meta: %{character.meta | combat: combat}})
        |> equip_feedback(
          equipped_item(character, Map.get(weapon_snap, :name)),
          [:unwield, :unequip],
          "你卸下了#{Map.get(weapon_snap, :name)}。\n"
        )

      true ->
        # 尝试卸下副手武器
        secondary_snap = Map.get(character.meta.combat.equipped, :secondary_weapon)

        if secondary_snap && snapshot_matches?(secondary_snap, item_name) do
          combat =
            character.meta.combat
            |> Combat.unequip(:secondary_weapon)
            |> subtract_weapon_prop(secondary_snap)

          conn
          |> put_character(%{character | meta: %{character.meta | combat: combat}})
          |> equip_feedback(
            equipped_item(character, Map.get(secondary_snap, :name)),
            [:unwield, :unequip],
            "你卸下了#{Map.get(secondary_snap, :name)}。\n"
          )
        else
          render_error(conn, "你没有装备这样东西。\n")
        end
    end
  end

  def remove(conn, %{"item_name" => item_name} = _params) do
    character = conn.character

    slot =
      Enum.find_value(character.meta.combat.equipped, fn
        {:weapon, _snap} -> nil
        {:secondary_weapon, _snap} -> nil
        {:handing, _snap} -> nil
        {slot, snap} -> if snapshot_matches?(snap, item_name), do: slot
      end)

    case slot do
      nil ->
        render_error(conn, "你没有装备这样东西。\n")

      slot ->
        snap = get_in(character.meta.combat.equipped, [slot])

        combat =
          character.meta.combat
          |> Combat.unequip(slot)
          |> subtract_armor_prop(snap)

        conn
        |> put_character(%{character | meta: %{character.meta | combat: combat}})
        |> equip_feedback(
          equipped_item(character, Map.get(snap, :name)),
          [:remove, :unequip],
          "你卸下了#{Map.get(snap, :name)}。\n"
        )
    end
  end

  # ---- 武器：使用 Equip.wield_decision 决定槽位 ----

  defp equip_weapon(conn, item_name) do
    character = conn.character

    with_item(conn, character, item_name, fn item ->
      flag = Map.get(item.meta, :flag, 1)
      damage = Map.get(item.meta, :damage)

      cond do
        is_nil(damage) or damage <= 0 ->
          render_error(conn, "#{item.name}不能这样装备。\n")

        true ->
          state = build_equip_state(character.meta.combat)

          case Equip.wield_decision(flag, state) do
            {:error, msg} ->
              render_error(conn, msg)

            {:weapon} ->
              # 装备到主手：需先清空原主手/副手/handing
              combat =
                clear_weapon_slots(character.meta.combat)
                |> put_weapon_snapshot(item, :weapon)
                |> apply_weapon_prop(item)

              conn
              |> put_character(%{character | meta: %{character.meta | combat: combat}})
              |> equip_feedback(
                item,
                [:wield],
                "你「唰」的一声抽出一柄#{item.name}握在手中。\n"
              )

            {:secondary_weapon} ->
              # 装备到副手
              combat =
                character.meta.combat
                |> put_weapon_snapshot(item, :secondary_weapon)
                |> apply_weapon_prop(item)

              conn
              |> put_character(%{character | meta: %{character.meta | combat: combat}})
              |> equip_feedback(item, [:wield], "你把#{item.name}握在副手。\n")

            {:swap} ->
              # 交换：卸下原主手（如果是副手类），装备新武器到主手
              old_weapon = Combat.weapon(character.meta.combat)

              combat =
                character.meta.combat
                |> Combat.unequip(:weapon)
                |> subtract_weapon_prop(old_weapon)
                |> put_weapon_snapshot(item, :weapon)
                |> apply_weapon_prop(item)

              conn
              |> put_character(%{character | meta: %{character.meta | combat: combat}})
              |> render(CommandView, "text", %{
                text: "你将#{Map.get(old_weapon, :name)}收回，改握#{item.name}。\n"
              })
              |> prompt(CommandView, "prompt", %{})
          end
      end
    end)
  end

  # ---- 护甲（按 armor_type 槽位） ----

  defp equip_armor(conn, item_name) do
    character = conn.character

    with_item(conn, character, item_name, fn item ->
      case armor_slot(item.meta) do
        nil ->
          render_error(conn, "#{item.name}不是可穿戴的护具。\n")

        slot ->
          if Combat.occupied?(character.meta.combat, slot) do
            render_error(conn, "你已经穿戴了同类型的护具了。\n")
          else
            snapshot = %{
              name: item.name,
              armor: Map.get(item.meta, :armor) || 0,
              prop: Map.get(item.meta, :armor_prop),
              consistence: Map.get(item.meta, :consistence) || 100
            }

            combat =
              character.meta.combat
              |> Combat.equip(slot, snapshot)
              |> apply_armor_prop(snapshot)

            conn
            |> put_character(%{character | meta: %{character.meta | combat: combat}})
            |> equip_feedback(item, [:wear], "你穿上了一件#{item.name}。\n")
          end
      end
    end)
  end

  # 槽位白名单固定，字符串→原子安全；nil 表示不可穿戴
  defp armor_slot(meta) do
    case Meta.normalize_armor_type(Map.get(meta, :armor_type)) do
      nil -> nil
      slot -> String.to_atom(slot)
    end
  end

  # ---- 辅助：Combat 状态转 Equip 期望的 state 结构 ----

  defp build_equip_state(combat) do
    %{
      weapon: Combat.weapon(combat),
      secondary_weapon: Map.get(combat.equipped, :secondary_weapon),
      handing: Map.get(combat.equipped, :handing)
    }
  end

  defp clear_weapon_slots(combat) do
    combat
    |> Combat.unequip(:weapon)
    |> Combat.unequip(:secondary_weapon)
    |> Combat.unequip(:handing)
  end

  defp put_weapon_snapshot(combat, item, slot) do
    snapshot = %{
      name: item.name,
      skill_type: Map.get(item.meta, :skill_type, "sword"),
      damage: Map.get(item.meta, :damage) || 0,
      prop: Map.get(item.meta, :weapon_prop),
      flag: Map.get(item.meta, :flag, 1)
    }

    Combat.equip(combat, slot, snapshot)
  end

  defp apply_weapon_prop(combat, item) do
    prop = Map.get(item.meta, :weapon_prop)

    if prop do
      Combat.apply_temp(combat, Equip.wield_state(%{}, prop))
    else
      combat
    end
  end

  defp subtract_weapon_prop(combat, weapon_snap) do
    prop = Map.get(weapon_snap, :prop)

    if prop do
      Combat.apply_temp(combat, Equip.unequip_state(%{}, prop))
    else
      combat
    end
  end

  defp apply_armor_prop(combat, armor_snap) do
    armor = Map.get(armor_snap, :armor) || 0
    prop = Map.get(armor_snap, :prop)
    Combat.apply_temp(combat, Equip.wear_state(%{}, armor, prop))
  end

  defp subtract_armor_prop(combat, armor_snap) do
    armor = Map.get(armor_snap, :armor) || 0
    prop = Map.get(armor_snap, :prop)

    temp_sub =
      %{}
      |> Equip.unequip_state(prop)
      |> Map.update(:armor, -armor, &(&1 - armor))

    Combat.apply_temp(combat, temp_sub)
  end

  # ---- 装备文案（P3-a：Item.Meta.messages → LPC message_vision 语义） ----

  # 装备/卸下反馈：物品带自定义文案 → 房间 vision 广播；否则渲染默认文案。
  #
  # - `item_or_nil`：物品定义（卸下路径按名字从背包回查，查不到为 nil → 默认文案）
  # - `keys`：按优先级回退查找的消息键（如卸武器 `[:unwield, :unequip]`；
  #   源里 `unwield_msg` 与 `unequip_msg` 同义，见 blade.c 只设 unequip_msg）
  # - `default_text`：无自定义文案时的既有默认文案（只给自己看）
  defp equip_feedback(conn, item, keys, default_text) do
    case equip_message(item, keys) do
      nil ->
        conn
        |> render(CommandView, "text", %{text: default_text})
        |> prompt(CommandView, "prompt", %{})

      template ->
        # {name} 与观看者无关，在此替换；{npc} 留给 VisionView 按接收者渲染
        # （自己→"你"，房间内其他人→行动者名）。
        text = String.replace(template, "{name}", item_name_of(item))

        conn
        |> publish_message(
          "rooms:#{conn.character.room_id}",
          text,
          [type: "vision"],
          &publish_error/2
        )
        |> assign(:prompt, false)
    end
  end

  # 卸载路径只有 combat 快照（name/skill_type/damage/prop/flag），没有物品定义；
  # 按快照全名从背包精确回查完整物品以读取 meta.messages。查不到返回 nil
  # （走默认文案）。用全名相等而非别名匹配：避免同名别名误配到别的物品，
  # 导致广播文案张冠李戴。
  defp equipped_item(character, expected_name) do
    Enum.find_value(character.inventory, fn instance ->
      item = Items.get!(instance.item_id)
      if item.name == expected_name, do: item
    end)
  rescue
    _ -> nil
  end

  defp equip_message(nil, _keys), do: nil

  defp equip_message(item, keys) do
    messages = Map.get(item.meta, :messages) || %{}

    Enum.find_value(keys, fn key ->
      case Map.get(messages, key) do
        template when is_binary(template) and template != "" -> template
        _ -> nil
      end
    end)
  end

  defp item_name_of(nil), do: "东西"
  defp item_name_of(item), do: item.name

  defp publish_error(conn, _error), do: conn

  # ---- 工具 ----

  defp with_item(conn, character, item_name, callback) do
    item_instance = find_instance(character.inventory, item_name)

    case item_instance && Items.get!(item_instance.item_id) do
      nil -> render_error(conn, "你的身上没有这样东西。\n")
      item -> female_only_guard(conn, character, item, callback)
    end
  end

  # female_only 穿戴限制（P3-c）：物品 female_only==true 时仅女性可装备。
  # LPC wear.c 语义：me->query("gender")=="男性" → 拒绝；gender 未知（nil）按 LPC
  # 恒不等于"男性" → 放行（fail-open，宁漏不误拦）。性别取自运行态
  # meta.env["gender"]（Records.apply_to_character 把 DB gender 写进 env）；
  # env 仅 PlayerMeta 有，故用 Map.get 取、缺省 %{}，避免 NPC 上 struct 取未定义键 KeyError。
  defp female_only_guard(conn, character, item, callback) do
    if female_only_conflict?(character, item) do
      render_error(conn, "只有女性才能穿戴。\n")
    else
      callback.(item)
    end
  end

  defp female_only_conflict?(character, item) do
    case Map.get(item.meta, :female_only) do
      true -> character_gender(character) == "男性"
      _ -> false
    end
  end

  defp character_gender(character) do
    env = Map.get(character.meta, :env, %{})
    Map.get(env, "gender") || Map.get(character.meta, :gender)
  end

  # remove/unwield 支持中英文名匹配快照（快照存的是全名）
  defp snapshot_matches?(snapshot, item_name) do
    Kantele.World.Item.matches?(%{name: Map.get(snapshot, :name)}, item_name) or
      Map.get(snapshot, :name) == String.trim(item_name)
  end

  defp find_instance(inventory, item_name) do
    Enum.find(inventory, fn item_instance ->
      item = Items.get!(item_instance.item_id)
      item_instance.id == item_name || item.callback_module.matches?(item, item_name)
    end)
  rescue
    _ -> nil
  end

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
