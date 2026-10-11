defmodule Kantele.Combat.Skills.TianchangZhang do
  @moduledoc """
  武学实装「tianchang-zhang」（源 tianchang-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 11 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tianchang_zhang/
  """

  use Kantele.Combat.Skill

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
end
