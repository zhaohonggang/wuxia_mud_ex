defmodule Kantele.Combat.Skills.Performs.WuhuDuanmendao.Duan do
  @moduledoc """
  perform「断字诀」（source wuhu-duanmendao/duan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "blade"}, {"dp", "parry"}], "level_gates": [{"wuhu-duanmendao", "50"}], "map_gates": [{"blade", "wuhu-duanmendao"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": [{"exp", "100000"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你现在的真气不足，难以施展", "你的五虎断门刀还不到家，难以施展", "你没有激发五虎断门刀，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("blade")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["HIW", "NOR", "RED"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "猛然伏地，使出五虎断门刀「断」字决，顿时一片白光"
      #                 "向前直滚而去！\n" NOR"], "success": []}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["attack", "damage", "parry"], "busy_lines": ["me->start_busy(1 + random(3));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define DUAN "「" HIW "断字诀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon, ob;
      #     string msg;
      #     int ap, dp, count;
      #     int i, num, exp;
      # 
      #     if (userp(me) && ! me->query("can_perform/wuhu-duanmendao/duan"))
      #             return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #     if (! target || ! me->is_fighting(target))
      #             return notify_fail(DUAN "只能在战斗中对对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon")) ||
      #         (string)weapon->query("skill_type") != "blade")
      #             return notify_fail("你使用的武器不对，难以施展" DUAN "。\n");
      # 
      #     if ((int)me->query("neili") < 200)
      #             return notify_fail("你现在的真气不足，难以施展" DUAN "。\n");
      # 
      #     if ((int)me->query_skill("wuhu-duanmendao", 1) < 50)
      #             return notify_fail("你的五虎断门刀还不到家，难以施展" DUAN "。\n");
      # 
      #     if (me->query_skill_mapped("blade") != "wuhu-duanmendao")
      #             return notify_fail("你没有激发五虎断门刀，难以施展" DUAN "。\n");
      # 
      #     if (! living(target))
      #             return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIW "$N" HIW "猛然伏地，使出五虎断门刀「断」字决，顿时一片白光"
      #               "向前直滚而去！\n" NOR;
      #     message_combatd(msg, me);
      # 
      #     me->clean_up_enemy();
      #     ob = me->select_opponent();
      #     ap = me->query_skill("blade");
      #     dp = target->query_skill("parry");
      #     exp = me->query("combat_exp");
      # 
      #     if (ap / 2 + random(ap) > dp)
      #         count = ap / 3;
      #     else
      #         count = 0;
      #     num = 2;
      #     if (exp < 100000 && exp > 600000)
      #         num += 0;
      #     else
      #         num += 600000 / exp;
      # 
      #     me->add_temp("apply/attack", count * num);
      #     me->add_temp("apply/parry", count * num);
      #     me->add_temp("apply/damage", count * num / 2);
      #     for (i = 0;i < num;i++)
      #     {
      #         COMBAT_D->do_attack(me, ob, me->query_temp("weapon"));
      #     }
      # 
      #     me->add_temp("apply/attack", -count* num);
      #     me->add_temp("apply/parry", -count* num);
      #     me->add_temp("apply/damage", -count * num / 2);
      # /*
      #     if (random(2) == 1)
      #         {
      #             me->add_temp("apply/attack", ap / 2);
      #             me->add_temp("apply/parry", ap / 2);
      #             me->add_temp("apply/damage", ap / 2);
      #             message_combatd(HIW  "$N从左面劈出第四刀！\n" NOR, me, target);
      #             COMBAT_D->do_attack(me, ob, me->query_temp("weapon"));
      #             me->add_temp("apply/attack", -ap / 2);
      #             me->add_temp("apply/parry", -ap / 2);
      #             me->add_temp("apply/damage", -ap / 2);
      # 
      #             if (random(2) == 1)
      #             {
      #                 me->add_temp("apply/attack", ap);
      #                 me->add_temp("apply/parry", ap);
      #                 me->add_temp("apply/damage", ap);
      #                 message_combatd(RED  "$N从右面劈出第五刀！\n" NOR, me, target);
      #                 COMBAT_D->do_attack(me, ob, me->query_temp("weapon"));
      #                 me->add_temp("apply/attack", -ap);
      #                 me->add_temp("apply/parry", -ap);
      #                 me->add_temp("apply/damage", -ap);
      #             }
      # 
      #         }
      # */
      #     me->add("neili", -100);
      #     me->start_busy(1 + random(3));
      #     return 1;
      # }
end
