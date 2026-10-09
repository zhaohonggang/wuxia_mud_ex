defmodule Kantele.Combat.Skills.QishangQuan do
  @moduledoc """
  武学实装「qishang-quan」（源 qishang-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/qishang_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N气凝如山，一式「金戈铁马」，双拳蓄势而发，击向$n的$l",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "内伤",
      "skill_name" => "金戈铁马"
    },
    %{
      "action" => "$N身形凝重，劲发腰背，一式「木已成舟」，缓缓向$n推出",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 15,
      "lvl" => 40,
      "damage_type" => "内伤",
      "skill_name" => "木已成舟"
    },
    %{
      "action" => "$N步伐轻灵，两臂伸舒如鞭，一式「水中捞月」，令$n无可躲闪",
      "force" => 250,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 20,
      "lvl" => 70,
      "damage_type" => "内伤",
      "skill_name" => "水中捞月"
    },
    %{
      "action" => "$N身形跃起，一式「火海刀山」，双拳当空击下，势不可挡",
      "force" => 290,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 30,
      "lvl" => 100,
      "damage_type" => "内伤",
      "skill_name" => "火海刀山"
    },
    %{
      "action" => "$N身形一矮，一式「土载万物」，两拳自下而上，攻向$n",
      "force" => 330,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 45,
      "lvl" => 120,
      "damage_type" => "内伤",
      "skill_name" => "土载万物"
    },
    %{
      "action" => "$N身形一转，一式「阴风惨惨」，攻向$n的身前身后",
      "force" => 350,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 60,
      "lvl" => 140,
      "damage_type" => "内伤",
      "skill_name" => "阴风惨惨"
    },
    %{
      "action" => "$N移形换位，步到拳到，一式「阳光普照」，四面八方都是拳影",
      "force" => 370,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 75,
      "lvl" => 150,
      "damage_type" => "内伤",
      "skill_name" => "阳光普照"
    },
    %{
      "action" => "$N长啸一声，向前踏出一步，双拳中宫直进，一式「七者皆伤」，骤然击向$n的前胸",
      "force" => 390,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 100,
      "lvl" => 160,
      "damage_type" => "内伤",
      "skill_name" => "七者皆伤"
    }
  ]

  @impl true
  def id(), do: "qishang-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 61}

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
