defmodule Kantele.Combat.Skills.JingangBuhuaiti do
  @moduledoc """
  金刚不坏体神功（对照 `kungfu/skill/jingang-buhuaiti.c`）

  护体内功载体：`valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jingang_buhuaiti/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=3000 门槛本版以 force>=300 代理；
  - LPC `valid_damage` 被动（反弹伤害/抵消）与 `query_effect_parry` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jingang-buhuaiti"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "jingang-buhuaiti", 0) < 100 or victim.neili < 300 or
         not is_nil(attacker.weapon_name) do
      {damage, nil}
    else
      ap = Map.get(attacker.skills, "force", 0) * 12 + attacker.max_neili
      dp = Map.get(victim.skills, "force", 0) * 12 + victim.neili

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
        {0, jingang_msg(rng)}
      else
        {damage, nil}
      end
    end
  end

  defp jingang_msg(rng) do
    case rng.(5) - 1 do
      0 -> "$n身前仿佛有一道无形气墙，让$N再难前进一步。\n"
      1 -> "只见$N这一招打了个正中！然而$n毫不在意，并没有放在心上。\n"
      2 -> "$N一招正好打在$n身上，可力量犹如石沉大海，丝毫不起作用。\n"
      3 -> "$N一招击在$n身上，可听$n一声大喝，$N反被护体罡气震退了数步。\n"
      _ -> "$n浑若无事的接下了$N这一招，却没有受到半点伤害。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage == "parry"

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 300 ->
        {:error, "你的内功火候不够，难以修习这等神功。\n"}

      Stats.skill(stats, "force") < Stats.skill(stats, id()) ->
        {:error, "你的基本内功水平有限，无法领会更高深的金刚不坏体神功。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)不能练（LPC practice_skill 未建模）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"jingang" => Kantele.Combat.Skills.Performs.JingangBuhuaiti.Jingang}
  end
end
