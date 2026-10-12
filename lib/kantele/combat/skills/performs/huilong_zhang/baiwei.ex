defmodule Kantele.Combat.Skills.Performs.HuilongZhang.Baiwei do
  @moduledoc """
  perform「神龙摆尾」（source huilong-zhang/baiwei.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 持杖 → 回龙杖>=80 →
  少林心法>=80 → 真气>=600。起手广播后连出 4 次快击
  （`COMBAT_D->do_attack(me, target, weapon, TYPE_QUICK)`），
  攻击方扣 100 真气并忙乱 `1+random(2)`（均为无条件）。

  差异（TODO(migrate)）：
  - `.c` 顶部的 `extra = huilong-zhang + staff` 全程未被引用（死代码），
    未在 Elixir 侧保留；
  - LPC 的 4 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `level` 基础判定 + 伤害（与 `biyan_dao/luo.ex` 同构）；
  - `.c` 的兵器检查写作 `!objectp(query_temp("weapon") || skill_type != "staff")`，
    语义即「未持杖」，未持武器/非杖合并为同一文案；
  - 命中/失手文案由引擎动作表生成，本文件不再自行发布战斗结果文案。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "huilong-zhang/baiwei"

  # LPC: count = 4; for (i=0;i < count;i++) COMBAT_D->do_attack(…, TYPE_QUICK);
  @strikes 4

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "huilong-zhang")

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          strikes: @strikes,
          rng: rng
        }
      })

      apply_effect(conn, character, target, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if( !target || !me->is_fighting(target) )
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「神龙摆尾」只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if( !objectp(me->query_temp("weapon") || (string)weapon->query("skill_type") != "staff"))
  #        return notify_fail("使用「神龙摆尾」时双手应该持杖！\n");
  defp check_weapon(combat) do
    if Combat.weapon(combat) == nil do
      {:error, "使用「神龙摆尾」时双手应该持杖！\n"}
    else
      :ok
    end
  end

  # LPC: if( query_skill("huilong-zhang", 1) < 80 ) / if( query_skill("shaolin-xinfa", 1) < 80 )
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "huilong-zhang") < 80 ->
        {:error, "你的回龙杖不够娴熟，不会使用「神龙摆尾」。\n"}

      Stats.skill(stats, "shaolin-xinfa") < 80 ->
        {:error, "你的内功等级不够，不能使用「神龙摆尾」。\n"}

      true ->
        :ok
    end
  end

  # LPC: if( (int)me->query("neili") < 600 )
  defp check_resources(character) do
    if character.meta.vitals.neili < 600 do
      {:error, "你现在内力太弱，不能使用「神龙摆尾」。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character, target, rng) do
    # LPC: msg = HIY "$N长啸一声，将内力聚于手中钢杖，突然一个转身，手中钢杖点向$n！\n" NOR;
    #      message_vision(msg, me, target);
    #      me->add("neili", -100 ); me->start_busy(1+random(2));
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 2))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> Broadcast.publish(
      "$N长啸一声，将内力聚于手中钢杖，突然一个转身，手中钢杖点向$n！\n",
      n1: character.name,
      n2: target.name
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 无 living(target) 门槛；目标侧 death 检查兜底。
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, _attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 1)
    strikes = Map.get(data, :strikes, @strikes)
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC 连击 4 次，每次 COMBAT_D->do_attack(me, target, weapon, TYPE_QUICK)
    damage =
      Enum.reduce(1..strikes, 0, fn _, acc ->
        if div(level, 2) + Engine.rand(rng, level) > dodge do
          acc + div(level, 2) + Engine.rand(rng, max(div(level, 2), 1))
        else
          acc
        end
      end)

    vitals =
      if damage > 0 do
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 3))
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> put_character(character)
  end
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
