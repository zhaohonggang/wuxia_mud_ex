defmodule Kantele.Combat.Skills.SongfengJian do
  @moduledoc """
  武学实装「songfeng-jian」（源 songfeng-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/songfeng_jian/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N纵身跃起手中$w轻挥，一招「苍松迎客」，斩向$n后颈",
      "force" => 80,
      "attack" => 35,
      "parry" => 10,
      "dodge" => 30,
      "damage" => 75,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "苍松迎客"
    },
    %{
      "action" => "$N手中$w连话三个弧形，一招「松针万丈」，向$n的右臂齐肩斩落",
      "force" => 100,
      "attack" => 45,
      "parry" => 22,
      "dodge" => 45,
      "damage" => 88,
      "lvl" => 30,
      "damage_type" => "刺伤",
      "skill_name" => "松针万丈"
    },
    %{
      "action" => "$N轻吁一声，飞身一跃而起，一招「风卷残云」，连续向$n刺出数剑",
      "force" => 120,
      "attack" => 51,
      "parry" => 18,
      "dodge" => 53,
      "damage" => 95,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "风卷残云"
    },
    %{
      "action" => "$N仰天一声清啸，斜行向前，一招「鸿飞冥冥」，$w横削直击，击向$n的$l",
      "force" => 150,
      "attack" => 58,
      "parry" => 20,
      "dodge" => 52,
      "damage" => 110,
      "lvl" => 90,
      "damage_type" => "割伤",
      "skill_name" => "鸿飞冥冥"
    }
  ]

  @impl true
  def id(), do: "songfeng-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 16}

  # LPC `valid_learn(object me)`（源 songfeng-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力不够，无法修习松风剑法。\n"}

      Stats.skill(stats, "dodge") < 60 ->
        {:error, "你的轻功火候太浅，无法修习松风剑法。\n"}

      Stats.query_dex(stats) < 25 ->
        {:error, "你的身法还不够灵活，无法修习松风剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的松风剑法。\n"}

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

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end
