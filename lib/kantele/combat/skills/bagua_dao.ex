defmodule Kantele.Combat.Skills.BaguaDao do
  @moduledoc """
  八卦刀法（对照 `kungfu/skill/bagua-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/bagua_dao/`。

  学习门槛 `valid_learn/2`（max_neili>=1200 / force>=150 / blade>=100 / blade>=bagua-dao）与
  练招消耗 `practice_cost`（LPC 扣 qi 55 / neili 70，须持刀）已按 LPC 迁移（2026-10-30）。
  LPC 的须持刀（weapon skill_type=="blade"）检查由 practice 流程把关，未写入 `valid_learn`；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N脚踏八卦方位，盘身驻地，一招「削耳撩腮」，手中$w由上至下向$n砍去",
      "force" => 125,
      "attack" => 15,
      "dodge" => 56,
      "parry" => 52,
      "damage" => 19,
      "lvl" => 0,
      "skill_name" => "削耳撩腮"
    },
    %{
      "action" => "$N使出「上步劈山」，身形向后乍然一闪，左手急速缠住$n左手，手中$w已罩向$n的$l",
      "force" => 153,
      "attack" => 32,
      "dodge" => 70,
      "parry" => 75,
      "damage" => 27,
      "lvl" => 20,
      "skill_name" => "上步劈山"
    },
    %{
      "action" => "$N脚踏八卦方位，反转刀尖，一招「反身劈山」，手中$w竟然用刀背劈向$n的胸前",
      "force" => 198,
      "attack" => 45,
      "dodge" => 67,
      "parry" => 87,
      "damage" => 34,
      "lvl" => 40,
      "skill_name" => "反身劈山"
    },
    %{
      "action" => "$N脚下踏着先天八卦的图式，身随意转，手随心动，一式「铁牛耕地」，$w缓缓的斜着向$n推去",
      "force" => 220,
      "attack" => 48,
      "dodge" => 75,
      "parry" => 91,
      "damage" => 49,
      "lvl" => 60,
      "skill_name" => "铁牛耕地"
    },
    %{
      "action" => "$N一招「朝阳刀」，左右腿虚点，$w一提一收，划出一个大平十字，挥向$n的颈部",
      "force" => 231,
      "attack" => 55,
      "dodge" => 73,
      "parry" => 96,
      "damage" => 58,
      "lvl" => 80,
      "skill_name" => "朝阳刀"
    },
    %{
      "action" => "$N一提气，劲贯刀锋，$w“嗡嗡”做响，一招「上歪门」，自上而下直插$n的头顶",
      "force" => 257,
      "attack" => 59,
      "dodge" => 73,
      "parry" => 95,
      "damage" => 66,
      "lvl" => 100,
      "skill_name" => "上歪门"
    },
    %{
      "action" => "$N使出「下歪门」，左手后撤，刀斜上招架，顺势下剁，刀光不停指向$n的$l",
      "force" => 253,
      "attack" => 60,
      "dodge" => 85,
      "parry" => 105,
      "damage" => 63,
      "lvl" => 120,
      "skill_name" => "下歪门"
    },
    %{
      "action" => "$N使出「回身劈山」，身法陡变，轻灵飘忽，乘$n眼花耳鸣之际，突然右手刀光反卷向$n的$l",
      "force" => 283,
      "attack" => 63,
      "dodge" => 87,
      "parry" => 118,
      "damage" => 69,
      "lvl" => 140,
      "skill_name" => "回身劈山"
    },
    %{
      "action" => "$N一招「上势抱刀」，$w大开大阖，自上而下划出一个大弧，笔直劈向$n",
      "force" => 268,
      "attack" => 66,
      "dodge" => 88,
      "parry" => 124,
      "damage" => 73,
      "lvl" => 160,
      "skill_name" => "上势抱刀"
    },
    %{
      "action" => "$N藏刀内收，一招「下势撩刀」，刀锋自下而上划了个半弧，向$n的$l挥去！\n$n只觉眼前一片流光般的刀影，向自己全身涌去，退后欲避，又觉一阵寒气直逼过来",
      "force" => 272,
      "attack" => 67,
      "dodge" => 94,
      "parry" => 133,
      "damage" => 82,
      "lvl" => 180,
      "skill_name" => "下势撩刀"
    },
    %{
      "action" => "$N蓦的使一招「八卦八阵」，顿时剑光中无数朵刀花从四面八方涌向$n全身",
      "force" => 280,
      "attack" => 72,
      "dodge" => 96,
      "parry" => 132,
      "damage" => 85,
      "lvl" => 200,
      "skill_name" => "八卦八阵"
    }
  ]



  @ultimate %{
    "action" => "$N凝神静气，使出极招 八卦刀法之极意",
    "lvl" => 300,
    "skill_name" => "极意"
  }
  @impl true
  def id(), do: "bagua-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  # LPC valid_learn 要求 max_neili>=1200 / force>=150 / blade>=100 / blade>=bagua-dao
  # （须持刀检查 weapon skill_type=="blade" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1200 ->
        {:error, "你的内力修为尚浅，无法练习八卦刀法。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "blade") < 100 ->
        {:error, "你的基本刀法水平有限，无法练习八卦刀法。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的基本刀法水平有限，无法领会更高深的八卦刀法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 70（须持刀，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 70}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, attacker) do
    Skill.pick_action_with_ultimate(
      @actions,
      level,
      attacker,
      @ultimate,
      &ultimate_values/2,
      rng
    )
  end

  @impl true
  def perform_list() do
    %{
      "mang" => Kantele.Combat.Skills.Performs.BaguaDao.Mang,
      "sha" => Kantele.Combat.Skills.Performs.BaguaDao.Sha,
      "tian" => Kantele.Combat.Skills.Performs.BaguaDao.Tian
    }
  end
  def actions(), do: @actions

  defp ultimate_values(attacker, rng) do
    blade = Skill.skill_of(attacker, "blade")
    dodge = Skill.skill_of(attacker, "dodge")
    force = Skill.skill_of(attacker, "force")
    parry = Skill.skill_of(attacker, "parry")
    r = &Skill.lpc_random(rng, &1)
    %{
      "force" => div(force, 2) + r.(force),
      "attack" => div(blade, 4) + r.(div(blade, 2)),
      "dodge" => div(dodge, 6) + r.(div(force, 3)),
      "parry" => div(parry, 6) + r.(div(parry, 3)),
      "damage" => div(force, 4) + r.(div(force, 2))
    }
  end

end
