defmodule Kantele.Combat.Skills.Force.Lifeheal do
  @moduledoc """
  他人疗伤（对照 `kungfu/skill/force/lifeheal.c`）

  目标疗伤：需非战斗、目标存活、有内功、内功>=50、
  max_neili>=300、neili>=150、目标 eff_qi < max_qi、
  目标 eff_qi >= max_qi/5。
  扣 neili 150，目标回复 eff_qi=10+force/2、qi=10+force/3（上限 max_qi）。
  由于 `exert` 无目标参数：尝试从 `combat.enemies` 取首个非忙乱者视为同伴；
  若无可用目标，提示 "这里没有需要你救助的人。\n"
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform "force/lifeheal"
  @name "疗伤"

  @impl true
  def id(), do: "force"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"lifeheal" => __MODULE__}
  end

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    vitals = character.meta.vitals

    with :ok <- gate_not_fighting(combat),
         :ok <- gate_has_force(stats),
         {:ok, force_lvl} <- gate_force_level(stats),
         :ok <- gate_max_neili(vitals),
         :ok <- gate_neili(vitals),
         {:ok, target} <- find_target(combat) do
      force_name = to_chinese(stats.mapped.force)

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform,
          force_lvl: force_lvl,
          rng: &:rand.uniform/1
        }
      })

      conn
      |> Broadcast.publish(
        "$N坐了下来运起#{force_name}，将手掌贴在#{target.name}背心，缓缓地将真气输入#{target.name}体内....\n过了不久，$N额头上冒出豆大的汗珠，#{target.name}吐出一口瘀血，脸色看起来红润多了。\n",
        n1: character.name,
        n2: target.name
      )
      |> put_character(%{character | meta: %{character.meta | vitals: %{vitals | neili: vitals.neili - 150}}})
      |> assign(:prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    force_lvl = Map.get(data, :force_lvl, 0)
    bindings = [n1: attacker.name, n2: character.name]

    if character.meta.combat.busy > 0 do
      conn
    else
      cure_eff = 10 + div(force_lvl, 2)
      cure_qi = 10 + div(force_lvl, 3)

      t_vitals = character.meta.vitals
      new_eff_qi = min(t_vitals.max_qi + cure_eff, t_vitals.base_qi)
      new_qi = min(t_vitals.qi + cure_qi, new_eff_qi)

      new_vitals = %{t_vitals | max_qi: new_eff_qi, qi: new_qi}
      character = %{character | meta: %{character.meta | vitals: new_vitals}}

      Performs.feedback(attacker, %{neili_cost: 0, busy: 0})

      conn
      |> Broadcast.publish(
        Messages.interpolate("过了不久，$N额头上冒出豆大的汗珠，$n吐出一口瘀血，脸色看起来红润多了。\n", bindings)
      )
      |> put_character(character)
    end
  end

  defp gate_not_fighting(combat) do
    if Combat.fighting?(combat) do
      {:error, "战斗中无法运功疗伤！\n"}
    else
      :ok
    end
  end

  defp gate_has_force(stats) do
    if Map.get(stats.mapped, "force") do
      :ok
    else
      {:error, "你必须激发一种内功才能替人疗伤。\n"}
    end
  end

  defp gate_force_level(stats) do
    force_name = Map.get(stats.mapped, "force")
    force_lvl = Stats.skill(stats, force_name)
    if force_lvl >= 50 do
      {:ok, force_lvl}
    else
      {:error, "你的内功等级不够。\n"}
    end
  end

  defp gate_max_neili(vitals) do
    if vitals.max_neili >= 300 do
      :ok
    else
      {:error, "你的内力修为不够。\n"}
    end
  end

  defp gate_neili(vitals) do
    if vitals.neili >= 150 do
      :ok
    else
      {:error, "你现在的真气不够。\n"}
    end
  end

  defp find_target(combat) do
    case combat.enemies do
      [target | _] when target.busy == 0 ->
        {:ok, target}
      _ ->
        {:error, "这里没有需要你救助的人。\n"}
    end
  end

  defp to_chinese(name) do
    case name do
      "hunyuan-yiqi" -> "混元一气"
      "taiji-shengong" -> "太极神功"
      "xiaowuxiang" -> "小无相"
      "longxiang-gong" -> "龙象般若功"
      "jiuyang-shengong" -> "九阳神功"
      "jiuyin-shengong" -> "九阴神功"
      "kuihua-mogong" -> "葵花魔功"
      "xixing-dafa" -> "吸星大法"
      "zhanshen-xinjing" -> "战神心经"
      "yijinjing" -> "易筋经"
      "hunyuan-gong" -> "混元功"
      _ -> name
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end