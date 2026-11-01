defmodule Kantele.Combat.Skills.BizhenQingzhang do
  @moduledoc """
  裨阵清掌（对照 `kungfu/skill/bizhen-qingzhang.c`）

  掌法载体：`valid_enable("strike")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/bizhen_qingzhang/`。

  学习门槛 `valid_learn/2`（max_neili>=1000 / force>=200 / strike>=140 / strike>=bizhen-qingzhang）与
  练招消耗 `practice_cost`（LPC 扣 qi 80 / neili 80，空手）已按 LPC 迁移（2026-10-30）。
  LPC 的「空手（query_temp("weapon")）」检查未在 `valid_learn` 建模
  （学习/练习本就空手，由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N身形急晃，一跃而至$n跟前，右掌带着切骨之劲砍向$n的$l",
      "force" => 180,
      "attack" => 23,
      "dodge" => 25,
      "parry" => 17,
      "damage" => 19,
      "lvl" => 0
    },
    %{
      "action" => "$N飞身跃起，双掌至上而下斜砍而出，顿时万千道掌寒劲从四面八方席卷$n",
      "force" => 240,
      "attack" => 41,
      "dodge" => 25,
      "parry" => 27,
      "damage" => 25,
      "lvl" => 30
    },
    %{
      "action" => "$N平掌为刀，斜斜砍出，幻出一道道刚猛的掌劲如飓风般裹向$n的全身",
      "force" => 330,
      "attack" => 58,
      "dodge" => 36,
      "parry" => 35,
      "damage" => 39,
      "lvl" => 60
    },
    %{
      "action" => "$N反转右掌护住全身，身形猛跃至$n面前，力注左掌，横向$n拦腰砍去",
      "force" => 410,
      "attack" => 96,
      "dodge" => 81,
      "parry" => 62,
      "damage" => 53,
      "lvl" => 90
    },
    %{
      "action" => "$N右掌后撤，手腕一翻，猛地挥掌砍出，幻出一道无比凌厉的掌劲直斩向$n的$l",
      "force" => 460,
      "attack" => 125,
      "dodge" => 35,
      "parry" => 47,
      "damage" => 78,
      "lvl" => 120
    },
    %{
      "action" => "$N双手挥舞出，形成一个大圈，一股劲气澎湃汹涌而来，逼得$n踉踉后退",
      "force" => 520,
      "attack" => 110,
      "dodge" => 45,
      "parry" => 40,
      "damage" => 85,
      "lvl" => 150
    }
  ]

  @impl true
  def id(), do: "bizhen-qingzhang"

  # LPC hit_ob：damage_bonus>=100 且 random(force) > 对手 force/2 时追加断肋创伤
  @impl true
  def hit_ob(attacker, victim, damage_bonus, _factor, rng) do
    ap = Map.get(attacker.skills, "force", 0)
    dp = div(Map.get(victim.skills, "force", 0), 2)

    if damage_bonus >= 100 and rng.(max(ap, 1)) - 1 > dp do
      {div(damage_bonus - 100, 2), "只听$n前胸“喀嚓”一声，竟像是肋骨碎断的声音！\n"}
    else
      {0, nil}
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["strike", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 80 / neili 80（空手）"
  @impl true
  def practice_cost(), do: %{qi: 80, neili: 80}

  # LPC `valid_learn(object me)`（源 bizhen-qingzhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练碧针清掌必须空手。\n"}

      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功火候不够，无法练习碧针清掌。\n"}

      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力太弱，无法练习碧针清掌。\n"}

      Stats.skill(stats, "strike") < 140 ->
        {:error, "你的基本掌法火候不够，无法练习碧针清掌。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法水平有限，无法领会更高深的碧针清掌。\n"}

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
    %{"pengpai" => Kantele.Combat.Skills.Performs.BizhenQingzhang.Pengpai}
  end
  def actions(), do: @actions

end
