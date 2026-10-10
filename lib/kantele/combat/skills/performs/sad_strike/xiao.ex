defmodule Kantele.Combat.Skills.Performs.SadStrike.Xiao do
  @moduledoc """
  perform「黯然销魂」（source sad-strike/xiao.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}, {"lvl", "sad-strike"}], "level_gates": [{"force", "320"}, {"sad-strike", "150"}], "map_gates": [], "prepared_gates": [{"unarmed", "sad-strike"}], "resource_gates": [{"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的真气不够！\n", "你的黯然销魂掌火候不够，无法施展", "你的内功修为不够，无法施展", "你现在没有准备使用黯然销魂掌，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") + me->query_skill("force")", "dp_formula": "target->query_skill("parry") + target->query_skill("force")"}, "color_codes": ["HIC", "HIM", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIY "$n" HIY "见$P" HIY "这一招变化莫测，奇幻无"
      #                          "方，不由大吃一惊，慌乱中破绽迭出。\n" NOR", "= HIC "$n" HIC "不敢小觑$P" HIC
      #                          "的来招，腾挪躲闪，小心招架。\n" NOR"], "success": ["HIM "\n$N" HIM "一声长吟：“黯然销魂者，唯别而已矣！”，顿时心如"
      #                 "止水，黯然神伤，于不经意中随手使出了" HIR "『黯然销魂』" HIM "！\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-70 * n"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(2) && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(2 + random(4));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(2) && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(2 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // xiao.c 黯然销魂
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define XIAO "「" HIW "黯然销魂" NOR "」"
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int ap, dp;
      #         int lvl, count;
      #         int i, n;
      # 
      #         if (userp(me) && ! me->query("can_perform/sad-strike/xiao"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(XIAO "只能在战斗中对对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(XIAO "只能空手使用。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你的真气不够！\n");
      # 
      #         if ((int)me->query_skill("sad-strike", 1) < 150)
      #                 return notify_fail("你的黯然销魂掌火候不够，无法施展" XIAO "。\n");
      # 
      #         if ((int)me->query_skill("force") < 320)
      #                 return notify_fail("你的内功修为不够，无法施展" XIAO "。\n");
      # 
      #         if (me->query_skill_prepared("unarmed") != "sad-strike")
      #                 return notify_fail("你现在没有准备使用黯然销魂掌，无法施展" XIAO "。\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIM "\n$N" HIM "一声长吟：“黯然销魂者，唯别而已矣！”，顿时心如"
      #               "止水，黯然神伤，于不经意中随手使出了" HIR "『黯然销魂』" HIM "！\n" NOR;
      # 
      #         ap = me->query_skill("unarmed") + me->query_skill("force");
      #         dp = target->query_skill("parry") + target->query_skill("force");
      #         lvl = me->query_skill("sad-strike", 1);
      #         n = 6;
      # 
      #         if (lvl > 600)
      #             n += (int)(lvl - 400) / 200;
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 count = ap / 10;
      #                 msg += HIY "$n" HIY "见$P" HIY "这一招变化莫测，奇幻无"
      #                        "方，不由大吃一惊，慌乱中破绽迭出。\n" NOR;
      #         } else
      #         {
      #                 msg += HIC "$n" HIC "不敢小觑$P" HIC
      #                        "的来招，腾挪躲闪，小心招架。\n" NOR;
      #                 count = 0;
      #         }
      # 
      #         message_sort(msg, me, target);
      #         me->add_temp("apply/attack", count);
      # 
      #         me->add("neili", -70 * n);
      #         for (i = 0; i < n; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 if (random(2) && ! target->is_busy())
      #                         target->start_busy(1);
      # 
      #                 COMBAT_D->do_attack(me, target, 0, 0);
      #         }
      # 
      #         me->start_busy(2 + random(4));
      #         me->add_temp("apply/attack", -count);
      # 
      #         return 1;
      # }
end
