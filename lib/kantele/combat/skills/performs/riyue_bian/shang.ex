defmodule Kantele.Combat.Skills.Performs.RiyueBian.Shang do
  @moduledoc """
  伤字诀「shang」（对照 `kungfu/skill/riyue-bian/shang.c`）

  攻击型绝招：鞭、force>=300、日月鞭法>=180、neili>=400、激发 whip=日月鞭法、
  目标存活且战斗中。攻击方发 `perform-incoming`；目标侧掷 `ap/2 + random(ap)`
  对抗其 force+parry（ap = whip+force）：命中 `damage = ap + random(ap/2)`、
  攻击方扣 300 内力/busy 1；失手攻击方扣 100 内力/busy 3。

  差异（TODO(migrate)）：`living(target)` 检查省略；`do_damage` 折算为
  `Vitals.damage + wound`。
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

  @perform "riyue-bian/shang"
  @name "「伤字诀」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         :ok <- weapon(combat),
         :ok <- force(stats),
         :ok <- level(stats),
         :ok <- neili(character),
         :ok <- mapped(stats) do
      weapon = Combat.weapon(combat)
      ap = ap(stats)

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform, ap: ap}
      })

      conn
      |> Broadcast.publish(
        "$N嘿然冷笑，手中的" <> (weapon && Map.get(weapon, :name)) <>
          "一振，霎时变得笔直，如同流星一般飞刺向$n！\n",
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

  defp ap(stats) do
    Stats.effective(stats, "whip") + Stats.effective(stats, "force")
  end

  defp known(stats) do
    if Stats.perform_known?(stats, @perform),
      do: :ok,
      else: {:error, "你还没有受过高人指点，无法施展#{@name}。\n"}
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@name}只能在战斗中对对手使用。\n"}
    end
  end

  defp weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: "whip"} -> :ok
      _ -> {:error, "你使用的武器不对。\n"}
    end
  end

  defp force(stats) do
    if Stats.effective(stats, "force") < 300,
      do: {:error, "你的内功的修为不够，不能使用这一绝技！\n"},
      else: :ok
  end

  defp level(stats) do
    if Stats.skill(stats, "riyue-bian") < 180,
      do: {:error, "你的日月鞭法修为不够，目前不能使用#{@name}！\n"},
      else: :ok
  end

  defp neili(character) do
    if character.meta.vitals.neili < 400,
      do: {:error, "你的真气不够，无法使用#{@name}！\n"},
      else: :ok
  end

  defp mapped(stats) do
    if Stats.mapped(stats, "whip") == "riyue-bian",
      do: :ok,
      else: {:error, "你没有激发日月鞭法，不能使用#{@name}！\n"}
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    bindings = [n1: attacker.name, n2: character.name]
    stats = character.meta.stats

    dp = Stats.effective(stats, "force") + Stats.effective(stats, "parry")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      damage = ap + Engine.rand(rng, max(div(ap, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 3))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 300, 1)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "只见$p一声惨叫，#{Map.get(data, :weapon_name, "长鞭")}竟然插在$p的身上，创口已" <>
            "经对穿，鲜血飞溅数尺，惨不堪言！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      Performs.feedback(attacker, 100, 3)

      Broadcast.publish(
        conn,
        Messages.interpolate("可是$p运足内力，奋力挡住了$P这神鬼莫测的一击！\n", bindings)
      )
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end