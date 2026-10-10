defmodule Kantele.Combat.Skills.Performs.ShedaoQigong.Xian do
  @moduledoc """
  perform「xian」（source shedao-qigong/xian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"dp", "dodge"}, {"pp", "parry"}], "level_gates": [{"shedao-qigong", "120"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你现在还不会使用神龙再现！\n", "「神龙再现」只能对战斗中的对手使用。\n", "你的蛇岛奇功修为有限，不能使用「神龙再现」！\n", "你的真气不够，无法运用「神龙再现」！\n", "你使用的兵器不对，怎么使用「神龙再现」！\n", "你没有将", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill(skill)", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "轻身一跃，已然逼近$n" HIW "随即一掌向$p"
      #                         HIW "肩头按去，虚虚实实，暗藏千百变化。\n" NOR", "HIW "$N" HIW "足不点地，飘然欺身上前，一剑刺出，" +
      #                         weapon->name() + HIW "直指$n" HIW "腰间。" NOR", "HIW "$N" HIW "手中" + weapon->name() +
      #                         HIW "吞吞吐吐，虚虚实实，化作一团光影，斜斜扫向$n"
      #                         HIW "腰间。\n" NOR", "= CYN "$n" CYN "不敢怠慢，见招拆招，接连破去$P"
      #                          CYN "后续三十六道变化，不漏半点破绽。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 50,
      #                                              HIR "$n" HIR "欲架不能，欲躲不得，一个闪失"
      #                                              "，被$P" HIR "打了个正中，鲜血迸流。\n" NOR)", "= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 55,
      #                                              HIR "$n" HIR "见$P" HIR "这招极为精妙，不敢"
      #                                              "抵挡，慌忙后退跃开，却见$P" HIR "招式一变，竟然料敌在先，\n"
      #                                              "一招正中$p" HIR "，直打了个鲜血四下飞溅。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-150"}, {"neili", "-180"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "staff"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-150"}, {"neili", "-180"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // xian.c 神龙再现
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         string skill;
      #         int ap, pp, dp, damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/shedao-qigong/xian"))
      #                 return notify_fail("你现在还不会使用神龙再现！\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! me->is_fighting(target))
      #                 return notify_fail("「神龙再现」只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_skill("shedao-qigong", 1) < 120)
      #                 return notify_fail("你的蛇岛奇功修为有限，不能使用「神龙再现」！\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你的真气不够，无法运用「神龙再现」！\n");
      # 
      #         if (objectp(weapon = me->query_temp("weapon")) &&
      #             weapon->query("skill_type") != "staff" &&
      #             weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的兵器不对，怎么使用「神龙再现」！\n");
      # 
      #         if (weapon)
      #                 skill = weapon->query("skill_type");
      #         else
      #                 skill = "unarmed";
      # 
      #         if (me->query_skill_mapped(skill) != "shedao-qigong")
      #                 return notify_fail("你没有将" + (string)to_chinese(skill)[4..<1] +
      #                                    "激发为蛇岛奇功, 不能使用「神龙再现」！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         switch (skill)
      #         {
      #         case "unarmed":
      #                 msg = HIW "$N" HIW "轻身一跃，已然逼近$n" HIW "随即一掌向$p"
      #                       HIW "肩头按去，虚虚实实，暗藏千百变化。\n" NOR;
      #                 break;
      # 
      #         case "sword":
      #                 msg = HIW "$N" HIW "足不点地，飘然欺身上前，一剑刺出，" +
      #                       weapon->name() + HIW "直指$n" HIW "腰间。" NOR;
      #                 break;
      # 
      #         case "staff":
      #                 msg = HIW "$N" HIW "手中" + weapon->name() +
      #                       HIW "吞吞吐吐，虚虚实实，化作一团光影，斜斜扫向$n"
      #                       HIW "腰间。\n" NOR;
      #                 break;
      #         }
      # 
      #         ap = me->query_skill(skill);
      #         pp = target->query_skill("parry");
      #         dp = target->query_skill("dodge");
      #         if (ap / 2 + random(ap) > pp)
      #         {
      #                 me->add("neili", -150);
      #                 me->start_busy(2);
      #                 damage = ap / 2 + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 50,
      #                                            HIR "$n" HIR "欲架不能，欲躲不得，一个闪失"
      #                                            "，被$P" HIR "打了个正中，鲜血迸流。\n" NOR);
      #         } else
      #         if (ap / 3 + random(ap) > dp)
      #         {
      #                 me->add("neili", -180);
      #                 me->start_busy(3);
      #                 damage = ap / 2 + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 55,
      #                                            HIR "$n" HIR "见$P" HIR "这招极为精妙，不敢"
      #                                            "抵挡，慌忙后退跃开，却见$P" HIR "招式一变，竟然料敌在先，\n"
      #                                            "一招正中$p" HIR "，直打了个鲜血四下飞溅。\n" NOR);
      #         } else
      #         {
      #                 me->add("neili", -100);
      #                 me->start_busy(3);
      #                 msg += CYN "$n" CYN "不敢怠慢，见招拆招，接连破去$P"
      #                        CYN "后续三十六道变化，不漏半点破绽。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
