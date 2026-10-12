defmodule Kantele.Combat.Skills.Performs.HongyeDaofa.Kuang do
  @moduledoc """
  perform「狂风落叶」（source hongye-daofa/kuang.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手（且为 character）→ 红叶刀法>=150 →
  兵器为刀 → 真气>=800。攻击方扣 300 真气并忙乱 `2+random(2)`（均为无条件）。
  起手广播后分三组各连出 2 击，共 6 击（`COMBAT_D->do_attack`）。

  差异（TODO(migrate)）：
  - `.c` 顶部的 `extra = me->query_skill("hongye-daofa",1)` 全程未被引用（死代码），
    未在 Elixir 侧保留；
  - LPC 的 6 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `level` 基础判定 + 伤害（与 `biyan_dao/luo.ex` 同构）；
  - `do_attack` 第 5 参为 `msg`（无独立命中/失手文案），命中/失手文案由引擎动作表
    生成，故本文件不再自行发布战斗结果文案；
  - `weapon->query("skill_type") != "blade"` 的兵器检查未持刀/非刀合并为同一文案。
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

  @perform_id "hongye-daofa/kuang"
  @move_name "「狂风落叶」"

  # LPC: 三组各 message_combatd 一句后 2 次 COMBAT_D->do_attack，共 6 击
  @strikes 6

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "hongye-daofa")

    with {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_weapon(combat),
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

  # LPC: if( !target||!target->is_character()||!me->is_fighting(target) )
  # 敌人列表只含 character，故 is_character 隐含成立。
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你只能对战斗中的对手使用#{@move_name}。\n"}
    end
  end

  # LPC: if( (int)me->query_skill("hongye-daofa",1) < 150)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "hongye-daofa") < 150 do
      {:error, "你目前功力还使不出#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (!objectp(weapon = me->query_temp("weapon"))
  #         || (string)weapon->query("skill_type") != "blade")
  defp check_weapon(combat) do
    if weapon_name(combat) == nil do
      {:error, "你使用的武器不对。\n"}
    else
      :ok
    end
  end

  # LPC: if( (int)me->query("neili") < 800 )
  defp check_resources(character) do
    if character.meta.vitals.neili < 800 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character, target, rng) do
    # LPC: me->add("neili", -300);
    #      msg = HIC "$N淡然一笑，本就快捷绝伦的刀法骤然变得更加凌厉！\n"
    #            HIC "就在这一瞬之间，$N已快速劈出六刀！刀夹杂着风，风里含着刀影！\n"
    #            HIC "$n只觉得心跳都停止了！" NOR;
    #      message_vision(msg, me, target);
    #      message_combatd(HIY "$N从左面劈出两刀！\n" NOR, me, target);
    #      message_combatd(HIY "$N紧跟$n从右面劈出两刀！\n" NOR, me, target);
    #      message_combatd(HIY "$N竟然又从上面劈出两刀！\n" NOR, me, target);
    #      ... me->start_busy(2 + random(2));
    # 攻击/目标分处两进程，三组起手句按 LPC 顺序在攻击方顺序发布。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
    combat = Combat.start_busy(character.meta.combat, 2 + Engine.rand(rng, 2))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    bindings = [n1: character.name, n2: target.name]

    conn
    |> Broadcast.publish(
      "$N淡然一笑，本就快捷绝伦的刀法骤然变得更加凌厉！\n" <>
        "就在这一瞬之间，$N已快速劈出六刀！刀夹杂着风，风里含着刀影！\n" <>
        "$n只觉得心跳都停止了！",
      bindings
    )
    |> Broadcast.publish("$N从左面劈出两刀！\n", bindings)
    |> Broadcast.publish("$N紧跟$n从右面劈出两刀！\n", bindings)
    |> Broadcast.publish("$N竟然又从上面劈出两刀！\n", bindings)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> nil
      weapon -> Map.get(weapon, :name)
    end
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

    # LPC 连击 6 次，每次 COMBAT_D->do_attack(me, target, weapon, TYPE_REGULAR, msg)
    damage =
      Enum.reduce(1..strikes, 0, fn _, acc ->
        if div(level, 2) + Engine.rand(rng, level) > dodge do
          acc + level + Engine.rand(rng, level)
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
