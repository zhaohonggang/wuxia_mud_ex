defmodule Kantele.Combat.Skills.Performs.DaojianGuizhen.Daojian do
  @moduledoc """
  刀剑七重天「daojian」（对照 `kungfu/skill/daojian-guizhen/daojian.c`）

  刀剑归真双持绝招：需同时装备一刀一剑，起手爆发后连出两式（右手武器一劈、
  左手武器一递）。攻击方算 `ap` 并下发 `combat/perform-incoming`，由目标侧
  `resolve_incoming` 计算 `dp` 并逐式判定命中/伤害，最后回执消耗 300 内力与忙乱。

  差异（TODO(migrate)）：
  - LPC 的 `me->query_temp("weapon")`/`query_temp("handing")` 双持对应
    `combat.equipped[:weapon]`/`combat.equipped[:secondary_weapon]`。
  - 第二式命中后的「转移武器」动画（`move`/`wield`）无对应动作，略。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "daojian-guizhen/daojian"
  @move_name "「刀剑七重天」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon1, weapon2} <- check_dual_weapon(combat),
         :ok <- check_weapon_consistence(weapon2),
         :ok <- check_weapon_types(weapon1, weapon2),
         :ok <- check_mapped(stats),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, level, weapon1, weapon2)
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (!objectp(weapon1) || !objectp(weapon2))
  #      return notify_fail("你没有同时装备刀剑，难以施展" DAOJIAN "。\n");
  defp check_dual_weapon(combat) do
    weapon1 = Combat.weapon(combat)
    weapon2 = Map.get(combat.equipped, :secondary_weapon)

    if weapon1 != nil and weapon2 != nil do
      {:ok, weapon1, weapon2}
    else
      {:error, "你没有同时装备刀剑，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (weapon2->query("consistence") <= 0)
  defp check_weapon_consistence(weapon2) do
    if Map.get(weapon2, :consistence, 100) <= 0 do
      {:error, "你的" <> weapon_name(weapon2) <> "已经严重损坏，无法继续使用了。\n"}
    else
      :ok
    end
  end

  # LPC: type1/type2 必须一刀一剑
  defp check_weapon_types(weapon1, weapon2) do
    type1 = Map.get(weapon1, :skill_type)
    type2 = Map.get(weapon2, :skill_type)

    cond do
      not weapon_type?(type1) or not weapon_type?(type2) ->
        {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}

      (type1 == "sword" and type2 != "blade") or (type1 == "blade" and type2 != "sword") ->
        {:error, "你没有同时装备刀剑，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp weapon_type?(type), do: type == "sword" or type == "blade"

  # LPC: me->query_skill_mapped("sword") != "daojian-guizhen"
  #      || me->query_skill_mapped("blade") != "daojian-guizhen"
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "daojian-guizhen" and
         Stats.mapped(stats, "blade") == "daojian-guizhen" do
      :ok
    else
      {:error, "你没有激发刀剑归真，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "daojian-guizhen")

    if level < 250 do
      {:error, "你的刀剑归真等级不够，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level, weapon1, weapon2) do
    rng = &:rand.uniform/1
    stats = character.meta.stats

    ap =
      Stats.skill(stats, "sword") +
        Stats.skill(stats, "blade") +
        div(Stats.skill(stats, "daojian-guizhen") * 3, 2)

    damage = ap + Engine.rand(rng, div(ap, 2))
    busy = 3 + Engine.rand(rng, 3)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        ap: ap,
        damage: damage,
        busy: busy,
        weapon1_name: weapon_name(weapon1),
        weapon2_name: weapon_name(weapon2)
      }
    })

    assign(conn, :prompt, false)
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    weapon1_name = Map.get(data, :weapon1_name, "")
    weapon2_name = Map.get(data, :weapon2_name, "")

    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    busy = Map.get(data, :busy, 3)

    dp =
      Stats.skill(stats, "force") +
        Stats.skill(stats, "dodge") +
        Stats.skill(stats, "parry")

    # 起手式：$N 将一刀一剑横置胸前
    conn =
      Broadcast.publish(
        conn,
        "$N将" <>
          weapon1_name <>
          "与" <>
          weapon2_name <>
          "横置于胸前，运转出「刀剑七重天」功力，内劲如海啸般爆发。\n",
        bindings
      )

    # LPC: if (ap / 3 + random(ap) > dp) { ap += ap / 5; damage += damage / 3; }
    {ap, damage, conn} =
      if div(ap, 3) + Engine.rand(rng, max(ap, 1)) > dp do
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$n见$N杀气大涨，不禁心生惧意，招架顿时散乱，全然不成章理。\n",
              bindings
            )
          )

        {ap + div(ap, 5), damage + div(damage, 3), conn}
      else
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$n见$N杀气大涨，丝毫不敢大意，急忙收敛心神，努力不受干扰。\n",
              bindings
            )
          )

        {ap, damage, conn}
      end

    # 第二式：右手 weapon1 一劈
    conn =
      Broadcast.publish(
        conn,
        "突然间$N身形一展，右手" <>
          weapon1_name <> "忽地一振，凌空卷出一道半弧，直劈$n而去。\n",
        bindings
      )

    {total, conn} =
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$n奋力抵挡，却哪里招架得住，被$N一招划中要脉，鲜血四处飞溅。\n",
              bindings
            )
          )

        {damage, conn}
      else
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate("$n心知这一招的凌厉，急忙凝神聚气，小心拆招，丝毫无损。\n", bindings)
          )

        {0, conn}
      end

    # 第三式：左手 weapon2 一递
    conn =
      Broadcast.publish(
        conn,
        "接着又将左手" <>
          weapon2_name <> "朝$n平平递出，招式看似简单，却蕴藏着极大的杀着。\n",
        bindings
      )

    {total, conn} =
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$n只觉眼花缭乱，全然无法洞察先机，$N一招命中，射出一柱鲜血。\n",
              bindings
            )
          )

        {total + damage, conn}
      else
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate("$n心知这一招的凌厉，急忙凝神聚气，小心拆招，丝毫无损。\n", bindings)
          )

        {total, conn}
      end

    # LPC: me->start_busy(3 + random(3)); me->add("neili", -300);
    Performs.feedback(attacker, 300, busy)

    conn
    |> put_character(apply_wound(character, total))
  end

  # do_damage(me, target, WEAPON_ATTACK, damage, 80, msg)
  defp apply_wound(character, damage) when damage > 0 do
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage * 80, 100))

    %{character | meta: %{character.meta | vitals: vitals}}
  end

  defp apply_wound(character, _damage), do: character

  defp weapon_name(weapon), do: Map.get(weapon, :name, "")

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "daojian-guizhen/daojian",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
