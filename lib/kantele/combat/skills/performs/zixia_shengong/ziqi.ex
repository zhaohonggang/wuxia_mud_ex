defmodule Kantele.Combat.Skills.Performs.ZixiaShengong.Ziqi do
  @moduledoc """
  exert「ziqi」（source zixia-shengong/ziqi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "zixia-shengong"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "150"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你的内力还不够！\n", "你的紫霞神功的修为不够，不能使用紫气东来! \n", "你没有剑.怎么用紫气东来呀? \n"], "buff_delete": ["ziqi"], "call_outs": [%{"args": "me, skill / 10", "delay": "skill", "fn": "remove_effect"}], "callback_functions": [%{"body": "if (me->query_temp("ziqi"))
      #           {
      #                   me->add_temp("apply/damage", -amount);
      #                   me->add_temp("apply/sword", -amount);
      #                   me->delete_temp("ziqi");
      #               ", "name": "remove_effect", "params": "object me, int amount", "return_type": "void"}], "color_codes": ["HIG", "HIR", "MAG", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-200"}], "resource_queries": ["max_qi", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": ["damage", "sword"], "busy_lines": ["if( me->is_fighting() ) me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": ["ziqi"]}
      #   - if( me->is_fighting() ) me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // from NT MudLIB
      # // ziqi.c 紫气东来
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # void remove_effect(object me, int amount);
      # 
      # int exert(object me, object target)
      # {
      # //      string msg;
      # //      mapping buff,data;
      #         int /*d_count,count,*/ qi, maxqi, skill;
      #         object weapon = me->query_temp("weapon");
      #         skill = me->query_skill("zixia-shengong", 1);
      # 
      #         if((int)me->query_temp("ziqi"))
      #                 return notify_fail(HIG"你已经在运起紫气东来了。\n");
      # 
      #         if((int)me->query("neili") < 200 )
      #                 return notify_fail("你的内力还不够！\n");
      # 
      #         if(skill < 150)
      #                 return notify_fail("你的紫霞神功的修为不够，不能使用紫气东来! \n");
      # 
      #         // 必须有兵器。加兵器威力
      #         if ( ! weapon || weapon->query("skill_type") != "sword" )
      #                 return notify_fail("你没有剑.怎么用紫气东来呀? \n");
      # 
      #         qi = me->query("qi");
      #         maxqi = me->query("max_qi");
      # 
      #         message_combatd(MAG "$N" MAG "猛吸一口气，脸上紫气大盛！手中的兵器隐隐透出一层紫光。。。\n" NOR, me);
      # 
      #         if( qi > (maxqi * 0.4) )
      #         {
      #                 me->add_temp("apply/damage", skill / 10);
      #                 me->add_temp("apply/sword", skill / 10);
      #                 me->set_temp("ziqi", 1);
      #                 me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 10 :), skill);
      #                 me->add("neili", -200);
      #         }
      #         else
      #         {
      #                 message_combatd(HIR "$N" HIR "拼尽毕生功力想提起紫气东来，但自己受伤太重，没能成功!\n" NOR, me);
      #         }
      # 
      #         if( me->is_fighting() ) me->start_busy(3);
      #         return 1;
      # }
      # 
      # void remove_effect(object me, int amount)
      # {
      #         if (me->query_temp("ziqi"))
      #         {
      #                 me->add_temp("apply/damage", -amount);
      #                 me->add_temp("apply/sword", -amount);
      #                 me->delete_temp("ziqi");
      #                 tell_object(me, "你的紫气东来运行完毕，紫气渐渐隐去。\n");
      #         }
      # }
end
