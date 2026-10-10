defmodule Kantele.Combat.Skills.Performs.PokongQuan.Kong do
  @moduledoc """
  perform「破碎虚空」（source pokong-quan/kong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "cuff"}, {"damage", "henshan-quan"}, {"dp", "parry"}], "level_gates": [{"force", "80"}, {"pokong-quan", "60"}], "map_gates": [{"cuff", "pokong-quan"}], "prepared_gates": [{"cuff", "pokong-quan"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你破空拳法不够娴熟，难以施展", "你没有激发破空拳法，难以施展", "你没有准备破空拳法，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("cuff")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIC", "HIG", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "\n$N" HIC "仰天长啸，双拳挥出，施一招「" HIW "破碎虚空"
      #                 HIC "」，拳速极快，破空长响，分袭$n" HIC "面门和胸口。" NOR", "CYN "$n" CYN "不慌不忙，以快打快，将$N"
      #                         CYN "这招化去。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
      #                                             HIR "$N" HIR "出手既快，方位又奇，$n"
      #                                             HIR "闪避不及，闷哼一声，已然中拳。\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("henshan-quan", 1)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-30"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(2));", "me->start_busy(2 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(2));
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
      # #define KONG "「" HIG "破碎虚空" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/pokong-quan/kong"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(KONG "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(KONG "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("pokong-quan", 1) < 60)
      #                 return notify_fail("你破空拳法不够娴熟，难以施展" KONG "。\n");
      # 
      #         if (me->query_skill_mapped("cuff") != "pokong-quan")
      #                 return notify_fail("你没有激发破空拳法，难以施展" KONG "。\n");
      # 
      #         if (me->query_skill_prepared("cuff") != "pokong-quan")
      #                 return notify_fail("你没有准备破空拳法，难以施展" KONG "。\n");
      # 
      #         if (me->query_skill("force") < 80)
      #                 return notify_fail("你的内功修为不够，难以施展" KONG "。\n");
      # 
      #         if ((int)me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不够，难以施展" KONG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         ap = me->query_skill("cuff");
      #         dp = target->query_skill("parry");
      # 
      #         msg = HIC "\n$N" HIC "仰天长啸，双拳挥出，施一招「" HIW "破碎虚空"
      #               HIC "」，拳速极快，破空长响，分袭$n" HIC "面门和胸口。" NOR;
      # 
      #         message_sort(msg, me, target);
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = (int)me->query_skill("henshan-quan", 1);
      #                 damage += random(damage / 2);
      # 
      #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
      #                                           HIR "$N" HIR "出手既快，方位又奇，$n"
      #                                           HIR "闪避不及，闷哼一声，已然中拳。\n" NOR);
      # 
      #                 me->add("neili", -100);
      #             me->start_busy(2 + random(2));
      #         } else
      #         {
      #                 msg = CYN "$n" CYN "不慌不忙，以快打快，将$N"
      #                       CYN "这招化去。\n" NOR;
      # 
      #                 me->add("neili", -30);
      #             me->start_busy(2 + random(3));
      #         }
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end
