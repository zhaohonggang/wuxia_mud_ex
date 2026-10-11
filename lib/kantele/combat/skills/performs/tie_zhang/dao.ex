defmodule Kantele.Combat.Skills.Performs.TieZhang.Dao do
  @moduledoc """
  perform「五指刀」（source tie-zhang/dao.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "tie-zhang/dao"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tie-zhang")
    count = 0
    i = 0

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
      Stats.skill(stats, "force") < 260 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "tie-zhang") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
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
      vitals.max_neili < 2500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 400 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 250}
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
    Performs.feedback(attacker, 250, 1)
    result = Messages.interpolate("$N身形一展，施出铁掌绝技「五指刀」，掌锋激起层层气浪，朝$n狂劈而去。
$n面对$N这排山倒海般的攻势，完全无法抵挡，招架散乱，连连退后。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-250"}], "apply_adds": ["attack", "unarmed_damage"], "assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "busy_lines": ["if (random(5) < 2 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "level_gates": [{"force", "260"}, {"tie-zhang", "180"}], "map_gates": [{"strike", "tie-zhang"}], "prepared_gates": [{"strike", "tie-zhang"}], "remote_damage": false, "resource_gates": [{"max_neili", "2500"}, {"neili", "400"}], "var_gates": [{"i", "5"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DAO "「" HIR "五指刀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int i, count;
  # 
  #         if (userp(me) && ! me->query("can_perform/tie-zhang/dao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DAO "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(DAO "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("tie-zhang", 1) < 180)
  #                 return notify_fail("你铁掌掌法火候不够，难以施展" DAO "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "tie-zhang")
  #                 return notify_fail("你没有激发铁掌掌法，难以施展" DAO "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "tie-zhang")
  #                 return notify_fail("你没有准备铁掌掌法，难以施展" DAO "。\n");
  # 
  #         if ((int)me->query_skill("force") < 260)
  #                 return notify_fail("你的内功修为不够，难以施展" DAO "。\n");
  # 
  #         if ((int)me->query("max_neili") < 2500)
  #                 return notify_fail("你的内力修为不够，难以施展" DAO "。\n");
  # 
  #         if ((int)me->query("neili") < 400)
  #                 return notify_fail("你现在的真气不足，难以施展" DAO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "身形一展，施出铁掌绝技「" HIR "五指刀" NOR +
  #               WHT "」，掌锋激起层层气浪，朝$n" WHT "狂劈而去。\n" NOR;  
  # 
  #         ap = me->query_skill("strike") + me->query("str") * 6;
  #         dp = target->query_skill("parry") + target->query("dex") * 6;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += HIR "$n" HIR "面对$N" HIR "这排山倒海般的攻"
  #                        "势，完全无法抵挡，招架散乱，连连退后。\n" NOR;
  #                 count = ap / 12;
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "心底微微一惊，心知不妙，急忙"
  #                        "凝聚心神，竭尽所能化解$N" HIC "数道掌力。\n" NOR;
  #                 count = 0;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         me->add_temp("apply/attack", count);
  #         me->add_temp("apply/unarmed_damage", count / 2);
  # 
  #         for (i = 0; i < 5; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (random(5) < 2 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #         me->add("neili", -250);
  #         me->start_busy(1 + random(5));
  #         me->add_temp("apply/attack", -count);
  #         me->add_temp("apply/unarmed_damage", -count / 2);
  #         return 1;
  # }
end
