defmodule Kantele.Combat.Skills.TianchangZhang do
  @moduledoc """
  武学实装「tianchang-zhang」（源 tianchang-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 11 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine
  - perform/exert 路由骨架见 tmp/perf_out/tianchang_zhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一式",
      "force" => 60,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "内伤",
      "skill_name" => "潜移默化"
    },
    %{
      "action" => "$N侧身冲上，一招",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 10,
      "lvl" => 30,
      "damage_type" => "内伤",
      "skill_name" => "披星戴月"
    },
    %{
      "action" => "$N提气跃起，使出",
      "force" => 140,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 15,
      "lvl" => 50,
      "damage_type" => "内伤",
      "skill_name" => "乌云密布"
    },
    %{
      "action" => "$N抽身退开一步，接着一式",
      "force" => 170,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 15,
      "lvl" => 90,
      "damage_type" => "内伤",
      "skill_name" => "寒风四起"
    },
    %{
      "action" => "$N双掌突然一拍又向外推开，一式",
      "force" => 190,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 25,
      "lvl" => 110,
      "damage_type" => "内伤",
      "skill_name" => "冰冻三尺"
    },
    %{
      "action" => "$N斜里穿出，使出",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 25,
      "lvl" => 130,
      "damage_type" => "内伤",
      "skill_name" => "骄阳似火"
    },
    %{
      "action" => "$N施展出",
      "force" => 250,
      "attack" => 0,
      "parry" => 45,
      "dodge" => 35,
      "damage" => 45,
      "lvl" => 150,
      "damage_type" => "内伤",
      "skill_name" => "三味真火"
    },
    %{
      "action" => "$N使一式",
      "force" => 270,
      "attack" => 0,
      "parry" => 55,
      "dodge" => 40,
      "damage" => 50,
      "lvl" => 170,
      "damage_type" => "内伤",
      "skill_name" => "月黑风高"
    },
    %{
      "action" => "$N使出",
      "force" => 300,
      "attack" => 0,
      "parry" => 50,
      "dodge" => 35,
      "damage" => 65,
      "lvl" => 180,
      "damage_type" => "内伤",
      "skill_name" => "与天比高"
    },
    %{
      "action" => "$N暗运潜力，施展出",
      "force" => 330,
      "attack" => 0,
      "parry" => 50,
      "dodge" => 35,
      "damage" => 70,
      "lvl" => 190,
      "damage_type" => "内伤",
      "skill_name" => "日月同辉"
    },
    %{
      "action" => "$N双掌交叉一翻，再向外一抱，使出",
      "force" => 350,
      "attack" => 0,
      "parry" => 55,
      "dodge" => 45,
      "damage" => 75,
      "lvl" => 200,
      "damage_type" => "内伤",
      "skill_name" => "日月争辉"
    }
  ]

  @impl true
  def id(), do: "tianchang-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 62}

  # LPC `valid_learn(object me)`（源 tianchang-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练天长掌法必须空手。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候不够，无法练天长掌法。\n"}

      not is_nil(max_neili) and max_neili < 750 ->
        {:error, "你的内力太弱，无法练天长掌法。\n"}

      Stats.skill(stats, "strike") < 80 ->
        {:error, "你的基本掌法火候不够，无法练习天长掌法。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法水平有限，无法领会更高深天长掌法。\n"}

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
      "huang" => Kantele.Combat.Skills.Performs.TianchangZhang.Huang
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end
