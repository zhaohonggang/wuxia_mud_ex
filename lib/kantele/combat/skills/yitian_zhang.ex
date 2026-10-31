defmodule Kantele.Combat.Skills.YitianZhang do
  @moduledoc """
  武学实装「yitian-zhang」（源 yitian-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/yitian_zhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出倚天屠龙掌中的一式",
      "force" => 110,
      "attack" => 0,
      "parry" => 7,
      "dodge" => 5,
      "damage" => 6,
      "lvl" => 0,
      "damage_type" => "内伤",
      "skill_name" => "武林至尊"
    },
    %{
      "action" => "$N使出倚天屠龙掌中的一式",
      "force" => 148,
      "attack" => 0,
      "parry" => 27,
      "dodge" => 15,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "内伤",
      "skill_name" => "宝刀屠龙"
    },
    %{
      "action" => "$N使出倚天屠龙掌中的一式",
      "force" => 195,
      "attack" => 0,
      "parry" => 33,
      "dodge" => 22,
      "damage" => 19,
      "lvl" => 50,
      "damage_type" => "内伤",
      "skill_name" => "号令天下"
    },
    %{
      "action" => "$N使出倚天屠龙掌中的一式",
      "force" => 245,
      "attack" => 0,
      "parry" => 41,
      "dodge" => 32,
      "damage" => 23,
      "lvl" => 80,
      "damage_type" => "内伤",
      "skill_name" => "莫敢不从"
    },
    %{
      "action" => "$N使出倚天屠龙掌中的一式",
      "force" => 280,
      "attack" => 0,
      "parry" => 46,
      "dodge" => 37,
      "damage" => 29,
      "lvl" => 120,
      "damage_type" => "内伤",
      "skill_name" => "倚天不出"
    },
    %{
      "action" => "$N使出倚天屠龙掌中的一式",
      "force" => 330,
      "attack" => 0,
      "parry" => 57,
      "dodge" => 45,
      "damage" => 36,
      "lvl" => 160,
      "damage_type" => "内伤",
      "skill_name" => "谁与争锋"
    }
  ]

  @impl true
  def id(), do: "yitian-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 62}

  # LPC `valid_learn(object me)`（源 yitian-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练倚天屠龙掌必须空手。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候不够，无法练倚天屠龙掌。\n"}

      not is_nil(max_neili) and max_neili < 750 ->
        {:error, "你的内力太弱，无法练倚天屠龙掌。\n"}

      Stats.skill(stats, "strike") < 80 ->
        {:error, "你的基本掌法火候不够，无法练习倚天屠龙掌。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法水平有限，无法领会更高深的倚天屠龙掌。\n"}

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
      "zheng" => Kantele.Combat.Skills.Performs.YitianZhang.Zheng
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end
