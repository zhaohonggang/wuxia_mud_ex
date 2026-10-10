defmodule Kantele.Combat.Skills.Performs.DragonStrike.Qin do
  @moduledoc """
  perform「擒龙手」（source dragon-strike/qin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

  TODO(migrate): 样本人工校对后，把以下门槛/语义写进 check_* 与 apply_effect。
  以上注释行（TODO(migrate)）校对完成后删除。
  """

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # TODO(migrate) 提取器门槛事实（核对后替换为真实查法）：
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "level_gates": [{"dragon-strike", "180"}, {"force", "260"}], "map_gates": [{"strike", "dragon-strike"}], "prepared_gates": [{"strike", "dragon-strike"}], "resource_gates": [{"max_neili", "3000"}, {"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "对方没有使用兵器，难以施展", "你内功修为不够，难以施展", "你内力修为不够，难以施展", "你降龙十八掌火候不够，难以施展", "你没有激发降龙十八掌，难以施展", "你没有准备降龙十八掌，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 10", "dp_formula": "target->query_skill("parry") + target->query("int") * 10"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "$n" CYN "只觉周围气流涌动，慌忙中连将手中"
      #                          + weapon->name() + CYN "挥舞得密不透风，使得$N"
      #                          CYN "无从下手。\n" NOR"], "success": ["HIR "$N" HIR "暴喝一声，全身内劲迸发，气贯右臂奋力外扯，企图将$n"
      #                 HIR "的" + weapon->name() + HIR "吸入掌中。\n" NOR", "= HIR "$n" HIR "只觉周围气流涌动，手中" + weapon->name()
      #                          + HIR "竟然拿捏不住，向$N" HIR "掌心脱手飞去。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define QIN "「" HIR "擒龙手" NOR "」"
      # 
      # int perform(object me)
      # {
      #         string msg;
      #         object weapon, target;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/dragon-strike/qin"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(QIN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(QIN "只能空手使用。\n");
      # 
      #         if (! objectp(weapon = target->query_temp("weapon")))
      #                 return notify_fail("对方没有使用兵器，难以施展" QIN "。\n");
      # 
      #         if ((int)me->query_skill("force") < 260)
      #                 return notify_fail("你内功修为不够，难以施展" QIN "。\n");
      # 
      #         if ((int)me->query("max_neili") < 3000)
      #                 return notify_fail("你内力修为不够，难以施展" QIN "。\n");
      # 
      #         if ((int)me->query_skill("dragon-strike", 1) < 180)
      #                 return notify_fail("你降龙十八掌火候不够，难以施展" QIN "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "dragon-strike")
      #                 return notify_fail("你没有激发降龙十八掌，难以施展" QIN "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "dragon-strike")
      #                 return notify_fail("你没有准备降龙十八掌，难以施展" QIN "。\n");
      # 
      #         if ((int)me->query("neili") < 400)
      #                 return notify_fail("你现在真气不够，难以施展" QIN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "暴喝一声，全身内劲迸发，气贯右臂奋力外扯，企图将$n"
      #               HIR "的" + weapon->name() + HIR "吸入掌中。\n" NOR;
      # 
      #         ap = me->query_skill("strike") + me->query("str") * 10;
      #         dp = target->query_skill("parry") + target->query("int") * 10;
      # 
      #         if (ap / 3 + random(ap) > dp)
      #         {
      #                 me->add("neili", -300);
      #                 msg += HIR "$n" HIR "只觉周围气流涌动，手中" + weapon->name()
      #                        + HIR "竟然拿捏不住，向$N" HIR "掌心脱手飞去。\n" NOR;
      #                 me->start_busy(2);
      #                 weapon->move(me, 1);
      #         } else
      #         {
      #                 me->add("neili", -200);
      #                 msg += CYN "$n" CYN "只觉周围气流涌动，慌忙中连将手中"
      #                        + weapon->name() + CYN "挥舞得密不透风，使得$N"
      #                        CYN "无从下手。\n" NOR;
      #                 me->start_busy(3);
      #         }
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end
