defmodule Kantele.Combat.Skills.Performs.FengleiZifa.She do
  @moduledoc """
  射日诀「she」（对照 `kungfu/skill/fenglei-zifa/she.c`）

  门槛：暗器（handing 抛掷物、余量>=1）、风雷子法>=100、neili>=100、
  目标存活且战斗中。
  攻击方消耗手中暗器 1 枚并发 `perform-incoming`；目标侧掷
  `random(combat_exp + skill³/10)` 对抗 `target combat_exp * 2/3`：命中则
  创伤 `skill/2 + random(skill/2)`；两分支攻击方均扣 80 内力、忙乱 2（回执）。

  差异（TODO(migrate)）：
  - LPC 命中后的 `weapon->hit_ob`/`combat_d` 追加伤害与 `eff_status_msg` 括号
    文案未建模，折算为一次 `skill/2 + random` 创伤；
  - `living(target)` 检查省略（由目标侧 `combat/perform-incoming` 死亡检查兜底）。
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

  @perform "fenglei-zifa/she"
  @name "「射日诀」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         {:ok, dart} <- handing(character),
         :ok <- level(stats),
         :ok <- neili(character) do
      character = consume_dart(character, dart)

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform,
          skill: Stats.skill(stats, "fenglei-zifa"),
          combat_exp: stats.combat_exp
        }
      })

      conn
      |> put_character(character)
      |> Broadcast.publish(
        "$N身形微微一展，单手一晃，只听“飕”的一声，一#{dart.meta.base_unit}#{dart.name}如闪电般射向$n而去。\n",
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

  defp handing(character) do
    case character.inventory |> Enum.find(& &1.handing) do
      nil ->
        {:error, "你现在手中并没有拿着暗器，无法施展#{@name}。\n"}

      dart ->
        if Map.get(dart.meta, :skill_type) == "throwing" && (Map.get(dart.meta, :amount) || 1) >= 1 do
          {:ok, dart}
        else
          {:error, "你现在手中并没有拿着暗器，无法施展#{@name}。\n"}
        end
    end
  end

  defp level(stats) do
    if Stats.skill(stats, "fenglei-zifa") < 100,
      do: {:error, "你的风雷子法不够娴熟，无法施展#{@name}。\n"},
      else: :ok
  end

  defp neili(character) do
    if character.meta.vitals.neili < 100,
      do: {:error, "你内力不足，无法施展#{@name}。\n"},
      else: :ok
  end

  defp consume_dart(character, dart) do
    amount = (Map.get(dart.meta, :amount) || 1) - 1

    inventory =
      character.inventory
      |> Enum.reject(fn item -> item == dart && amount < 1 end)
      |> Enum.map(fn item ->
        if item == dart, do: %{item | meta: Map.put(item.meta, :amount, amount)}, else: item
      end)

    %{character | inventory: inventory}
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    skill = max(Map.get(data, :skill, 0), 0)
    my_exp = Map.get(data, :combat_exp, 0) + div(skill * skill, 10) * skill
    ob_exp = character.meta.stats.combat_exp
    bindings = [n1: attacker.name, n2: character.name]

    if Engine.rand(rng, max(my_exp, 1)) > div(ob_exp * 2, 3) do
      damage = div(skill, 2) + Engine.rand(rng, max(div(skill, 2), 1))
      vitals = Vitals.wound(character.meta.vitals, :qi, damage)
      character = %{character | meta: %{character.meta | vitals: vitals}}
      Performs.feedback(attacker, 80, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate("$n闪避不及，顿时被这招打了个血肉模糊的窟窿，整个人疼得几乎都要散架。\n", bindings)
      )
      |> put_character(character)
    else
      Performs.feedback(attacker, 80, 2)
      Broadcast.publish(conn, Messages.interpolate("可是$p轻轻一纵，躲闪开了$P发出的暗器。\n", bindings))
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end