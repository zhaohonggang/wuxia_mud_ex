defmodule Kantele.Combat.Skills.Performs.BazhenZhang.Yin do
  @moduledoc """
  perform「神卦天印」（source bazhen-zhang/yin.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：未持兵器 → 内功>=180 → 八阵八卦掌>=130 →
  激发 strike 为八阵八卦掌 → 准备 strike 招式 → 真气>=300 → 目标存活。
  命中判定 `random(strike) > parry/2`；命中时伤害 `strike/2 + random(strike)`；
  命中扣 250 真气并忙乱 2，失手扣 100 真气并忙乱 3。

  差异（TODO(migrate)）：
  - `do_damage` 的第 5 参 `percent` 为护甲穿透比例，Elixir 侧 Vitals 未建模
    护甲，按同级迁移惯例只做 `Vitals.damage(:qi, damage)`；
  - `living(target)` 门槛未实现，由目标侧 `combat/perform-incoming` 兜底；
  - `me->query_temp("secondary_weapon")` 副兵器检查未实现。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "bazhen-zhang/yin"

  @move_name "「神卦天印」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "bazhen-zhang")
    damage = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          damage: damage,
          rng: rng
        }
      })

      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_gates(character) do
    with :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 180 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "bazhen-zhang") < 130 ->
        {:error, "你的八阵八卦掌不够娴熟，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "bazhen-zhang" ->
        {:error, "你没有激发八阵八卦掌，难以施展#{@move_name}。\n"}

      Stats.prepared_perform(stats, "strike") == nil or String.split(Stats.prepared_perform(stats, "strike"), "/") |> hd() != "bazhen-zhang" ->
        {:error, "你没有准备八阵八卦掌，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "#{@move_name}只能空手施展。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：仅前置广播。
    # C 的 -250/busy 2（命中）与 -100/busy 3（失手）均为条件消耗，
    # 由 do_resolve_incoming 通过 Performs.feedback 作用于攻击方。
    conn =
      Broadcast.publish(
        conn,
        "$N凝神沉履，积聚全身功力于一掌，携着雷霆之势奋力向$n胸前拍落。",
        n1: character.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「神卦天印」只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    skill = max(Map.get(data, :damage, 0), 1)
    stats = character.meta.stats
    dp = div(Stats.skill(stats, "parry"), 2)
    # LPC: if (random(me->query_skill("strike")) > target->query_skill("parry") / 2)
    hit = Engine.rand(rng, skill) > dp

    vitals =
      if hit do
        # C: damage = damage / 2 + random(damage)
        dmg = div(skill, 2) + Engine.rand(rng, skill)
        Vitals.damage(character.meta.vitals, :qi, dmg)
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # 命中：add("neili", -250) + start_busy(2)；失手：add("neili", -100) + start_busy(3)
    {neili_cost, busy} = if hit, do: {250, 2}, else: {100, 3}

    Performs.feedback(attacker, neili_cost, busy)

    msg =
      if hit,
        do: "结果$p招架不及，被$P一掌印在胸口，接连断了数根肋骨，喷出一大口鲜血！\n",
        else: "可是$p奋力招架，不露半点破绽，将$P这一招驱之于无形。\n"

    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-250"}], "assign_refs": [{"damage", "strike"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"bazhen-zhang", "130"}, {"force", "180"}], "map_gates": [{"strike", "bazhen-zhang"}], "prepared_gates": [{"strike", "bazhen-zhang"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YIN "「" HIR "神卦天印" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/bazhen-zhang/yin"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YIN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(YIN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("force") < 180)
  #                 return notify_fail("你的内功修为不够，难以施展" YIN "。\n");
  # 
  #         if ((int)me->query_skill("bazhen-zhang", 1) < 130)
  #                 return notify_fail("你的八阵八卦掌不够娴熟，难以施展" YIN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "bazhen-zhang")
  #                 return notify_fail("你没有激发八阵八卦掌，难以施展" YIN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "bazhen-zhang")
  #                 return notify_fail("你没有准备八阵八卦掌，难以施展" YIN "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在真气不够，难以施展" YIN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "凝神沉履，积聚全身功力于一掌，携着雷霆之势奋力向$n"
  #               HIR "胸前拍落。\n" NOR;
  # 
  #         if (random(me->query_skill("strike")) > target->query_skill("parry") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("strike");
  #                 damage = damage / 2 + random(damage);
  #                 me->add("neili", -250);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
  #                                            HIR "结果$p" HIR "招架不及，被$P" HIR
  #                                            "一掌印在胸口，接连断了数根肋骨，喷出"
  #                                            "一大口鲜血！\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -100);
  #                 msg += CYN "可是$p" CYN "奋力招架，不露半点破绽，将$P"
  #                        CYN "这一招驱之于无形。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
