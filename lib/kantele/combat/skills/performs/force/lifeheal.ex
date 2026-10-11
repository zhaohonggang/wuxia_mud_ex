defmodule Kantele.Combat.Skills.Performs.Force.Lifeheal do
  @moduledoc """
  exert「lifeheal」（source force/lifeheal.c，由 translate_perform.py 生成，inherit ?）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

  @impl true
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character), do: check_resources(character)

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 150 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}], "remote_damage": false, "resource_gates": [{"max_neili", "300"}, {"neili", "150"}]}

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
