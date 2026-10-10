defmodule Kantele.Combat.Skills.Performs.DagouBang.Tian do
  @moduledoc """
  天下无狗「tian」（对照 `kungfu/skill/dagou-bang/tian.c`）

  门槛：杖、打狗棒法>=220、激发 staff=打狗棒法、force>=300、neili>=500。
  攻击方算 `ap = 打狗棒法 + begging + martial-cognize`，目标侧以
  `ap/2 + random(ap)` 对抗 `dodge + count + martial-cognize`：命中
  `attack_time = 5 + random(ap/45)`、`count = ap/6`；失手 `attack_time = 5`、
  `count = ap/12`（`attack_time` 上限 9）。攻击方按 `attack_time*30` 扣内力、
  busy `1+random(attack_time)`。

  差异（TODO(migrate)）：LPC 逐次 `do_attack`，本实现折算为一次合计伤害；
  `family/beggarlvl` 加成未建模。
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

  @perform "dagou-bang/tian"
  @name "「天下无狗」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         :ok <- weapon(combat),
         :ok <- mapped(stats),
         :ok <- level(stats),
         :ok <- force(stats),
         :ok <- neili(character) do
      weapon = Combat.weapon(combat)
      ap = ap(stats)

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform, ap: ap, level: Stats.skill(stats, "dagou-bang")}
      })

      conn
      |> Broadcast.publish(
        "$N手中" <> (weapon && Map.get(weapon, :name)) <>
          "一卷，带起阵阵风声，犹若千百根相似，层层叠叠将$n笼罩其中。\n",
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
    Stats.skill(stats, "dagou-bang") + Stats.skill(stats, "begging") + Stats.skill(stats, "martial-cognize")
  end

  defp known(stats) do
    if Stats.perform_known?(stats, @perform), do: :ok, else: {:error, "你所使用的外功中没有这种功能。\n"}
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
    if Stats.skill(stats, "dagou-bang") < 220,
      do: {:error, "你打狗棒法不够娴熟，难以施展#{@name}。\n"},
      else: :ok
  end

  defp force(stats) do
    if Stats.skill(stats, "force") < 300,
      do: {:error, "你的内功火候不足，难以施展#{@name}。\n"},
      else: :ok
  end

  defp neili(character) do
    if character.meta.vitals.neili < 500,
      do: {:error, "你现在的真气不够，难以施展#{@name}。\n"},
      else: :ok
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    bindings = [n1: attacker.name, n2: character.name]
    stats = character.meta.stats

    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "count") + Stats.skill(stats, "martial-cognize")

    {attack_time, count, hit} =
      if div(ap, 2) + Engine.rand(rng, ap) > dp do
        {5 + Engine.rand(rng, max(div(ap, 45), 1)), div(ap, 6), true}
      else
        {5, div(ap, 12), false}
      end

    attack_time = min(attack_time, 9)
    neili_cost = attack_time * 30
    busy = 1 + Engine.rand(rng, max(attack_time, 1))

    # 折算合计伤害（LPC 逐次 do_attack）
    damage = attack_time * max(div(ap, 20), 1) + div(count, 2)
    vitals = Vitals.damage(character.meta.vitals, :qi, damage)
    vitals = Vitals.wound(vitals, :qi, div(damage, 3))
    character = %{character | meta: %{character.meta | vitals: vitals}}

    Performs.feedback(attacker, neili_cost, busy)

    result =
      if hit do
        Messages.interpolate("$n只觉眼花缭乱，发现四面八方皆是杖影，心底寒意顿生，招架散乱。\n", bindings)
      else
        Messages.interpolate("$n只觉眼前一花，发现四面八方皆是杖影，急忙收敛心神，仔细招架。\n", bindings)
      end

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end
