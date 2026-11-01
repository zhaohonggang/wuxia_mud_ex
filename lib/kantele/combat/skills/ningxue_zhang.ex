defmodule Kantele.Combat.Skills.NingxueZhang do
  @moduledoc """
  凝血掌法（对照 `kungfu/skill/ningxue-zhang.c`）

  掌/杖法载体：`valid_enable("strike")` / `valid_enable("parry")` / `valid_enable("staff")`。

  绝招实现见 `lib/kantele/combat/skills/performs/ningxue_zhang/`。

  学习门槛 `valid_learn/2`（max_neili>=200 / force>=60 / staff>=20 / staff>=self）与练招消耗
  `practice_cost`（qi 75 / neili 78）已按 LPC 迁移（2026-10-30）。LPC valid_learn 的「须持杖」检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N纵步上前，手中$w自下而上，沉猛无比地向$n的小腹挑去",
      "force" => 35,
      "attack" => 8,
      "dodge" => -10,
      "parry" => 5,
      "damage" => 5,
      "lvl" => 0
    },
    %{
      "action" => "$N快步跨出，左手平托$w，右掌猛推杖端，顶向$n的胸口",
      "force" => 50,
      "attack" => 10,
      "dodge" => -10,
      "parry" => 8,
      "damage" => 8,
      "lvl" => 30
    },
    %{
      "action" => "$N高举$w，全身跃起，手中$w朝着$n头盖天灵盖猛然击落下去",
      "force" => 65,
      "attack" => 15,
      "dodge" => -5,
      "parry" => 10,
      "damage" => 12,
      "lvl" => 60
    },
    %{
      "action" => "$N双手持杖如橹，对准$n猛地一搅，如同平地刮起一阵旋风",
      "force" => 80,
      "attack" => 18,
      "dodge" => -5,
      "parry" => 12,
      "damage" => 15,
      "lvl" => 80
    },
    %{
      "action" => "$N横持$w，杖端化出无数个圆圈，凝滞沉重，把$n缠在其中",
      "force" => 100,
      "attack" => 26,
      "dodge" => -15,
      "parry" => 18,
      "damage" => 20,
      "lvl" => 100
    },
    %{
      "action" => "$N全身滚倒，$w盘地横飞，化出漫天杖影，杖影把$n裹了起来",
      "force" => 130,
      "attack" => 35,
      "dodge" => 5,
      "parry" => 22,
      "damage" => 27,
      "lvl" => 120
    },
    %{
      "action" => "$N双手和十，躬身一递出$w，只见$w自肘弯飞出，拦腰向$n撞去",
      "force" => 160,
      "attack" => 40,
      "dodge" => -5,
      "parry" => 28,
      "damage" => 30,
      "lvl" => 140
    },
    %{
      "action" => "$N大喝一声，手中$w如飞龙般自掌中跃出，直向$n的胸口穿入",
      "force" => 180,
      "attack" => 52,
      "dodge" => -5,
      "parry" => 35,
      "damage" => 35,
      "lvl" => 160
    }
  ]

  @impl true
  def id(), do: "ningxue-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["strike", "parry", "staff"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 75 / neili 78（须持杖，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 75, neili: 78}

  # LPC `valid_learn(object me)`（源 ningxue-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "staff" ->
        {:error, "你使用的武器不对。\n"}

      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力修为不足，无法学习凝雪杖法。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候太浅，无法学习凝雪杖法。\n"}

      Stats.skill(stats, "staff") < 20 ->
        {:error, "你的基本杖法太浅，无法学习凝雪杖法。\n"}

      Stats.skill(stats, "staff") < lvl ->
        {:error, "你的基本杖法水平有限，无法领会更高深的凝雪杖法。\n"}

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
    %{"xue" => Kantele.Combat.Skills.Performs.NingxueZhang.Xue}
  end
  def actions(), do: @actions

end
