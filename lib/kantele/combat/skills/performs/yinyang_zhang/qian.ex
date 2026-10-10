defmodule Kantele.Combat.Skills.Performs.YinyangZhang.Qian do
  @moduledoc """
  perform「千掌环」（source yinyang-zhang/qian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "level_gates": [{"yinyang-zhang", "100"}], "map_gates": [], "prepared_gates": [{"strike", "yinyang-zhang"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你阴阳掌不够娴熟，难以施展", "你没有准备阴阳掌，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["HIC", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "\n$N" HIC "一声长啸，将内力运于双掌之上，施出绝招"
      #                 "「" HIW "千掌环" HIC "」，刹时间尘土漫天飞扬，$N" HIC
      #                 "双掌不断地连续拍出，攻势凌厉，令人不敢大意。\n" NOR", "HIY "$n" HIY "看清$N" HIY "这几招的来路，但"
      #                         "内劲所至，掌风犀利，也只得小心抵挡。\n" NOR"], "success": ["HIR "结果$n" HIR "目不暇接，顿时被$N" HIR "掌"
      #                         "风所困，顿时阵脚大乱。\n" NOR"]}, "resource_adds": [{"neili", "-attack_time * 20"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (target->is_busy())", "me->start_busy(1 + random(attack_time));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - me->start_busy(1 + random(attack_time));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define QIAN "「" HIW "千掌环" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int ap, dp;
      #         int attack_time, i;
      # 
      #         if (userp(me) && ! me->query("can_perform/yinyang-zhang/qian"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(QIAN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(QIAN "只能空手施展。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if ((int)me->query_skill("yinyang-zhang", 1) < 100)
      #                 return notify_fail("你阴阳掌不够娴熟，难以施展" QIAN "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "yinyang-zhang")
      #                 return notify_fail("你没有准备阴阳掌，难以施展" QIAN "。\n");
      # 
      #         if ((int)me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不够，难以施展" QIAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         ap = me->query_skill("strike");
      #         dp = target->query_skill("dodge");
      # 
      #         msg = HIC "\n$N" HIC "一声长啸，将内力运于双掌之上，施出绝招"
      #               "「" HIW "千掌环" HIC "」，刹时间尘土漫天飞扬，$N" HIC
      #               "双掌不断地连续拍出，攻势凌厉，令人不敢大意。\n" NOR;
      #         message_sort(msg, me, target);
      # 
      #     if (random(ap) > dp / 2)
      #     {
      #         msg = HIR "结果$n" HIR "目不暇接，顿时被$N" HIR "掌"
      #                       "风所困，顿时阵脚大乱。\n" NOR;
      #                 me->add_temp("apply/attack", 100);
      #         } else
      #         {
      #                 msg = HIY "$n" HIY "看清$N" HIY "这几招的来路，但"
      #                       "内劲所至，掌风犀利，也只得小心抵挡。\n" NOR;
      #         }
      #     message_vision(msg, me, target);
      # 
      #         attack_time += 3 + random(ap / 40);
      # 
      #         if (attack_time > 6)
      #                 attack_time = 6;
      # 
      #     me->add("neili", -attack_time * 20);
      # 
      #     for (i = 0; i < attack_time; i++)
      #     {
      #         if (! me->is_fighting(target))
      #             break;
      #                 COMBAT_D->do_attack(me, target, 0, 0);
      #     }
      #         me->add_temp("apply/attack", -100);
      #     me->start_busy(1 + random(attack_time));
      # 
      #     return 1;
      # }
end
