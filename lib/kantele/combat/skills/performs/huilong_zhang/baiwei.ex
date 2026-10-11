defmodule Kantele.Combat.Skills.Performs.HuilongZhang.Baiwei do
  @moduledoc """
  perform「baiwei」（source huilong-zhang/baiwei.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "huilong-zhang/baiwei"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "huilong-zhang")
    extra = (Stats.skill(stats, "huilong-zhang") + Stats.skill(stats, "staff"))
    count = 4
    i = 0

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
      Stats.skill(stats, "huilong-zhang") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "shaolin-xinfa") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 600 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
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
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"extra", "huilong-zhang"}], "busy_lines": ["me->start_busy(1+random(2));"], "level_gates": [{"huilong-zhang", "80"}, {"shaolin-xinfa", "80"}], "remote_damage": false, "resource_gates": [{"neili", "600"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <weapon.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg; 
  #         object weapon;
  #         int extra;
  #         int count, i;
  # 
  #         extra = me->query_skill("huilong-zhang",1) + me->query_skill("staff", 1);    
  #                   
  #         
  #         if( !target ) target = offensive_target(me);
  # 
  #         if( !target || !me->is_fighting(target) )
  #                 return notify_fail("「神龙摆尾」只能在战斗中对对手使用。\n");
  # 
  #         if( !objectp(me->query_temp("weapon") || (string)weapon->query("skill_type") != "staff"))
  #                 return notify_fail("使用「神龙摆尾」时双手应该持杖！\n");
  # 
  #         if( (int)me->query_skill("huilong-zhang", 1) < 80 )
  #                 return notify_fail("你的回龙杖不够娴熟，不会使用「神龙摆尾」。\n");
  # 
  #         if( (int)me->query_skill("shaolin-xinfa", 1) < 80 )
  #                 return notify_fail("你的内功等级不够，不能使用「神龙摆尾」。\n");
  #      
  #         if( (int)me->query("neili") < 600 )
  #                 return notify_fail("你现在内力太弱，不能使用「神龙摆尾」。\n");
  # 
  #         msg = HIY "$N长啸一声，将内力聚于手中钢杖，突然一个转身，手中钢杖点向$n！\n" NOR;
  # 
  #         message_vision(msg, me, target); 
  # 
  #         count = 4;
  #            
  #         for (i=0;i < count;i++)
  #         {
  #            COMBAT_D->do_attack(me, target, me->query_temp("weapon"), TYPE_QUICK);
  #         }
  # 
  #         me->add("neili", -100 );
  # 
  #         me->start_busy(1+random(2));
  # 
  #             return 1;
  # }
end
