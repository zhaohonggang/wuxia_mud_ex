defmodule Kantele.Combat.Skills.Performs.TieZhang.Yin do
  @moduledoc """
  perform「阴阳磨」（source tie-zhang/yin.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
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
    improve = 0
    n = 0
    i = 0
    lvl = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "tie-zhang") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "tie-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 400}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 400, 1)
    result = Messages.interpolate("$N施出铁掌绝技「阴阳磨」，左掌不着半点力道，携着阴寒劲向$n拂去。

紧接着$N右掌一振，掌风过处，竟席卷起一股热浪，向$n胸前猛然拍落。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
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
