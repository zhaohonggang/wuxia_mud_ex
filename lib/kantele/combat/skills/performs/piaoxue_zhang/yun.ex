defmodule Kantele.Combat.Skills.Performs.PiaoxueZhang.Yun do
  @moduledoc """
  perform「云海明灯」（source piaoxue-zhang/yun.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "200"}, {"piaoxue-zhang", "150"}], "map_gates": [{"strike", "piaoxue-zhang"}], "prepared_gates": [{"strike", "piaoxue-zhang"}], "resource_gates": [{"max_neili", "2000"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能施展", "你的内功的修为不够，无法施展", "你的飘雪穿云掌修为不够，无法施展", "你的真气不够，无法施展", "你没有激发飘雪穿云掌，无法施展", "你没有准备使用飘雪穿云掌，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "一声暴喝，陡然施出飘雪穿云掌绝技「云海明灯」，瞬"
      #                 "间连续攻出数招。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(2 + random(3));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define YUN "「" HIW "云海明灯" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/piaoxue-zhang/yun"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(YUN "只能在战斗中对对手使用。\n");
      # 
      #         if (me->query_temp("weapon") ||
      #             me->query_temp("secondary_weapon"))
      #                 return notify_fail("你必须空手才能施展" YUN "。\n");
      # 
      #         if (me->query_skill("force") < 200)
      #                 return notify_fail("你的内功的修为不够，无法施展" YUN "。\n");
      # 
      #         if (me->query_skill("piaoxue-zhang", 1) < 150)
      #                 return notify_fail("你的飘雪穿云掌修为不够，无法施展" YUN "。\n");
      # 
      #         if (me->query("neili") < 200 || me->query("max_neili") < 2000)
      #                 return notify_fail("你的真气不够，无法施展" YUN "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "piaoxue-zhang")
      #                 return notify_fail("你没有激发飘雪穿云掌，无法施展" YUN "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "piaoxue-zhang")
      #                 return notify_fail("你没有准备使用飘雪穿云掌，无法施展" YUN "。\n");
      # 
      #         if (! living(target))
      #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIW "$N" HIW "一声暴喝，陡然施出飘雪穿云掌绝技「云海明灯」，瞬"
      #               "间连续攻出数招。\n" NOR;
      #     message_combatd(msg, me);
      # 
      #     me->add("neili", -100);
      # 
      #         // 第一招
      #         me->add_temp("apply/attack", 30);
      #           COMBAT_D->do_attack(me, target, weapon, 0);
      # 
      #         // 第二招
      #         me->add_temp("apply/attack", 60);
      #     COMBAT_D->do_attack(me, target, weapon, 0);
      # 
      #         // 第三招
      #         me->add_temp("apply/attack", 90);
      #     COMBAT_D->do_attack(me, target, weapon, 0);
      # 
      #         // 消除攻击修正
      #         me->add_temp("apply/attack", -180);
      # 
      #     me->start_busy(2 + random(3));
      # 
      #     return 1;
      # }
end
