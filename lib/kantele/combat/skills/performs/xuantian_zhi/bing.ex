defmodule Kantele.Combat.Skills.Performs.XuantianZhi.Bing do
  @moduledoc """
  perform「冰坚地狱」（source xuantian-zhi/bing.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"dp", "force"}, {"lvl", "xuantian-zhi"}], "level_gates": [{"xuantian-wujigong", "180"}, {"xuantian-zhi", "180"}], "map_gates": [{"finger", "xuantian-zhi"}], "prepared_gates": [{"finger", "xuantian-zhi"}], "resource_gates": [{"max_neili", "2000"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "xuantian_zhi", "duration_formula": "lvl / 50 + random(lvl / 20)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali"))"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能使用", "你没有激发玄天指，不能使用", "你现在没有准备使用玄天指，无法使用", "你的玄天无极功火候不够，使不出", "你的玄天指不够熟练，不会使用", "你的内力修为不足，无法使用", "你的真气不够，无法使用", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger") + me->query("con") * 5", "dp_formula": "target->query_skill("force") + target->query("con") * 5"}, "color_codes": ["CYN", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "默运玄天无极功，顿时一层寒霜笼罩全身，一声冷"
      #                 "笑，聚力于指，直戳$n" HIW "要穴！\n"NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK,
      #                                            damage, 70, HIW "$n" HIW "稍不留神，已被$P" HIW
      #                                            "一指点中，阴寒之劲顿时侵入三焦六脉。\n" NOR)", "= CYN "$n" CYN "见$N" CYN "来势汹涌，急忙提气跃开。\n" NOR"], "success": []}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}], "affect_by": ["xuantian_zhi"], "apply_adds": [], "busy_lines": ["me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define BING "「" HIW "冰坚地狱" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      #         int lvl;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/xuantian-zhi/bing"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(BING "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(me->query_temp("weapon")))
      #                 return notify_fail("你必须空手才能使用" BING "。\n");         
      # 
      #         if (me->query_skill_mapped("finger") != "xuantian-zhi")
      #                 return notify_fail("你没有激发玄天指，不能使用" BING "。\n");
      # 
      #         if (me->query_skill_prepared("finger") != "xuantian-zhi")
      #                 return notify_fail("你现在没有准备使用玄天指，无法使用" BING "。\n");
      # 
      #         if ((int)me->query_skill("xuantian-wujigong", 1) < 180)
      #                 return notify_fail("你的玄天无极功火候不够，使不出" BING "。\n");
      # 
      #         if ((int)me->query_skill("xuantian-zhi", 1) < 180)
      #                 return notify_fail("你的玄天指不够熟练，不会使用" BING "。\n");
      # 
      #         if ((int)me->query("max_neili") < 2000)
      #                 return notify_fail("你的内力修为不足，无法使用" BING "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你的真气不够，无法使用" BING "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "默运玄天无极功，顿时一层寒霜笼罩全身，一声冷"
      #               "笑，聚力于指，直戳$n" HIW "要穴！\n"NOR;  
      # 
      #         lvl = me->query_skill("xuantian-zhi", 1);
      # 
      #         ap = me->query_skill("finger") + me->query("con") * 5;
      #         dp = target->query_skill("force") + target->query("con") * 5;
      # 
      #         me->start_busy(4);
      #         if (ap / 2 + random(ap) > dp)
      #         { 
      #                 damage = ap + random(ap / 2);
      #                 me->add("neili", -400);
      #                 target->affect_by("xuantian_zhi",
      #                                ([ "level" : me->query("jiali") + random(me->query("jiali")),
      #                                   "id"    : me->query("id"),
      #                                   "duration" : lvl / 50 + random(lvl / 20) ]));
      #                                   msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK,
      #                                          damage, 70, HIW "$n" HIW "稍不留神，已被$P" HIW
      #                                          "一指点中，阴寒之劲顿时侵入三焦六脉。\n" NOR);
      #         } else
      #         {
      #                 msg += CYN "$n" CYN "见$N" CYN "来势汹涌，急忙提气跃开。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
