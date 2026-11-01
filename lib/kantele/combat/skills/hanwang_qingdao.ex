defmodule Kantele.Combat.Skills.HanwangQingdao do
  @moduledoc """
  汉王清刀（对照 `kungfu/skill/hanwang-qingdao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/hanwang_qingdao/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / force>=30 / blade>=self）与练招消耗
  `practice_cost`（qi 55 / neili 58）已按 LPC 迁移（2026-10-30）。须持刀检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N一招「青刀现影」，$w有如一条黑龙在$n的周身旋游，勿快勿慢，变化若神",
      "force" => 40,
      "attack" => 10,
      "dodge" => -10,
      "parry" => 5,
      "damage" => 5,
      "lvl" => 0,
      "skill_name" => "青刀现影"
    },
    %{
      "action" => "$N一招「万水千山」，左右腿一前一后，$w乱披风势向$n的$l斩去",
      "force" => 90,
      "attack" => 20,
      "dodge" => -10,
      "parry" => 8,
      "damage" => 5,
      "lvl" => 10,
      "skill_name" => "万水千山"
    },
    %{
      "action" => "$N纵身跃落，一招「横扫千军」，$w带着疾风呼的一声便向$n横扫过去",
      "force" => 110,
      "attack" => 25,
      "dodge" => -5,
      "parry" => 12,
      "damage" => 15,
      "lvl" => 30,
      "skill_name" => "横扫千军"
    },
    %{
      "action" => "$N一招「指点江山」，$w大开大阖，左右并进，左一刀，右一刀向$n的两肩砍落",
      "force" => 130,
      "attack" => 30,
      "dodge" => 5,
      "parry" => 15,
      "damage" => 25,
      "lvl" => 50,
      "skill_name" => "指点江山"
    },
    %{
      "action" => "$N手中$w自上而下，一招「飞瀑青影」，刀光流泻，如一片雪白瀑布砍向$n的头部",
      "force" => 160,
      "attack" => 35,
      "dodge" => 10,
      "parry" => 25,
      "damage" => 30,
      "lvl" => 80,
      "skill_name" => "飞瀑青影"
    },
    %{
      "action" => "$N挥舞$w，使出一招「直捣黄龙」，上劈下撩，左挡右开，如千军万马般罩向$n",
      "force" => 180,
      "attack" => 40,
      "dodge" => 15,
      "parry" => 32,
      "damage" => 35,
      "lvl" => 100,
      "skill_name" => "直捣黄龙"
    },
    %{
      "action" => "$N带得刀风劲疾，一招「一刀两断」，一个猛转身，连刀带人往$n的$l的劈去",
      "force" => 190,
      "attack" => 45,
      "dodge" => 5,
      "parry" => 35,
      "damage" => 50,
      "lvl" => 120,
      "skill_name" => "一刀两断"
    },
    %{
      "action" => "$N向前一个弓步，一招「千军万马」，$w直直的劈出，一片流光般的刀影向$n的全身罩去",
      "force" => 220,
      "attack" => 50,
      "dodge" => 20,
      "parry" => 45,
      "damage" => 60,
      "lvl" => 150,
      "skill_name" => "千军万马"
    }
  ]

  @impl true
  def id(), do: "hanwang-qingdao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的基本刀法水平有限，无法领会更高深的韩王青刀。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 58（须持刀，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 58}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"ying" => Kantele.Combat.Skills.Performs.HanwangQingdao.Ying}
  end
  def actions(), do: @actions

end
