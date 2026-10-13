defmodule Kantele.Combat.Skills.Performs.TieZhang.Yin do
  @moduledoc """
  perform「阴阳磨」（source tie-zhang/yin.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
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

  @perform_id "tie-zhang/yin"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tie-zhang")
    ap = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "tie-zhang") < 220 -> {:error, "你铁掌掌法火候不够，难以施展「阴阳磨」。\n"}
      Stats.skill(stats, "force") < 300 -> {:error, "你的内功修为不够，难以施展「阴阳磨」。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "tie-zhang" ->
        {:error, "你没有激发铁掌掌法，难以施展「阴阳磨」。\n"}

      Stats.prepared_perform(stats, "strike") == nil or
          String.split(Stats.prepared_perform(stats, "strike"), "/") |> hd() != "tie-zhang" ->
        {:error, "你没有准备铁掌掌法，难以施展「阴阳磨」。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3500 -> {:error, "你的内力修为不够，难以施展「阴阳磨」。\n"}
      vitals.neili < 500 -> {:error, "你现在的真气不足，难以施展「阴阳磨」。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "「阴阳磨」只能空手施展。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: me->add("neili", -400)
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 400}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3 + :rand.uniform(3))
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    # LPC: colors removed by join_adjacent → single literal
    conn =
      Broadcast.publish(
        conn,
        "$N施出铁掌绝技「阴阳磨」，左掌不着半点力道，携着阴寒劲向$n拂去。\n",
        n1: character.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「阴阳磨」只能对战斗中的对手使用。\n"}
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
    stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(stats, "parry")
    dd = Stats.skill(stats, "dodge")
    _dd = dd
    hit1? = div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp

    Performs.feedback(attacker, 400, 2)

    vitals =
      if hit1? do
        Vitals.damage(
          character.meta.vitals,
          :qi,
          div(ap, 2) + Engine.rand(rng, max(div(ap, 2), 1))
        )
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # Stage 1 message
    msg1 =
      if hit1? do
        "霎那间$n已被$N阴寒掌劲拂中要害，不由得浑身一颤，难受之极。\n"
      else
        "$n见$N掌出如风，心知此招后着极是凌厉，当即斜跳闪开。\n"
      end

    # Stage 2 attack broadcast (always shown in LPC)
    conn =
      Broadcast.publish(
        conn,
        "\n紧接着$N右掌一振，掌风过处，竟席卷起一股热浪，向$n胸前猛然拍落。\n",
        n1: attacker.name
      )

    # Stage 2 resolution
    hit2? =
      div(ap, 2) + Engine.rand(rng, max(ap, 1)) >
        dd

    msg2 =
      if hit2? do
        "只听嗤的一声，$N右掌如击败革，正中$n胸口，震断了数根肋骨。\n"
      else
        "忽闻呼啸声大至，眼见$N掌势如虹，急忙纵跃躲避开来。\n"
      end

    result1 = Messages.interpolate(msg1, n1: attacker.name, n2: character.name)
    result2 = Messages.interpolate(msg2, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result1)
    |> Broadcast.publish(result2)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-400"}], "affect_by": ["tiezhang_yang", "tiezhang_yin"], "assign_refs": [{"ap", "strike"}, {"dd", "dodge"}, {"dp", "parry"}, {"lvl", "strike"}], "busy_lines": ["me->start_busy(3 + random(3));"], "level_gates": [{"force", "300"}, {"tie-zhang", "220"}], "map_gates": [{"strike", "tie-zhang"}], "prepared_gates": [{"strike", "tie-zhang"}], "remote_damage": true, "resource_gates": [{"max_neili", "3500"}, {"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YIN "「" HIR "阴阳磨" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string finala(object me, object target, int damage);
  # string finalb(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp, dd;
  #         int damage;
  # 
  #         float improve;
  #         int lvl, i, n;
  #         string martial;
  #         string *ks;
  #         martial = "strike";
  # 
  #         if (userp(me) && ! me->query("can_perform/tie-zhang/yin"))
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
  #         if ((int)me->query_skill("tie-zhang", 1) < 220)
  #                 return notify_fail("你铁掌掌法火候不够，难以施展" YIN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "tie-zhang")
  #                 return notify_fail("你没有激发铁掌掌法，难以施展" YIN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "tie-zhang")
  #                 return notify_fail("你没有准备铁掌掌法，难以施展" YIN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 300)
  #                 return notify_fail("你的内功修为不够，难以施展" YIN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3500)
  #                 return notify_fail("你的内力修为不够，难以施展" YIN "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不足，难以施展" YIN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "施出铁掌绝技「" HIR "阴阳磨"
  #               HIW "」，左掌不着半点力道，携着阴寒劲向$n"
  #               HIW "拂去。\n" NOR;
  # 
  #         ap = me->query_skill("strike") + me->query("str") * 5;
  #         dp = target->query_skill("parry") + target->query("con") * 5;
  #         dd = target->query_skill("dodge") + target->query("dex") * 5;
  # 
  #         lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvl = lvl * 4 / 5;
  #         ks = keys(me->query_skills(martial));
  #         improve = 0;
  #         n = 0;
  #         //最多给予5个技能的加成
  #         for (i = 0; i < sizeof(ks); i++)
  #         {
  #             if (SKILL_D(ks[i])->valid_enable(martial))
  #             {
  #                 n += 1;
  #                 improve += (int)me->query_skill(ks[i], 1);
  #                 if (n > 4 )
  #                     break;
  #             }
  #         }
  # 
  #         improve = improve * 4 / 100 / lvl;
  # 
  #         ap += ap * improve;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
  #                                            (: finala, me, target :));
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见$N" CYN "掌出如风，心知"
  #                        "此招后着极是凌厉，当即斜跳闪开。\n" NOR;
  #         }
  # 
  #         msg += HIR "\n紧接着$N" HIR "右掌一振，掌风过处，竟席"
  #                "卷起一股热浪，向$n" HIR "胸前猛然拍落。\n" NOR;
  # 
  #         if (ap / 2 + random(ap) > dd)
  #         {
  #                 damage = ap / 2 + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
  #                                            (: finalb, me, target :));
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "忽闻呼啸声大至，眼见$N" CYN
  #                        "掌势如虹，急忙纵跃躲避开来。\n" NOR;
  #         }
  #         me->start_busy(3 + random(3));
  #         me->add("neili", -400);
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
  # 
  # string finala(object me, object target, int damage)
  # {
  #         int lvl;
  #         lvl = me->query_skill("strike");
  # 
  #         target->affect_by("tiezhang_yin",
  #                        ([ "level" : me->query("jiali") + random(me->query("jiali") / 2),
  #                           "id"    : me->query("id"),
  #                           "duration" : lvl / 50 + random(lvl / 50) ]));
  # 
  #         return HIW "霎那间$n" HIW "已被$N" HIW "阴寒掌劲拂中要"
  #                "害，不由得浑身一颤，难受之极。\n" NOR;
  # }
  # 
  # string finalb(object me, object target, int damage)
  # {
  #         int lvl;
  #         lvl = me->query_skill("strike");
  # 
  #         target->affect_by("tiezhang_yang",
  #                        ([ "level" : me->query("jiali") + random(me->query("jiali") / 2),
  #                           "id"    : me->query("id"),
  #                           "duration" : lvl / 50 + random(lvl / 50) ]));
  # 
  #         return HIR "只听嗤的一声，$N" HIR "右掌如击败革，正中"
  #                "$n" HIR "胸口，震断了数根肋骨。\n" NOR;
  # }
end
