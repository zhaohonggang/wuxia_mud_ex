defmodule Kantele.Combat.Skills.Performs.LiuyangZhang.Zhong do
  @moduledoc """
  perform「生死符」（source liuyang-zhang/zhong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}], "level_gates": [{"force", "200"}, {"liuyang-zhang", "150"}], "map_gates": [{"strike", "liuyang-zhang"}, {"throwing", "liuyang-zhang"}], "prepared_gates": [{"strike", "liuyang-zhang"}], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "ss_poison", "duration_formula": "ap / 70 + random(ap / 30)", "id_formula": "me->query("id")", "level_formula": "flvl + random(flvl * 2)"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内功不够火候，难以施展", "你的天山六阳掌不够娴熟，难以施展", "你没有激发掌法天山六阳掌，难以施展", "你没有激发暗器天山六阳掌，难以施展", "你现在没有准备天山六阳掌，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force") + me->query_skill("throwing") + me->query_skill("medical")", "dp_formula": "target->query_skill("force") + target->query_skill("medical")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "逆运真气，化空气中的水露为寒冰，凝于掌中，继而掌"
      #                 "出如风，轻飘飘地向$n" HIW "拍落。\n"", "= CYN "可是$p" CYN "内力激荡，将$P"
      #                          CYN "那枚生死符硬生生震出体外。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 50,
      #                                              HIR "只见$n" HIR "被$N" HIR "一掌拍中"
      #                                              "，紧接着身子一颤，$P" HIR "那枚生死符"
      #                                              "已种入$p" HIR "体内！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "10 + random(5)", "kind": "wound", "part": "jing", "source": "me"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": ["ss_poison"], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(4));", "me->start_busy(3);", "target->start_busy(1);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(4));
      #   - me->start_busy(3);
      #   - target->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define ZHONG "「" HIW "生死符" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int damage;
      #         int ap, dp, flvl;
      # 
      #         if (userp(me) && ! me->query("can_perform/liuyang-zhang/zhong"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHONG "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_skill("force") < 200)
      #                 return notify_fail("你的内功不够火候，难以施展" ZHONG "。\n");
      # 
      #         if ((int)me->query_skill("liuyang-zhang", 1) < 150)
      #                 return notify_fail("你的天山六阳掌不够娴熟，难以施展" ZHONG "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "liuyang-zhang")
      #                 return notify_fail("你没有激发掌法天山六阳掌，难以施展" ZHONG "。\n");
      # 
      #         if (me->query_skill_mapped("throwing") != "liuyang-zhang")
      #                 return notify_fail("你没有激发暗器天山六阳掌，难以施展" ZHONG "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "liuyang-zhang")
      #                 return notify_fail("你现在没有准备天山六阳掌，难以施展" ZHONG "。\n");
      # 
      #         if (me->query("neili") < 100)
      #                 return notify_fail("你的真气不够，难以施展" ZHONG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "逆运真气，化空气中的水露为寒冰，凝于掌中，继而掌"
      #               "出如风，轻飘飘地向$n" HIW "拍落。\n";
      # 
      #         ap = me->query_skill("force") + me->query_skill("throwing") + me->query_skill("medical");
      #         dp = target->query_skill("force") + target->query_skill("medical");
      #         flvl = me->query("jiali");
      #         if (ap / 3 + random(ap) > dp)
      #         {
      #                 target->receive_wound("jing", 10 + random(5), me);
      #                 damage = ap / 2 + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 50,
      #                                            HIR "只见$n" HIR "被$N" HIR "一掌拍中"
      #                                            "，紧接着身子一颤，$P" HIR "那枚生死符"
      #                                            "已种入$p" HIR "体内！\n" NOR);
      #                 target->affect_by("ss_poison",
      #                                ([ "level" : flvl + random(flvl * 2),
      #                                   "id"    : me->query("id"),
      #                                   "duration" : ap / 70 + random(ap / 30) ]));
      #                 me->start_busy(1 + random(4));
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "内力激荡，将$P"
      #                        CYN "那枚生死符硬生生震出体外。\n" NOR;
      #                 me->start_busy(3);
      #                 target->start_busy(1);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
