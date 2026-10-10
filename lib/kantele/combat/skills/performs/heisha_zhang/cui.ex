defmodule Kantele.Combat.Skills.Performs.HeishaZhang.Cui do
  @moduledoc """
  perform「催魂掌」（source heisha-zhang/cui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "force"}, {"lvl", "heisha-zhang"}], "level_gates": [{"force", "150"}, {"heisha-zhang", "100"}], "map_gates": [{"strike", "heisha-zhang"}], "prepared_gates": [{"strike", "heisha-zhang"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "sha_poison", "duration_formula": "lvl / 50 + random(lvl / 20)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali"))"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能使用", "你没有激发黑砂掌，难以施展", "你现在没有准备使用黑砂掌，难以施展", "你的黑砂掌不够熟练，难以施展", "你的内力修为不足，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIB", "HIR", "NOR"], "combat_messages": %{"fail": ["= CYN "$n" CYN "见$N"
      #                          CYN "来势汹涌，奋力格挡，终于化解开来。\n" NOR"], "other": ["HIB "$N" HIB "冷笑数声，单掌陡然一振，催魂般悄然拍至$n"
      #                 HIB "前胸，不着半点力道。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK,
      #                                            damage, 20, HIR "$n" HIR "只觉$N" HIR "掌劲穿"
      #                                            "胸而过，一时说不出的难受，呕出一大口黑血。\n"
      #                                            NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": ["sha_poison"], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define CUI "「" HIB "催魂掌" NOR "」"
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
      #         if (userp(me) && ! me->query("can_perform/heisha-zhang/cui"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(CUI "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(me->query_temp("weapon")))
      #                 return notify_fail("你必须空手才能使用" CUI "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "heisha-zhang")
      #                 return notify_fail("你没有激发黑砂掌，难以施展" CUI "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "heisha-zhang")
      #                 return notify_fail("你现在没有准备使用黑砂掌，难以施展" CUI "。\n");
      # 
      #         if ((int)me->query_skill("heisha-zhang", 1) < 100)
      #                 return notify_fail("你的黑砂掌不够熟练，难以施展" CUI "。\n");
      # 
      #         if ((int)me->query_skill("force") < 150)
      #                 return notify_fail("你的内力修为不足，难以施展" CUI "。\n");
      # 
      #         if ((int)me->query("neili") < 200)
      #                 return notify_fail("你的真气不够，难以施展" CUI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIB "$N" HIB "冷笑数声，单掌陡然一振，催魂般悄然拍至$n"
      #               HIB "前胸，不着半点力道。\n" NOR;  
      # 
      #         lvl = me->query_skill("heisha-zhang", 1);
      # 
      #         ap = me->query_skill("strike");
      #         dp = target->query_skill("force");
      # 
      #         me->start_busy(3);
      #         if (ap / 2 + random(ap) > dp)
      #         { 
      #                 damage = ap / 2 + random(ap / 3);
      #                 me->add("neili", -100);
      #                 target->affect_by("sha_poison",
      #                                ([ "level" : me->query("jiali") + random(me->query("jiali")),
      #                                   "id"    : me->query("id"),
      #                                   "duration" : lvl / 50 + random(lvl / 20) ]));
      #                                   msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK,
      #                                          damage, 20, HIR "$n" HIR "只觉$N" HIR "掌劲穿"
      #                                          "胸而过，一时说不出的难受，呕出一大口黑血。\n"
      #                                          NOR);
      #         } else
      #         {
      #                 msg += CYN "$n" CYN "见$N"
      #                        CYN "来势汹涌，奋力格挡，终于化解开来。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end
