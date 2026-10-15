defmodule Kantele.Combat.Skills.Performs.ChousuiZhang.Dan do
  @moduledoc """
  绝招「炼心弹」（对照 kungfu/skill/chousui-zhang/dan.c）

  星宿派远程火弹：按 `chousui-zhang`/`poison` 等级分档决定威力与焰色，弹射
  火团袭向战斗中的对手。与「截手式」同为攻击型 perform，走 `combat/perform-incoming`
  由目标结算；内力消耗分三档（被震灭 -150 / 命中 -220 / 被闪避 -100），
  目标以 `combat/perform-feedback` 回执由本模块补扣，忙乱同理由回执设置。

  TODO(migrate):
  - 手中毒药（`query_temp("handing")`）的物品名与消耗：本引擎无 handing 物品，
    缺省以「毒丸」代名（与 `.c` 的 `name = NOR + RED "毒丸"` 分支一致）。
  - 命中后的 `fire_poison` 附加毒与护甲 `consistence` 损耗、`receive_wound("jing", ...)`：
    条件宿主（NPC）/jing 创伤/装备耐久未接，见目标侧 TODO。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "chousui-zhang/dan"
  @dan "「炼心弹」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, lvl} <- check_chousui(stats),
         {:ok, lvp} <- check_poison(stats),
         :ok <- check_throwing(stats),
         :ok <- check_mapped(stats),
         :ok <- check_prepared(stats),
         :ok <- check_max_neili(character),
         :ok <- check_neili(character),
         :ok <- check_handing(character) do
      apply_perform(conn, character, target, lvl, lvp)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@dan}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_chousui(stats) do
    level = Stats.skill(stats, "chousui-zhang")

    if level < 120 do
      {:error, "你的抽髓掌不够娴熟，难以施展#{@dan}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_poison(stats) do
    level = Stats.skill(stats, "poison")

    if level < 180 do
      {:error, "你对毒技的了解不够，难以施展#{@dan}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_throwing(stats) do
    if Stats.skill(stats, "throwing") < 190 do
      {:error, "你暗器手法火候不够，难以施展#{@dan}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") == "chousui-zhang" do
      :ok
    else
      {:error, "你没有激发抽髓掌，难以施展#{@dan}。\n"}
    end
  end

  # LPC: me->query_skill_prepared("strike") != "chousui-zhang"
  defp check_prepared(stats) do
    prepared = Stats.prepared_perform(stats, "strike")

    if prepared == nil or hd(String.split(prepared, "/")) != "chousui-zhang" do
      {:error, "你没有准备抽髓掌，难以施展#{@dan}。\n"}
    else
      :ok
    end
  end

  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 1800 do
      {:error, "你的内力修为不足，难以施展#{@dan}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在的内息不足，难以施展#{@dan}。\n"}
    else
      :ok
    end
  end

  # LPC: 手中毒药（handing）三态检查；本引擎无 handing 物品，缺省放行。
  defp check_handing(character) do
    case handing(character) do
      nil ->
        :ok

      du when is_map(du) ->
        cond do
          not poison_item?(du) ->
            {:error, "你手中所拿的" <> item_name(du) <> "不是毒药，难以施展#{@dan}。\n"}

          no_shot?(du) ->
            {:error, "将" <> item_name(du) <> "弹射出去？似乎不太好吧。\n"}

          true ->
            :ok
        end

      _ ->
        {:error, "你必须拿着(hand)些毒药才能施展#{@dan}。\n"}
    end
  end

  defp handing(character) do
    character.meta
    |> Map.get(:temp, %{})
    |> Map.get("handing")
  end

  defp poison_item?(du) do
    meta = Map.get(du, :meta, %{})
    Map.get(meta, "can_daub") == true && Map.get(meta, "poison_type") != nil
  end

  defp no_shot?(du), do: Map.get(du, :no_shot, false)

  defp item_name(du), do: Map.get(du, :name, "")

  defp apply_perform(conn, character, target, lvl, lvp) do
    rng = &:rand.uniform/1
    {pos, fire} = power_tier(lvl, lvp, rng)
    damage = div(pos, 2) + Engine.rand(rng, div(pos, 2))

    vitals = character.meta.vitals
    stats = character.meta.stats

    # LPC: name = objectp(du) ? du->name() : (NOR + RED "毒丸")
    name = "毒丸"

    msg =
      "$N单掌一抖，施出星宿派绝技「炼心弹」，将手中" <>
        name <>
        "「嗖」的弹射了出去。\n却见那" <>
        name <>
        "射至中途，竟蓦地爆裂开，化作" <>
        fire <>
        "飘然袭向$n。\n"

    conn =
      Broadcast.publish(conn, msg,
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: lvl,
        poison: lvp,
        pos: pos,
        damage: damage,
        an: vitals.max_neili + div(vitals.neili, 4),
        ap: Stats.effective(stats, "strike") + Stats.skill(stats, "poison"),
        userp: true
      }
    })

    # 消耗手中毒药（若有）
    handing = handing(character)

    new_inventory =
      if handing && is_map(handing) do
        Enum.reject(character.inventory, &(&1.id == handing.id))
      else
        character.inventory
      end

    new_temp = Map.put(Map.get(character.meta, :temp, %{}), "handing", nil)
    new_meta = Map.put(character.meta, :temp, new_temp)
    new_character = %{character | inventory: new_inventory, meta: new_meta}

    conn
    |> put_character(new_character)
    |> assign(:prompt, false)
  end

  # 威力分档（dan.c 64-83）：等级越高，基础威力 pos 与焰色越强
  defp power_tier(lvl, lvp, rng) do
    cond do
      lvl >= 200 and lvp >= 270 ->
        {300 + Engine.rand(rng, div(lvp * 4, 3)), "一团莹绿色的碧焰"}

      lvl >= 180 and lvp >= 240 ->
        {200 + Engine.rand(rng, div(lvp * 3, 4)), "一个殷红色的火球"}

      lvl >= 150 and lvp >= 210 ->
        {100 + Engine.rand(rng, div(lvp * 2, 3)), Enum.join(["数点殷红色的", "火星"], "")}

      true ->
        {50 + Engine.rand(rng, div(lvp, 2)), Enum.join(["一点暗红色的", "火星"], "")}
    end
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    vitals = character.meta.vitals
    stats = character.meta.stats

    bindings = [n1: attacker.name, n2: character.name]

    an = Map.get(data, :an, 0)
    dn = vitals.max_neili + div(vitals.neili, 4)

    cond do
      Engine.rand(rng, max(an, 1)) + div(an, 2) < div(dn * 2, 3) ->
        # 对方内力过高：震灭，攻击方 -150 内力 / busy 3
        Performs.feedback(attacker, 150, 3)

        Broadcast.publish(
          conn,
          Messages.interpolate("然而$n全然不放在心上，轻轻一抖，已将$N射来的火焰震灭。\n", bindings)
        )

      true ->
        ap = Map.get(data, :ap, 0)

        dp =
          if Map.get(data, :userp, true) do
            Stats.effective(stats, "dodge") + Stats.effective(stats, "martial-cognize")
          else
            Stats.effective(stats, "dodge") + Stats.effective(stats, "parry")
          end

        if Engine.rand(rng, max(ap, 1)) + div(ap, 2) > dp do
          # 命中：jing 直接伤害和创伤，攻击方 -220 内力 / busy 2
          damage = Map.get(data, :damage, 0)

          vitals =
            vitals
            |> Vitals.damage(:jing, div(damage, 2))
            |> Vitals.wound(:jing, div(damage, 3))

          character = %{character | meta: %{character.meta | vitals: vitals}}

          # 火毒（dan.c final 181-184）
          lvp = Map.get(data, :poison, 0)
          poison_level = div(lvp, 2) + Engine.rand(rng, div(lvp, 2))
          poison_duration = 3 + Engine.rand(rng, div(lvp, 30))

          conn =
            ConditionEvent.apply_poison(conn, %{
              "level" => poison_level,
              "duration" => poison_duration,
              "remain" => poison_duration,
              "id" => attacker.id,
              "name" => "火毒"
            })

          # 护甲 consistence 损耗（dan.c final 157-179）
          {character, armor_name} = wear_armor(character)

          wound_text = "$n一个不慎，火星顿时溅到" <> armor_name <> "之上，大势燃烧起来，皮肉烧得嗤嗤作响。\n"

          Performs.feedback(attacker, 220, 2)

          conn
          |> Broadcast.publish(Messages.interpolate(wound_text, bindings))
          |> put_character(character)
        else
          # 被闪避：攻击方 -100 内力 / busy 3
          Performs.feedback(attacker, 100, 3)

          Broadcast.publish(
            conn,
            Messages.interpolate("可是$n见势不妙，急忙腾挪身形，终于避开了$N射来的火焰。\n", bindings)
          )
        end
    end
  end

  # 护甲 consistence 损耗（dan.c final 157-179）：
  # 优先衣服，其次盔甲；stable >= 100 的护具不损耗，但仍取用其名。
  defp wear_armor(character) do
    equipped = character.meta.combat.equipped

    case pick_armor(equipped) do
      {slot, snapshot} ->
        character = degrade_armor(character, equipped, slot, snapshot)
        {character, Map.get(snapshot, :name, skin_name())}

      nil ->
        {character, skin_name()}
    end
  end

  defp degrade_armor(character, equipped, slot, snapshot) do
    if armor_stable?(snapshot) do
      character
    else
      consistence = Map.get(snapshot, :consistence) || 100
      new_consistence = max(consistence - :rand.uniform(10), 0)

      if new_consistence == consistence do
        character
      else
        updated = Map.put(snapshot, :consistence, new_consistence)
        updated_equipped = Map.put(equipped, slot, updated)
        updated_combat = %{character.meta.combat | equipped: updated_equipped}
        %{character | meta: %{character.meta | combat: updated_combat}}
      end
    end
  end

  defp skin_name, do: "肌肤"

  defp pick_armor(equipped) do
    Enum.find_value([:cloth, :armor], fn slot ->
      case Map.get(equipped, slot) do
        snapshot when is_map(snapshot) -> {slot, snapshot}
        _ -> nil
      end
    end)
  end

  defp armor_stable?(snapshot), do: Map.get(snapshot, :stable, 1) >= 100

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
