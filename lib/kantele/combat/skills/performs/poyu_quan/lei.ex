defmodule Kantele.Combat.Skills.Performs.PoyuQuan.Lei do
  @moduledoc """
  perform「雷动九天」（source poyu-quan/lei.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "cuff"}, {"skill", "poyu-quan"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": [{"skill", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你已经在运功中了。\n", "你现在的真气不够。\n", "你的劈石破玉拳修为不够，无法施展"], "buff_delete": ["lei"], "call_outs": [%{"args": "me, count", "delay": "skill / 3", "fn": "remove_effect"}], "callback_functions": [%{"body": "if ((int)me->query_temp("lei"))
      #       {
      #           me->add_temp("str", -amount);
      #           me->add_temp("dex", -amount);
      #           me->delete_temp("lei");
      #           tell_object(me, CYN "你的雷动九天运行完毕，将内力收回丹田。\n" NO", "name": "remove_effect", "params": "object me, int amount", "return_type": "void"}], "color_codes": ["CYN", "HIM", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-400"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": ["lei"]}
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // leidong 雷动九天
      # // by winder 98.12
      # // modify by rcwiz 2003
      # 
      # #include <ansi.h>
      # 
      # inherit F_CLEAN_UP;
      # 
      # #define LEI "「" HIM "雷动九天" NOR "」"
      # 
      # void remove_effect(object me, int amount);
      # 
      # int perform(object me)
      # {
      #     int skill, count/*, count1*/;
      # 
      # 
      #         if (userp(me) && ! me->query("can_perform/poyu-quan/lei"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if ((int)me->query_temp("lei"))
      #         return notify_fail("你已经在运功中了。\n");
      # 
      #     if ((int)me->query("neili") < 500)
      #         return notify_fail("你现在的真气不够。\n");
      # 
      #     //skill = me->query_skill("cuff");
      #     skill = (int)me->query_skill("poyu-quan",1);
      # 
      #     if (skill < 120)
      #         return notify_fail("你的劈石破玉拳修为不够，无法施展" LEI "\n");
      # 
      #     me->add("neili", -400);
      #     message_combatd(HIM "$N" HIM "深深吸了一口气，脸上顿时"
      #                         "紫气大盛，出手越来越重！\n" NOR, me);
      # 
      #     //count = skill / 10;
      #     count = skill / 6;
      # 
      #         if (me->is_fighting())
      #                 me->start_busy(2);
      # 
      #     me->add_temp("str", count);
      #     me->add_temp("dex", count);
      #     me->set_temp("lei", 1);
      #     me->start_call_out((: call_other,  __FILE__, "remove_effect", me, count :), skill / 3);
      # 
      #     return 1;
      # }
      # 
      # void remove_effect(object me, int amount)
      # {
      #     if ((int)me->query_temp("lei"))
      #     {
      #         me->add_temp("str", -amount);
      #         me->add_temp("dex", -amount);
      #         me->delete_temp("lei");
      #         tell_object(me, CYN "你的雷动九天运行完毕，将内力收回丹田。\n" NOR);
      #     }
      # }
end
