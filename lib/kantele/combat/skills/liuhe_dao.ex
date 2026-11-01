defmodule Kantele.Combat.Skills.LiuheDao do
  @moduledoc """
  六合刀法（对照 `kungfu/skill/liuhe-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/liuhe_dao/`。

  学习门槛 `valid_learn/2`（max_neili>=200 / force>=50 / blade>=liuhe-dao）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 43，须持刀）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持刀（weapon skill_type=="blade"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N手中$w斜指，一招「展刀诀」，反身一顿，一刀向$n的$l撩去",
      "force" => 20,
      "dodge" => 10,
      "parry" => 25,
      "damage" => 5,
      "lvl" => 0,
      "skill_name" => "展刀诀"
    },
    %{
      "action" => "$N一招「抹刀诀」，左右腿虚点，$w一提一收，平刃挥向$n的颈部",
      "force" => 30,
      "dodge" => 30,
      "parry" => 40,
      "damage" => 10,
      "lvl" => 20,
      "skill_name" => "抹刀诀"
    },
    %{
      "action" => "$N展身虚步，提腰跃落，一招「剁刀诀」，刀锋一卷，拦腰斩向$n",
      "force" => 40,
      "dodge" => 35,
      "parry" => 45,
      "damage" => 15,
      "lvl" => 40,
      "skill_name" => "剁刀诀"
    },
    %{
      "action" => "$N一招「钩刀诀」，$w大开大阖，自上而下划出一个大弧，笔直劈向$n",
      "force" => 60,
      "dodge" => 45,
      "parry" => 45,
      "damage" => 20,
      "lvl" => 60,
      "skill_name" => "钩刀诀"
    },
    %{
      "action" => "$N手中$w一沉，一招「砍刀诀」，双手持刃拦腰反切，砍向$n的胸口",
      "force" => 80,
      "dodge" => 50,
      "parry" => 55,
      "damage" => 25,
      "lvl" => 80,
      "skill_name" => "砍刀诀"
    },
    %{
      "action" => "$N挥舞$w，使出一招「劈刀诀」，上劈下撩，左挡右开，齐齐罩向$n",
      "force" => 90,
      "dodge" => 65,
      "parry" => 55,
      "damage" => 30,
      "lvl" => 100,
      "skill_name" => "劈刀诀"
    },
    %{
      "action" => "$N一招「六合总诀」，左脚跃步落地，$w顺势往前，挟风声劈向$n的$l",
      "force" => 120,
      "dodge" => 75,
      "parry" => 85,
      "damage" => 35,
      "lvl" => 120,
      "skill_name" => "六合总诀"
    },
    %{
      "action" => "$N盘身驻地，一招「六势合一」，挥出一片流光般的刀影，向$n的全身涌去",
      "force" => 140,
      "dodge" => 90,
      "parry" => 90,
      "damage" => 40,
      "lvl" => 140,
      "skill_name" => "六势合一"
    }
  ]

  @impl true
  def id(), do: "liuhe-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  # LPC valid_learn 要求 max_neili>=200 / force>=50 / blade>=liuhe-dao
  # （须持刀检查 weapon skill_type=="blade" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力修为不够。\n"}

      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的基本刀法水平有限，无法领会更高深的六合刀法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 43（须持刀，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 43}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"shan" => Kantele.Combat.Skills.Performs.LiuheDao.Shan}
  end
  def actions(), do: @actions

end
