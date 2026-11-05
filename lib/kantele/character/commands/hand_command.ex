defmodule Kantele.Character.HandCommand do
  @moduledoc """
  手持命令：`hand <物品>` / `hand nothing`

  对应 LPC `cmds/std/hand.c`。
  拿出背包中的物品握在手中（不装备，仅占用一只手），随时准备使用；
  `hand nothing` 收回手中物品到包囊。

  ## 移植范围（LPC 门控逐条落地）

  1. 无参数 → 提示 "你要拿出什么东西？"
  2. `hand nothing|none`：
     - 未持物 → "你本来就什么都没有拿啊？"
     - 已持物 → "$N把X收回包囊。\n"，清空 :handing 槽位
  3. `hand <物品>`：
     - 物品在背包中（present）→ 否则 "你身上没有这样东西。"
     - 已持同一物品 → "你不是正拿着它吗？"
     - 已持其他物品 → 先收回旧物（"$N收回手中的X。\n"）
     - 重量 > 20000 克 → "X太重了，你单手拿不住。"
     - 主手武器为双手或已有副手武器 → "双手都拿着武器，没有办法再拿着X了。"
     - 物品已装备 → "你正装备着它呢！"
     - 否则设定 :handing 槽位，"$N拿出X，握在手中。\n"

  ## 与 LPC 的差异

  - LPC `query_temp("handing")`/`set_temp("handing")`/`delete_temp("handing")`
    映射为 Ex 的 `combat.equipped[:handing]` 槽位（与 wield/remove 共用，见
    wield_command.ex:84、clear_weapon_slots）。
  - LPC 不区分 query_amount/base_weight；此处统一取 item.meta.weight（克）。
  - 默认文案只给自己看（同 wield/wear）；物品自定义 `messages.hand`/
    `messages.handing` 走房间 vision 广播（{npc}→"你"）。
  - 无全局 temp dbase，手持状态随角色运行时 combat 状态持有。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Item.Equip
  alias Kantele.World.Item
  alias Kantele.World.Items

  @weight_limit 20_000

  def run(conn, %{"rest" => rest}) when is_binary(rest) do
    case String.trim(rest) do
      "" -> usage(conn)
      "nothing" -> put_away(conn)
      "none" -> put_away(conn)
      item_name -> hold(conn, conn.character, item_name)
    end
  end

  def run(conn, %{}), do: usage(conn)

  # ---- put away: hand nothing / none ----

  defp put_away(conn) do
    character = conn.character
    holding = Map.get(character.meta.combat.equipped, :handing)

    cond do
      is_nil(holding) ->
        render_error(conn, "你本来就什么都没有拿啊。\n")

      true ->
        item = equipped_item(character, Map.get(holding, :name))
        combat = Combat.unequip(character.meta.combat, :handing)
        conn =
          put_character(conn, %{character | meta: %{character.meta | combat: combat}})

        text =
          case item do
            nil -> "你把手中的东西收回包囊。\n"
            _ -> "$N把#{item.name}收回包囊。\n"
          end

        render_error(conn, text)
    end
  end

  # ---- hold: hand <item> ----

  defp hold(conn, character, item_name) do
    with_item(conn, character, item_name, fn item ->
      combat = character.meta.combat

      cond do
        # 已持同一物品
        holding_same?(combat, item) ->
          render_error(conn, "你不是正拿着#{item.name}吗？\n")

        true ->
          # 已持别的物品：先收回（LPC：delete_temp("handing") 后 message_vision 收回旧物）
          {combat, conn} =
            if holding_present?(combat) do
              old = Map.get(combat.equipped, :handing)
              old_item = equipped_item(character, Map.get(old, :name))
              combat = Combat.unequip(combat, :handing)
              conn =
                put_character(conn, %{character | meta: %{character.meta | combat: combat}})

              text =
                case old_item do
                  nil -> "你把手中的东西收回。\n"
                  _ -> "$N收回手中的#{old_item.name}。\n"
                end

              {combat, render_error(conn, text)}
            else
              {combat, conn}
            end

          cond do
            too_heavy?(item) ->
              render_error(conn, "#{item.name}太重了，你单手拿不住。\n")

            both_hands_occupied?(combat) ->
              render_error(
                conn,
                "你双手都拿着武器，没有办法再拿着#{item.name}了。\n"
              )

            equipped_anywhere?(combat, item) ->
              render_error(conn, "你正装备着#{item.name}呢！\n")

            true ->
              set_handing(conn, character, combat, item)
          end
      end
    end)
  end

  # ---- 设定手持槽位 ----

  defp set_handing(conn, character, combat, item) do
    combat = Combat.equip(combat, :handing, %{name: item.name})
    conn = put_character(conn, %{character | meta: %{character.meta | combat: combat}})

    unit = Map.get(item.meta, :unit) || "件"
    render_or_vision(conn, item, [:hand], "你拿出一#{unit}#{item.name}，握在手中。\n")
  end

  # ---- 门控 ----

  defp holding_same?(combat, item) do
    holding = Map.get(combat.equipped, :handing)
    is_map(holding) and Map.get(holding, :name) == item.name
  end

  defp holding_present?(combat), do: not is_nil(Map.get(combat.equipped, :handing))

  defp too_heavy?(item), do: (Map.get(item.meta, :weight) || 0) > @weight_limit

  defp both_hands_occupied?(combat) do
    weapon = Combat.weapon(combat)
    secondary = Map.get(combat.equipped, :secondary_weapon)

    is_map(weapon) and (Equip.two_handed?(Map.get(weapon, :flag, 0)) or not is_nil(secondary))
  end

  defp equipped_anywhere?(combat, item) do
    Enum.any?(combat.equipped, fn
      {_slot, snap} when is_map(snap) -> Map.get(snap, :name) == item.name
      _ -> false
    end)
  end

  # ---- 辅助：与 wield_command 同模式的背包查找与输出 ----

  defp with_item(conn, character, item_name, callback) do
    case find_instance(character.inventory, item_name) do
      nil -> render_error(conn, "你的身上没有这样东西。\n")
      item_instance ->
        item = Items.get!(item_instance.item_id)
        callback.(item)
    end
  rescue
    _ -> render_error(conn, "你的身上没有这样东西。\n")
  end

  defp find_instance(inventory, item_name) do
    Enum.find(inventory, fn item_instance ->
      item = Items.get!(item_instance.item_id)
      item_instance.id == item_name or Item.matches?(item, item_name)
    end)
  rescue
    _ -> nil
  end

  defp equipped_item(character, expected_name) do
    Enum.find_value(character.inventory, fn instance ->
      item = Items.get!(instance.item_id)
      if item.name == expected_name, do: item
    end)
  rescue
    _ -> nil
  end

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end

  defp render_or_vision(conn, item, keys, default_text) do
    case equip_message(item, keys) do
      nil ->
        conn
        |> render(CommandView, "text", %{text: default_text})
        |> prompt(CommandView, "prompt", %{})

      template ->
        text = String.replace(template, "{name}", item.name)
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

  defp publish_error(conn, _error), do: conn

  defp usage(conn) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：hand <物品> | nothing\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
