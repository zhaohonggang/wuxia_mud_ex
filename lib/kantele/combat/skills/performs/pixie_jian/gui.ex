defmodule Kantele.Combat.Skills.Performs.PixieJian.Gui do
  @moduledoc """
  perform「鬼魅身法」（source pixie-jian/gui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "pixie-jian"}, {"dp", "parry"}, {"skill", "pixie-jian"}], "level_gates": [], "map_gates": [{"dodge", "pixie-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": [{"skill", "100"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的辟邪剑法不够娴熟，难以施展", "你现在的真气不足，难以施展", "你没有准备使用辟邪剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("pixie-jian", 1) * 2", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$p" CYN "看破了$P" CYN "的身法，并没有受"
      #                          "到任何影响。\n" NOR"], "success": ["HIR "$N" HIR "身子忽进忽退，宛若鬼魅，身形诡秘异常，在$n"
      #                 HIR "身边飘忽不定。\n" NOR", "= HIR "$p" HIR "霎时只觉眼花缭乱，只能紧守门户，不"
      #                          "敢妄自出击！\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 45 + 2);", "me->start_busy(1);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(ap / 45 + 2);
      #   - me->start_busy(1);
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
      # #define GUI "「" HIR "鬼魅身法" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     string msg;
      # //      object weapon;
      #         int ap, dp;
      #         int skill;
      # 
      #         if (userp(me) && ! me->query("can_perform/pixie-jian/gui"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! me->is_fighting(target))
      #                 return notify_fail(GUI "只能对战斗中的对手使用。\n");
      # 
      #     if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         skill = me->query_skill("pixie-jian", 1);
      # 
      #         if (skill < 100)
      #                 return notify_fail("你的辟邪剑法不够娴熟，难以施展" GUI "。\n");
      # 
      #         if (me->query("neili") < 100)
      #                 return notify_fail("你现在的真气不足，难以施展" GUI "。\n");
      # 
      #         if (me->query_skill_mapped("dodge") != "pixie-jian")
      #                 return notify_fail("你没有准备使用辟邪剑法，难以施展" GUI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIR "$N" HIR "身子忽进忽退，宛若鬼魅，身形诡秘异常，在$n"
      #               HIR "身边飘忽不定。\n" NOR;
      # 
      #         ap = me->query_skill("pixie-jian", 1) * 2;
      #         dp = target->query_skill("parry");
      # 
      #     if (ap / 2 + random(ap) > dp)
      #         {
      #         msg += HIR "$p" HIR "霎时只觉眼花缭乱，只能紧守门户，不"
      #                        "敢妄自出击！\n" NOR;
      #         target->start_busy(ap / 45 + 2);
      #         me->start_busy(1);
      #     } else
      #         {
      #         msg += CYN "可是$p" CYN "看破了$P" CYN "的身法，并没有受"
      #                        "到任何影响。\n" NOR;
      #         me->start_busy(2);
      #     }
      #         me->add("neili", -50);
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end
