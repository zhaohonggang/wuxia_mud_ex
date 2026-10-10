defmodule Kantele.Combat.Skills.Performs.LeimingBian.Cibei do
  @moduledoc """
  perform「cibei」（source leiming-bian/cibei.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"at", "leiming-bian"}, {"df", "dodge"}, {"extra", "leiming-bian"}, {"lmt", "leiming-bian"}, {"skill", "buddhism"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "1500"}, {"shen", "200000"}], "var_gates": [{"extra", "160"}, {"lmt", "3"}, {"skill", "150"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你使用的外功中没有这个功能。\n", "［慈悲字诀］只能对战斗中的对手使用。\n", "你的雷鸣鞭法修为太差,还不能使用慈悲字诀！\n", "你的禅宗心法等级不够，怎能支持慈悲字诀？ \n", "慈悲字诀需以无边正气为辅,大师还是多行善事吧! \n", "你的内力修为不够辅助慈悲字诀。\n", "你手中没有兵器如何使用慈悲字诀。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "NOR", "RED"], "combat_messages": %{"fail": [], "other": ["RED "只见$N喃喃自语道：慈悲为怀，手中的" + weapon->name() + RED "仿佛如来出世般倒卷向$n。\n" NOR", "= CYN "$n不禁被$N的无边佛法打动，猛的后退，脸上没有一丝血色...\n" NOR", "= "( $n" + eff_status_msg(p) + " )\n"", "HIG "\n紧接着$N手中的" + weapon->name() + HIG "连续晃动，竟然不知道有多少击。\n" NOR", "HIG "\n$n左躲右闪，强$N的攻击完全化于无形！\n" NOR"], "success": []}, "damage_formula": %{"formula": "me->query("shen", 1) / 2000"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage / 3", "kind": "wound", "part": "qi", "source": "me"}], "resource_adds": [{"neili", "-200"}, {"neili", "-300"}], "resource_queries": ["max_qi", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "affect_by": [], "apply_adds": ["attack", "damage"], "busy_lines": ["target->start_busy(3);", "me->start_busy(random(2) + 2);", "me->start_busy(random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - target->start_busy(3);
      #   - me->start_busy(random(2) + 2);
      #   - me->start_busy(random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # #include "/kungfu/skill/eff_msg.h";
      # 
      # int perform(object me, object target)
      # {
      #         string msg; 
      #         int extra, skill, at, df, i, lmt, damage, p;
      #         object weapon;
      #         extra = me->query_skill("leiming-bian",1);
      # 
      #         //if (userp(me) && !me->query("can_perform/leiming-bian/cibei"))
      #        //       return notify_fail("你使用的外功中没有这个功能。\n");
      #         if( !target ) target = offensive_target(me);
      # 
      #         if( !target
      #                  || !target->is_character()
      #                  || !me->is_fighting(target) )
      #               return notify_fail("［慈悲字诀］只能对战斗中的对手使用。\n");
      # 
      #         if( extra < 160)
      #               return notify_fail("你的雷鸣鞭法修为太差,还不能使用慈悲字诀！\n");
      # 
      #         skill = me->query_skill("buddhism", 1);
      # 
      #         if( skill < 150)
      #               return notify_fail("你的禅宗心法等级不够，怎能支持慈悲字诀？ \n");
      # 
      #         if( me->query("shen") < 200000)
      #               return notify_fail("慈悲字诀需以无边正气为辅,大师还是多行善事吧! \n");
      # 
      #         if( me->query("neili") < 1500 )
      #               return notify_fail("你的内力修为不够辅助慈悲字诀。\n");
      # 
      #         weapon = me->query_temp("weapon");
      # 
      #         if( !weapon
      #          || weapon->query("skill_type") != "whip")
      #               return notify_fail("你手中没有兵器如何使用慈悲字诀。\n");
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = RED "只见$N喃喃自语道：慈悲为怀，手中的" + weapon->name() + RED "仿佛如来出世般倒卷向$n。\n" NOR;
      # 
      #         at = me->query("combat_exp") * me->query_skill("leiming-bian", 1) / 1000;
      #         df = target->query("combat_exp") * target->query_skill("dodge", 1) / 1000;
      # 
      #         if( (random(at) + at / 2)  > df )
      #         {
      #             damage = me->query("shen", 1) / 2000;
      # 
      #             //if(damage > 1500) damage = 1500 + (damage-1500)/100;
      #             if(damage > 1500) damage = 1500; //设定上限 2017-02-03
      # 
      #             msg += CYN "$n不禁被$N的无边佛法打动，猛的后退，脸上没有一丝血色...\n" NOR;
      #             target->receive_damage("qi", damage, me);
      #             target->receive_wound("qi", damage / 3, me);
      # 
      #             p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
      #             msg += "( $n" + eff_status_msg(p) + " )\n";
      #             message_vision(msg, me, target);
      #             target->start_busy(3);
      # 
      #             weapon = me->query_temp("weapon");
      #             msg = HIG "\n紧接着$N手中的" + weapon->name() + HIG "连续晃动，竟然不知道有多少击。\n" NOR;
      #             message_vision(msg,me,target);
      # 
      #             lmt = random(me->query_skill("leiming-bian", 1) / 50) + 1;
      #             if ( lmt < 3 ) lmt = 3;
      #             if ( lmt > 6 ) lmt = 6;
      # 
      #             for(i=1;i <= lmt;i++)
      #             {
      #                  extra = me->query_skill("leiming-bian", 1);
      #                  me->add_temp("apply/attack", extra / 5);
      #                  me->add_temp("apply/damage", extra / 5);
      #                  COMBAT_D->do_attack(me,target, me->query_temp("weapon"), 1);
      #                  me->add_temp("apply/attack",-extra / 5);
      #                  me->add_temp("apply/damage",-extra / 5);
      #             }
      #             me->add("neili",-300);
      #             me->start_busy(random(2) + 2);
      #         } else
      #        {
      #               msg = HIG "\n$n左躲右闪，强$N的攻击完全化于无形！\n" NOR;
      #               message_vision(msg,me,target);
      #               me->add("neili",-200);
      #               me->start_busy(random(2));
      #        }
      #         return 1;
      # }
end
