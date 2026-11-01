defmodule Kantele.Combat.Skills.DongyangDao do
  @moduledoc """
  东洋刀法（对照 `kungfu/skill/dongyang-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/dongyang_dao/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / force>=30 / blade>=dongyang-dao）与
  练招消耗 `practice_cost`（LPC 扣 qi 60 / neili 42，须持刀）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持刀（weapon skill_type=="blade"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N大喝一声，手中$w直劈下来，带起一阵风",
      "force" => 40,
      "attack" => 30,
      "dodge" => 32,
      "parry" => 5,
      "damage" => 95,
      "lvl" => 0
    },
    %{
      "action" => "$N突然横切，划向$n的$l",
      "force" => 80,
      "attack" => 35,
      "dodge" => 33,
      "parry" => 8,
      "damage" => 110,
      "lvl" => 10
    },
    %{
      "action" => "$N手中的$w连续变换几个方向，最后突然直刺$n的$l",
      "force" => 110,
      "attack" => 40,
      "dodge" => 37,
      "parry" => 12,
      "damage" => 110,
      "lvl" => 30
    },
    %{
      "action" => "$N手中的$w猛然旋转，舞起一团刀影，直逼$n",
      "force" => 130,
      "attack" => 45,
      "dodge" => 45,
      "parry" => 15,
      "damage" => 125,
      "lvl" => 50
    },
    %{
      "action" => "$N手中$w一沉，双手持刃拦腰反切，砍向$n的$l",
      "force" => 140,
      "attack" => 40,
      "dodge" => 47,
      "parry" => 18,
      "damage" => 125,
      "lvl" => 80
    },
    %{
      "action" => "$N长啸一声，手中的$w不住的晃动，宛若三把刀劈向$n",
      "force" => 180,
      "attack" => 45,
      "dodge" => 55,
      "parry" => 25,
      "damage" => 135,
      "lvl" => 100
    },
    %{
      "action" => "$N一转身，把背后全被卖给$n，突然双手一转，$w从$N腰侧刺了出来",
      "force" => 200,
      "attack" => 45,
      "dodge" => 55,
      "parry" => 31,
      "damage" => 140,
      "lvl" => 120
    },
    %{
      "action" => "$N猛然前袭，手中$w化作一道刀芒闪电般的刺向$n",
      "force" => 210,
      "attack" => 50,
      "dodge" => 60,
      "parry" => 33,
      "damage" => 160,
      "lvl" => 150
    }
  ]

  @impl true
  def id(), do: "dongyang-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 60 / neili 42（须持刀，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 60, neili: 42}

  # LPC `valid_learn(object me)`（源 dongyang-dao.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够。\n"}

      Stats.skill(stats, "blade") < lvl ->
        {:error, "你的基本刀法水平有限，无法领会更高深的东洋刀法。\n"}

      Stats.skill(stats, "blade") < lvl ->
        {:error, "你的基本刀法水平有限，无法领会更高深的东洋刀法。\n"}

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
    %{
      "luan" => Kantele.Combat.Skills.Performs.DongyangDao.Luan,
      "zhan" => Kantele.Combat.Skills.Performs.DongyangDao.Zhan
    }
  end
  def actions(), do: @actions

end
