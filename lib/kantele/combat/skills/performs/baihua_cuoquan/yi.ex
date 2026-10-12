defmodule Kantele.Combat.Skills.Performs.BaihuaCuoquan.Yi do
  @moduledoc """
  perform「百花错易」（source baihua-cuoquan/yi.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：未持兵器 → max_neili>=3000 → force>=280 →
  百花错拳>=150 → 激发 unarmed 的准备招式 → neili>=500 → 目标存活。
  攻击方发 `perform-incoming`；命中判定 `ap/2 + random(ap)` vs
  `parry + dex*10`（`ap = unarmed + str*10`），命中时 `apply/attack` 临时
  加成 `ap/12`；随后连出 6 击，每击 40% 概率令目标忙乱 1 回合。
  攻击方扣 300 内力并忙乱 `1+random(6)`。

  差异（TODO(migrate)）：
  - LPC 的 6 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `level/10` 基础伤害 + 命中判定（命中时 `apply/attack` 加成并入）；
  - `living(target)` 门槛未实现，由目标侧 `combat/perform-incoming` 兜底；
  - `me->query_temp("secondary_weapon")` 副兵器检查未实现。
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

  @perform_id "baihua-cuoquan/yi"

  @move_name "「百花错易」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "baihua-cuoquan")
    ap = Stats.skill(stats, "unarmed") + stats.str * 10

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

  defp check_gates(character) do
    with :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "#{@move_name}只能空手施展。\n"}
      true -> :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "你的内力的修为不够，现在无法使用#{@move_name}。\n"}
      Stats.skill(stats, "force") < 280 -> {:error, "你的内功火候不足，无法使用#{@move_name}。\n"}
      Stats.skill(stats, "baihua-cuoquan") < 150 -> {:error, "你的百花错拳火候不够，无法使用#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.prepared_perform(stats, "unarmed") == nil or String.split(Stats.prepared_perform(stats, "unarmed"), "/") |> hd() != "baihua-cuoquan" ->
        {:error, "你现在没有准备使用百花错拳，无法使用#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 -> {:error, "你的真气不够，无法运用#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果（C：message_vision 后 me->add("neili", -300)）
    # start_busy(1 + random(6)) 位于 6 连击之后，由目标侧 feedback 回执。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn = Broadcast.publish(conn, "$N大喝一声，双掌纷飞，擒拿手中夹着鹰爪功，左手查拳，右手绵掌。攻出去是
八卦掌，收回时已是太极拳，诸家杂陈，毫无规律，铺天盖地向$n狂涌而去。\n\n", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「百花错易」只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    level = max(Map.get(data, :level, 0), 1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "parry") + stats.dex * 10
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp) count = ap / 12; else count = 0
    landed = div(ap, 2) + Engine.rand(rng, ap) > dp
    count = if landed, do: div(ap, 12), else: 0

    # LPC: for (i = 0; i < 6; i++) { if (random(5) < 2 && ! target->is_busy())
    #         target->start_busy(1); COMBAT_D->do_attack(me, target, 0, 0); }
    # 折算：每击 level/10 基础伤害 + 命中判定（apply/attack 加成并入）
    per_hit = max(div(level, 10), 1)
    hit_ap = div(ap, 2) + count

    {damage, _hits} =
      Enum.reduce(1..6, {0, 0}, fn _, {damage_acc, hit_acc} ->
        if hit_ap + Engine.rand(rng, ap) > dp do
          {damage_acc + per_hit + Engine.rand(rng, per_hit), hit_acc + 1}
        else
          {damage_acc, hit_acc}
        end
      end)

    # LPC: 每击前 if (random(5) < 2 && ! target->is_busy()) target->start_busy(1)
    combat =
      if character.meta.combat.busy <= 0 and Engine.rand(rng, 5) < 2 do
        Combat.start_busy(character.meta.combat, 1)
      else
        character.meta.combat
      end

    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # 攻击方：6 连击后 start_busy(1 + random(6))（neili -300 已在 apply_effect 扣除）
    Performs.feedback(attacker, 0, 1 + Engine.rand(rng, 6))

    # 命中/失手各一句（与 .c 一致）
    msg =
      if landed,
        do: "$n只见$N运拳如奔，快拳缤纷递出，顿感头晕目眩，不知该如何抵挡。",
        else: "$n只见$N运拳如奔，快拳缤纷递出，连忙振作精神勉强抵挡。"

    result = Messages.interpolate(msg, bindings)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "apply_adds": ["attack"], "assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "busy_lines": ["if (random(5) < 2 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "level_gates": [{"baihua-cuoquan", "150"}, {"force", "280"}], "prepared_gates": [{"unarmed", "baihua-cuoquan"}], "remote_damage": false, "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}], "var_gates": [{"i", "6"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // yi.c 百花错易
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YI "「" HIW "百花错易" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int count;
  #         int i;
  #  
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/baihua-cuoquan/yi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YI "只能对战斗中的对手使用。\n");
  #  
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(YI "只能空手施展。\n");
  #                 
  #         if (me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力的修为不够，现在无法使用" YI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 280)
  #                 return notify_fail("你的内功火候不足，无法使用" YI "。\n");
  # 
  #         if ((int)me->query_skill("baihua-cuoquan", 1) < 150)
  #                 return notify_fail("你的百花错拳火候不够，无法使用" YI "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "baihua-cuoquan")
  #                 return notify_fail("你现在没有准备使用百花错拳，无法使用" YI "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，无法运用" YI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "大喝一声，双掌纷飞，擒拿手中夹着鹰爪功，左手查"
  #               "拳，右手绵掌。攻出去是\n八卦掌，收回时已是太极拳，诸家杂陈，"
  #               "毫无规律，铺天盖地向$n" HIW "狂涌而去。\n\n" NOR;
  # 
  #         ap = me->query_skill("unarmed") + me->query("str") * 10;
  #         dp = target->query_skill("parry") + target->query("dex") * 10;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 count = ap / 12;
  #                 msg += HIR "$n" HIR "只见$N" HIR "运拳如奔，快拳缤纷递出，"
  #                        "顿感头晕目眩，不知该如何抵挡。\n" NOR;
  #         } else
  #         {
  #                 msg += HIY "$n" HIY "只见$N" HIY "运拳如奔，快拳缤纷递出，"
  #                        "连忙振作精神勉强抵挡。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_vision(msg, me, target);
  #         me->add_temp("apply/attack", count);
  # 
  #         me->add("neili", -300);
  # 
  #         for (i = 0; i < 6; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(5) < 2 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->start_busy(1 + random(6));
  #         me->add_temp("apply/attack", -count);
  # 
  #         return 1;
  # }
end
