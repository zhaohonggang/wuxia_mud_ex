defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Quan do
  @moduledoc """
  perform「九阴神拳」（source jiuyin-shengong/quan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "cuff"}, {"ap", "unarmed"}, {"dp", "dodge"}], "level_gates": [{"cuff", "220"}, {"jiuyin-shengong", "230"}], "map_gates": [], "prepared_gates": [{"cuff", "jiuyin-shengong"}, {"unarmed", "jiuyin-shengong"}], "resource_gates": [{"neili", "240"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你的九阴神功还不够娴熟，不能使用", "你的基本拳法还不够娴熟，不能使用", "你的内力不够，不能使用", "此招只能空手施展！\n", "你没有准备使用九阴神功，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("cuff")", "dp_formula": "target->query_skill("dodge") + target->query("dex") * 20 +
      #            target->query_skill("martial-cognize", 1)"}, "color_codes": ["HIC", "HIG", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "一声冷哼，握拳击出，招式雄浑，难擢其威！\n" NOR", "= HIG "只见$n" HIG "不慌不忙，轻轻一闪，躲过了$N" HIG "这一击！\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 85 + random(5),
      #                                      HIR "$n" HIR "连忙格挡，可是这一拳力道何等之重，哪里抵"
      #                                          "挡得住？只被打得吐血三尺，连退数步！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": "<", "right_side": "dp"}, "resource_adds": [{"neili", "-50"}, {"neili", "-90"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}, {"neili", "-90"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // quan 九阴神拳
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define QUAN "「" HIW "九阴神拳" NOR "」"
      # 
      # int perform(object me, object target)
      # {
      #     string msg;
      #     int ap, dp;
      #     int damage;
      # 
      #     if (!target)
      #     {
      #         me->clean_up_enemy();
      #         target = me->select_opponent();
      #     }
      # 
      #     if (!target || !me->is_fighting(target))
      #         return notify_fail(QUAN "只能对战斗中的对手使用。\n");
      # 
      #     if (me->query_skill("jiuyin-shengong", 1) < 230)
      #         return notify_fail("你的九阴神功还不够娴熟，不能使用" QUAN "！\n");
      # 
      #     if (me->query_skill("cuff", 1) < 220)
      #         return notify_fail("你的基本拳法还不够娴熟，不能使用" QUAN "！\n");
      # 
      #     if (me->query("neili") < 240)
      #         return notify_fail("你的内力不够，不能使用" QUAN "！\n");
      # 
      #     if (me->query_temp("weapon"))
      #         return notify_fail("此招只能空手施展！\n");
      # 
      #     if (me->query_skill_prepared("unarmed") != "jiuyin-shengong" && me->query_skill_prepared("cuff") != "jiuyin-shengong")
      #         return notify_fail("你没有准备使用九阴神功，无法施展" QUAN "。\n");
      # 
      #     if (!living(target))
      #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIC "$N" HIC "一声冷哼，握拳击出，招式雄浑，难擢其威！\n" NOR;
      # 
      #     ap = me->query_skill("unarmed");
      #     if (ap < me->query_skill("cuff"))
      #         ap = me->query_skill("cuff");
      #     ap += me->query_skill("martial-cognize", 1);
      #     dp = target->query_skill("dodge") + target->query("dex") * 20 +
      #          target->query_skill("martial-cognize", 1);
      # 
      #     me->start_busy(2);
      #     me->add("neili", -50);
      #     if (ap / 2 + random(ap) < dp)
      #     {
      #         msg += HIG "只见$n" HIG "不慌不忙，轻轻一闪，躲过了$N" HIG "这一击！\n" NOR;
      #     }
      #     else
      #     {
      #         me->add("neili", -90);
      #         damage = ap / 2 + random(ap / 2);
      #         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 85 + random(5),
      #                                    HIR "$n" HIR "连忙格挡，可是这一拳力道何等之重，哪里抵"
      #                                        "挡得住？只被打得吐血三尺，连退数步！\n" NOR);
      #     }
      # 
      #     message_combatd(msg, me, target);
      #     return 1;
      # }
end
