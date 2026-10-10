defmodule Kantele.Combat.Skills.Performs.DamoJian.Zhe do
  @moduledoc """
  perform「达摩折元剑」（source damo-jian/zhe.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "force"}, {"lvl", "damo-jian"}], "level_gates": [{"damo-jian", "200"}], "map_gates": [{"sword", "damo-jian"}], "prepared_gates": [], "resource_gates": [{"max_neili", "2000"}, {"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "damo_zheyuan", "duration_formula": "5 + random(lvl / 20)", "id_formula": "me->query("id")", "level_formula": "lvl + random(lvl)"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你达摩剑法不够娴熟，难以施展", "你没有激发达摩剑法，难以施展", "你的内力修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword") + me->query_skill("force")", "dp_formula": "target->query_skill("force") * 2"}, "callback_functions": [%{"body": "int lvl = me->query_skill("damo-jian", 1);
      #   
      #           target->affect_by("damo_zheyuan",
      #                   ([ "level"    : lvl + random(lvl),
      #                      "id"       : me->query("id"),
      #                 ", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": ["= CYN "可是$n" CYN "内力深厚，使得$P"
      #                          CYN "这一招没有起到任何作用。\n" NOR"], "other": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                              (: final, me, target, damage :))"], "success": ["HIR "$N" HIR "蓦地将" + weapon->name() +
      #                 HIR "往前一送，顿时一道光华自剑上亮起，直逼$n"
      #                 HIR "丹田而去。\n" NOR"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 3)"}, "do_damage_calls": [%{"attack_type": "WEAPON_ATTACK", "callback": "final", "damage_factor": 50, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage / 3", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 6", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-100"}, {"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-200"}], "affect_by": ["damo_zheyuan"], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
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
      # #define ZHE "「" HIR "达摩折元剑" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # string final(object me, object target, int damage);
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string msg;
      #         int ap, dp;
      #         int damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/damo-jian/zhe"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHE "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你所使用的武器不对，难以施展" ZHE "。\n");
      # 
      #     if ((int)me->query_skill("damo-jian", 1) < 200)
      #                 return notify_fail("你达摩剑法不够娴熟，难以施展" ZHE "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "damo-jian")
      #                 return notify_fail("你没有激发达摩剑法，难以施展" ZHE "。\n");
      # 
      #         if ((int)me->query("max_neili") < 2000)
      #                 return notify_fail("你的内力修为不够，难以施展" ZHE "。\n");
      # 
      #         if (me->query("neili") < 300)
      #                 return notify_fail("你现在的真气不足，难以施展" ZHE "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "蓦地将" + weapon->name() +
      #               HIR "往前一送，顿时一道光华自剑上亮起，直逼$n"
      #               HIR "丹田而去。\n" NOR;
      # 
      #         ap = me->query_skill("sword") + me->query_skill("force");
      #         dp = target->query_skill("force") * 2;
      # 
      #     if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap / 3 + random(ap / 3);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                            (: final, me, target, damage :));
      #                 me->start_busy(2);
      #                 me->add("neili", -200);
      #     } else
      #         {
      #         msg += CYN "可是$n" CYN "内力深厚，使得$P"
      #                        CYN "这一招没有起到任何作用。\n" NOR;
      #         me->start_busy(4);
      #                 me->add("neili", -100);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
      # 
      # string final(object me, object target, int damage)
      # {
      #         int lvl = me->query_skill("damo-jian", 1);
      # 
      #         target->affect_by("damo_zheyuan",
      #                 ([ "level"    : lvl + random(lvl),
      #                    "id"       : me->query("id"),
      #                    "duration" : 5 + random(lvl / 20) ]));
      # 
      #         target->receive_damage("jing", damage / 3, me);
      #         target->receive_wound("jing", damage / 6, me);
      # 
      #         return HIR "突然$n" HIR "只觉丹田忽然一热，随即变得冷"
      #                "冰冰，不禁大惊失色。\n" NOR;
      # }
end
