defmodule Kantele.Combat.Skills.Performs.LuohanJian.Wuxing do
  @moduledoc """
  perform「wuxing」（source luohan-jian/wuxing.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"extra", "luohan-jian"}, {"skill", "luohan-jian"}], "level_gates": [{"luohan-jian", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「来去若无形」只能在战斗中使用。\n", "「来去若无形」必须用剑才能施展。\n", "你的「罗汉剑法」不够娴熟，不会使用「来去若无形」。\n", "你的内力不够。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIB", "HIC", "HIG", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "$N身行突变，瞬间犹如分出无数身影闪电般的向$n攻去！\n" NOR", "COMBAT_D->do_damage(me, target, WEAPON_ATTACK, skill, 80,  
      #   
      #   
      #                       HIC "            来去若无形    幻化无真境 \n" NOR)"], "success": []}, "resource_adds": [{"neili", "-200"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": ["attack", "damage"], "busy_lines": ["me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # //来去若无形 wuxing.c 
      #          
      # #include <ansi.h> 
      # #include <skill.h> 
      # #include <weapon.h> 
      # #include <combat.h> 
      #          
      # //inherit F_CLEAN_UP; 
      #  
      # void remove_effect(object me, int a_amount, int d_amount); 
      #  
      # inherit F_SSERVER; 
      # int perform(object me, object target) 
      # { 
      #         object weapon; 
      #         int skill; 
      #         int extra; 
      #         string msg; 
      #   
      #         if ( !target ) target = offensive_target(me); 
      #          
      #         if ( !target 
      #                 ||      !target->is_character() 
      #                 ||      !me->is_fighting(target) ) 
      #                         return notify_fail("「来去若无形」只能在战斗中使用。\n"); 
      #  
      #         if (!objectp(weapon = me->query_temp("weapon")) 
      #                 || (string)weapon->query("skill_type") != "sword") 
      #                 return notify_fail("「来去若无形」必须用剑才能施展。\n"); 
      #          
      #         if( (int)me->query_skill("luohan-jian", 1) < 100 ) 
      #                 return notify_fail("你的「罗汉剑法」不够娴熟，不会使用「来去若无形」。\n"); 
      #  
      #         if( (int)me->query("neili") < 300  )  
      #                 return notify_fail("你的内力不够。\n"); 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      #  
      #         skill = me->query_skill("luohan-jian",1); 
      #          
      #         extra = me->query_skill("luohan-jian",1) / 10; 
      #         extra += me->query_skill("luohan-jian",1) / 10; 
      #         me->add_temp("apply/attack", extra);     
      #         me->add_temp("apply/damage", extra); 
      #          
      #         msg = HIG "$N身行突变，瞬间犹如分出无数身影闪电般的向$n攻去！\n" NOR; 
      #                message_vision(msg, me, target);  
      #          
      #         me->add("neili", -200); 
      #          
      #         message_combatd(HIR "  来字决！\n" NOR, me, target);  
      #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
      #                                        TYPE_REGULAR);  
      #          
      #         message_combatd(HIY "    去字决！\n" NOR, me, target);  
      #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
      #                                        TYPE_REGULAR);  
      #  
      #         message_combatd(HIG "      若字决！\n" NOR, me, target);  
      #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
      #                                        TYPE_REGULAR);  
      #          
      #         message_combatd(HIB "        无字决！\n" NOR, me, target);  
      #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
      #                                        TYPE_REGULAR);  
      #          
      #         message_combatd(HIW "          形字决！\n" NOR, me, target);  
      #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"),  
      #                                        TYPE_REGULAR);  
      # 
      #         msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, skill, 80,  
      # 
      # 
      #                     HIC "            来去若无形    幻化无真境 \n" NOR); 
      #         message_combatd(msg, me, target);  
      # 
      # 
      #         me->start_busy(3); 
      #         me->add_temp("apply/attack", -extra); 
      #         me->add_temp("apply/damage", -extra); 
      #  
      #         return 1; 
      # } 
end
