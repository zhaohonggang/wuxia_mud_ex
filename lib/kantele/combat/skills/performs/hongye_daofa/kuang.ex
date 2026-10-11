defmodule Kantele.Combat.Skills.Performs.HongyeDaofa.Kuang do
  @moduledoc """
  perform「狂风落叶」（source hongye-daofa/kuang.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "hongye-daofa/kuang"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "hongye-daofa")
    extra = Stats.skill(stats, "hongye-daofa")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          rng: rng
        }
      })

      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
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
      Stats.skill(stats, "hongye-daofa") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 300, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "assign_refs": [{"extra", "hongye-daofa"}], "busy_lines": ["me->start_busy(2 + random(2));"], "level_gates": [{"hongye-daofa", "150"}], "remote_damage": false, "resource_gates": [{"neili", "800"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  #           
  # #include <ansi.h>  
  # #include <combat.h>  
  #   
  # #define KUANG "「" HIR "狂风落叶" NOR "」"   
  #   
  # inherit F_SSERVER;  
  #   
  # int perform(object me, object target)  
  # {  
  #         int extra;  
  #         object weapon;  
  #         string msg;  
  #   
  #         extra=me->query_skill("hongye-daofa",1);  
  #    
  #   
  #         if( !target ) target = offensive_target(me);  
  #   
  #         if( !target||!target->is_character()||!me->is_fighting(target) )  
  #                 return notify_fail("你只能对战斗中的对手使用" KUANG "。\n");  
  #           
  #         if( (int)me->query_skill("hongye-daofa",1) < 150)  
  #                 return notify_fail("你目前功力还使不出" KUANG "。\n");  
  #   
  #         if (!objectp(weapon = me->query_temp("weapon"))  
  #                 || (string)weapon->query("skill_type") != "blade")  
  #                         return notify_fail("你使用的武器不对。\n");  
  #           
  #         if( (int)me->query("neili") < 800 )  
  #                         return notify_fail("你的内力不够。\n");  
  #           
  #         me->add("neili", -300);  
  #         msg = HIC "$N淡然一笑，本就快捷绝伦的刀法骤然变得更加凌厉！\n"  
  #               HIC "就在这一瞬之间，$N已快速劈出六刀！刀夹杂着风，风里含着刀影！\n"  
  #               HIC "$n只觉得心跳都停止了！" NOR;  
  #   
  #         message_vision(msg, me, target);                  
  #                   
  #         message_combatd(HIY  "$N从左面劈出两刀！\n" NOR, me, target);   
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"), TYPE_REGULAR, msg);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"), TYPE_REGULAR, msg);  
  #   
  #         message_combatd(HIY  "$N紧跟$n从右面劈出两刀！\n" NOR, me, target);   
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"), TYPE_REGULAR, msg);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"), TYPE_REGULAR, msg);  
  #   
  #         message_combatd(HIY  "$N竟然又从上面劈出两刀！\n" NOR, me, target);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"), TYPE_REGULAR, msg);  
  #         COMBAT_D->do_attack(me,target, me->query_temp("weapon"), TYPE_REGULAR, msg);  
  #   
  #         me->start_busy(2 + random(2));  
  #         return 1;  
  # }  
end
