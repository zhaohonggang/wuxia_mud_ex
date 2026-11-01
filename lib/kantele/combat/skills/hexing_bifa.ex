defmodule Kantele.Combat.Skills.HexingBifa do
  @moduledoc """
  鹤形笔法（对照 `kungfu/skill/hexing-bifa.c`）

  笔/匕首法载体：`valid_enable("dagger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/hexing_bifa/`。

  学习门槛 `valid_learn/2`（max_neili>=300 / dagger>=hexing-bifa）与
  练招消耗 `practice_cost`（LPC 扣 qi 55 / neili 52，须持短兵）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持短兵（weapon skill_type=="dagger"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N一招「飞鸿展翅」，手中$w猛然点向$n小腹",
      "force" => 120,
      "attack" => 24,
      "dodge" => 10,
      "parry" => 20,
      "damage" => 45,
      "lvl" => 0,
      "skill_name" => "飞鸿展翅"
    },
    %{
      "action" => "$N不退反进，一招「兰花抚穴式」，手中$w点向$n天池穴",
      "force" => 150,
      "attack" => 40,
      "dodge" => 14,
      "parry" => 30,
      "damage" => 60,
      "lvl" => 40,
      "skill_name" => "兰花抚穴式"
    },
    %{
      "action" => "$N手中$w猛然旋转，使出「云开日出」，疾点$n的天门穴",
      "force" => 180,
      "attack" => 60,
      "dodge" => 25,
      "parry" => 32,
      "damage" => 75,
      "lvl" => 60,
      "skill_name" => "云开日出"
    },
    %{
      "action" => "$N手中$w呼呼做响，使出「天旋地转」，$w直打$n的区门穴",
      "force" => 220,
      "attack" => 50,
      "dodge" => 5,
      "parry" => 35,
      "damage" => 70,
      "lvl" => 80,
      "skill_name" => "天旋地转"
    },
    %{
      "action" => "$N飞身跃起，一式「漫天金光」，手中$w犹如万千光点向$n飞击而去",
      "force" => 260,
      "attack" => 70,
      "dodge" => 10,
      "parry" => 45,
      "damage" => 80,
      "lvl" => 100,
      "skill_name" => "漫天金光"
    },
    %{
      "action" => "$N招式陡然变慢，一招「金羽飞箭」，手中$w如离弦之箭直袭$w要穴",
      "force" => 300,
      "attack" => 100,
      "dodge" => 51,
      "parry" => 50,
      "damage" => 110,
      "lvl" => 120,
      "skill_name" => "金羽飞箭"
    }
  ]

  @impl true
  def id(), do: "hexing-bifa"

  @impl true
  def valid_enable(usage), do: usage in ["dagger", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 52（须持短兵，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 52}

  # LPC `valid_learn(object me)`（源 hexing-bifa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力修为不够。\n"}

      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "dagger" ->
        {:error, "你必须先找一把相应的武器才能学习鹤形笔法。\n"}

      Stats.skill(stats, "dagger") < lvl ->
        {:error, "你的基本短兵水平有限，无法领会更高深的鹤形笔法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"dian" => Kantele.Combat.Skills.Performs.HexingBifa.Dian}
  end
  def actions(), do: @actions

end
