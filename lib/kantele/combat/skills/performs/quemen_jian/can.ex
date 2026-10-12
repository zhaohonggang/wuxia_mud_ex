defmodule Kantele.Combat.Skills.Performs.QuemenJian.Can do
  @moduledoc """
  perform「天残剑诀」（对照 `kungfu/skill/quemen-jian/can.c`）

  门槛：剑类武器、force>=120、quemen-jian>=80、max_neili>=800、neili>=100、
  激发 sword 为 quemen-jian、目标存活且战斗中。

  攻击方发 `perform-incoming`；连出 4 剑（LPC 4× `COMBAT_D->do_attack`），
  攻击方扣 80 内力并忙乱 `1+random(4)`（由目标侧 `combat/perform-feedback` 回执）。

  差异（TODO(migrate)）：
  - LPC 的 4 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `level/10` 基础伤害 + 与「缠字诀」同构的命中判定
    （`level/2 + random(level)` vs `dodge`）；
  - `living(target)` 门槛未实现，由目标侧 `combat/perform-incoming` 兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages

  @perform_id "quemen-jian/can"
  @move_name "「天残剑诀」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "quemen-jian")
    ap = Stats.skill(stats, "sword")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
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
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 120 -> {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
      Stats.skill(stats, "quemen-jian") < 80 -> {:error, "你缺门剑法不够娴熟，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "quemen-jian" -> {:error, "你没有激发缺门剑法，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 800 -> {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}
      vitals.neili < 100 -> {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    weapon = Combat.weapon(character.meta.combat)

    cond do
      weapon == nil or weapon.skill_type != "sword" -> {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character, target) do
    # 无条件攻击方效果：消耗/Busy + 前置广播
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 80}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1 + :rand.uniform(4))
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    weapon_name = Combat.weapon(combat).name

    conn =
      Broadcast.publish(
        conn,
        "$N施出缺门剑法天残剑诀，手中" <> weapon_name <> "唰唰唰唰连续四剑，笼罩$n周身！",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
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
    level = max(Map.get(data, :level, 0), 1)
    stats = character.meta.stats
    dodge = Stats.skill(stats, "dodge")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: for (i = 0; i < 4; i++) COMBAT_D->do_attack(me, target, weapon, 0);
    # 折算：每击 level/10 基础伤害 + 命中判定（level/2 + random(level) vs dodge）
    per_hit = max(div(level, 10), 1)

    {damage, hits} =
      Enum.reduce(1..4, {0, 0}, fn _, {damage_acc, hit_acc} ->
        if div(level, 2) + Engine.rand(rng, level) > dodge do
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

    result =
      if hits > 0 do
        Messages.interpolate("$n被$N的连续四剑罩住，身上连中数剑，节节败退！\n", bindings)
      else
        Messages.interpolate("可是$n左闪右避，堪堪避开了$N的连续四剑。\n", bindings)
      end

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-80"}], "busy_lines": ["me->start_busy(1 + random(4));"], "level_gates": [{"force", "120"}, {"quemen-jian", "80"}], "map_gates": [{"sword", "quemen-jian"}], "remote_damage": false, "resource_gates": [{"max_neili", "800"}, {"neili", "100"}], "var_gates": [{"i", "4"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define CAN "「" HIR "天残剑诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/quemen-jian/can"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(CAN "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" CAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 120 )
  #                 return notify_fail("你的内功火候不够，难以施展" CAN "。\n");
  # 
  #         if ((int)me->query_skill("quemen-jian", 1) < 80)
  #                 return notify_fail("你缺门剑法不够娴熟，难以施展" CAN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 800)
  #                 return notify_fail("你的内力修为不够，难以施展" CAN "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不够，难以施展" CAN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "quemen-jian")
  #                 return notify_fail("你没有激发缺门剑法，难以施展" CAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "施出缺门剑法天残剑诀，手中" + weapon->name() +
  #               HIR "唰唰唰唰连续四剑，笼罩$n" HIR "周身！\n" NOR;
  #         message_combatd(msg, me, target);
  # 
  #         me->add("neili", -80);
  # 
  #         for (i = 0; i < 4; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->start_busy(1 + random(4));
  #         return 1;
  # }
end
