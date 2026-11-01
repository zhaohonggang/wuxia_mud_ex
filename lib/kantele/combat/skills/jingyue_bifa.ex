defmodule Kantele.Combat.Skills.JingyueBifa do
  @moduledoc """
  惊月笔法（对照 `kungfu/skill/jingyue-bifa.c`）

  笔/匕首法载体：`valid_enable("dagger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jingyue_bifa/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / dagger>=self）与练招消耗
  `practice_cost`（qi 45 / neili 42）已按 LPC 迁移（2026-10-30）。LPC valid_learn 的「须持短兵」检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N一招「惊空式」，手中$w疾点向$n的期门穴",
      "force" => 90,
      "attack" => 15,
      "dodge" => -10,
      "parry" => 20,
      "damage" => 25,
      "lvl" => 0,
      "skill_name" => "惊空式"
    },
    %{
      "action" => "$N吐气开声一招「皓月式」，$w如灵蛇吞吐，向$n白海穴戳去",
      "force" => 110,
      "attack" => 30,
      "dodge" => 10,
      "parry" => 30,
      "damage" => 30,
      "lvl" => 40,
      "skill_name" => "皓月式"
    },
    %{
      "action" => "$N向前跨上一步，手中$w使出「穿云式」，疾点$n的地仓穴",
      "force" => 130,
      "attack" => 40,
      "dodge" => 5,
      "parry" => 32,
      "damage" => 35,
      "lvl" => 60,
      "skill_name" => "穿云式"
    },
    %{
      "action" => "$N手中的$w自左而右地一晃，使出「飞雪式」带着呼呼风声横打$n的章门穴",
      "force" => 150,
      "attack" => 50,
      "dodge" => 5,
      "parry" => 35,
      "damage" => 40,
      "lvl" => 80,
      "skill_name" => "飞雪式"
    },
    %{
      "action" => "$N飞身跃起，一式「金光式」，卷起漫天笔影，$w向$n电射而去",
      "force" => 170,
      "attack" => 60,
      "dodge" => 10,
      "parry" => 45,
      "damage" => 50,
      "lvl" => 100,
      "skill_name" => "金光式"
    },
    %{
      "action" => "$N凝气守中，$w逼出尺许雪亮笔锋，挥出「天灵式」，一笔快似一笔地攻向$n",
      "force" => 180,
      "attack" => 65,
      "dodge" => 5,
      "parry" => 50,
      "damage" => 60,
      "lvl" => 120,
      "skill_name" => "天灵式"
    }
  ]

  @impl true
  def id(), do: "jingyue-bifa"

  @impl true
  def valid_enable(usage), do: usage in ["dagger", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 42（须持短兵，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 42}

  # LPC `valid_learn(object me)`（源 jingyue-bifa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力修为不够。\n"}

      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "dagger" ->
        {:error, "你必须先找一把相应的武器才能学习惊月笔法。\n"}

      Stats.skill(stats, "dagger") < lvl ->
        {:error, "你的基本短兵水平有限，无法领会更高深的惊月笔法。\n"}

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
    %{"ci" => Kantele.Combat.Skills.Performs.JingyueBifa.Ci}
  end
  def actions(), do: @actions

end
