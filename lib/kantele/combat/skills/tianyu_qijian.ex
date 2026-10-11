defmodule Kantele.Combat.Skills.TianyuQijian do
  @moduledoc """
  武学实装「tianyu-qijian」（源 tianyu-qijian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 9 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tianyu_qijian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一式「海天一线」，手中$w嗡嗡微振，幻成一条疾光刺向$n的$l",
      "force" => 60,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "海天一线"
    },
    %{
      "action" => "$N错步上前，使出「闪电惊虹」，手中$w划出一道剑光劈向$n的$l",
      "force" => 70,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "割伤",
      "skill_name" => "闪电惊虹"
    },
    %{
      "action" => "$N手中$w一抖，一招「日在九天」，斜斜一剑反腕撩出，攻向$n的$l",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 20,
      "lvl" => 40,
      "damage_type" => "割伤",
      "skill_name" => "日在九天"
    },
    %{
      "action" => "$N手中剑锵啷啷长吟一声，一式「咫尺天涯」，一道剑光飞向$n的$l",
      "force" => 90,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 25,
      "lvl" => 50,
      "damage_type" => "刺伤",
      "skill_name" => "咫尺天涯"
    },
    %{
      "action" => "$N一式「怒剑狂花」，手中$w舞出无数剑花，使$n难断虚实，无可躲避",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "怒剑狂花"
    },
    %{
      "action" => "$N手中$w斜指苍天，剑芒吞吐，一式「九弧震日」，对准$n的$l斜斜击出",
      "force" => 140,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 35,
      "lvl" => 70,
      "damage_type" => "刺伤",
      "skill_name" => "九弧震日"
    },
    %{
      "action" => "$N一式「漫天风雪」，手腕急抖，挥洒出万点金光，刺向$n的$l",
      "force" => 160,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 40,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "漫天风雪"
    },
    %{
      "action" => "$N一式「天河倒泻」，$w飞斩盘旋，如疾电般射向$n的胸口",
      "force" => 190,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 45,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "天河倒泻"
    },
    %{
      "action" => "$N一式「天外飞仙」，$w突然从天而降，一片金光围掠$n全身",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 50,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "天外飞仙"
    }
  ]

  @impl true
  def id(), do: "tianyu-qijian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 25}

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
      "huan" => Kantele.Combat.Skills.Performs.TianyuQijian.Huan,
      "ju" => Kantele.Combat.Skills.Performs.TianyuQijian.Ju,
      "shan" => Kantele.Combat.Skills.Performs.TianyuQijian.Shan
    }
  end
end
