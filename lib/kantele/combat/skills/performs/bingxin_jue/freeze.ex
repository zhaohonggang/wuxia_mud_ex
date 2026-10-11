defmodule Kantele.Combat.Skills.Performs.BingxinJue.Freeze do
  @moduledoc """
  exert「freeze」（source bingxin-jue/freeze.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

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
      Stats.skill(stats, "bingxin-jue") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: 0}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}], "busy_lines": ["me->start_busy(2);", "target->start_busy(1);"], "level_gates": [{"bingxin-jue", "150"}], "remote_damage": false, "resource_gates": [{"neili", "1000"}], "set_flags": [{"neili", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #         int ap;
  #         int dp;
  #         int damage;
  #         string msg;
  # 
  #         if (target == me || ! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail("你只能用寒气攻击战斗中的对手。\n");
  # 
  #         if (me->query_skill("bingxin-jue", 1) < 150)
  #                 return notify_fail("你的冰心决火候不够，无法运用寒气。\n");
  # 
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你的内力不够!");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "默运冰心决，一股寒气迎面扑向$n"
  #               HIW "，四周登时雪花飘飘。\n" NOR;
  # 
  #         ap = me->query_skill("force");
  #         dp = me->query_skill("force");
  # 
  #         me->start_busy(2);
  # 
  #         if (ap / 2 + random(ap) > random(dp))
  #         {
  #                 damage = ap / 3 + random(ap / 3);
  #                 target->receive_damage("qi", damage, me);
  #                 target->receive_wound("qi", damage, me);
  #                 if (target->query("neili") > damage)
  #                         target->add("neili", damage);
  #                 else
  #                         target->set("neili", 0);
  # 
  #                 msg += HIR "$n" HIR "忽然觉得一阵透骨寒意，霎时间"
  #                        "浑身的血液几乎都要凝固了。\n" NOR;
  #                 target->start_busy(1);
  #         } else
  #                 msg += HIY "$n" HIY "感到一阵寒意自心底泛起，连忙"
  #                        "运动抵抗，堪勘无事。\n" NOR;
  # 
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
