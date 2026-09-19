defmodule Kantele.Combat.Skills.Performs.DuanjiaJian.Lian do
  @moduledoc """
  五绝连环「lian」（对照 `kungfu/skill/duanjia-jian/lian.c`）

  门槛：杖/剑、段家剑法>=120、激发武器对应用法（staff/sword）为段家剑法、
  force>=150、neili>=300、目标存活且战斗中。
  攻击方发 `perform-incoming`；连出 5 击，每击 20% 概率令目标忙乱 1 回合；
  命中每击造成 `level/15 + random(level/15)` 伤害（创伤 1/3）。
  攻击方扣 100 内力并忙乱 `1+random(5)`（由目标侧 `combat/perform-feedback` 回执）。

  差异（TODO(migrate)）：
  - LPC 的 5 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击 `level/15` 基础伤害 + 「缠字诀」同构的命中判定（`level/2 + random(level)` vs dodge）；
  - `living(target)` 门槛未实现：敌人列表只存引用快照，无 vitals 可查，
    改由目标侧 `combat/perform-incoming` 的死亡检查兜底。
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

  @perform "duanjia-jian/lian"
  @name "「五绝连环」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- weapon(combat),
         {:ok, level} <- level(stats),
         :ok <- mapped(stats, combat),
         :ok <- force(stats),
         :ok <- neili(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform, level: level}
      })

      conn
      |> Broadcast.publish(
        "$N深吸一口气，脚下步步进击，稳重之极，手中的" <>
          Map.get(weapon, :name) <> "使得犹如飞龙一般，缠绕向$n！\n",
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
      %{skill_type: type} = weapon when type in ["staff", "sword"] -> {:ok, weapon}
      _ -> {:error, "你使用的武器不对，难以施展#{@name}。\n"}
    end
  end

  defp level(stats) do
    level = Stats.skill(stats, "duanjia-jian")

    if level < 120,
      do: {:error, "你的段家剑法不够娴熟，难以施展#{@name}。\n"},
      else: {:ok, level}
  end

  defp mapped(stats, combat) do
    case Combat.weapon(combat) do
      %{skill_type: usage} ->
        if Stats.mapped(stats, usage) == "duanjia-jian",
          do: :ok,
          else: {:error, "你现在没有激发段家剑，难以施展#{@name}。\n"}

      _ ->
        {:error, "你使用的武器不对，难以施展#{@name}。\n"}
    end
  end

  defp force(stats) do
    if Stats.skill(stats, "force") < 150,
      do: {:error, "你的内功修为不够，难以施展#{@name}。\n"},
      else: :ok
  end

  defp neili(character) do
    if character.meta.vitals.neili < 300,
      do: {:error, "你现在的真气不够，难以施展#{@name}。\n"},
      else: :ok
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 1)
    bindings = [n1: attacker.name, n2: character.name]
    dodge = Stats.skill(character.meta.stats, "dodge")
    per_hit = max(div(level, 15), 1)

    {combat, damage, hits} =
      Enum.reduce(1..5, {character.meta.combat, 0, 0}, fn _, {combat_acc, damage_acc, hit_acc} ->
        # 每击 20% 概率令目标忙乱 1 回合（仅当目标未忙乱，LPC random(5)==0）
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

    Performs.feedback(attacker, 100, 1 + Engine.rand(rng, 5))

    result =
      if hits > 0 do
        Messages.interpolate("$p被$N的五绝连环罩住，身上连中数招，节节败退！\n", bindings)
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