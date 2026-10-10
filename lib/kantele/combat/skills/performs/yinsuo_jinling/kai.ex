defmodule Kantele.Combat.Skills.Performs.YinsuoJinling.Kai do
  @moduledoc """
  perform「开天辟地」（source yinsuo-jinling/kai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "whip"}, {"damage", "yinsuo-jinling"}, {"dp", "parry"}], "level_gates": [{"force", "180"}, {"yinsuo-jinling", "140"}], "map_gates": [{"whip", "yinsuo-jinling"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你银索金铃够娴熟，难以施展", "你没有激发银索金铃，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("whip")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "\n$N" HIW "长啸一声，疼空而起，施出绝招「" HIY "开天辟地" HIW
      #                 "」，手中" +weapon->name() + HIW "犹如长龙般龙吟不定，临空而下，罩"
      #                 "向$n。" NOR", "CYN "\n$n" CYN "见$N" CYN "这招袭来，内力"
      #                         "充盈，只得向后一纵，才躲过这一鞭。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                              HIR "\n但见$N" HIR "攻势如洪，气势磅礴，"
      #                                              "$n" HIR "心中略微一惊，惨叫一声，顿"
      #                                              "时鲜血淋淋。\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("yinsuo-jinling", 1)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-220"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-220"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(2));", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(2));
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
      # #define KAI "「" HIY "开天辟地" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      #         object weapon;
      # 
      #         if (userp(me) && ! me->query("can_perform/yinsuo-jinling/kai"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(KAI "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "whip")
      #                 return notify_fail("你所使用的武器不对，难以施展" KAI "。\n");
      # 
      #         if ((int)me->query_skill("yinsuo-jinling", 1) < 140)
      #                 return notify_fail("你银索金铃够娴熟，难以施展" KAI "。\n");
      # 
      #         if (me->query_skill_mapped("whip") != "yinsuo-jinling")
      #                 return notify_fail("你没有激发银索金铃，难以施展" KAI "。\n");
      # 
      #         if (me->query_skill("force") < 180)
      #                 return notify_fail("你的内功修为不够，难以施展" KAI "。\n");
      # 
      #         if ((int)me->query("neili") < 300)
      #                 return notify_fail("你现在的真气不够，难以施展" KAI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         ap = me->query_skill("whip");
      #         dp = target->query_skill("parry");
      # 
      #         msg = HIW "\n$N" HIW "长啸一声，疼空而起，施出绝招「" HIY "开天辟地" HIW
      #               "」，手中" +weapon->name() + HIW "犹如长龙般龙吟不定，临空而下，罩"
      #               "向$n。" NOR;
      # 
      #         message_sort(msg, me, target);
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = (int)me->query_skill("yinsuo-jinling", 1);
      #                 damage += random(damage / 2);
      # 
      #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                            HIR "\n但见$N" HIR "攻势如洪，气势磅礴，"
      #                                            "$n" HIR "心中略微一惊，惨叫一声，顿"
      #                                            "时鲜血淋淋。\n" NOR);
      # 
      #                 me->start_busy(2 + random(2));
      #                 me->add("neili", -220);
      #         } else
      #         {
      #                 msg = CYN "\n$n" CYN "见$N" CYN "这招袭来，内力"
      #                       "充盈，只得向后一纵，才躲过这一鞭。\n" NOR;
      # 
      #                 me->start_busy(4);
      #                 me->add("neili", -100);
      #         }
      #         message_vision(msg, me, target);
      #         return 1;
      # }
end
