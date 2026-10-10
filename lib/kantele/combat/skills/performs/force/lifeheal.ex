defmodule Kantele.Combat.Skills.Performs.Force.Lifeheal do
  @moduledoc """
  exert「lifeheal」（source force/lifeheal.c，由 translate_perform.py 骨架生成，inherit ?）

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
      #   %{"assign_refs": [], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "300"}, {"neili", "150"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你要用真气为谁疗伤？\n", "战斗中无法运功疗伤！\n", "你不能给", "你必须激发一种内功才能替人疗伤。\n", "你的", "你的内力修为不够。\n", "你现在的真气不够。\n"], "color_codes": ["HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-150"}, {"qi", "10 + (int)me->query_skill("force") / 3"}], "resource_queries": ["max_neili", "max_qi", "neili", "qi"], "resource_sets": [{"qi", "(int)target->query("eff_qi")"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": [], "remote_damage": false, "set_flags": [], "temp_set": []}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // lifeheal.c
      # 
      # #include <ansi.h>
      # 
      # int exert(object me, object target)
      # {
      #         string force;
      # 
      #         if (! target || target == me)
      #                 return notify_fail("你要用真气为谁疗伤？\n");
      # 
      #         if (me->is_fighting() || target->is_fighting())
      #                 return notify_fail("战斗中无法运功疗伤！\n");
      # 
      #         if (target->query("not_living"))
      #                 return notify_fail("你不能给" + target->name() + "疗伤。\n");
      # 
      #         force = me->query_skill_mapped("force");
      #         if (! force)
      #                 return notify_fail("你必须激发一种内功才能替人疗伤。\n");
      # 
      #         if ((int)me->query_skill(force,1) < 50)
      #                 return notify_fail("你的" + to_chinese(force) + "等级不够。\n");
      # 
      #         if ((int)me->query("max_neili") < 300)
      #                 return notify_fail("你的内力修为不够。\n");
      # 
      #         if ((int)me->query("neili") < 150)
      #                 return notify_fail("你现在的真气不够。\n");
      # 
      #         if ((int)target->query("eff_qi") >= (int)target->query("max_qi"))
      #                 return notify_fail( target->name() +
      #                         "现在没有受伤，不需要你运功治疗！\n");
      # 
      #         if ((int)target->query("eff_qi") < (int)target->query("max_qi") / 5)
      #                 return notify_fail( target->name() +
      #                         "已经受伤过重，经受不起你的真气震荡！\n");
      # 
      #         message_vision(
      #                 HIY "$N坐了下来运起" + to_chinese(force) +
      #                 "，将手掌贴在$n背心，缓缓地将真气输入$n体内....\n"
      #                 HIW "过了不久，$N额头上冒出豆大的汗珠，$n吐出一"
      #                 "口瘀血，脸色看起来红润多了。\n" NOR,
      #                 me, target );
      # 
      #         target->receive_curing("qi", 10 + (int)me->query_skill("force") / 2);
      #         target->add("qi", 10 + (int)me->query_skill("force") / 3);
      #         if ((int)target->query("qi") > (int)target->query("eff_qi"))
      #                 target->set("qi", (int)target->query("eff_qi"));
      # 
      #         me->add("neili", -150);
      #         return 1;
      # }
end
