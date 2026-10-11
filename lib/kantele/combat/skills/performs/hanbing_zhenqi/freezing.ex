defmodule Kantele.Combat.Skills.Performs.HanbingZhenqi.Freezing do
  @moduledoc """
  exert「寒冰真气」（source hanbing-zhenqi/freezing.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat

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
      vitals.max_neili < 2200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "assign_refs": [{"skill", "hanbing-zhenqi"}], "busy_lines": ["me->start_busy(3);"], "remote_damage": false, "resource_gates": [{"con", "34"}, {"max_neili", "2200"}, {"neili", "1000"}], "temp_set": ["freezing"], "var_gates": [{"skill", "140"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # inherit F_CLEAN_UP;
  # 
  # #define FRE "「" HIW "寒冰真气" NOR "」"
  # 
  # void remove_effect(object me);
  # 
  # int exert(object me, object target)
  # {
  #         int skill;
  # 
  #         if (userp(me) && ! me->query("can_perform/hanbing-zhenqi/freezing"))
  #                 return notify_fail("你所学的内功中没有这种功能。\n");
  # 
  #         if ((int)me->query_temp("freezing"))
  #                 return notify_fail("你现在正在施展" FRE "。\n");
  # 
  #         if (target != me)
  #                 return notify_fail(FRE "只能对自己使用。\n");
  # 
  #         skill = me->query_skill("hanbing-zhenqi", 1);
  # 
  #         if (me->query("con") < 34)
  #                 return notify_fail("你的先天根骨不足，无法施展" FRE "。\n");
  # 
  #         if (skill < 140)
  #                 return notify_fail("你的寒冰真气不够，难以施展" FRE "。\n");
  # 
  #         if ((int)me->query("max_neili") < 2200)
  #                 return notify_fail("你的内力修为不足，难以施展" FRE "。\n");
  # 
  #         if (! me->query_temp("powerup"))
  #                 return notify_fail("你现在尚未曾运功，难以施展" FRE "。\n");
  # 
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你目前的内力不够，难以施展" FRE "。\n");
  # 
  #         me->add("neili", -300);
  # 
  #         message_combatd(HIW "$N" HIW "一声冷笑，体内寒冰真气迅速疾转数个周"
  #                         "天，将力聚于掌心。\n" NOR, me);
  #         me->set_temp("freezing", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect",
  #                               me, skill :), skill);
  #         if (me->is_fighting())
  #                 me->start_busy(3);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me)
  # {
  #         if (me->query_temp("freezing"))
  #         {
  #                 me->delete_temp("freezing");
  #                 tell_object(me, "你的" FRE "运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
