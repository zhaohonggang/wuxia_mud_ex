defmodule Kantele.Combat.Skills.Performs.LingsheQuan.Rou do
  @moduledoc """
  perform「柔字诀」（source lingshe-quan/rou.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标在战斗中 → 未持兵器 → 灵蛇拳法>=100 → 真气>=200 →
  目标存活。命中判定 `(cuff+驯兽)/2 + random(cuff+驯兽)` > 目标 `dodge`；
  命中则目标忙乱 1、伤害 `(force+cuff)/2 + random(同值)`（50% 外伤比例）、
  扣 100 真气、攻击方忙乱 2；未命中扣 50 真气、忙乱 3。

  差异（TODO(migrate)）：LPC 无 can_perform 门槛，故无 check_perform_known；
  内力/忙乱由目标侧 feedback 回执。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "lingshe-quan/rou"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: Stats.skill(stats, "lingshe-quan"),
          skill: Stats.skill(stats, "lingshe-quan"),
          # LPC: ap = me->query_skill("cuff") + me->query_skill("training", 1)
          ap: Stats.skill(stats, "cuff") + Stats.skill(stats, "training"),
          # LPC: damage = (force + cuff) / 2（命中后 + random(damage)）
          damage_base: div(Stats.skill(stats, "force") + Stats.skill(stats, "cuff"), 2),
          rng: rng
        }
      })

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「柔字诀」只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (objectp(me->query_temp("weapon")))
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "你要施展拳法不能使用武器。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("lingshe-quan", 1) < 100)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "lingshe-quan") < 100 do
      {:error, "你的灵蛇拳法不够娴熟，现在还无法使用「柔字诀」。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在真气不够，无法运用「柔字诀」。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIG "$N" HIG "一拳打出，半途中手臂忽然不可思议的转了个圈子，
    #               打向$n" HIG "，令$p" HIG "防不胜防。\n" NOR;
    # （相邻字面量合并为单段；伤害/忙乱在目标侧结算）
    conn
    |> Broadcast.publish(
      "$N一拳打出，半途中手臂忽然不可思议的转了个圈子，打向$n，令$p防不胜防。\n",
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
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    base = max(Map.get(data, :damage_base, 0), 0)
    dp = Stats.skill(character.meta.stats, "dodge")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # target->start_busy(1);
      # damage = (force + cuff) / 2 + random(damage);
      # do_damage(UNARMED_ATTACK, damage, 50, …);
      damage = base + Engine.rand(rng, base)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 2))

      combat = Combat.start_busy(character.meta.combat, 1)
      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      # me->add("neili", -100); me->start_busy(2);
      Performs.feedback(attacker, 100, 2)

      conn
      |> Broadcast.publish(
        "只见$n大吃一惊，仓皇之下不及闪躲，被$N一拳打了个正中，闷哼一声，连退数步！\n",
        n1: attacker.name,
        n2: character.name
      )
      |> put_character(character)
    else
      # me->add("neili", -50); me->start_busy(3);
      Performs.feedback(attacker, 50, 3)

      conn
      |> Broadcast.publish(
        "可是$p见机的快，连忙施展身法，避开了拳。\n",
        n1: attacker.name,
        n2: character.name
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // rou.c 柔字诀
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     int damage;
  #     string msg;
  #         int ap, dp;
  # 
  #         if (! target) target = offensive_target(me);
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("「柔字诀」只能对战斗中的对手使用。\n");
  # 
  #     if (objectp(me->query_temp("weapon")))
  #         return notify_fail("你要施展拳法不能使用武器。\n");
  # 
  #     if ((int)me->query_skill("lingshe-quan", 1) < 100)
  #         return notify_fail("你的灵蛇拳法不够娴熟，现在还无法使用「柔字诀」。\n");
  # 
  #     if ((int)me->query("neili") < 200)
  #         return notify_fail("你现在真气不够，无法运用「柔字诀」。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIG "$N" HIG "一拳打出，半途中手臂忽然不可思议的转了个圈子，打向$n"
  #               HIG "，令$p" HIG "防不胜防。\n"NOR;
  # 
  #         ap = me->query_skill("cuff") + me->query_skill("training", 1);
  #         dp = target->query_skill("dodge");
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         target->start_busy(1);
  #         damage = (int)me->query_skill("force") + (int)me->query_skill("cuff");
  #                 damage = damage / 2;
  #                 damage += random(damage);
  # 
  #         me->add("neili", -100);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
  #                                            HIR "只见$n" HIR "大吃一惊，仓皇之下不及闪躲，被$N"
  #                                            HIR "一拳打了个正中，闷哼一声，连退数步！\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += HIC "可是$p" HIC "见机的快，连忙施展身法，避开了拳。\n" NOR;
  #         me->add("neili", -50);
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
