defmodule Kantele.Combat.Skills.Performs.TianchanZhang.Chan do
  @moduledoc """
  perform「毒蟾掌」（source tianchan-zhang/chan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}, {"lvl", "tianchan-zhang"}, {"poison", "poison"}], "level_gates": [{"force", "150"}], "map_gates": [{"strike", "tianchan-zhang"}], "prepared_gates": [{"strike", "tianchan-zhang"}], "resource_gates": [{"neili", "300"}], "var_gates": [{"lvl", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "tianchan_zhang", "duration_formula": "lvl / 60 + random(lvl / 30)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali"))"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须是空手才能使用", "你没有激发天蟾掌法，难以施展", "你没有准备使用天蟾掌法，难以施展", "你天蟾掌法不够纯熟，难以施展", "你的内功火候太低，，难以施展", "你的内力不够，，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + random(poison)", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIY "$p" HIY "见$P" HIY "来势汹涌，急忙纵身一跃而起，躲"
      #                          "开了这一击！\n" NOR"], "success": ["HIR "$N" HIR "一声冷笑，聚气于掌，飞身一跃而起，一招"
      #                     "携满剧毒的「毒蟾掌」对着$n" HIR "凌空拍下！\n"NOR", "= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 70,
      #                           HIR "只听$n" HIR "惨叫一声，被$N" HIR "这一掌"
      #                           "拍个正着，顿时毒气攻心，“哇”地喷出一大口鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "lvl * 3 / 2 + random(lvl) + random(poison)"}, "hit_formula": %{"left_side": "ap + random(ap)", "operator": ">", "right_side": "dp + random(dp)"}, "resource_adds": [{"neili", "-100"}, {"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-150"}], "affect_by": ["tianchan_zhang"], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define CHAN "「" HIR "毒蟾掌" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me)
      # {
      #         string msg;
      #         object /*weapon,*/ target;
      #         int /*skill,*/ ap, dp;
      #         int damage, lvl, poison;
      # 
      #         if (userp(me) && ! me->query("can_perform/tianchan-zhang/chan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(CHAN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon"))
      #                 return notify_fail("你必须是空手才能使用" CHAN "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "tianchan-zhang")
      #                 return notify_fail("你没有激发天蟾掌法，难以施展" CHAN "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "tianchan-zhang")
      #                 return notify_fail("你没有准备使用天蟾掌法，难以施展" CHAN "。\n");
      # 
      #         lvl = me->query_skill("tianchan-zhang", 1);
      #         poison = me->query_skill("poison");
      # 
      #         if (lvl < 120)
      #                 return notify_fail("你天蟾掌法不够纯熟，难以施展" CHAN "。\n");
      # 
      #         if (me->query_skill("force") < 150)
      #                 return notify_fail("你的内功火候太低，，难以施展" CHAN "。\n");
      # 
      #         if (me->query("neili") < 300)
      #                 return notify_fail("你的内力不够，，难以施展" CHAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "一声冷笑，聚气于掌，飞身一跃而起，一招"
      #                   "携满剧毒的「毒蟾掌」对着$n" HIR "凌空拍下！\n"NOR;
      # 
      #         ap = me->query_skill("strike") + random(poison);
      #         dp = target->query_skill("parry");
      # 
      #         if ( ap + random(ap) > dp + random(dp) )
      #         {
      #                 me->add("neili", -150);
      #                 damage = lvl * 3 / 2 + random(lvl) + random(poison);
      #                 target->affect_by("tianchan_zhang", ([
      #                         "level" : me->query("jiali") + random(me->query("jiali")),
      #                         "id"    : me->query("id"),
      #                         "duration" : lvl / 60 + random(lvl / 30)
      #                 ]));
      #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 70,
      #                         HIR "只听$n" HIR "惨叫一声，被$N" HIR "这一掌"
      #                         "拍个正着，顿时毒气攻心，“哇”地喷出一大口鲜血。\n" NOR);
      # 
      #                 me->start_busy(2);
      #         } else
      #         {
      #                 msg += HIY "$p" HIY "见$P" HIY "来势汹涌，急忙纵身一跃而起，躲"
      #                        "开了这一击！\n" NOR;
      #                 me->add("neili", -100);
      #                 me->start_busy(3);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
