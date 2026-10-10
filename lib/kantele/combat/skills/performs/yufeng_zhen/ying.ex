defmodule Kantele.Combat.Skills.Performs.YufengZhen.Ying do
  @moduledoc """
  perform「无影针」（source yufeng-zhen/ying.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"my_exp", "throwing"}, {"ob_exp", "dodge"}, {"skill", "yufeng-zhen"}], "level_gates": [{"force", "100"}, {"yufeng-zhen", "100"}], "map_gates": [{"throwing", "yufeng-zhen"}], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你现在手中并没有拿着针，怎么施展", "你手中没有针，无法施展", "你的玉蜂针手法不够娴熟，不会使用", "你的内功火候不够，无法施展", "你没有激发玉蜂针，不能使用", "你内力不够，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "amount_calls": [{"query_amount", ""}], "amount_gates": ["1"], "color_codes": ["HIG", "HIR", "HIY", "NOR"], "combat_d_ahinfo": %{"clear": true, "query": true}, "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "身不慌，足不移，手掌只是轻轻一抖，只见"
      #                "一点寒光闪过，闪电般的射向$n" HIY "！\n" NOR", "COMBAT_D->query_ahinfo()))
      #                           msg += pmsg", "= "( $n" + eff_status_msg(p) + " )\n"", "= HIG "可是$p" HIG "从容不迫，轻巧的闪过了$P" HIG "发出的" +
      #                          weapon->name() + HIG "。\n" NOR"], "success": ["= HIR "结果$p" HIR "反应不及，中了$P" + HIR "一" +
      #                          weapon->query("base_unit") + weapon->name() +
      #                          HIR "！\n" NOR"]}, "hit_ob_calls": [{"me", "target", "me->query("jiali") + 100"}], "receive_damage_calls": [%{"formula": "skill + random(skill / 3)", "kind": "wound", "part": "qi", "source": "me"}], "reset_action": true, "resource_adds": [{"neili", "-80"}], "resource_queries": ["max_qi", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "throwing"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define YING "「" HIY "无影针" NOR "」"
      # 
      # #include "/kungfu/skill/eff_msg.h";
      # 
      # int perform(object me, object target)
      # {
      #         int skill;
      #         // int i, n;
      #         int my_exp, ob_exp, p;
      #         string pmsg;
      #         string msg;
      #         object weapon;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! me->query("can_perform/yufeng-zhen/ying"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(YING "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("handing")) ||
      #             (string)weapon->query("skill_type") != "throwing")
      #                 return notify_fail("你现在手中并没有拿着针，怎么施展" YING "？\n");
      # 
      #         if (weapon->query_amount() < 1)
      #                 return notify_fail("你手中没有针，无法施展" YING "。\n");
      # 
      #         if ((skill = me->query_skill("yufeng-zhen", 1)) < 100)
      #                 return notify_fail("你的玉蜂针手法不够娴熟，不会使用" YING "。\n");
      # 
      #         if (me->query_skill("force") < 100)
      #                 return notify_fail("你的内功火候不够，无法施展" YING "。\n");
      # 
      #         if (me->query_skill_mapped("throwing") != "yufeng-zhen")
      #                 return notify_fail("你没有激发玉蜂针，不能使用" YING "。\n");
      # 
      #         if ((int)me->query("neili") < 100)
      #                 return notify_fail("你内力不够，无法施展" YING "\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         me->add("neili", -80);
      #         weapon->add_amount(-1);
      # 
      #         msg= HIY "$N" HIY "身不慌，足不移，手掌只是轻轻一抖，只见"
      #              "一点寒光闪过，闪电般的射向$n" HIY "！\n" NOR;
      # 
      #         me->start_busy(2 + random(2));
      # 
      #         my_exp = me->query_skill("throwing");
      #         ob_exp = target->query_skill("dodge");
      #         if (my_exp / 2 + random(my_exp) > ob_exp)
      #         {
      #                 msg += HIR "结果$p" HIR "反应不及，中了$P" + HIR "一" +
      #                        weapon->query("base_unit") + weapon->name() +
      #                        HIR "！\n" NOR;
      #                 target->receive_wound("qi", skill + random(skill / 3), me);
      # 
      #                 COMBAT_D->clear_ahinfo();
      #                 weapon->hit_ob(me, target, me->query("jiali") + 100);
      # 
      #                 p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
      # 
      #                 if (stringp(pmsg = COMBAT_D->query_ahinfo()))
      #                         msg += pmsg;
      # 
      #                 msg += "( $n" + eff_status_msg(p) + " )\n";
      # 
      #                 message_combatd(msg, me, target);
      #         } else
      #         {
      #                 msg += HIG "可是$p" HIG "从容不迫，轻巧的闪过了$P" HIG "发出的" +
      #                        weapon->name() + HIG "。\n" NOR;
      #                 message_combatd(msg, me, target);
      #         }
      # 
      #         me->reset_action();
      #         return 1;
      # }
end
