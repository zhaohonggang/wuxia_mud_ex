defmodule Kantele.Combat.Skills.LianhuaZhi do
  @moduledoc """
  武学实装「lianhua-zhi」（源 lianhua-zhi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/lianhua_zhi/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N侧身抬臂，右指划了个半圈，一式「腊月开莲」击向$n的$l",
      "force" => 100,
      "attack" => 10,
      "parry" => 15,
      "dodge" => -5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "腊月开莲"
    },
    %{
      "action" => "$N左掌虚托，一式「莲蕊璨目」，右指穿腋疾出，指向$n的胸前",
      "force" => 140,
      "attack" => 15,
      "parry" => 18,
      "dodge" => -5,
      "damage" => 0,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "莲蕊璨目"
    },
    %{
      "action" => "$N俯身斜倚，左手半推，右手一式「荷内莲香」，向$n的$l划过",
      "force" => 170,
      "attack" => 20,
      "parry" => 25,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "荷内莲香"
    },
    %{
      "action" => "$N双目微睁，一式「杏莲九出」，双手幻化出千百个指影，拂向$n的$l",
      "force" => 210,
      "attack" => 28,
      "parry" => 30,
      "dodge" => 5,
      "damage" => 10,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "杏莲九出"
    },
    %{
      "action" => "$N一式「七宝莲花」，左掌护住丹田，右手斜指苍天，蓄势点向$n的$l",
      "force" => 250,
      "attack" => 30,
      "parry" => 35,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "七宝莲花"
    },
    %{
      "action" => "$N双掌平托胸前，十指叉开，一式「叶底留莲」，指向$n的周身大穴",
      "force" => 280,
      "attack" => 45,
      "parry" => 40,
      "dodge" => 20,
      "damage" => 15,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "叶底留莲"
    }
  ]

  @impl true
  def id(), do: "lianhua-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 51}

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
