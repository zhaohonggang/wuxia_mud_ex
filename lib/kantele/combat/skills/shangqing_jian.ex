defmodule Kantele.Combat.Skills.ShangqingJian do
  @moduledoc """
  武学实装「shangqing-jian」（源 shangqing-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/shangqing_jian/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N使一式「蜃楼铃声」，手中$w疾挥而下，幻出一道孤光刺向$n的$l",
      "force" => 90,
      "attack" => 30,
      "parry" => 25,
      "dodge" => 10,
      "damage" => 25,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "蜃楼铃声"
    },
    %{
      "action" => "$N错步上前，一招「紫气氤氲」，剑意若有若无，$w淡淡刺向$n的$l",
      "force" => 140,
      "attack" => 60,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 40,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "紫气氤氲"
    },
    %{
      "action" => "$N一式「域外来云」，纵身飘开数尺，又猛地错步上前，手中$w疾刺$n的$l",
      "force" => 180,
      "attack" => 60,
      "parry" => 28,
      "dodge" => 25,
      "damage" => 40,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "域外来云"
    },
    %{
      "action" => "$N纵身轻轻跃起，一式「清风拂冈」，剑光如雨点般的洒向$n",
      "force" => 220,
      "attack" => 75,
      "parry" => 35,
      "dodge" => 20,
      "damage" => 60,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "清风拂冈"
    },
    %{
      "action" => "$N手中$w剑芒吞吐，挥洒而出，一式「浊清一潭」，对准$n的$l直直刺出",
      "force" => 260,
      "attack" => 90,
      "parry" => 50,
      "dodge" => 25,
      "damage" => 70,
      "lvl" => 160,
      "damage_type" => "刺伤",
      "skill_name" => "浊清一潭"
    },
    %{
      "action" => "$N大喝一声，$w逼出丈许剑芒刺向$n，正是一式「朝拜金顶」，疾刺$n的$l",
      "force" => 285,
      "attack" => 97,
      "parry" => 48,
      "dodge" => 31,
      "damage" => 73,
      "lvl" => 200,
      "damage_type" => "刺伤",
      "skill_name" => "朝拜金顶"
    }
  ]

  @impl true
  def id(), do: "shangqing-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 100, neili: 55}

  # LPC `valid_learn(object me)`（源 shangqing-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 600 ->
        {:error, "你的内力修为不够，无法学习上清剑法。\n"}

      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内功火候太浅，无法学习上清剑法。\n"}

      Stats.skill(stats, "sword") < 60 ->
        {:error, "你的基本剑法火候太浅，无法学习上清剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的上清剑法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
  @doc "当前等级对应的最高招式名（query_skill_name）"
  def query_skill_name(level) do
    @actions
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> Map.get(action, "skill_name")
    end
  end

  @impl true
  def perform_list() do
    %{
      "qing" => Kantele.Combat.Skills.Performs.ShangqingJian.Qing,
      "zhuo" => Kantele.Combat.Skills.Performs.ShangqingJian.Zhuo
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end
