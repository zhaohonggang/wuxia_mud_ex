defmodule Kantele.Combat.Skills.ChuangwangDao do
  @moduledoc """
  创王刀法（对照 `kungfu/skill/chuangwang-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/chuangwang_dao/`。

  学习门槛 `valid_learn/2`（max_neili>=50 / force>=10 / blade>=chuangwang-dao）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 43，须持刀）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持刀（weapon skill_type=="blade"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N手中$w斜指，一招「沙场点兵」，反身一顿，一刀向$n的$l撩去",
      "force" => 20,
      "dodge" => 10,
      "parry" => 25,
      "damage" => 5,
      "lvl" => 0,
      "skill_name" => "沙场点兵"
    },
    %{
      "action" => "$N一招「过关斩将」，左右腿虚点，$w一提一收，平刃挥向$n的颈部",
      "force" => 30,
      "dodge" => 30,
      "parry" => 10,
      "damage" => 10,
      "lvl" => 20,
      "skill_name" => "过关斩将"
    },
    %{
      "action" => "$N展身虚步，提腰跃落，一招「擒贼擒王」，刀锋一卷，拦腰斩向$n",
      "force" => 40,
      "dodge" => 35,
      "parry" => 25,
      "damage" => 11,
      "lvl" => 40,
      "skill_name" => "擒贼擒王"
    },
    %{
      "action" => "$N一招「声东击西」，$w大开大阖，自上而下划出一个大弧，笔直劈向$n",
      "force" => 60,
      "dodge" => 36,
      "parry" => 25,
      "damage" => 17,
      "lvl" => 60,
      "skill_name" => "声东击西"
    },
    %{
      "action" => "$N手中$w一沉，一招「千军万马」，双手持刃拦腰反切，砍向$n的胸口",
      "force" => 80,
      "dodge" => 34,
      "parry" => 35,
      "damage" => 21,
      "lvl" => 80,
      "skill_name" => "千军万马"
    },
    %{
      "action" => "$N挥舞$w，使出一招「气破金汤」，上劈下撩，左挡右开，齐齐罩向$n",
      "force" => 90,
      "dodge" => 41,
      "parry" => 38,
      "damage" => 27,
      "lvl" => 100,
      "skill_name" => "气破金汤"
    }
  ]

  @impl true
  def id(), do: "chuangwang-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  # LPC valid_learn 要求 max_neili>=50 / force>=10 / blade>=chuangwang-dao（须持刀检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 50 ->
        {:error, "你的内力修为不够。\n"}

      Stats.skill(stats, "force") < 10 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的基本刀法水平有限，无法领会更高深的闯王刀法。\n"}

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
    %{"xiong" => Kantele.Combat.Skills.Performs.ChuangwangDao.Xiong}
  end
  def actions(), do: @actions

end
