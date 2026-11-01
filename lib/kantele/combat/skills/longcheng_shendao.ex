defmodule Kantele.Combat.Skills.LongchengShendao do
  @moduledoc """
  龙城神刀（对照 `kungfu/skill/longcheng-shendao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/longcheng_shendao/`。

  学习门槛 `valid_learn/2`（max_neili>=1000 / force>=150 / blade>=80 / blade>=self）与练招消耗
  `practice_cost`（qi 65 / neili 68）已按 LPC 迁移（2026-10-30）。须持刀检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N手中$w轻挥，一招「冬去春来」，身形一转，一刀向$n的$l撩去",
      "force" => 120,
      "attack" => 25,
      "dodge" => 10,
      "parry" => 40,
      "damage" => 30,
      "lvl" => 0,
      "skill_name" => "冬去春来"
    },
    %{
      "action" => "$N一招「月上西楼」，左脚虚点，$w一收一推，平刃挥向$n的脸部",
      "force" => 160,
      "attack" => 28,
      "dodge" => 12,
      "parry" => 45,
      "damage" => 45,
      "lvl" => 30,
      "skill_name" => "月上西楼"
    },
    %{
      "action" => "$N虚步侧身，一招「推窗望月」，刀锋一卷，拦腰斩向$n",
      "force" => 200,
      "attack" => 31,
      "dodge" => 25,
      "parry" => 49,
      "damage" => 65,
      "lvl" => 60,
      "skill_name" => "推窗望月"
    },
    %{
      "action" => "$N一招「梦断巫山」，$w自上而下划出一个大弧，笔直劈向$n",
      "force" => 240,
      "attack" => 48,
      "dodge" => 25,
      "parry" => 54,
      "damage" => 80,
      "lvl" => 90,
      "skill_name" => "梦断巫山"
    },
    %{
      "action" => "$N侧步拧身，一招「似是而非」，拦腰反切，$w砍向$n的胸口",
      "force" => 270,
      "attack" => 60,
      "dodge" => 30,
      "parry" => 72,
      "damage" => 90,
      "lvl" => 120,
      "skill_name" => "似是而非"
    },
    %{
      "action" => "$N挥舞$w，使出一招「月挂中天」，幻起片片刀影，齐齐罩向$n",
      "force" => 300,
      "attack" => 71,
      "dodge" => 35,
      "parry" => 80,
      "damage" => 96,
      "lvl" => 150,
      "skill_name" => "月挂中天"
    },
    %{
      "action" => "$N一招「日月交辉」，只见漫天刀光闪烁，重重刀影向$n的全身涌去",
      "force" => 330,
      "attack" => 80,
      "dodge" => 42,
      "parry" => 94,
      "damage" => 105,
      "lvl" => 180,
      "skill_name" => "日月交辉"
    }
  ]

  @impl true
  def id(), do: "longcheng-shendao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "blade") < 80 ->
        {:error, "你的基本刀法火候不够。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的刀法水平有限，无法领会更高深的龙城神刀。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 65 / neili 68（须持刀，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 65, neili: 68}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{
      "feng" => Kantele.Combat.Skills.Performs.LongchengShendao.Feng,
      "fengyu" => Kantele.Combat.Skills.Performs.LongchengShendao.Fengyu
    }
  end
  def actions(), do: @actions

end
