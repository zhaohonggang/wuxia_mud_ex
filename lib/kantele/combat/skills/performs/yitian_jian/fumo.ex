defmodule Kantele.Combat.Skills.Performs.YitianJian.Fumo do
  @moduledoc """
  perform「伏魔剑诀」（source yitian-jian/fumo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"yitian-jian", "120"}], "map_gates": [{"sword", "yitian-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，无法施展", "你的倚天剑法不够娴熟，无法施展", "你现在真气不够，无法施展", "你没有激发倚天剑法，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "callback_functions": [%{"body": "return  HIR "只听$n" HIR "一声惨叫，被这一剑穿胸而入，顿"
      #                   "时鲜血四处飞溅。\n" NOR;", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一声冷哼，手中" + weapon->name() +
      #                 HIW "一振，剑身微颤，声若龙吟，剑光携着数个剑花"
      #                 "同时洒向$n" HIW "。\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
      #                                              (: final, me, target, damage :))", "= HIC "可$n" HIC "却是镇定逾恒，一丝不乱，"
      #                          "全神将此招化解开来。\n" NOR"], "success": []}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "WEAPON_ATTACK", "callback": "final", "damage_factor": 40, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define FUMO "「" HIR "伏魔剑诀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # string final(object me, object target, int damage);
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp;
      #         int damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/yitian-jian/fumo"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(FUMO "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，无法施展" FUMO "。\n");
      # 
      #         if ((int)me->query_skill("yitian-jian", 1) < 120)
      #                 return notify_fail("你的倚天剑法不够娴熟，无法施展" FUMO "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你现在真气不够，无法施展" FUMO "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "yitian-jian") 
      #                 return notify_fail("你没有激发倚天剑法，无法施展" FUMO "。\n");
      # 
      #         if (! living(target))
      #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "一声冷哼，手中" + weapon->name() +
      #               HIW "一振，剑身微颤，声若龙吟，剑光携着数个剑花"
      #               "同时洒向$n" HIW "。\n" NOR;
      # 
      #         me->add("neili", -150);
      #         ap = me->query_skill("sword");
      #         dp = target->query_skill("parry");
      #         if (target->is_bad()) ap += ap / 5;
      # 
      #         me->start_busy(3);
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap / 2 + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
      #                                            (: final, me, target, damage :));
      #         } else
      #         {
      #                 msg += HIC "可$n" HIC "却是镇定逾恒，一丝不乱，"
      #                        "全神将此招化解开来。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
      # 
      # string final(object me, object target, int damage)
      # {
      #         return  HIR "只听$n" HIR "一声惨叫，被这一剑穿胸而入，顿"
      #                 "时鲜血四处飞溅。\n" NOR;
      # }
end
