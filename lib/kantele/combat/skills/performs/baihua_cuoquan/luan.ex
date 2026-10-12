defmodule Kantele.Combat.Skills.Performs.BaihuaCuoquan.Luan do
  @moduledoc """
  perform「百花错乱」（source baihua-cuoquan/luan.c，inherit F_SSERVER）

  文案与逻辑按原始 LPC 源码逐条字面对齐（见文末参考注释）。
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "baihua-cuoquan/luan"

  @move_name "「百花错乱」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "baihua-cuoquan")
    ap = Stats.skill(stats, "unarmed")
    damage = (div(ap, 8) + Engine.rand(rng, div(ap, 8)))

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          damage: damage,
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
         :ok <- check_resources(character),
         :ok <- check_mapped(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "baihua-cuoquan") < 120 ->
        {:error, "你的百花错拳等级不够，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "你的真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "baihua-cuoquan" ->
        {:error, "你没有激发百花错拳，难以施展#{@move_name}。\n"}

      Stats.prepared_perform(stats, "unarmed") == nil or String.split(Stats.prepared_perform(stats, "unarmed"), "/") |> hd() != "baihua-cuoquan" ->
        {:error, "你现在没有准备使用百花错拳，无法使用#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果（C：me->add("neili", -50)，紧接广播、命中判定之前）
    # 命中分支的 -150 / busy 1 与失手分支的 -80 / busy 3 均为条件消耗，
    # 由 do_resolve_incoming 通过 Performs.feedback 作用于攻击方。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    conn = Broadcast.publish(conn, "$N顿步沉身，双掌朝$n交错打出，掌锋拳影重重叠叠，正是一招「百花错乱」。", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「百花错乱」只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
      character.meta.combat.busy > 0 ->
        Broadcast.publish(conn, "$n目前正自顾不暇，放胆攻击吧。", n1: attacker.name, n2: character.name)
      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, div(ap * 4, 3)) > dp
    vitals = character.meta.vitals
    combat = character.meta.combat

    {vitals, combat} =
      if hit do
        damage = div(ap, 8) + Engine.rand(rng, div(ap, 8))
        vitals = Vitals.damage(vitals, :qi, damage)
        # C：me->add("neili", -150); me->start_busy(1);
        Performs.feedback(attacker, 150, 1)

        # C：if (ap / 2 + random(ap) > dp && ! target->is_busy())
        #         target->start_busy(ap / 30 + 2);
        combat =
          if combat.busy <= 0 and div(ap, 2) + Engine.rand(rng, ap) > dp do
            Combat.start_busy(combat, div(ap, 30) + 2)
          else
            combat
          end

        {vitals, combat}
      else
        # C：me->add("neili", -80); me->start_busy(3);
        Performs.feedback(attacker, 80, 3)
        {vitals, combat}
      end

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    msg =
      if hit,
        do: "$n只觉$N拳影重重，顿时眼花缭乱，连中数拳，被攻了个措手不及。",
        else: "$n只见$N拳势汹涌，不敢轻视，急忙凝神聚气，奋力化解开来。"

    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}, {"neili", "-50"}, {"neili", "-80"}], "assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}, {"skill", "baihua-cuoquan"}], "busy_lines": ["if (target->is_busy())", "me->start_busy(1);", "if (ap / 2 + random(ap) > dp && ! target->is_busy())", "target->start_busy(ap / 30 + 2);", "me->start_busy(3);"], "map_gates": [{"unarmed", "baihua-cuoquan"}], "prepared_gates": [{"unarmed", "baihua-cuoquan"}], "remote_damage": true, "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "120"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LUAN "「" HIW "百花错乱" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int skill, ap, dp, damage;
  #     string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/baihua-cuoquan/luan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LUAN "只能对战斗中的对手使用。\n");
  # 
  #         skill = me->query_skill("baihua-cuoquan", 1);
  # 
  #         if (skill < 120)
  #                 return notify_fail("你的百花错拳等级不够，难以施展" LUAN "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你的真气不够，难以施展" LUAN "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "baihua-cuoquan")
  #                 return notify_fail("你没有激发百花错拳，难以施展" LUAN "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "baihua-cuoquan")
  #                 return notify_fail("你现在没有准备使用百花错拳，无法使用" LUAN "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "$N" HIW "顿步沉身，双掌朝$n" HIW "交错打出，掌锋拳影重"
  #               "重叠叠，正是一招「百花错乱」。\n" NOR;
  #     me->add("neili", -50);
  # 
  #         ap = me->query_skill("unarmed");
  #         dp = target->query_skill("parry");
  #         if (ap / 2 + random(ap * 4 / 3) > dp)
  #         {
  #                 me->add("neili", -150);
  #                 damage = ap / 8 + random(ap / 8);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 0,
  #                                            HIR "$n" HIR "只觉$N" HIR "拳影重重，"
  #                                            "顿时眼花缭乱，连中数拳，被攻了个措手"
  #                                            "不及。\n" NOR);
  #                 me->start_busy(1);
  #                 if (ap / 2 + random(ap) > dp && ! target->is_busy())
  #                         target->start_busy(ap / 30 + 2);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "只见$N" CYN "拳势汹涌，不敢轻视，急忙凝神聚"
  #                        "气，奋力化解开来。\n" NOR;
  #                 me->add("neili", -80);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
