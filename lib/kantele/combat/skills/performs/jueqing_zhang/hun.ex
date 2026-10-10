defmodule Kantele.Combat.Skills.Performs.JueqingZhang.Hun do
  @moduledoc """
  perform「魂飞魄散」（source jueqing-zhang/hun.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"damage", "jueqing-zhang"}, {"dp", "parry"}], "level_gates": [{"force", "180"}, {"jueqing-zhang", "140"}], "map_gates": [{"strike", "jueqing-zhang"}], "prepared_gates": [{"strike", "jueqing-zhang"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你绝情掌不够娴熟，难以施展", "你没有激发绝情掌，难以施展", "你没有准备绝情掌，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIC", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "\n$N" HIC "运转真气，将内力注于掌风之中，双掌猛"
      #                 "然拍向$n" HIC "，掌风凌厉无比，气势凌人，直可惊天"
      #                 "地，泣鬼神，正是绝情谷绝学「" HIM "魂飞魄散" HIC "」。"
      #                 "\n" NOR", "= CYN "$n" CYN "见$N" CYN "这掌拍来，内力"
      #                          "充盈，气势凌人，只得奋力向后一纵，才躲"
      #                          "过这一掌。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                              HIR "但见$N" HIR "双掌拍来，掌风作响，"
      #                                              "当真气势凌人。$n" HIR "顿觉心惊胆战，"
      #                                              "毫无招架之力，微迟疑间$N" HIR "这掌"
      #                                              "已正中$n" HIR "胸口，顿将$p震退数步。"
      #                                              " \n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("jueqing-zhang", 1)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-200"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define HUN "「" HIM "魂飞魄散" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/jueqing-zhang/hun"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(HUN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(HUN "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("jueqing-zhang", 1) < 140)
      #                 return notify_fail("你绝情掌不够娴熟，难以施展" HUN "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "jueqing-zhang")
      #                 return notify_fail("你没有激发绝情掌，难以施展" HUN "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "jueqing-zhang")
      #                 return notify_fail("你没有准备绝情掌，难以施展" HUN "。\n");
      # 
      #         if (me->query_skill("force") < 180)
      #                 return notify_fail("你的内功修为不够，难以施展" HUN "。\n");
      # 
      #         if ((int)me->query("neili") < 300)
      #                 return notify_fail("你现在的真气不够，难以施展" HUN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         ap = me->query_skill("strike");
      #         dp = target->query_skill("parry");
      # 
      #         msg = HIC "\n$N" HIC "运转真气，将内力注于掌风之中，双掌猛"
      #               "然拍向$n" HIC "，掌风凌厉无比，气势凌人，直可惊天"
      #               "地，泣鬼神，正是绝情谷绝学「" HIM "魂飞魄散" HIC "」。"
      #               "\n" NOR;
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = (int)me->query_skill("jueqing-zhang", 1);
      #                 damage += random(damage);
      # 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                            HIR "但见$N" HIR "双掌拍来，掌风作响，"
      #                                            "当真气势凌人。$n" HIR "顿觉心惊胆战，"
      #                                            "毫无招架之力，微迟疑间$N" HIR "这掌"
      #                                            "已正中$n" HIR "胸口，顿将$p震退数步。"
      #                                            " \n" NOR);
      # 
      #                 me->start_busy(3);
      #                 me->add("neili", -200);
      #         } else
      #         {
      #                 msg += CYN "$n" CYN "见$N" CYN "这掌拍来，内力"
      #                        "充盈，气势凌人，只得奋力向后一纵，才躲"
      #                        "过这一掌。\n" NOR;
      # 
      #                 me->start_busy(4);
      #                 me->add("neili", -100);
      #         }
      #         message_sort(msg, me, target);
      #         return 1;
      # }
end
