defmodule Kantele.Combat.Skills.Performs.QingyunBian.Duan do
  @moduledoc """
  perform「duan」（source qingyun-bian/duan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"power", "qingyun-bian"}], "level_gates": [{"force", "100"}, {"whip", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [], "var_gates": [{"power", "150"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["[断云决]只能对战斗中的对手使用。\n", "你的基本内功火候未到，无法施展断云决！\n", "断云决需要精湛的青云鞭法方能有效施展！\n", "你的内力不够使用断云决！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIM", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "exp_compare": [{"10", "0"}, {"10", "2"}, {"10", "4"}, {"10", "6"}, {"10", "8"}], "resource_adds": [{"neili", "-power"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["armor", "attack", "damage", "dodge"], "busy_lines": ["me->start_busy( 2 + random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy( 2 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # //duan.c
      # // gladiator
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int str, power;
      #         // string weapon; 
      # 
      #         if( !target ) target = offensive_target(me);
      # 
      #         if( !target
      #                 ||      !target->is_character()
      #                 ||      !me->is_fighting(target) )
      #                 return notify_fail("[断云决]只能对战斗中的对手使用。\n");
      # 
      #         if( me->query_skill("force",1) < 100 )
      #                 return notify_fail("你的基本内功火候未到，无法施展断云决！\n");
      # 
      #         if( me->query_skill("whip",1) < 100 )
      #                 return notify_fail("断云决需要精湛的青云鞭法方能有效施展！\n");
      # 
      #                 // for a 800K player, frce/2 = 150, shen/3K = 300, power = 300
      #                 // for players > 1.2M, power will hit max
      # 
      #         str = me->query_str();
      # 
      #         power = random( me->query_skill("qingyun-bian",1) / 3) + me->query_skill("force",1) / 2;
      # 
      #         if(power<150)power=150;
      #         if(power>480)power=480;
      # 
      #         if( me->query("neili") <= 200 )
      #                 return notify_fail("你的内力不够使用断云决！\n");
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         message_vision(HIW "$N运足内力，猛地一扬"NOR + "$n" +
      #                        HIW "卷起无边风云遮月掩日，一股"NOR +
      #                        HIM "罡风" NOR + HIW "随著漫天鞭影扑天盖地的向敌人袭来。\n"
      #                          NOR, me, me->query_temp("weapon"));
      # 
      #         me->add_temp("apply/attack", power / 5);
      #         me->add_temp("apply/damage", power / 5);
      #         target->add_temp("apply/armor",-power / 5);
      #         target->add_temp("apply/dodge",-power / 5);
      # 
      #         COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
      #         COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
      # 
      #         if (random(10)>0) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
      #         if (random(10)>2) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
      #         if (random(10)>4) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
      #         if (random(10)>6) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
      #         if (random(10)>8) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
      # 
      # 
      #         me->start_perform(1 + random(2),"[断云决]");
      # 
      #         me->add_temp("apply/attack", -power / 5);
      #         me->add_temp("apply/damage",-power / 5);
      #         target->add_temp("apply/armor",power / 5);
      #         target->add_temp("apply/dodge",power / 5);
      # 
      #         me->add("neili", -power);
      #         me->start_busy( 2 + random(2));
      # 
      #         return 1;
      # }
end
