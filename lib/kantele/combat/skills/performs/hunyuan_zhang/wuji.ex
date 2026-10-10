defmodule Kantele.Combat.Skills.Performs.HunyuanZhang.Wuji do
  @moduledoc """
  perform「混元无极」（source hunyuan-zhang/wuji.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "force"}, {"skill", "hunyuan-zhang"}], "level_gates": [{"force", "120"}], "map_gates": [], "prepared_gates": [{"strike", "hunyuan-zhang"}], "resource_gates": [{"max_neili", "1400"}, {"neili", "240"}], "var_gates": [{"skill", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的混元掌等级不够, 不能施展", "你内功修为不够，无法施展", "你内力修为不足，无法施展", "你的内力不够，无法施展", "你没有准备使用混元掌，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "怒喝一声，潜运「" HIW "混元无极" HIC "」，双拳挟"
      #                 "着隐隐的风雷之声向$n" HIC "击去。\n" NOR", "= CYN "只见$n" CYN "不慌不忙，轻轻一闪，躲过"
      #                          "了$N" CYN "的必杀一击！\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
      #                                              HIR "$n" HIR "只觉得胸前一阵剧痛，“哇”的一"
      #                                              "声喷出一口鲜血！\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-120"}, {"neili", "-220"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-220"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(2));", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(2));
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // wuji.c 混元无极
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define WU "「" HIW "混元无极" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     string msg;
      # //    object weapon;
      #     int skill, ap, dp, damage;
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #         if (userp(me) && ! me->query("can_perform/hunyuan-zhang/wuji"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! me->is_fighting(target))
      #         return notify_fail(WU "只能对战斗中的对手使用。\n");
      # 
      #     skill = me->query_skill("hunyuan-zhang", 1);
      # 
      #     if (skill < 120)
      #         return notify_fail("你的混元掌等级不够, 不能施展" WU "！\n");
      # 
      #     if (me->query_skill("force", 1) < 120)
      #         return notify_fail("你内功修为不够，无法施展" WU "！\n");
      # 
      #     if (me->query("max_neili") < 1400)
      #         return notify_fail("你内力修为不足，无法施展" WU "！\n");
      # 
      #     if (me->query("neili") < 240)
      #         return notify_fail("你的内力不够，无法施展" WU "！\n");
      # 
      #         if (me->query_skill_prepared("strike") != "hunyuan-zhang")
      #                 return notify_fail("你没有准备使用混元掌，无法施展" WU "！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIC "$N" HIC "怒喝一声，潜运「" HIW "混元无极" HIC "」，双拳挟"
      #               "着隐隐的风雷之声向$n" HIC "击去。\n" NOR;
      # 
      #     ap = me->query_skill("strike");
      #     dp = target->query_skill("force");
      #     if (ap / 2 + random(ap) > dp)
      #     {
      #         me->add("neili", -220);
      #         damage = ap + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
      #                                            HIR "$n" HIR "只觉得胸前一阵剧痛，“哇”的一"
      #                                            "声喷出一口鲜血！\n" NOR);
      #         me->start_busy(1 + random(2));
      #     } else
      #     {
      #         me->add("neili", -120);
      #         msg += CYN "只见$n" CYN "不慌不忙，轻轻一闪，躲过"
      #                        "了$N" CYN "的必杀一击！\n" NOR;
      #         me->start_busy(3);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end
