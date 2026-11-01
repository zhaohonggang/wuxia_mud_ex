defmodule Kantele.Combat.Skills.HujiaDaofa do
  @moduledoc """
  胡家刀法（对照 `kungfu/skill/hujia-daofa.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/hujia_daofa/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=1400 且未习得 daojian-guizhen，
    本版以 force>=80 代理（互斥项未建模）；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N手中$w横推，一招「推波助澜」，由上至下向$nl砍去",
      "force" => 120,
      "attack" => 35,
      "dodge" => 30,
      "parry" => 12,
      "damage" => 40,
      "lvl" => 0,
      "skill_name" => "推波助澜"
    },
    %{
      "action" => "$N一招「沙鸥掠波」，刀锋自下而上划了个半弧，$w一提一收，平刃挥向$n的$l",
      "force" => 160,
      "attack" => 42,
      "dodge" => 40,
      "parry" => 15,
      "damage" => 50,
      "lvl" => 20,
      "skill_name" => "沙鸥掠波"
    },
    %{
      "action" => "$N使出一招「天设牢笼」，将$w舞得如白雾一般，铺天盖地压向$n",
      "force" => 185,
      "attack" => 51,
      "dodge" => 45,
      "parry" => 17,
      "damage" => 60,
      "lvl" => 40,
      "skill_name" => "天设牢笼"
    },
    %{
      "action" => "$N一招「闭门铁扇」，左手平平拍出，右手$w缓缓的斜着向$n推去",
      "force" => 220,
      "attack" => 55,
      "dodge" => 55,
      "parry" => 21,
      "damage" => 70,
      "lvl" => 60,
      "skill_name" => "闭门铁扇"
    },
    %{
      "action" => "$N手拖$w，转身跃起，一招「翼德闯帐」，一道白光射向$n的$l",
      "force" => 255,
      "attack" => 65,
      "dodge" => 60,
      "parry" => 32,
      "damage" => 80,
      "lvl" => 80,
      "skill_name" => "翼德闯帐"
    },
    %{
      "action" => "$N挥舞$w，使出一招「白鹤舒翅」，上劈下撩，左挡右开，齐齐罩向$n",
      "force" => 290,
      "attack" => 70,
      "dodge" => 70,
      "parry" => 35,
      "damage" => 90,
      "lvl" => 120,
      "skill_name" => "白鹤舒翅"
    },
    %{
      "action" => "$N一招「春风送暖」，左脚跃步落地，$w顺势往前，挟风声劈向$n的$l",
      "force" => 320,
      "attack" => 80,
      "dodge" => 85,
      "parry" => 35,
      "damage" => 100,
      "lvl" => 160,
      "skill_name" => "春风送暖"
    },
    %{
      "action" => "$N蓦的使一招「八方藏刀」，顿时剑光中无数朵刀花从四面八方涌向$n$l",
      "force" => 340,
      "attack" => 110,
      "dodge" => 100,
      "parry" => 50,
      "damage" => 110,
      "lvl" => 200,
      "skill_name" => "八方藏刀"
    }
  ]



  @ultimate %{
    "action" => "$N凝神静气，使出极招 胡家刀法之极意",
    "lvl" => 300,
    "skill_name" => "极意"
  }
  @impl true
  def id(), do: "hujia-daofa"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 hujia-daofa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "daojian-guizhen") > 0 ->
        {:error, "你已经将苗家剑法和胡家刀法二者合一了。\n"}

      not is_nil(max_neili) and max_neili < 1400 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "blade") < 120 ->
        {:error, "你的基本刀法火候不够，无法学习胡家刀法。\n"}

      Stats.skill(stats, "blade") < lvl ->
        {:error, "你的基本刀法水平有限，无法领会更高深的胡家刀法。\n"}

      true ->
        :ok
    end
  end

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
      "cang" => Kantele.Combat.Skills.Performs.HujiaDaofa.Cang,
      "xian" => Kantele.Combat.Skills.Performs.HujiaDaofa.Xian,
      "zhui" => Kantele.Combat.Skills.Performs.HujiaDaofa.Zhui
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

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
