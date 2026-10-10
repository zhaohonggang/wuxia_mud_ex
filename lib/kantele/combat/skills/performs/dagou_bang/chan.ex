defmodule Kantele.Combat.Skills.Performs.DagouBang.Chan do
  @moduledoc """
  缠字诀「chan」（对照 `kungfu/skill/dagou-bang/chan.c`）

  门槛：杖、打狗棒法>=60、激发 staff=打狗棒法、force>=100、neili>=100。
  攻击方发 `perform-incoming`；目标侧掷 `level/2 + random(level)` 对抗其 dodge：
  命中则目标 busy `level/18+2`、攻击方 busy 1；失手攻击方 busy 2；
  两种情况攻击方均扣 50 内力（回执）。
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

  @perform "dagou-bang/chan"
  @name "「缠字诀」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         :ok <- weapon(combat),
         :ok <- mapped(stats),
         {:ok, level} <- level(stats),
         :ok <- force(stats),
         :ok <- neili(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform, level: level}
      })

      conn
      |> Broadcast.publish(
        "$N使出打狗棒法「缠」字诀，棒头在地下连点，连绵不绝地挑向$n的小腿和脚踝。\n",
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
      [] -> {:error, @name <> "只能对战斗中的对手使用。\n"}
    end
  end

  defp weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: "staff"} -> :ok
      _ -> {:error, "你使用的武器不对，难以施展#{@name}。\n"}
    end
  end

  defp mapped(stats) do
    if Stats.mapped(stats, "staff") == "dagou-bang",
      do: :ok,
      else: {:error, "你没有激发打狗棒法，难以施展#{@name}。\n"}
  end

  defp level(stats) do
    level = Stats.skill(stats, "dagou-bang")

    if level < 60,
      do: {:error, "你打狗棒法不够娴熟，难以施展#{@name}。\n"},
      else: {:ok, level}
  end

  defp force(stats) do
    if Stats.skill(stats, "force") < 100,
      do: {:error, "你的内功火候不足，难以施展#{@name}。\n"},
      else: :ok
  end

  defp neili(character) do
    if character.meta.vitals.neili < 100,
      do: {:error, "你现在的真气不够，难以施展#{@name}。\n"},
      else: :ok
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = Map.get(data, :level, 0)
    bindings = [n1: attacker.name, n2: character.name]

    if character.meta.combat.busy > 0 do
      conn
    else
      if div(level, 2) + Engine.rand(rng, max(level, 1)) > Stats.skill(character.meta.stats, "dodge") do
        combat = Combat.start_busy(character.meta.combat, div(level, 18) + 2)
        character = %{character | meta: %{character.meta | combat: combat}}
        Performs.feedback(attacker, 50, 1)

        conn
        |> Broadcast.publish(
          Messages.interpolate("棒影窜动间$n招式陡然一紧，已被$N攻的蹦跳不停，手忙脚乱！\n", bindings)
        )
        |> put_character(character)
      else
        Performs.feedback(attacker, 50, 2)
        Broadcast.publish(conn, Messages.interpolate("可是$n看破了$N的企图，镇定解招，一丝不乱。\n", bindings))
      end
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end
