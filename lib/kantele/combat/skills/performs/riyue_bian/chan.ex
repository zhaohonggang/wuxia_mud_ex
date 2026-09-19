defmodule Kantele.Combat.Skills.Performs.RiyueBian.Chan do
  @moduledoc """
  缠绕「chan」（对照 `kungfu/skill/riyue-bian/chan.c`）

  攻击型绝招：鞭、neili>=80、激发 whip=日月鞭法、目标存活且战斗中、目标非busy。
  攻击方发 `perform-incoming`；目标侧掷 `whip/2 + random(whip)` 对抗其 parry：
  命中则目标 busy `riyue-bian/20+2`、攻击方 busy 1；失手攻击方 busy 2。

  差异（TODO(migrate)）：LPC 在攻击方师兄读 `target->is_busy()` 直接拒绝，
  本版目标 busy 时由目标侧静默忽略；`living(target)` 检查省略。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform "riyue-bian/chan"
  @name "「缠绕」诀"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         :ok <- weapon(combat),
         :ok <- neili(character),
         :ok <- mapped(stats) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform,
          ap: Stats.effective(stats, "whip"),
          level: Stats.skill(stats, "riyue-bian")
        }
      })

      conn
      |> Broadcast.publish(
        "$N使出日月鞭法「缠绕」诀，连挥数鞭企图把$n的全身缠绕起来。\n",
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
      [] -> {:error, "牵制攻击只能对战斗中的对手使用。\n"}
    end
  end

  defp weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: "whip"} -> :ok
      _ -> {:error, "你没有拿着鞭子。\n"}
    end
  end

  defp neili(character) do
    if character.meta.vitals.neili < 80,
      do: {:error, "你现在真气不够，无法施展#{@name}！\n"},
      else: :ok
  end

  defp mapped(stats) do
    if Stats.mapped(stats, "whip") == "riyue-bian",
      do: :ok,
      else: {:error, "你没有激发日月鞭法，无法施展#{@name}！\n"}
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    level = Map.get(data, :level, 0)
    bindings = [n1: attacker.name, n2: character.name]

    if character.meta.combat.busy > 0 do
      conn
    else
      if div(ap, 2) + Engine.rand(rng, ap) > Stats.effective(character.meta.stats, "parry") do
        combat = Combat.start_busy(character.meta.combat, div(level, 20) + 2)
        character = %{character | meta: %{character.meta | combat: combat}}
        Performs.feedback(attacker, 0, 1)

        conn
        |> Broadcast.publish(Messages.interpolate("结果$p被$P攻了个措手不及！\n", bindings))
        |> put_character(character)
      else
        Performs.feedback(attacker, 0, 2)
        Broadcast.publish(conn, Messages.interpolate("可是$p看破了$P的企图，小心应对，并没有上当。\n", bindings))
      end
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end