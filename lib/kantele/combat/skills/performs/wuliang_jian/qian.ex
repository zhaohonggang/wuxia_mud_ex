defmodule Kantele.Combat.Skills.Performs.WuliangJian.Qian do
  @moduledoc """
  perform「乾坤无量」（source wuliang-jian/qian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"force", "150"}, {"wuliang-jian", "100"}], "map_gates": [{"sword", "wuliang-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功的修为不够，难以施展", "你的无量剑法修为不够，难以施展", "你的真气不够，难以施展", "你没有激发无量剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可却见" CYN "$n" CYN "猛的拔地而起，避开了"
      #                          CYN "$N" CYN "的剑招。\n"NOR"], "success": ["HIR "只见$N" HIR "手中" + weapon->name() + HIR "“唰"
      #                 "唰唰唰”连攻四剑，剑招去势极快，全然笼罩$n" HIR "！\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
      #                                              HIR "结果$n" HIR "阻挡不及，顿时被$N"
      #                                              HIR "斩中数剑，伤口见骨，苦不堪言。\n"
      #                                              NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // qian.c
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define QIAN "「" HIR "乾坤无量" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp;
      #         int damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/wuliang-jian/qian"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(QIAN "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #               (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" QIAN "。\n");
      # 
      #         if (me->query_skill("force") < 150)
      #                 return notify_fail("你的内功的修为不够，难以施展" QIAN "。\n");
      # 
      #         if (me->query_skill("wuliang-jian", 1) < 100)
      #                 return notify_fail("你的无量剑法修为不够，难以施展" QIAN "。\n");
      # 
      #         if (me->query("neili") < 300)
      #                 return notify_fail("你的真气不够，难以施展" QIAN "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "wuliang-jian")
      #                 return notify_fail("你没有激发无量剑法，难以施展" QIAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "只见$N" HIR "手中" + weapon->name() + HIR "“唰"
      #               "唰唰唰”连攻四剑，剑招去势极快，全然笼罩$n" HIR "！\n" NOR;
      # 
      #         ap = me->query_skill("sword");
      #         dp = target->query_skill("parry");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap / 2 + random(ap / 2);
      #                 me->add("neili", -150);
      #                 me->start_busy(2);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
      #                                            HIR "结果$n" HIR "阻挡不及，顿时被$N"
      #                                            HIR "斩中数剑，伤口见骨，苦不堪言。\n"
      #                                            NOR);
      #         } else
      #         {
      #                 me->add("neili", -50);
      #                 me->start_busy(3);
      #                 msg += CYN "可却见" CYN "$n" CYN "猛的拔地而起，避开了"
      #                        CYN "$N" CYN "的剑招。\n"NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
