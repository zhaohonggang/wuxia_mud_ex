defmodule Kantele.Combat.Skills.Performs.HuilongZhang.Baiwei do
  @moduledoc """
  perform「baiwei」（source huilong-zhang/baiwei.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"extra", "huilong-zhang"}], "level_gates": [{"huilong-zhang", "80"}, {"shaolin-xinfa", "80"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "600"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「神龙摆尾」只能在战斗中对对手使用。\n", "使用「神龙摆尾」时双手应该持杖！\n", "你的回龙杖不够娴熟，不会使用「神龙摆尾」。\n", "你的内功等级不够，不能使用「神龙摆尾」。\n", "你现在内力太弱，不能使用「神龙摆尾」。\n"], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N长啸一声，将内力聚于手中钢杖，突然一个转身，手中钢杖点向$n！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": true}, "weapon_type": "staff"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1+random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1+random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <weapon.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg; 
      #         object weapon;
      #         int extra;
      #         int count, i;
      # 
      #         extra = me->query_skill("huilong-zhang",1) + me->query_skill("staff", 1);    
      #                   
      #         
      #         if( !target ) target = offensive_target(me);
      # 
      #         if( !target || !me->is_fighting(target) )
      #                 return notify_fail("「神龙摆尾」只能在战斗中对对手使用。\n");
      # 
      #         if( !objectp(me->query_temp("weapon") || (string)weapon->query("skill_type") != "staff"))
      #                 return notify_fail("使用「神龙摆尾」时双手应该持杖！\n");
      # 
      #         if( (int)me->query_skill("huilong-zhang", 1) < 80 )
      #                 return notify_fail("你的回龙杖不够娴熟，不会使用「神龙摆尾」。\n");
      # 
      #         if( (int)me->query_skill("shaolin-xinfa", 1) < 80 )
      #                 return notify_fail("你的内功等级不够，不能使用「神龙摆尾」。\n");
      #      
      #         if( (int)me->query("neili") < 600 )
      #                 return notify_fail("你现在内力太弱，不能使用「神龙摆尾」。\n");
      # 
      #         msg = HIY "$N长啸一声，将内力聚于手中钢杖，突然一个转身，手中钢杖点向$n！\n" NOR;
      # 
      #         message_vision(msg, me, target); 
      # 
      #         count = 4;
      #            
      #         for (i=0;i < count;i++)
      #         {
      #            COMBAT_D->do_attack(me, target, me->query_temp("weapon"), TYPE_QUICK);
      #         }
      # 
      #         me->add("neili", -100 );
      # 
      #         me->start_busy(1+random(2));
      # 
      #             return 1;
      # }
end
