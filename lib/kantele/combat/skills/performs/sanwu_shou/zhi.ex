defmodule Kantele.Combat.Skills.Performs.SanwuShou.Zhi do
  @moduledoc """
  perform「无所不至」（source sanwu-shou/zhi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "whip"}, {"dp", "dodge"}], "level_gates": [{"sanwu-shou", "100"}], "map_gates": [{"whip", "sanwu-shou"}], "prepared_gates": [], "resource_gates": [{"neili", "140"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你三无三不手不够娴熟，难以施展", "你没有激发三无三不手，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("whip")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["HIC", "HIM", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIM "\n$N" HIM "长啸一声，腾空而起，施出绝招 「" HIW "无"
      #                 "所不至" HIM "」手中" + weapon->name() + HIM "化出无数"
      #                 "光点，犹如满天花雨般洒向$n全身各处" HIM "。" NOR", "HIC "$n" HIC "见$N" HIC "这几鞭招式凌厉，凶猛异"
      #                        "常，只得苦苦招架。\n" NOR"], "success": ["HIR "结果$n" HIR "被$N" HIR "攻了个措手不及，$n"
      #                         HIR "慌忙招架，心中叫苦。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 2)", "operator": ">", "right_side": "dp"}, "misc_gates": ["gender"], "resource_adds": [{"neili", "-attack_time * 20"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1 + random(attack_time));"], "remote_damage": false, "set_flags": [], "temp_set": []}
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
      # #define ZHI "「" HIW "无所不至" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string msg;
      #     int ap, dp;
      #     int count;
      #     int i, attack_time;
      # 
      #     if (userp(me) && ! me->query("can_perform/sanwu-shou/zhi"))
      #             return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #     if (! target || ! me->is_fighting(target))
      #             return notify_fail(ZHI "只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon"))
      #             || (string)weapon->query("skill_type") != "whip")
      #             return notify_fail("你所使用的武器不对，难以施展" ZHI "。\n");
      # 
      #     if ((int)me->query_skill("sanwu-shou", 1) < 100)
      #             return notify_fail("你三无三不手不够娴熟，难以施展" ZHI "。\n");
      # 
      #     if (me->query_skill_mapped("whip") != "sanwu-shou")
      #             return notify_fail("你没有激发三无三不手，难以施展" ZHI "。\n");
      # 
      #     if (me->query("neili") < 140)
      #             return notify_fail("你现在的真气不够，难以施展" ZHI "。\n");
      # 
      #     if (! living(target))
      #             return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIM "\n$N" HIM "长啸一声，腾空而起，施出绝招 「" HIW "无"
      #               "所不至" HIM "」手中" + weapon->name() + HIM "化出无数"
      #               "光点，犹如满天花雨般洒向$n全身各处" HIM "。" NOR;
      # 
      #     message_sort(msg, me, target);
      # 
      #     ap = me->query_skill("whip");
      #     dp = target->query_skill("dodge");
      #     attack_time = 4;
      # 
      #     if (target->query("shen") > 0)
      #         ap += ap * 10 / 100;
      # 
      #     if (target->query("gender") != "女性")
      #     {
      #         attack_time += 1;
      #         ap += ap * 15 / 100;
      #     }
      # 
      #     if (ap / 2 + random(ap * 2) > dp)
      #     {
      #                 msg = HIR "结果$n" HIR "被$N" HIR "攻了个措手不及，$n"
      #                       HIR "慌忙招架，心中叫苦。\n" NOR;
      #                 count = ap / 8;
      #                 attack_time += random(ap / 45);
      #     } else
      #     {
      #                 msg= HIC "$n" HIC "见$N" HIC "这几鞭招式凌厉，凶猛异"
      #                      "常，只得苦苦招架。\n" NOR;
      #                 count = ap / 15;
      #     }
      #     me->add_temp("apply/attack", count);
      #     message_combatd(msg, me, target);
      # 
      #     if (attack_time > 7)
      #             attack_time = 7;
      # 
      #     me->add("neili", -attack_time * 20);
      # 
      #     for (i = 0; i < attack_time; i++)
      #     {
      #         if (! me->is_fighting(target))
      #             break;
      # 
      #         COMBAT_D->do_attack(me, target, weapon, 0);
      #     }
      #     me->add_temp("apply/attack", -count);
      #     me->start_busy(1 + random(attack_time));
      # 
      #     return 1;
      # }
end
