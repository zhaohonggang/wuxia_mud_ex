defmodule Kantele.Combat.Skills.Performs.LongxiangGong.Zhen do
  @moduledoc """
  perform「真·般若极」（source longxiang-gong/zhen.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "longxiang-gong/zhen"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "longxiang-gong")
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
      Stats.skill(stats, "longxiang-gong") < 390 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "longxiang-gong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "unarmed") != "longxiang-gong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 7000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 600}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

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
    Performs.feedback(attacker, 600, 1)
    result = Messages.interpolate("$n全然无力阻挡，竟被$N一下击得飞起，重重的跌落在地上。
$n不及闪避，顿被$N一下击中，尽伤三焦六脉。
$n被$N罡劲所逼，一时无力作出抵挡，竟呆立当场。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-600"}], "apply_adds": ["attack"], "assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(1);", "if (random(5) < 2 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "level_gates": [{"longxiang-gong", "390"}], "map_gates": [{"force", "longxiang-gong"}, {"unarmed", "longxiang-gong"}], "prepared_gates": [{"unarmed", "longxiang-gong"}], "remote_damage": true, "resource_gates": [{"max_neili", "7000"}, {"neili", "1000"}], "var_gates": [{"i", "8"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHEN "「" HIW "真·般若极" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int ap, dp, damage, jia;
  #         int i, count;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/longxiang-gong/zhen"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHEN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(ZHEN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("longxiang-gong", 1) < 390)
  #                 return notify_fail("你的龙象般若功修为不够，难以施展" ZHEN "。\n");
  # 
  #         if (me->query("max_neili") < 7000)
  #                 return notify_fail("你的内力修为不足，难以施展" ZHEN "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "longxiang-gong")
  #                 return notify_fail("你没有激发龙象般若功为拳脚，难以施展" ZHEN "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "longxiang-gong")
  #                 return notify_fail("你没有激发龙象般若功为内功，难以施展" ZHEN "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "longxiang-gong")
  #                 return notify_fail("你没有准备使用龙象般若功，难以施展" ZHEN "。\n");
  # 
  #         if (me->query("neili") < 1000)
  #                 return notify_fail("你现在的真气不足，难以施展" ZHEN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "仰天一声怒嚎，将龙象般若功提运至极限，全身顿时罡劲"
  #               "迸发，真气蒸腾而出，笼罩$N" HIY "\n四方！电光火石间，$N" HIY "双"
  #               "拳已携着雷霆万钧之势崩击而出，卷起万里尘埃，正是密宗绝学：\n\n" NOR;
  # 
  #         msg += HIW
  #         "        般      般般般           若        若           极    极极极极极极\n"
  #         "    般般般般    般  般       若若若若若若若若若若       极       极    极\n"
  #         "    般    般    般  般           若        若       极极极极极  极    极\n"
  #         "    般 般 般 般般    般般          若                 极极极  极极极 极极极\n"
  #         "  般般般般般般             若若若若若若若若若若若若  极 极 极  极极     极\n"
  #         "    般    般   般般般般         若                   极 极 极  极 极   极\n"
  #         "    般 般 般    般  般        若 若若若若若若若      极 极 极 极   极极\n"
  #         "    般    般     般般       若   若          若         极   极     极\n"
  #         "   般    般   般般  般般         若若若若若若若         极  极  极极极极极\n\n" NOR;
  # 
  #         msg += HIY "$N" HIY "一道掌力打出，接着便涌出了第二道、第三道掌力，掌势"
  #                "连绵不绝，气势如虹！直到$N" HIY "\n第十三道掌力打完，四周所笼罩"
  #                "着的罡劲方才慢慢消退！而$n" HIY "此时却已是避无可避！\n\n" NOR;
  # 
  #         ap = me->query_skill("unarmed") + me->query("con") * 10;
  #         dp = target->query_skill("parry") + target->query("dex") * 10;
  # 
  #         if (ap * 2 / 3 + random(ap) > dp)
  # {
  #         if (me->query("max_neili") / 2 + random(me->query("max_neili") / 2) > target->query("max_neili") * 5/4)
  #     {
  #                 msg += HIR "$n" HIR "全然无力阻挡，竟被$N"
  #                        HIR "一下击得飞起，重重的跌落在地上。\n" NOR;
  #             me->add("neili", -100);
  #           me->start_busy(1);
  # 
  #             message_combatd(msg, me, target);
  # 
  #                 target->unconcious();
  # 
  #             return 1;
  #     } else
  #         {
  #             jia = me->query("jiali");
  #                 damage = ap / 2 + random(jia * 5);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
  #                                                    HIR "$n" HIR "不及闪避，顿被$N" HIR
  #                                 HIR "一下击中，尽伤三焦六脉。\n" NOR);
  #                         msg += HIR "$n" HIR "被$N" HIR "罡劲所逼，一时无力作出抵挡，竟呆立当场。\n" NOR;
  #                         count = ap / 10;
  #         }
  # } else
  #         {
  #                 msg += HIY "$n" HIY "见$N" HIY "来势迅猛之极，甚难防备，连"
  #                        "忙振作精神，小心抵挡。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         me->add_temp("apply/attack", count);
  # 
  #         me->add("neili", -600);
  # 
  #         for (i = 0; i < 8; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(5) < 2 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->start_busy(1 + random(6));
  #         me->add_temp("apply/attack", -count);
  # 
  #         return 1;
  # 
  # }
end
