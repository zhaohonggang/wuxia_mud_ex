defmodule Kantele.Combat.Skills.XiaoyaoJian do
  @moduledoc """
  武学实装「xiaoyao-jian」（源 xiaoyao-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 12 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xiaoyao_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「落叶飘飘」，$w似幻作无数道银索，四面八方的罩向$n",
      "force" => 110,
      "attack" => 35,
      "parry" => -25,
      "dodge" => -20,
      "damage" => 43,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "落叶飘飘"
    },
    %{
      "action" => "$N一招「水中浮萍」，剑锋乱指，攻向$n，$n根本不能分辩$w的来路",
      "force" => 155,
      "attack" => 43,
      "parry" => -34,
      "dodge" => -25,
      "damage" => 51,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "中浮萍"
    },
    %{
      "action" => "$N使出「飘然直去」，$w幻一条飞练，带着一股寒气划向$n的$l",
      "force" => 178,
      "attack" => 48,
      "parry" => -24,
      "dodge" => -28,
      "damage" => 62,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "飘然直去"
    },
    %{
      "action" => "$N身子向上弹起，左手下指，一招「千里不留行」，右手$w带着一团剑花，逼向$n的$l",
      "force" => 211,
      "attack" => 53,
      "parry" => -24,
      "dodge" => -22,
      "damage" => 84,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "千里不留行"
    },
    %{
      "action" => "$N一招「拂衣抹剑」，左脚跃步落地，右手$w幻成一条雪白的瀑布，扫向$n的$l",
      "force" => 238,
      "attack" => 69,
      "parry" => -35,
      "dodge" => -28,
      "damage" => 95,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "拂衣抹剑"
    },
    %{
      "action" => "$N右腿半屈般蹲，$w平指，一招「仙人何去」，剑尖无声无色的慢慢的刺向$n的$l",
      "force" => 268,
      "attack" => 73,
      "parry" => -15,
      "dodge" => -38,
      "damage" => 110,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "仙人何去"
    },
    %{
      "action" => "$N一招「梦里看剑」，剑锋乱指，攻向$n，$n根本不能分辩$w的来路",
      "force" => 255,
      "attack" => 71,
      "parry" => -24,
      "dodge" => -25,
      "damage" => 108,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "梦里看剑"
    },
    %{
      "action" => "$N使出「深山空谷」，$w幻一条飞练，带着一股寒气划向$n的$l",
      "force" => 270,
      "attack" => 78,
      "parry" => -19,
      "dodge" => -18,
      "damage" => 123,
      "lvl" => 140,
      "damage_type" => "刺伤",
      "skill_name" => "深山空谷"
    },
    %{
      "action" => "$N身子向上弹起，左手下指，一招「群仙聚会」，右手$w带着一团剑花，逼向$n的$l",
      "force" => 291,
      "attack" => 103,
      "parry" => -28,
      "dodge" => -23,
      "damage" => 141,
      "lvl" => 160,
      "damage_type" => "刺伤",
      "skill_name" => "群仙聚会"
    },
    %{
      "action" => "$N一招「飘飘不定」，左脚跃步落地，右手$w幻成一条雪白的瀑布，扫向$n的$l",
      "force" => 283,
      "attack" => 91,
      "parry" => -25,
      "dodge" => -22,
      "damage" => 155,
      "lvl" => 180,
      "damage_type" => "刺伤",
      "skill_name" => "飘飘不定"
    },
    %{
      "action" => "$N右腿半屈般蹲，$w平指，一招「千山万水」，剑尖无声无色的慢慢的刺向$n的$l",
      "force" => 300,
      "attack" => 97,
      "parry" => -37,
      "dodge" => -28,
      "damage" => 158,
      "lvl" => 200,
      "damage_type" => "刺伤",
      "skill_name" => "千山万水"
    },
    %{
      "action" => "$N一招「去留人间」，$w在$n的周身飞舞，令$n眼花缭乱，剑身在半空中突然停住刺向$n的$l",
      "force" => 328,
      "attack" => 118,
      "parry" => -27,
      "dodge" => -25,
      "damage" => 170,
      "lvl" => 220,
      "damage_type" => "刺伤",
      "skill_name" => "去留人间"
    }
  ]

  @impl true
  def id(), do: "xiaoyao-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 0, neili: 82}

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
