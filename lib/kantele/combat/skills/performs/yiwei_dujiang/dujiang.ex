defmodule Kantele.Combat.Skills.Performs.YiweiDujiang.Dujiang do
  @moduledoc """
  perform「dujiang」（source yiwei-dujiang/dujiang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "yiwei-dujiang"}], "level_gates": [{"dodge", "150"}, {"force", "150"}, {"yiwei-dujiang", "150"}], "map_gates": [{"force", "hunyuan-yiqi"}, {"force", "luohan-fumogong"}, {"force", "yijinjing"}], "prepared_gates": [], "resource_gates": [{"max_neili", "1000"}, {"neili", "250"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你已经运起「一苇渡江」了。\n", "你的一苇渡江等级不够，难以施展此项绝技！\n", "你现在没有激发少林内功为内功，难以施展", "你的身法不够使用「一苇渡江」绝技！\n", "你的内功火候不够，难以施展此项绝技！\n", "你的轻功修为不够，不会使用此项绝技！\n", "你的内力修为不够使用「一苇渡江」！\n", "你此时的内力不足！\n"], "buff_delete": ["dujiang"], "call_outs": [%{"args": "me, count", "delay": "skill / 2", "fn": "remove_effect"}], "callback_functions": [%{"body": "if ((int)me->query_temp("dujiang"))
      #           {
      #                   me->add_temp("dex", -amount);
      #                   me->delete_temp("dujiang");
      #                   tell_object(me, "你的「一苇渡江」运功完毕，将内力收回丹田。\n");", "name": "remove_effect", "params": "object me, int amount, int amount1", "return_type": "void"}], "color_codes": ["HIB", "NOR"], "combat_messages": %{"fail": [], "other": ["HIB "$N" HIB "运起少林高深内功，施展「一苇渡江」绝技,"
      #                     "身形一展，整个人顿时凌空飘起，身体变得越来越轻。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": ["dujiang"]}
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # void remove_effect(object me, int amount, int amount1);
      # 
      # inherit F_CLEAN_UP;
      # 
      # int perform(object me, object target)
      # {
      #         // object weapon;
      #         string msg;
      #         int count, skill;
      # 
      #         if ((int)me->query_temp("dujiang"))
      #                 return notify_fail("你已经运起「一苇渡江」了。\n");
      # 
      #         if ((int)me->query_skill("yiwei-dujiang", 1)< 150)
      #                 return notify_fail("你的一苇渡江等级不够，难以施展此项绝技！\n");
      # 
      #         if ((me->query_skill_mapped("force") != "hunyuan-yiqi") && (me->query_skill_mapped("force") != "yijinjing") && (me->query_skill_mapped("force") != "luohan-fumogong"))
      #                 return notify_fail("你现在没有激发少林内功为内功，难以施展"  "。\n");
      #         if ((int)me->query_dex() < 30)
      #                 return notify_fail("你的身法不够使用「一苇渡江」绝技！\n");
      # 
      #         if ((int)me->query_skill("force", 1)< 150)
      #                 return notify_fail("你的内功火候不够，难以施展此项绝技！\n");
      # 
      #         if ((int)me->query_skill("dodge", 1)< 150)
      #                 return notify_fail("你的轻功修为不够，不会使用此项绝技！\n");
      # 
      #         if ((int)me->query("max_neili") < 1000)
      #                 return notify_fail("你的内力修为不够使用「一苇渡江」！\n");
      # 
      #         if ((int)me->query("neili") < 250)
      #                 return notify_fail("你此时的内力不足！\n");
      # 
      #         msg = HIB "$N" HIB "运起少林高深内功，施展「一苇渡江」绝技,"
      #                   "身形一展，整个人顿时凌空飘起，身体变得越来越轻。\n" NOR;
      # 
      #         message_combatd(msg, me, target);
      #         skill = me->query_skill("yiwei-dujiang", 1);
      # 
      #         count = skill / 50;
      # 
      #         if (me->is_fighting())
      #                 me->start_busy(2);
      # 
      #         me->add_temp("dex", count);
      #         me->set_temp("dujiang", 1);
      #         me->start_call_out((: call_other,  __FILE__, "remove_effect", me, count :), skill / 2);
      # 
      #         me->add("neili", -200);
      #         return 1;
      # }
      # 
      # void remove_effect(object me, int amount, int amount1)
      # {
      #         if ((int)me->query_temp("dujiang"))
      #         {
      #                 me->add_temp("dex", -amount);
      #                 me->delete_temp("dujiang");
      #                 tell_object(me, "你的「一苇渡江」运功完毕，将内力收回丹田。\n");
      #         }
      # }
end
