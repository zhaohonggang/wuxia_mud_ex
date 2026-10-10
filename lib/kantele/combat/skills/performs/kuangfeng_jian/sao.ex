defmodule Kantele.Combat.Skills.Performs.KuangfengJian.Sao do
  @moduledoc """
  横扫乾坤「sao」（对照 `kungfu/skill/kuangfeng-jian/sao.c`）

  门槛：狂风快剑>=100、激发 sword 为狂风快剑、neili>=200、目标存活且战斗中。
  攻击方发 `perform-incoming`；连出 6 击，每击 50% 概率令目标忙乱 1 回合；
  命中判定带攻击方蓄势加成（`heal` 累计，目前恒 0），每击造成
  `level/10 + random(level/10)` 伤害。
  攻击方扣 150 内力并忙乱 `1+random(6)`（由目标侧 `combat/perform-feedback` 回执）。

  差异（TODO(migrate)）：
  - LPC 的 6 次 `COMBAT_D->do_attack` 折算为每击 `level/10` 基础伤害 +
    命中判定（`level/2 + random(level + count)` vs dodge）；
  - LPC 命中时 `add_temp("curse", 1)` 与 `set_temp("heal", ...)` 的"撕裂累积"
    未建模；`living(target)` 由目标侧 `combat/perform-incoming` 兜底。
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

  @perform "kuangfeng-jian/sao"
  @name "「横扫乾坤」"

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
         :ok <- neili(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform, level: level, attack_bonus: 0}
      })

      conn
      |> Broadcast.publish(
        "$N一声长啸，手中" <> Map.get(weapon, :name) <> "横扫而出，剑光如狂风骤雨般卷向$n！\n",
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
    level = Stats.skill(stats, "kuangfeng-jian")

    if level < 100,
      do: {:error, "你的狂风快剑火候不够，难以施展#{@name}。\n"},
      else: {:ok, level}
  end

  defp mapped(stats, weapon) do
    if Stats.mapped(stats, weapon.skill_type) == "kuangfeng-jian",
      do: :ok,
      else: {:error, "你现在没有激发狂风快剑，难以施展#{@name}。\n"}
  end

  defp neili(character) do
    if character.meta.vitals.neili < 200,
      do: {:error, "你现在的真气不够，难以施展#{@name}。\n"},
      else: :ok
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 1)
    attack_bonus = max(Map.get(data, :attack_bonus, 0), 0)
    bindings = [n1: attacker.name, n2: character.name]
    dodge = Stats.skill(character.meta.stats, "dodge")
    per_hit = max(div(level, 10), 1)

    {combat, damage, hits} =
      Enum.reduce(1..6, {character.meta.combat, 0, 0}, fn _, {combat_acc, damage_acc, hit_acc} ->
        # 剑势连绵，50% 概率令目标忙乱 1 回合（仅当目标未忙乱）
        combat_acc =
          if Engine.rand(rng, 2) == 0 && combat_acc.busy == 0 do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if div(level, 2) + Engine.rand(rng, level + attack_bonus) > dodge do
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

    Performs.feedback(attacker, 150, 1 + Engine.rand(rng, 6))

    result =
      if hits > 0 do
        Messages.interpolate("$p在$N狂猛地快剑下毫无还手之力，身上已平添无数剑伤！\n", bindings)
      else
        Messages.interpolate("可是$p身形急速闪动，堪堪避开了$N的狂风快剑。\n", bindings)
      end

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end