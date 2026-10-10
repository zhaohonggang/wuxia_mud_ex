defmodule Kantele.Combat.Skills.Performs.GuzhuoZhang.Yu do
  @moduledoc """
  perform「大智若愚」（source guzhuo-zhang/yu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "force"}], "level_gates": [{"force", "260"}, {"guzhuo-zhang", "180"}], "map_gates": [{"strike", "guzhuo-zhang"}], "prepared_gates": [{"strike", "guzhuo-zhang"}], "resource_gates": [{"max_neili", "2800"}, {"neili", "600"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你内功修为不够，难以施展", "你内力修为不够，难以施展", "你古拙掌法火候不够，难以施展", "你没有激发古拙掌法，难以施展", "你没有准备古拙掌法，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 10", "dp_formula": "target->query_skill("force") + target->query("int") * 10"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "$n" CYN "见$N" CYN "这掌来势非凡，不敢"
      #                          "轻易招架，当即飞身纵跃闪开。\n" NOR"], "success": ["HIR "$N" HIR "体内真气迸发，大喝一声，双掌向$n" HIR "平平推"
      #                 "去，招数朴实无华，毫无半点花巧可言。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                              HIR "$n" HIR "勘破不透掌中虚实，$N" HIR
      #                                              "双掌正中$p" HIR "前胸，“喀嚓喀嚓”接"
      #                                              "连断了数根肋骨。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define YU "「" HIR "大智若愚" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/guzhuo-zhang/yu"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(YU "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(YU "只能空手使用。\n");
      # 
      #         if ((int)me->query_skill("force") < 260)
      #                 return notify_fail("你内功修为不够，难以施展" YU "。\n");
      # 
      #         if ((int)me->query("max_neili") < 2800)
      #                 return notify_fail("你内力修为不够，难以施展" YU "。\n");
      # 
      #         if ((int)me->query_skill("guzhuo-zhang", 1) < 180)
      #                 return notify_fail("你古拙掌法火候不够，难以施展" YU "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "guzhuo-zhang")
      #                 return notify_fail("你没有激发古拙掌法，难以施展" YU "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "guzhuo-zhang")
      #                 return notify_fail("你没有准备古拙掌法，难以施展" YU "。\n");
      # 
      #         if ((int)me->query("neili") < 600)
      #                 return notify_fail("你现在真气不够，难以施展" YU "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "体内真气迸发，大喝一声，双掌向$n" HIR "平平推"
      #               "去，招数朴实无华，毫无半点花巧可言。\n" NOR;  
      # 
      #         ap = me->query_skill("strike") + me->query("str") * 10;
      #         dp = target->query_skill("force") + target->query("int") * 10;
      # 
      #         me->start_busy(3);
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         { 
      #                 damage = ap + random(ap / 2);
      #                 me->add("neili", -300);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                            HIR "$n" HIR "勘破不透掌中虚实，$N" HIR
      #                                            "双掌正中$p" HIR "前胸，“喀嚓喀嚓”接"
      #                                            "连断了数根肋骨。\n" NOR);
      #         } else
      #         {
      #                 msg += CYN "$n" CYN "见$N" CYN "这掌来势非凡，不敢"
      #                        "轻易招架，当即飞身纵跃闪开。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
