defmodule Kantele.Combat.Skills.Performs.SixFinger.Six do
  @moduledoc """
  perform「六脉剑气」（source six-finger/six.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"dp", "force"}, {"skill", "liumai-shenjian"}], "level_gates": [{"force", "400"}], "map_gates": [], "prepared_gates": [{"finger", "liumai-shenjian"}], "resource_gates": [{"max_neili", "7000"}, {"neili", "500"}], "var_gates": [{"i", "6"}, {"skill", "220"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你没有准备使用六脉神剑，无法施展", "你的六脉神剑修为有限，无法使用", "你的内功火候不够，难以施展", "你的内力修为没有达到那个境界，无法运转内", "你的真气不够，现在无法施展", "你必须是空手才能施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "摊开双手，手指连弹，霎时间空气炙热，几"
      #                 "欲沸腾，六道剑气分自六穴，一起冲向$n" HIW "！\n" NOR"], "success": ["= HIR "$n" HIR "见此剑气纵横，微一愣神，不禁心萌退意。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}], "affect_by": [], "apply_adds": ["dodge", "parry"], "busy_lines": ["if (random(2) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(2) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # #define SIX "「" HIW "六脉剑气" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # 
      # int perform(object me, object target)
      # {
      # //      mapping prepare;
      #         string msg;
      #         int skill;
      #         int delta;
      #         int i;
      #         int ap, dp;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/liumai-shenjian/six"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(SIX "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_skill_prepared("finger") != "liumai-shenjian")
      #                 return notify_fail("你没有准备使用六脉神剑，无法施展" SIX "。\n");
      # 
      #         skill = me->query_skill("liumai-shenjian", 1);
      # 
      #         if (skill < 220)
      #                 return notify_fail("你的六脉神剑修为有限，无法使用" SIX "！\n");
      # 
      #         if (me->query_skill("force") < 400)
      #                 return notify_fail("你的内功火候不够，难以施展" SIX "！\n");
      # 
      #         if (me->query("max_neili") < 7000)
      #                 return notify_fail("你的内力修为没有达到那个境界，无法运转内"
      #                                    "力形成" SIX "！\n");
      # 
      #         if (me->query("neili") < 500)
      #                 return notify_fail("你的真气不够，现在无法施展" SIX "！\n");
      # 
      #         if (me->query_temp("weapon"))
      #                 return notify_fail("你必须是空手才能施展" SIX "！\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "摊开双手，手指连弹，霎时间空气炙热，几"
      #               "欲沸腾，六道剑气分自六穴，一起冲向$n" HIW "！\n" NOR;
      # 
      #         ap = me->query_skill("finger");
      #         dp = target->query_skill("force");
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 msg += HIR "$n" HIR "见此剑气纵横，微一愣神，不禁心萌退意。\n" NOR;
      #                 delta = -random(skill / 5);
      #         } else
      #                 delta = 0;
      # 
      #         message_combatd(msg, me, target);
      # 
      #         me->add("neili", -400);
      #         target->add_temp("apply/parry", delta);
      #         target->add_temp("apply/dodge", delta);
      #         for (i = 0; i < 6; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      # 
      #                 if (random(2) == 1 && ! target->is_busy())
      #                         target->start_busy(1);
      # 
      #                 me->set_temp("liumai-shenjian/hit_msg", i);
      # 
      #                 COMBAT_D->do_attack(me, target, 0, i * 3);
      #         }
      #         target->add_temp("apply/parry", -delta);
      #         target->add_temp("apply/dodge", -delta);
      #         me->delete_temp("liumai-shenjian/hit_msg");
      #         me->start_busy(1 + random(5));
      # 
      #         return 1;
      # }
end
