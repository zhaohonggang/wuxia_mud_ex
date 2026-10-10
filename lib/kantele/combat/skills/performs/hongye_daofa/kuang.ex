defmodule Kantele.Combat.Skills.Performs.HongyeDaofa.Kuang do
  @moduledoc """
  perform「狂风落叶」（source hongye-daofa/kuang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"extra", "hongye-daofa"}], "level_gates": [{"hongye-daofa", "150"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "800"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你只能对战斗中的对手使用", "你目前功力还使不出", "你使用的武器不对。\n", "你的内力不够。\n"], "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N淡然一笑，本就快捷绝伦的刀法骤然变得更加凌厉！\n"  
      #                 HIC "就在这一瞬之间，$N已快速劈出六刀！刀夹杂着风，风里含着刀影！\n"  
      #                 HIC "$n只觉得心跳都停止了！" NOR"], "success": []}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      #           
      # #include <ansi.h>  
      # #include <combat.h>  
      #   
      # #define KUANG "「" HIR "狂风落叶" NOR "」"   
      #   
      # inherit F_SSERVER;  
      #   
      # int perform(object me, object target)  
      # {  
      #         int extra;  
      #         object weapon;  
      #         string msg;  
      #   
      #         extra=me->query_skill("hongye-daofa",1);  
      #    
      #   
      #         if( !target ) target = offensive_target(me);  
      #   
      #         if( !target||!target->is_character()||!me->is_fighting(target) )  
      #                 return notify_fail("你只能对战斗中的对手使用" KUANG "。\n");  
      #           
      #         if( (int)me->query_skill("hongye-daofa",1) < 150)  
      #                 return notify_fail("你目前功力还使不出" KUANG "。\n");  
      #   
      #         if (!objectp(weapon = me->query_temp("weapon"))  
      #                 || (string)weapon->query("skill_type") != "blade")  
      #                         return notify_fail("你使用的武器不对。\n");  
      #           
      #         if( (int)me->query("neili") < 800 )  
      #                         return notify_fail("你的内力不够。\n");  
      #           
      #         me->add("neili", -300);  
      #         msg = HIC "$N淡然一笑，本就快捷绝伦的刀法骤然变得更加凌厉！\n"  
      #               HIC "就在这一瞬之间，$N已快速劈出六刀！刀夹杂着风，风里含着刀影！\n"  
      #               HIC "$n只觉得心跳都停止了！" NOR;  
      #   
      #         message_vision(msg, me, target);                  
      #                   
      #         message_combatd(HIY  "$N从左面劈出两刀！\n" NOR, me, target);   
      #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"), TYPE_REGULAR, msg);  
      #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"), TYPE_REGULAR, msg);  
      #   
      #         message_combatd(HIY  "$N紧跟$n从右面劈出两刀！\n" NOR, me, target);   
      #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"), TYPE_REGULAR, msg);  
      #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"), TYPE_REGULAR, msg);  
      #   
      #         message_combatd(HIY  "$N竟然又从上面劈出两刀！\n" NOR, me, target);  
      #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"), TYPE_REGULAR, msg);  
      #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"), TYPE_REGULAR, msg);  
      #   
      #         me->start_busy(2 + random(2));  
      #         return 1;  
      # }  
end
