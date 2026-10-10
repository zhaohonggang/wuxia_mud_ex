defmodule Kantele.Combat.Skills.Performs.XianglongZhang.Zhen do
  @moduledoc """
  perform「震惊百里」（source xianglong-zhang/zhen.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "level_gates": [{"force", "300"}, {"xianglong-zhang", "150"}], "map_gates": [{"strike", "xianglong-zhang"}], "prepared_gates": [{"strike", "xianglong-zhang"}], "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你降龙十八掌火候不够，难以施展", "你没有激发降龙十八掌，难以施展", "你没有准备降龙十八掌，难以施展", "你的内功修为不够，难以施展", "你的内力修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 10", "dp_formula": "target->query_skill("dodge") + target->query("dex") * 10"}, "color_codes": ["CYN", "HIR", "HIW", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "$N" WHT "施出降龙十八掌之「" HIW "震惊百里" NOR +
      #                 WHT "」，全身真气鼓动，双掌如排山倒海般压向$n" WHT "。\n"NOR", "= CYN "$n" CYN "眼见$N" CYN "来势汹涌，丝毫不"
      #                          "敢小觑，急忙闪在了一旁。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
      #                                              HIR "$n" HIR "只觉一股罡风涌至，根本不"
      #                                              "及躲避，$N" HIR "双掌正中前胸，鲜血如"
      #                                              "箭般喷出。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-400"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define ZHEN "「" HIW "震惊百里" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/xianglong-zhang/zhen"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHEN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(ZHEN "只能空手使用。\n");
      # 
      #         if ((int)me->query_skill("xianglong-zhang", 1) < 150)
      #                 return notify_fail("你降龙十八掌火候不够，难以施展" ZHEN "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "xianglong-zhang")
      #                 return notify_fail("你没有激发降龙十八掌，难以施展" ZHEN "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "xianglong-zhang")
      #                 return notify_fail("你没有准备降龙十八掌，难以施展" ZHEN "。\n");
      # 
      #         if ((int)me->query_skill("force") < 300)
      #                 return notify_fail("你的内功修为不够，难以施展" ZHEN "。\n");
      # 
      #         if ((int)me->query("max_neili") < 3000)
      #                 return notify_fail("你的内力修为不够，难以施展" ZHEN "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你现在的真气不足，难以施展" ZHEN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = WHT "$N" WHT "施出降龙十八掌之「" HIW "震惊百里" NOR +
      #               WHT "」，全身真气鼓动，双掌如排山倒海般压向$n" WHT "。\n"NOR;  
      # 
      #         ap = me->query_skill("strike") + me->query("str") * 10;
      #         dp = target->query_skill("dodge") + target->query("dex") * 10;
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         { 
      #                 damage = ap + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
      #                                            HIR "$n" HIR "只觉一股罡风涌至，根本不"
      #                                            "及躲避，$N" HIR "双掌正中前胸，鲜血如"
      #                                            "箭般喷出。\n" NOR);
      #                 me->add("neili", -400);
      #                 me->start_busy(3);
      #         } else
      #         {
      #                 msg += CYN "$n" CYN "眼见$N" CYN "来势汹涌，丝毫不"
      #                        "敢小觑，急忙闪在了一旁。\n" NOR;
      #                 me->add("neili", -200);
      #                 me->start_busy(4);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
