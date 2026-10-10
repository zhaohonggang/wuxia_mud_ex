defmodule Kantele.Combat.Skills.Performs.PoguangDao.Yang do
  @moduledoc """
  perform「破阳刀」（source poguang-dao/yang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "blade"}, {"dp", "parry"}], "level_gates": [{"force", "150"}, {"poguang-dao", "120"}], "map_gates": [{"blade", "poguang-dao"}], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你破光刀法不够娴熟，难以施展", "你没有激发破光刀法，难以施展", "你的内功火候不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("blade")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "\n$N" HIW "一声怒喝，内劲瀑涨，施展出绝招「" HIY "破阳刀" HIW
      #                 "」手中" + wn + HIW "出神般的挥舞而出，虽然招式看似简单，但其中却"
      #                 "蕴藏着无穷的威力，有如神助一般。" NOR", "CYN "然而$n" CYN "以快制快，侧身"
      #                         "一跳，躲过这招。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
      #                                             HIR "$n" HIR "见$N" HIR "来势凶猛，刀"
      #                                             "光闪烁，惊骇间肩膀已中一刀，一股鲜血"
      #                                             "喷涌而出。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-180"}, {"neili", "-200"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-180"}, {"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(4));", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(4));
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define YANG "「" HIY "破阳刀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg, wn;
      #         object weapon;
      #         int ap, dp;
      # 
      #         me = this_player();
      # 
      #         if (userp(me) && ! me->query("can_perform/poguang-dao/yang"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(YANG "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "blade")
      #                 return notify_fail("你所使用的武器不对，难以施展" YANG "。\n");
      # 
      #         if ((int)me->query_skill("poguang-dao", 1) < 120)
      #                 return notify_fail("你破光刀法不够娴熟，难以施展" YANG "。\n");
      # 
      #         if (me->query_skill_mapped("blade") != "poguang-dao")
      #                 return notify_fail("你没有激发破光刀法，难以施展" YANG "。\n");
      # 
      #         if ((int)me->query_skill("force") < 150)
      #                 return notify_fail("你的内功火候不够，难以施展" YANG "。\n");
      # 
      #         if ((int)me->query("neili") < 400)
      #                 return notify_fail("你现在的真气不够，难以施展" YANG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         wn = weapon->name();
      # 
      #         msg = HIW "\n$N" HIW "一声怒喝，内劲瀑涨，施展出绝招「" HIY "破阳刀" HIW
      #               "」手中" + wn + HIW "出神般的挥舞而出，虽然招式看似简单，但其中却"
      #               "蕴藏着无穷的威力，有如神助一般。" NOR;
      # 
      #         message_sort(msg, me, target);
      # 
      #         ap = me->query_skill("blade");
      #         dp = target->query_skill("parry");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 2);
      #              msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
      #                                           HIR "$n" HIR "见$N" HIR "来势凶猛，刀"
      #                                           "光闪烁，惊骇间肩膀已中一刀，一股鲜血"
      #                                           "喷涌而出。\n" NOR);
      #              me->start_busy(2 + random(4));
      #              me->add("neili", -200);
      #         } else
      #         {
      #              msg = CYN "然而$n" CYN "以快制快，侧身"
      #                       "一跳，躲过这招。\n" NOR;
      # 
      #              me->start_busy(2);
      #              me->add("neili", -180);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
