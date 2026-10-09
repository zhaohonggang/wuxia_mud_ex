defmodule Kantele.Combat.Skills.WuxingQuan do
  @moduledoc """
  武学实装「wuxing-quan」（源 wuxing-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wuxing_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N右脚立定、左脚虚点，一式",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "赤火手"
    },
    %{
      "action" => "$N左脚虚踏，全身右转，一招",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "行风腿"
    },
    %{
      "action" => "$N身形飘忽不定，猛然一招",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 40,
      "damage_type" => "抓伤",
      "skill_name" => "水龙抓"
    },
    %{
      "action" => "$N双手大开大阖，宽打高举，使一招",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "烁金掌"
    },
    %{
      "action" => "$N左掌圈花扬起，屈肘当胸，右手虎口朝上，一招",
      "force" => 260,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "土霸拳"
    },
    %{
      "action" => "$N凝神聚气，一招",
      "force" => 300,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 30,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "神木指"
    },
    %{
      "action" => "$N双拳划弧，一记",
      "force" => 320,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 40,
      "lvl" => 120,
      "damage_type" => "内伤",
      "skill_name" => "五行总诀"
    }
  ]

  @impl true
  def id(), do: "wuxing-quan"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 56}

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

end
