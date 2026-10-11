defmodule Kantele.Combat.Skills.Performs.LuohanFumogong.Fireice do
  @moduledoc """
  exert「冰」（source luohan-fumogong/fireice.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

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
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "luohan-fumogong") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 4000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
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
  #   %{"add_costs": [{"neili", "-300"}], "apply_adds": ["armor", "damage", "unarmed_damage"], "assign_refs": [{"skill", "luohan-fumogong"}], "busy_lines": ["me->start_busy(3);"], "level_gates": [{"luohan-fumogong", "180"}], "remote_damage": false, "resource_gates": [{"max_neili", "4000"}, {"neili", "500"}], "temp_set": ["fireice"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # #define FIREICE "「" HIW "冰" HIR "火" HIW "九重天" NOR "」"
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #         int skill;
  #         string fam;
  #         fam = me->query("family/family_name");
  # 
  #         if (userp(me) && ! me->query("skybook/item/xuanbingjiu"))
  #                 return notify_fail("你所学的内功中没有这种功能。\n");
  # 
  #         if (target != me)
  #                 return notify_fail("你只能用" FIREICE "来提升自己的战斗力。\n");
  # 
  #         if ((int)me->query_temp("fireice"))
  #                 return notify_fail("你现在正在施展" FIREICE "。\n");
  # 
  #         if ((int)me->query_skill("luohan-fumogong", 1) < 180)
  #                 return notify_fail("你罗汉伏魔功火候不足，难以施展" FIREICE "。\n");
  # 
  #         if ((int)me->query("max_neili") < 4000)
  #                 return notify_fail("你的内力修为不足，难以施展" FIREICE "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在的内力不足，难以施展" FIREICE "。\n");
  # 
  #         skill = me->query_skill("luohan-fumogong", 1);
  #         me->add("neili", -300);
  #         me->receive_damage("qi", 0);
  # 
  #         message_combatd(HIC "$N" HIC "纵声长啸，运转「" HIW "冰"
  #                         HIR "火" HIW "九重天" HIC "」真气，聚力"
  #                         "于掌间，光华流动，煞为壮观。\n" NOR, me);
  # 
  #         me->add_temp("apply/unarmed_damage", skill / 5);
  #         me->add_temp("apply/damage", skill / 5);
  #         me->add_temp("apply/armor", skill * 2 / 5);
  #         me->set_temp("fireice", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect",
  #                               me, skill / 5 :), skill);
  # 
  #         if (me->is_fighting())
  #                 me->start_busy(3);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if (me->query_temp("fireice"))
  #         {
  #                 me->add_temp("apply/unarmed_damage", -amount);
  #                 me->add_temp("apply/damage", -amount);
  #                 me->add_temp("apply/armor", -amount * 2);
  #                 me->delete_temp("fireice");
  #                 tell_object(me, "你的" FIREICE "运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
