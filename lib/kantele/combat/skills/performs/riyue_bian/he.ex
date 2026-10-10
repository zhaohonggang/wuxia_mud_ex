defmodule Kantele.Combat.Skills.Performs.RiyueBian.He do
  @moduledoc """
  合字诀「he」（对照 `kungfu/skill/riyue-bian/he.c`）

  攻击型绝招：鞭、日月鞭法>=120、neili>=350、激发 whip=日月鞭法、
  目标存活且战斗中。攻击方发 `perform-incoming`；目标侧掷 `whip/2 + random(whip*2)`
  对抗其 parry：命中 `attack_time = 5 + random(whip/45)`（上限 10）、
  `count = whip/5`；失手 `attack_time = 5`、`count = 0`。
  攻击方按 `attack_time*20` 扣内力、busy `1+random(attack_time)`。

  差异（TODO(migrate)）：LPC `do_attack` 逐次连击与 `apply/attack` 临时加成
  未建模，折算为一次合计伤害；`living(target)` 检查省略。
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

  @perform "riyue-bian/he"
  @name "「合」字诀"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         :ok <- weapon(combat),
         :ok <- level(stats),
         :ok <- neili(character),
         :ok <- mapped(stats) do
      weapon = Combat.weapon(combat)

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform,
          ap: Stats.effective(stats, "whip")
        }
      })

      conn
      |> Broadcast.publish(
        "$N将手中的" <> (weapon && Map.get(weapon, :name)) <>
          "一抖，使出日月鞭法「合」字诀，舞起漫天鞭影！\n",
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
      else: {:error, "你还没有受过高人指点，无法施展#{@name}。\n"}
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "日月鞭法#{@name}只能对战斗中的对手使用。\n"}
    end
  end

  defp weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: "whip"} -> :ok
      _ -> {:error, "你使用的武器不对。\n"}
    end
  end

  defp level(stats) do
    if Stats.skill(stats, "riyue-bian") < 120,
      do: {:error, "你的日月鞭法不够娴熟，不会使用#{@name}。\n"},
      else: :ok
  end

  defp neili(character) do
    if character.meta.vitals.neili < 350,
      do: {:error, "你的真气不够，无法使用#{@name}。\n"},
      else: :ok
  end

  defp mapped(stats) do
    if Stats.mapped(stats, "whip") == "riyue-bian",
      do: :ok,
      else: {:error, "你没有激发日月鞭法，无法使用#{@name}。\n"}
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    bindings = [n1: attacker.name, n2: character.name]
    stats = character.meta.stats

    dp = Stats.effective(stats, "parry")

    {attack_time, count, hit} =
      if div(ap, 2) + Engine.rand(rng, ap * 2) > dp do
        {5 + Engine.rand(rng, max(div(ap, 45), 1)), div(ap, 5), true}
      else
        {5, 0, false}
      end

    attack_time = min(attack_time, 10)
    neili_cost = attack_time * 20
    busy = 1 + Engine.rand(rng, max(attack_time, 1))

    # 折算合计伤害（LPC 逐次 do_attack + apply/attack 加成）
    damage = attack_time * max(div(ap, 20), 1) + div(count, 2)
    vitals = Vitals.damage(character.meta.vitals, :qi, damage)
    vitals = Vitals.wound(vitals, :qi, div(damage, 3))
    character = %{character | meta: %{character.meta | vitals: vitals}}

    Performs.feedback(attacker, neili_cost, busy)

    result =
      if hit do
        Messages.interpolate("结果$p被$P攻了个措手不及，目接不暇，疲于奔命！\n", bindings)
      else
        Messages.interpolate("$n见$N鞭势恢弘，心下凛然，凝神应付。\n", bindings)
      end

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end