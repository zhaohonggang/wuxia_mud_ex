defmodule Kantele.Combat.Skills.PiliQuan do
  @moduledoc """
  武学实装「pili-quan」（源 pili-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 3 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine
  - perform/exert 路由骨架见 tmp/perf_out/pili_quan/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「霹雳闪」，双拳飞出，袭向$n$l",
      "force" => 130,
      "attack" => 15,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "霹雳闪"
    },
    %{
      "action" => "$N左右双拳连环击出，一招「天雷轰」，拳风骤响，袭向$n$l",
      "force" => 185,
      "attack" => 17,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 43,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "天雷轰"
    },
    %{
      "action" => "$N左掌圈花扬起，屈肘当胸，右手虎口朝上，一招「天地绝」打向$n的",
      "force" => 220,
      "attack" => 21,
      "parry" => 33,
      "dodge" => 31,
      "damage" => 68,
      "lvl" => 40,
      "damage_type" => "内伤",
      "skill_name" => "天地绝"
    }
  ]

  @impl true
  def id(), do: "pili-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 45}

  # LPC `valid_learn(object me)`（源 pili-quan.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练霹雳闪必须空手。\n"}

      Stats.skill(stats, "force") < 20 ->
        {:error, "你的内功火候不够，无法学霹雳神拳。\n"}

      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力太弱，无法练霹雳神拳。\n"}

      Stats.skill(stats, "cuff") < 20 ->
        {:error, "你的基本拳法火候太浅。\n"}

      Stats.skill(stats, "cuff") < lvl ->
        {:error, "你的基本拳法水平有限，无法领会更高深的霹雳神拳。\n"}

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
      "jin" => Kantele.Combat.Skills.Performs.PiliQuan.Jin
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end
