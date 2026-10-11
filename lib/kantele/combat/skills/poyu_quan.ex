defmodule Kantele.Combat.Skills.PoyuQuan do
  @moduledoc """
  武学实装「poyu-quan」（源 poyu-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/poyu_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N右脚立定、左脚虚点，一式「起手式」，左右手一高一低，击向$n的$l",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "起手式"
    },
    %{
      "action" => "$N左脚虚踏，全身右转，一招「石破天惊」，右拳猛地击向$n的$l",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "石破天惊"
    },
    %{
      "action" => "$N双手大开大阖，宽打高举，使一招「铁闩横门」，双拳向$n的$l打去",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "铁闩横门"
    },
    %{
      "action" => "$N左掌圈花扬起，屈肘当胸，右手虎口朝上，一招「千斤坠地」打向$n的$l",
      "force" => 260,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "千斤坠地"
    },
    %{
      "action" => "$N使一招「傍花拂柳」，上身前探，双拳划了个半圈，击向$n的$l",
      "force" => 300,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 30,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "傍花拂柳"
    },
    %{
      "action" => "$N双拳划弧，一记「金刚挚尾」，掌出如电，一下子切到$n的手上",
      "force" => 320,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 40,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "金刚挚尾"
    },
    %{
      "action" => "$N施出「封闭手」，双拳拳出如风，同时打向$n头，胸，腹三处要害",
      "force" => 350,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 45,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "封闭手"
    },
    %{
      "action" => "$N左脚内扣，右腿曲坐，一式「粉石碎玉」，双拳齐齐捶向$n的胸口",
      "force" => 380,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 55,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "粉石碎玉"
    }
  ]

  @impl true
  def id(), do: "poyu-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

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


  @impl true
  def perform_list() do
    %{
      "feng" => Kantele.Combat.Skills.Performs.PoyuQuan.Feng,
      "lei" => Kantele.Combat.Skills.Performs.PoyuQuan.Lei,
      "po" => Kantele.Combat.Skills.Performs.PoyuQuan.Po
    }
  end
end
