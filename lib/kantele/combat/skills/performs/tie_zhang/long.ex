defmodule Kantele.Combat.Skills.Performs.TieZhang.Long do
  @moduledoc """
  perform「龙影掌」（source tie-zhang/long.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}, {"level", "tie-zhang"}], "level_gates": [{"force", "150"}, {"tie-zhang", "100"}], "map_gates": [{"strike", "tie-zhang"}], "prepared_gates": [{"strike", "tie-zhang"}], "resource_gates": [{"max_neili", "1500"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你铁掌掌法火候不够，难以施展", "你没有激发铁掌掌法，难以施展", "你没有准备铁掌掌法，难以施展", "你的内功修为不够，难以施展", "你的内力修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 5", "dp_formula": "target->query_skill("parry") + target->query("dex") * 5"}, "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$n" CYN "看破了$N"
      #                          CYN "的企图，镇定解招，一丝不乱。\n" NOR"], "success": ["WHT "$N" WHT "双掌交错，施出铁掌绝技「" HIR "龙影掌" NOR +
      #                 WHT "」，旋起层层残影，笼罩$n" WHT "四方。\n" NOR", "= HIR "残影晃动间$n" HIR "招式陡然一紧，竟被$N"
      #                          HIR "的掌招牵引得手忙脚乱！\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-80"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(level / 18 + 2);", "me->start_busy(2);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(level / 18 + 2);
      #   - me->start_busy(2);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define LONG "「" HIR "龙影掌" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //    object weapon;
      #     string msg;
      #         int ap, dp;
      #         int level;
      # 
      #         if (userp(me) && ! me->query("can_perform/tie-zhang/long"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(LONG "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(LONG "只能空手施展。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if ((level = (int)me->query_skill("tie-zhang", 1)) < 100)
      #                 return notify_fail("你铁掌掌法火候不够，难以施展" LONG "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "tie-zhang")
      #                 return notify_fail("你没有激发铁掌掌法，难以施展" LONG "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "tie-zhang")
      #                 return notify_fail("你没有准备铁掌掌法，难以施展" LONG "。\n");
      # 
      #         if ((int)me->query_skill("force") < 150)
      #                 return notify_fail("你的内功修为不够，难以施展" LONG "。\n");
      # 
      #         if ((int)me->query("max_neili") < 1500)
      #                 return notify_fail("你的内力修为不够，难以施展" LONG "。\n");
      # 
      #         if ((int)me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不足，难以施展" LONG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = WHT "$N" WHT "双掌交错，施出铁掌绝技「" HIR "龙影掌" NOR +
      #               WHT "」，旋起层层残影，笼罩$n" WHT "四方。\n" NOR;
      # 
      #         ap = me->query_skill("strike") + me->query("str") * 5;
      #         dp = target->query_skill("parry") + target->query("dex") * 5;
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #         msg += HIR "残影晃动间$n" HIR "招式陡然一紧，竟被$N"
      #                        HIR "的掌招牵引得手忙脚乱！\n" NOR;
      #                 target->start_busy(level / 18 + 2);
      #                 me->start_busy(2);
      #                 me->add("neili", -100);
      #     } else
      #         {
      #         msg += CYN "可是$n" CYN "看破了$N"
      #                        CYN "的企图，镇定解招，一丝不乱。\n" NOR;
      #                 me->start_busy(2);
      #                 me->add("neili", -80);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end
