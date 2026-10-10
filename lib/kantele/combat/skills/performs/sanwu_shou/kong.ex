defmodule Kantele.Combat.Skills.Performs.SanwuShou.Kong do
  @moduledoc """
  perform「无孔不入」（source sanwu-shou/kong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "whip"}, {"dp", "parry"}], "level_gates": [{"force", "180"}, {"sanwu-shou", "140"}], "map_gates": [{"whip", "sanwu-shou"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你三无三不手够娴熟，难以施展", "你没有激发三无三不手，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("whip")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "\n$N" HIY "一声长啸，内劲暴涨，施出绝招「" HIW "无孔"
      #                 "不入" HIY "」手中" + weapon->name() + HIY "哧哧作响，龙"
      #                 "吟不定，$N" HIY "猛然腾空而起，挥舞着手中的" + weapon->name() +
      #                 HIY "，凌空直下，涌向$n" HIY "。\n" NOR", "CYN "$n" CYN "见$N" CYN "这招袭来，内力"
      #                         "充盈，只得向后一纵，才躲过这一鞭。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60 + count,
      #                                              HIR "但见$N" HIR "攻势如洪，气势磅礴，"
      #                                              "$n" HIR "心中略微一惊，惨叫一声，顿"
      #                                              "时鲜血淋淋。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "misc_gates": ["gender"], "resource_adds": [{"neili", "-100"}, {"neili", "-220"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-220"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(3));", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(3));
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
      # #define KONG "「" HIY "无孔不入" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage, count;
      #         string msg;
      #         int ap, dp;
      #         object weapon;
      # 
      #         if (userp(me) && ! me->query("can_perform/sanwu-shou/kong"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(KONG "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "whip")
      #                 return notify_fail("你所使用的武器不对，难以施展" KONG "。\n");
      # 
      #         if ((int)me->query_skill("sanwu-shou", 1) < 140)
      #                 return notify_fail("你三无三不手够娴熟，难以施展" KONG "。\n");
      # 
      #         if (me->query_skill_mapped("whip") != "sanwu-shou")
      #                 return notify_fail("你没有激发三无三不手，难以施展" KONG "。\n");
      # 
      #         if (me->query_skill("force") < 180)
      #                 return notify_fail("你的内功修为不够，难以施展" KONG "。\n");
      # 
      #         if ((int)me->query("neili") < 300)
      #                 return notify_fail("你现在的真气不够，难以施展" KONG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         ap = me->query_skill("whip");
      #         dp = target->query_skill("parry");
      #         count = 0;
      # 
      #         if (target->query("shen") > 0)
      #         {
      #             count += 20;
      #             ap += ap * 10 / 100;
      #         }
      # 
      #         if (target->query("gender") != "女性")
      #         {
      #             count += 30;
      #             ap += ap * 15 / 100;
      #         }
      # 
      # 
      #         msg = HIY "\n$N" HIY "一声长啸，内劲暴涨，施出绝招「" HIW "无孔"
      #               "不入" HIY "」手中" + weapon->name() + HIY "哧哧作响，龙"
      #               "吟不定，$N" HIY "猛然腾空而起，挥舞着手中的" + weapon->name() +
      #               HIY "，凌空直下，涌向$n" HIY "。\n" NOR;
      #         message_sort(msg, me, target);
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap);
      #                 damage += damage * count / 100;
      #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60 + count,
      #                                            HIR "但见$N" HIR "攻势如洪，气势磅礴，"
      #                                            "$n" HIR "心中略微一惊，惨叫一声，顿"
      #                                            "时鲜血淋淋。\n" NOR);
      # 
      #                 me->start_busy(1 + random(3));
      #                 me->add("neili", -220);
      #         } else
      #         {
      #                 msg = CYN "$n" CYN "见$N" CYN "这招袭来，内力"
      #                       "充盈，只得向后一纵，才躲过这一鞭。\n" NOR;
      # 
      #                 me->start_busy(4);
      #                 me->add("neili", -100);
      #         }
      #         message_vision(msg, me, target);
      #         return 1;
      # }
end
