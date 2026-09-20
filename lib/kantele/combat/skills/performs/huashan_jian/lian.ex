defmodule Kantele.Combat.Skills.Performs.HuashanJian.Lian do
  @moduledoc """
  剑掌五连环「lian」（对照 `kungfu/skill/huashan-jian/lian.c`）

  门槛：华山剑法>=50、激发 weapon 对应用法为华山剑法、force>=100、
  neili>=160、目标存活且战斗中。
  攻击方发 `perform-incoming`；连出 5 击，每击 20% 概率令目标忙乱 1 回合；
  命中每击造成 `level/10 + random(level/10)` 伤害（创伤 1/3）。
  攻击方扣 120 内力并忙乱 `1+random(3)`（由目标侧 `combat/perform-feedback` 回执）。

  差异（TODO(migrate)）：
  - LPC 的 5 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `level/10` 基础伤害 + 「缠字诀」同构的命中判定
    （`level/2 + random(level)` vs dodge）；
  - `living(target)` 门槛未实现，由目标侧 `combat/perform-incoming` 兜底。
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform "huashan-jian/lian"
  @name "「剑掌五连环」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- weapon(combat),
         {:ok, level} <- level(stats),
         :ok <- mapped(stats, weapon),
         :ok <- force(stats),
         :ok <- neili(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform, level: level}
      })

      conn
      |> Broadcast.publish(
        "$N手中" <> Map.get(weapon, :name) <> "剑法如行云流水，剑掌齐发，直取$n周身要害！\n",
        n1: character.name,
        n2: target.name
      )
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
      _ -> {:error, "你使用的武器不对，难以施展#{@name}。\n"}
    end
  end

  defp level(stats) do
    level = Stats.skill(stats, "huashan-jian")

    if level < 50,
      do: {:error, "你的华山剑法还不够纯熟，难以施展#{@name}。\n"},
      else: {:ok, level}
  end

  defp mapped(stats, weapon) do
    if Stats.mapped(stats, weapon.skill_type) == "huashan-jian",
      do: :ok,
      else: {:error, "你现在没有激发华山剑法，难以施展#{@name}。\n"}
  end

  defp force(stats) do
    if Stats.skill(stats, "force") < 100,
      do: {:error, "你的内功修为不够，难以施展#{@name}。\n"},
      else: :ok
  end

  defp neili(character) do
    if character.meta.vitals.neili < 160,
      do: {:error, "你现在的真气不够，难以施展#{@name}。\n"},
      else: :ok
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 1)
    bindings = [n1: attacker.name, n2: character.name]
    dodge = Stats.skill(character.meta.stats, "dodge")
    per_hit = max(div(level, 10), 1)

    {combat, damage, hits} =
      Enum.reduce(1..5, {character.meta.combat, 0, 0}, fn _, {combat_acc, damage_acc, hit_acc} ->
        # 每击与剑掌配合，20% 概率令目标忙乱 1 回合（仅当目标未忙乱）
        combat_acc =
          if Engine.rand(rng, 5) == 0 && combat_acc.busy == 0 do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if div(level, 2) + Engine.rand(rng, level) > dodge do
          {combat_acc, damage_acc + per_hit + Engine.rand(rng, per_hit), hit_acc + 1}
        else
          {combat_acc, damage_acc, hit_acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    Performs.feedback(attacker, 120, 1 + Engine.rand(rng, 3))

    result =
      if hits > 0 do
        Messages.interpolate("$p被$N的剑掌五连环罩住，身上连中数招，节节败退！\n", bindings)
      else
        Messages.interpolate("可是$p左闪右避，堪堪避开了$N的连环进击。\n", bindings)
      end

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end