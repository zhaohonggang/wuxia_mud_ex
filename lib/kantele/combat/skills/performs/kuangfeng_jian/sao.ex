defmodule Kantele.Combat.Skills.Performs.KuangfengJian.Sao do
  @moduledoc """
  风扫落叶「sao」（对照 `kungfu/skill/kuangfeng-jian/sao.c`，inherit F_SSERVER）

  门槛：持剑、sword 已激发为 kuangfeng-jian、真气 >= 180、kuangfeng-jian >= 100、
  dodge >= 100、目标存活且战斗中。攻击方广播起手、扣 150 内力并发
  `combat/perform-incoming`；目标侧连受 6 击，每击以
  `level/2 + random(level)` 对抗 dodge，命中造成 `level/3 + random(level/3)`
  伤害、50% 概率令目标忙乱 1 回合。
  攻击方忙乱 `1+random(6)` 由目标侧 `combat/perform-feedback` 回执。
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
  alias Kantele.Combat.Performs

  @perform "kuangfeng-jian/sao"
  @name "「风扫落叶」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- weapon(combat),
         :ok <- mapped(stats),
         :ok <- neili(character),
         {:ok, level} <- level(stats),
         :ok <- dodge(stats),
         :ok <- target_alive(target) do
      # LPC: count = random(me->query_skill("kuangfeng-jian", 1));
      #      me->add_temp("apply/attack", count);
      count = Engine.rand(&:rand.uniform/1, max(level, 1))

      # LPC: msg = HIC "$N" HIC "大喝一声，手中的" + weapon->name() +
      #           HIC "犹如狂风疾电一般劈刺向$n" HIC "！\n"
      #           HIR "霎时间只见剑气层层叠叠如波浪般汹涌而起，$n"
      #           HIR "只觉得呼吸登时不畅。\n" NOR;
      # NOTE: weapon->name() 把起手文案拆成两段字面量。
      start_msg =
        "$N大喝一声，手中的" <>
          (Map.get(weapon, :name) || "") <>
          "犹如狂风疾电一般劈刺向$n！\n霎时间只见剑气层层叠叠如波浪般汹涌而起，$n只觉得呼吸登时不畅。\n"

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform,
          level: level,
          attack_bonus: count
        }
      })

      # LPC: me->add("neili", -150); me->start_busy(1 + random(6));
      # NOTE: 内力/忙乱经目标侧 Performs.feedback 回执落实。

      conn
      |> put_character(character)
      |> Broadcast.publish(start_msg, n1: character.name, n2: target.name)
      |> assign(:prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp known(stats) do
    if Stats.perform_known?(stats, @perform),
      do: :ok,
      else: {:error, "你所使用的外功中没有这种功能。\n"}
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@name}只能对战斗中的对手使用。\n"}
    end
  end

  defp weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: type} = weapon when type == "sword" -> {:ok, weapon}
      _ -> {:error, "你使用的武器不对！\n"}
    end
  end

  defp mapped(stats) do
    if Stats.mapped(stats, "sword") == "kuangfeng-jian",
      do: :ok,
      else: {:error, "你没有激发狂风剑法，难以施展#{@name}。\n"}
  end

  defp neili(character) do
    if character.meta.vitals.neili < 180,
      do: {:error, "你的真气不够，无法施展#{@name}！\n"},
      else: :ok
  end

  defp level(stats) do
    level = Stats.skill(stats, "kuangfeng-jian")

    if level < 100,
      do: {:error, "你的狂风剑法还不到家，无法施展#{@name}！\n"},
      else: {:ok, level}
  end

  defp dodge(stats) do
    if Stats.skill(stats, "dodge") < 100,
      do: {:error, "你的轻功修为不足，无法施展#{@name}！\n"},
      else: :ok
  end

  defp target_alive(target) do
    if not dead?(target),
      do: :ok,
      else: {:error, "对方都已经这样了，用不着这么费力吧？\n"}
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

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
    level = max(Map.get(data, :level, 0), 1)
    attack_bonus = max(Map.get(data, :attack_bonus, 0), 0)
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC: for (i = 0; i < 6; i++) {
    #          if (! me->is_fighting(target)) break;
    #          if (! target->is_busy() && random(2) == 1) target->start_busy(1);
    #          COMBAT_D->do_attack(me, target, weapon, 0);
    #      }
    {combat, damage} =
      Enum.reduce(1..6, {character.meta.combat, 0}, fn _i, {combat_acc, damage_acc} ->
        combat_acc =
          if combat_acc.busy == 0 && Engine.rand(rng, 2) == 1 do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if div(level, 2) + Engine.rand(rng, level + attack_bonus) > dodge do
          {combat_acc, damage_acc + div(level, 3) + Engine.rand(rng, max(div(level, 3), 1))}
        else
          {combat_acc, damage_acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    Performs.feedback(attacker, 150, 1 + Engine.rand(rng, 6))

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end
