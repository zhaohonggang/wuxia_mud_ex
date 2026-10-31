defmodule Kantele.Combat.Skills.TaijiJian do
  @moduledoc """
  太极剑法（对照 `kungfu/skill/taiji-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/taiji_jian/`。

  学习门槛 `valid_learn/2`（int>=26 / max_neili>=1500 / force>=200 /
  taiji-quan>=100 / sword>=100 / sword>=taiji-jian）与练招消耗 `practice_cost`
  （LPC 扣 qi 50 / neili 64，须持剑）已按 LPC 迁移（2026-10-30）。
  招式表（query_action）的静态招式未在本文件建模，沿用基类占位（TODO）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "taiji-jian"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "taiji-jian", 0) < 100 or
         is_nil(victim.weapon_name) or victim.weapon_skill_type != "sword" do
      {damage, nil}
    else
      mp = Map.get(attacker.skills, "count", 0)
      ap = Map.get(attacker.skills, "force", 0) + mp
      dp = div(Map.get(victim.skills, "parry", 0), 2) + Map.get(victim.skills, "taiji-jian", 0)

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
        {0, taiji_jian_msg(rng, victim.weapon_name)}
      else
        if mp >= 100 do
          {damage, taiji_jian_fail_msg(rng, victim.weapon_name)}
        else
          {damage, nil}
        end
      end
    end
  end

  defp taiji_jian_msg(rng, weapon) do
    case rng.(3) - 1 do
      0 -> "$n一抖手中的#{weapon}，划出了一个圆圈，竟然让$N的攻击全然落空。\n"
      1 -> "$n手中#{weapon}轻挑，正指向$N攻势中的破绽。\n"
      _ -> "$n晃动手中的#{weapon}，不住的变幻剑势，让$N完全无法捕捉到力道。\n"
    end
  end

  defp taiji_jian_fail_msg(rng, weapon) do
    case rng.(2) - 1 do
      0 -> "$n一抖手中的#{weapon}，划出了一个圆圈，$N理也不理，当即挥招直入，进袭$n。\n"
      _ -> "$n手中#{weapon}轻挑，正指向$N攻势中的破绽，可是$N身形一变，破绽立刻不成为破绽。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 int>=26 / max_neili>=1500 / force>=200 /
  # taiji-quan>=100 / sword>=100 / sword>=taiji-jian
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      stats.int < 26 ->
        {:error, "你先天悟性太差，难以领会太极剑的要诣。\n"}

      not is_nil(max_neili) and max_neili < 1500 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "taiji-quan") < 100 ->
        {:error, "你的太极拳火候太浅。\n"}

      Stats.skill(stats, "sword") < 100 ->
        {:error, "你的基本剑法水平有限，无法修炼太极剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的太级剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 50 / neili 64（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 64}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "chan" => Kantele.Combat.Skills.Performs.TaijiJian.Chan,
      "jia" => Kantele.Combat.Skills.Performs.TaijiJian.Jia,
      "sui" => Kantele.Combat.Skills.Performs.TaijiJian.Sui,
      "zhenwu" => Kantele.Combat.Skills.Performs.TaijiJian.Zhenwu,
      "zhuan" => Kantele.Combat.Skills.Performs.TaijiJian.Zhuan
    }
  end
end
