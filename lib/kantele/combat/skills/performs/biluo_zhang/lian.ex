defmodule Kantele.Combat.Skills.Performs.BiluoZhang.Lian do
  @moduledoc """
  perform「峰连碧罗」（source biluo-zhang/lian.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：未持兵器 → 碧罗掌法>=100 → 激发 strike 为碧罗掌法 →
  准备 strike 招式 → 内功>=120 → 真气>=200 → 目标存活。
  前置广播后判定 `random(strike) > parry/2`：命中则挂 `apply/attack` +50，
  连出 6 击，结束后撤除；攻击方扣 `attack_time*20`（=120）真气并忙乱
  `1+random(6)`。

  差异（TODO(migrate)）：
  - LPC 的 6 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `level/10` 基础伤害 + 命中判定（命中文档的 `apply/attack` +50
    并入每击命中基数）；
  - `attack_time += 3 + random(ap/40)` 后紧跟 `if (attack_time > 6)
    attack_time = 6`，而 attack_time 初值即 6 故恒被压回 6，直接取 6；
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

  @perform_id "biluo-zhang/lian"

  @move_name "「峰连碧罗」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "biluo-zhang")
    # LPC: ap = me->query_skill("strike")（命中判定基数）
    ap = Stats.skill(stats, "strike")

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

  # LPC 顺序：weapon → biluo-zhang → mapped strike → prepared strike → force → neili
  defp check_gates(character) do
    with :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_force(character),
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

    cond do
      Stats.skill(stats, "biluo-zhang") < 100 ->
        {:error, "你碧罗掌法不够娴熟，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "biluo-zhang" ->
        {:error, "你没有激发碧罗掌法，难以施展#{@move_name}。\n"}

      Stats.prepared_perform(stats, "strike") == nil or String.split(Stats.prepared_perform(stats, "strike"), "/") |> hd() != "biluo-zhang" ->
        {:error, "你没有准备碧罗掌法，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_force(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  # LPC: msg = HIC "\n$N" HIC "双掌陡然连续反转，一招「" HIG "峰连碧罗"
  #       HIC "」，双掌带风，已将$n" HIC "笼罩在掌风之中。" NOR;
  #      message_sort(msg, me, target);
  # 该段各字面量均只被空白分隔，C 侧 join_adjacent 会并为一条，故 .ex 亦为单字面量。
  defp apply_effect(conn, character) do
    conn =
      Broadcast.publish(
        conn,
        "\n$N双掌陡然连续反转，一招「峰连碧罗」，双掌带风，已将$n笼罩在掌风之中。",
        n1: character.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「峰连碧罗」只能对战斗中的对手使用。\n"}
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
    dp = Stats.skill(stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(ap) > dp / 2) 命中 → me->add_temp("apply/attack", 50)
    landed = Engine.rand(rng, ap) > div(dp, 2)
    apply_attack = if landed, do: 50, else: 0

    # LPC: attack_time += 3 + random(ap/40); if (attack_time > 6) attack_time = 6;
    # attack_time 初值即 6，其后只增不减，故恒被压回 6（详见 moduledoc 差异说明）。
    attack_time = 6

    # LPC: for (i = 0; i < attack_time; i++) COMBAT_D->do_attack(me, target, 0, 0);
    # 折算：每击 level/10 基础伤害 + 命中判定（命中文档的 apply/attack +50 并入）
    per_hit = max(div(level, 10), 1)
    hit_ap = div(ap, 2) + apply_attack

    {damage, _hits} =
      Enum.reduce(1..attack_time, {0, 0}, fn _, {damage_acc, hit_acc} ->
        if hit_ap + Engine.rand(rng, ap) > dp do
          {damage_acc + per_hit + Engine.rand(rng, per_hit), hit_acc + 1}
        else
          {damage_acc, hit_acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # 攻击方：add("neili", -attack_time * 20) + start_busy(1 + random(attack_time))
    # LPC 的 add_temp("apply/attack", -50) 随之撤除（折算后不保留该临时加成）。
    Performs.feedback(attacker, attack_time * 20, 1 + Engine.rand(rng, attack_time))

    # 命中/失手各一句（与 .c 一致）
    msg =
      if landed,
        do: "结果$n目不暇接，顿时被$N掌风所困，顿时阵脚大乱。\n",
        else: "$n看清$N这几招的来路，但内劲所至，掌风犀利，也只得小心抵挡。\n"

    result = Messages.interpolate(msg, bindings)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"apply_adds": ["attack"], "assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(1 + random(attack_time));"], "level_gates": [{"biluo-zhang", "100"}, {"force", "120"}], "map_gates": [{"strike", "biluo-zhang"}], "prepared_gates": [{"strike", "biluo-zhang"}], "remote_damage": false, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LIAN "「" HIG "峰连碧罗" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int attack_time, i;
  # 
  #         if (userp(me) && ! me->query("can_perform/biluo-zhang/lian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LIAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(LIAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("biluo-zhang", 1) < 100)
  #                 return notify_fail("你碧罗掌法不够娴熟，难以施展" LIAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "biluo-zhang")
  #                 return notify_fail("你没有激发碧罗掌法，难以施展" LIAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "biluo-zhang")
  #                 return notify_fail("你没有准备碧罗掌法，难以施展" LIAN "。\n");
  # 
  #         if (me->query_skill("force") < 120)
  #                 return notify_fail("你的内功修为不够，难以施展" LIAN "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" LIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIC "\n$N" HIC "双掌陡然连续反转，一招「" HIG "峰连碧罗"
  #               HIC "」，双掌带风，已将$n" HIC "笼罩在掌风之中。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #     if (random(ap) > dp / 2)
  #     {
  #         msg = HIR "结果$n" HIR "目不暇接，顿时被$N" HIR "掌"
  #                       "风所困，顿时阵脚大乱。\n" NOR;
  #                 me->add_temp("apply/attack", 50);
  #         } else
  #         {
  #                 msg = HIY "$n" HIY "看清$N" HIY "这几招的来路，但"
  #                       "内劲所至，掌风犀利，也只得小心抵挡。\n" NOR;
  #         }
  #     message_combatd(msg, me, target);
  # 
  #         attack_time += 3 + random(ap / 40);
  # 
  #         if (attack_time > 6)
  #                 attack_time = 6;
  # 
  #     me->add("neili", -attack_time * 20);
  # 
  #     for (i = 0; i < attack_time; i++)
  #     {
  #         if (! me->is_fighting(target))
  #             break;
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #     }
  #         me->add_temp("apply/attack", -50);
  #     me->start_busy(1 + random(attack_time));
  # 
  #     return 1;
  # }
end
