defmodule Kantele.Combat.Skills.Performs.DuanjiaJian.Jing do
  @moduledoc """
  惊天一剑「jing」（对照 `kungfu/skill/duanjia-jian/jing.c`）

  门槛：剑、段家剑法>=80、激发 sword=段家剑法、force>=120、neili>=300、
  目标存活且战斗中。
  攻击方发 `perform-incoming`（带 force/sword）；目标侧掷 `random(force)`
  对抗 `target force/2`：成则造成 `(force+sword)/5 + random(...)` 伤害
  （创伤 50%）、攻击方扣同额内力并忙乱 2；失手攻击方扣 100 内力并忙乱 3
  （由 `combat/perform-feedback` 回执）。

  差异（TODO(migrate)）：
  - LPC 的 `COMBAT_D->do_damage` 折算为一次性 qi 伤害 + 50% 创伤；
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

  @perform "duanjia-jian/jing"
  @name "「惊天一剑」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         :ok <- weapon(combat),
         {:ok, level} <- level(stats),
         :ok <- mapped(stats),
         {:ok, force} <- force(stats),
         :ok <- neili(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform,
          level: level,
          force: force,
          sword: Stats.skill(stats, "sword")
        }
      })

      conn
      |> Broadcast.publish("$N一跃而起，手腕一抖，挽出一个美丽的剑花，飞向$n而去。\n",
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
      %{skill_type: "sword"} -> :ok
      _ -> {:error, "你使用的武器不对，难以施展#{@name}。\n"}
    end
  end

  defp level(stats) do
    level = Stats.skill(stats, "duanjia-jian")

    if level < 80,
      do: {:error, "你的段家剑法不够娴熟，难以施展#{@name}。\n"},
      else: {:ok, level}
  end

  defp mapped(stats) do
    if Stats.mapped(stats, "sword") == "duanjia-jian",
      do: :ok,
      else: {:error, "你现在没有激发段家剑，难以施展#{@name}。\n"}
  end

  defp force(stats) do
    level = Stats.skill(stats, "force")

    if level < 120,
      do: {:error, "你的内功修为不够，难以施展#{@name}。\n"},
      else: {:ok, level}
  end

  defp neili(character) do
    if character.meta.vitals.neili < 300,
      do: {:error, "你现在的真气不够，难以施展#{@name}。\n"},
      else: :ok
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    attacker_force = max(Map.get(data, :force, 0), 1)
    attacker_sword = Map.get(data, :sword, 0)
    target_force = Stats.skill(character.meta.stats, "force")
    bindings = [n1: attacker.name, n2: character.name]

    if Engine.rand(rng, attacker_force) > div(target_force, 2) do
      base = max(div(attacker_force + attacker_sword, 5), 1)
      damage = base + Engine.rand(rng, base)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 2))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, damage, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "只见$N人剑合一，穿向$n，$n只觉一股热流穿心而过，喉头一甜，鲜血狂喷而出！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      Performs.feedback(attacker, 100, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p猛地向边上一跃，跳出了$P的攻击范围。\n", bindings)
      )
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end