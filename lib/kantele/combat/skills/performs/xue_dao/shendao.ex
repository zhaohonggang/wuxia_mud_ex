defmodule Kantele.Combat.Skills.Performs.XueDao.Shendao do
  @moduledoc """
  perform「shendao」（source xue-dao/shendao.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "blade"}], "level_gates": [{"force", "100"}, {"xue-dao", "100"}], "map_gates": [{"blade", "xue-dao"}], "prepared_gates": [], "resource_gates": [{"max_neili", "1200"}, {"neili", "400"}, {"qi", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你还不会使用「祭血神刀」！\n", "「祭血神刀」只能对战斗中的对手使用。\n", "装备刀才能使用「祭血神刀」！\n", "你血刀刀法不够娴熟，使不出「祭血神刀」。\n", "你内功火候不够，难以施展「祭血神刀」。\n", "你的内力修为不足，无法运足内力。\n", "你现在真气不够，无法将「祭血神刀」使完！\n", "你还敢使这招？找死啊！\n", "你为人不够凶残，还无法领会「祭血神刀」的奥妙。\n", "你没有激发血刀刀法，不能使用「祭血神刀」。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$n" CYN "侧身避让，不慌不忙，躲过了$N"
      #                          CYN "的必杀一刀。\n"NOR"], "success": ["HIR "$N" HIR "右手持刀向左肩一勒，一阵血珠溅满刀面，紧接着右臂抡出，一片血光"
      #                 "裹住刀影向$n" HIR "当头劈落，\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 70,
      #                                              HIR "$n" HIR "疾忙侧身避让，但血刀疾闪，只觉眼"
      #                                              "前一阵血红，刀刃劈面而下，鲜血飞"
      #                                              "溅，不禁惨声大嚎！\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("blade")"}, "receive_damage_calls": [%{"formula": "50", "kind": "wound", "part": "qi", "source": None}], "resource_adds": [{"neili", "-100"}, {"neili", "-350"}], "resource_queries": ["max_neili", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-350"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // shendao.c  血刀「祭血神刀」
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         object weapon;
      # 
      #         if (userp(me) && ! me->query("can_perform/xue-dao/shendao"))
      #                 return notify_fail("你还不会使用「祭血神刀」！\n");
      # 
      #         if (! target)
      #                 target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("「祭血神刀」只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "blade")
      #                 return notify_fail("装备刀才能使用「祭血神刀」！\n");
      # 
      #         if ((int)me->query_skill("xue-dao", 1) < 100)
      #                 return notify_fail("你血刀刀法不够娴熟，使不出「祭血神刀」。\n");
      # 
      #         if ((int)me->query_skill("force") < 100 )
      #                 return notify_fail("你内功火候不够，难以施展「祭血神刀」。\n");
      # 
      #         if ((int)me->query("max_neili") < 1200)
      #                 return notify_fail("你的内力修为不足，无法运足内力。\n");
      # 
      #         if ((int)me->query("neili") < 400)
      #                 return notify_fail("你现在真气不够，无法将「祭血神刀」使完！\n");
      # 
      #         if ((int)me->query("qi") < 100)
      #                 return notify_fail("你还敢使这招？找死啊！\n");
      # 
      #         if ((int)me->query("shen") > -1000)
      #                 return notify_fail("你为人不够凶残，还无法领会「祭血神刀」的奥妙。\n");
      # 
      #         if (me->query_skill_mapped("blade") != "xue-dao")
      #                 return notify_fail("你没有激发血刀刀法，不能使用「祭血神刀」。\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "右手持刀向左肩一勒，一阵血珠溅满刀面，紧接着右臂抡出，一片血光"
      #               "裹住刀影向$n" HIR "当头劈落，\n" NOR;
      # 
      #         if (random(me->query_skill("blade")) > (int)target->query_skill("force") / 2)
      #         {
      #                 damage = me->query_skill("blade");
      #                 damage = damage / 2 + random(damage / 2);
      #                 if (me->query("character") == "心狠手辣")
      #                         damage += damage * 3 / 10;
      #                 me->add("neili", -350);
      #                 me->start_busy(2);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 70,
      #                                            HIR "$n" HIR "疾忙侧身避让，但血刀疾闪，只觉眼"
      #                                            "前一阵血红，刀刃劈面而下，鲜血飞"
      #                                            "溅，不禁惨声大嚎！\n" NOR);
      #         } else
      #         {
      #                 me->start_busy(2);
      #                 msg += CYN "可是$n" CYN "侧身避让，不慌不忙，躲过了$N"
      #                        CYN "的必杀一刀。\n"NOR;
      #                 me->add("neili", -100);
      #         }
      #         me->receive_wound("qi", 50);
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end
