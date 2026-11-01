defmodule Kantele.Combat.Skills.JiandunZhusuo do
  @moduledoc """
  剑盾爪锁（对照 `kungfu/skill/jiandun-zhusuo.c`）

  鞭/爪法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jiandun_zhusuo/`。

  学习门槛 `valid_learn/2`（max_neili>=500 / force>=100 / whip>=20 / whip>=self）与练招消耗
  `practice_cost`（qi 45 / neili 55）已按 LPC 迁移（2026-10-30）。须持鞭检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N端坐不动，一招「缚虎诀」，手中$w抖得笔直，对准$n$l直刺而去",
      "force" => 80,
      "attack" => 30,
      "dodge" => 35,
      "parry" => 25,
      "damage" => 30,
      "lvl" => 0,
      "skill_name" => "缚虎诀"
    },
    %{
      "action" => "$N身形一转，一招「刺鹤诀」，手中$w如矫龙般腾空一卷，猛地向$n劈头打下",
      "force" => 130,
      "attack" => 38,
      "dodge" => 43,
      "parry" => 27,
      "damage" => 45,
      "lvl" => 40,
      "skill_name" => "刺鹤诀"
    },
    %{
      "action" => "$N力贯鞭梢，一招「拌马诀」，手中$w舞出满天鞭影，铺天盖地袭向$n全身",
      "force" => 160,
      "attack" => 45,
      "dodge" => 63,
      "parry" => 29,
      "damage" => 61,
      "lvl" => 80,
      "skill_name" => "拌马诀"
    },
    %{
      "action" => "$N一声娇喝，一招「打蛇诀」，手中$w变换莫测，从意想不到的方位扫向$n",
      "force" => 180,
      "attack" => 50,
      "dodge" => 65,
      "parry" => 33,
      "damage" => 68,
      "lvl" => 120,
      "skill_name" => "打蛇诀"
    },
    %{
      "action" => "$N飞身一跃而起，凌空一招「猎豹诀」，$w宛如蛟龙通天，携着飕飕破空之声袭向$n",
      "force" => 210,
      "attack" => 53,
      "dodge" => 76,
      "parry" => 36,
      "damage" => 73,
      "lvl" => 160,
      "skill_name" => "猎豹诀"
    },
    %{
      "action" => "$N身形飘逸无定，一招「盘鹰诀」，手中$w幻出无数鞭影，笼罩$n全身",
      "force" => 230,
      "attack" => 65,
      "dodge" => 92,
      "parry" => 35,
      "damage" => 91,
      "lvl" => 180,
      "skill_name" => "盘鹰诀"
    },
    %{
      "action" => "$N身形飘逸无定，一招「擒龙诀」，手中$w幻出无数鞭影，笼罩$n全身",
      "force" => 251,
      "attack" => 66,
      "dodge" => 117,
      "parry" => 40,
      "damage" => 120,
      "lvl" => 200,
      "skill_name" => "擒龙诀"
    }
  ]

  @impl true
  def id(), do: "jiandun-zhusuo"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 55（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 55}

  # LPC `valid_learn(object me)`（源 jiandun-zhusuo.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "whip" ->
        {:error, "你必须先找一条鞭子才能练剑盾珠索。\n"}

      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力不足，没有办法练剑盾珠索。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅，没有办法练剑盾珠索。\n"}

      Stats.skill(stats, "whip") < 20 ->
        {:error, "你的基本鞭法火候太浅，没有办法练剑盾珠索。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法水平还不够，无法领会更高深的剑盾珠索。\n"}

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
      "fu" => Kantele.Combat.Skills.Performs.JiandunZhusuo.Fu,
      "qian" => Kantele.Combat.Skills.Performs.JiandunZhusuo.Qian
    }
  end
  def actions(), do: @actions

end
