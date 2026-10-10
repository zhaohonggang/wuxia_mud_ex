defmodule Kantele.Combat.Skills.Performs.TanzhiShentong.Po do
  @moduledoc """
  perform「破九域」（source tanzhi-shentong/po.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"dp", "dodge"}], "level_gates": [{"tanzhi-shentong", "180"}, {"throwing", "180"}], "map_gates": [{"finger", "tanzhi-shentong"}], "prepared_gates": [{"finger", "tanzhi-shentong"}], "resource_gates": [{"max_neili", "2400"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你手中没有拿着暗器，难以施展", "你弹指神通修为不够，难以施展", "你基本暗器修为不够，难以施展", "你没有激发弹指神通，难以施展", "你没有准备弹指神通，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger") + me->query_skill("throwing")", "dp_formula": "target->query_skill("dodge") + target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_d_ahinfo": %{"clear": true, "query": true}, "combat_messages": %{"fail": [], "other": ["HIW "陡见$N" HIW "双目精光四射，顿听破空声大作，一" +
      #                 weapon->query("base_unit") + weapon->name() + HIW "由"
      #                 "指尖弹出，疾速射向$n" HIW "。\n" NOR", "= HIW "$n" HIW "手腕一麻，手中" + weapon2->name() +
      #                                  HIW "不由脱手而出！\n" NOR", "COMBAT_D->query_ahinfo()))
      #                              msg += pmsg", "= "( $n" + eff_status_msg(p) + " )\n"", "= CYN "可是$p" CYN "早料得$P" CYN "有此一着，急"
      #                          "忙飞身跃起，躲闪开来。\n" NOR"], "success": ["= HIR "只见那" + weapon->query("base_unit") +
      #                          weapon->name() + HIR "来势迅猛之极，$n" HIR
      #                          "根本无暇闪避，被这招击个正中！\n" NOR"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "hit_ob_calls": [{"me", "target", "me->query("jiali") + 300"}], "receive_damage_calls": [%{"formula": "damage", "kind": "wound", "part": "qi", "source": "me"}], "reset_action": true, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "max_qi", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "throwing"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include "/kungfu/skill/eff_msg.h";
      # 
      # #define PO "「" HIW "破九域" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int ap, dp, damage, p;
      #         string pmsg;
      #         string msg;
      #         object weapon, weapon2;
      # 
      #         if (userp(me) && ! me->query("can_perform/tanzhi-shentong/po"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(PO "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("handing"))
      #            || (string)weapon->query("skill_type") != "throwing")
      #                 return notify_fail("你手中没有拿着暗器，难以施展" PO "。\n");
      # 
      #         if ((int)me->query_skill("tanzhi-shentong", 1) < 180)
      #                 return notify_fail("你弹指神通修为不够，难以施展" PO "。\n");
      # 
      #         if ((int)me->query_skill("throwing", 1) < 180)
      #                 return notify_fail("你基本暗器修为不够，难以施展" PO "。\n");
      # 
      #         if (me->query_skill_mapped("finger") != "tanzhi-shentong")
      #                 return notify_fail("你没有激发弹指神通，难以施展" PO "。\n");
      # 
      #         if (me->query_skill_prepared("finger") != "tanzhi-shentong")
      #                 return notify_fail("你没有准备弹指神通，难以施展" PO "。\n");
      # 
      #         if (me->query("max_neili") < 2400)
      #                 return notify_fail("你的内力修为不足，难以施展" PO "。\n");
      # 
      #         if (me->query("neili") < 500)
      #                 return notify_fail("你现在的真气不够，难以施展" PO "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         me->add("neili", -300);
      #         weapon->add_amount(-1);
      # 
      #         msg = HIW "陡见$N" HIW "双目精光四射，顿听破空声大作，一" +
      #               weapon->query("base_unit") + weapon->name() + HIW "由"
      #               "指尖弹出，疾速射向$n" HIW "。\n" NOR;
      # 
      #         ap = me->query_skill("finger") + me->query_skill("throwing");
      #         dp = target->query_skill("dodge") + target->query_skill("parry");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #             me->start_busy(2);
      #                    //damage = ap / 2 + random(ap / 3);
      #                    damage = ap / 2 + random(ap / 2);
      # 
      #                 msg += HIR "只见那" + weapon->query("base_unit") +
      #                        weapon->name() + HIR "来势迅猛之极，$n" HIR
      #                        "根本无暇闪避，被这招击个正中！\n" NOR;
      # 
      #                 target->receive_wound("qi", damage, me);
      #                    COMBAT_D->clear_ahinfo();
      #                    weapon->hit_ob(me, target, me->query("jiali") + 300);
      # 
      #                 if ((weapon2 = target->query_temp("weapon"))
      #                    && ap / 3 + random(ap) > dp)
      #                 {
      #                         msg += HIW "$n" HIW "手腕一麻，手中" + weapon2->name() +
      #                                HIW "不由脱手而出！\n" NOR;
      #                         weapon2->move(environment(me));
      #                 }
      # 
      #                 p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
      #                 if (stringp(pmsg = COMBAT_D->query_ahinfo()))
      #                            msg += pmsg;
      #                            msg += "( $n" + eff_status_msg(p) + " )\n";
      #                    message_combatd(msg, me, target);
      #         } else
      #         {
      #             me->start_busy(3);
      #                 msg += CYN "可是$p" CYN "早料得$P" CYN "有此一着，急"
      #                        "忙飞身跃起，躲闪开来。\n" NOR;
      #                 message_combatd(msg, me, target);
      #         }
      #         me->reset_action();
      #         return 1;
      # }
end
