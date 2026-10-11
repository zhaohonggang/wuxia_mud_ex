defmodule Kantele.Combat.Skills.PiliShou do
  @moduledoc """
  武学实装「pili-shou」（源 pili-shou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/pili_shou/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一式「五指连心」，右掌直取$n的$l",
      "force" => 100,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "五指连心"
    },
    %{
      "action" => "$N大喝一声，一式「火上心头」，双掌掌力雄浑无比，连连拍向$n的$l",
      "force" => 130,
      "attack" => 0,
      "parry" => 15,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "火上心头"
    },
    %{
      "action" => "$N使一式「混元无际」，左掌虚出，右掌猛然跟进，直取$n的$l",
      "force" => 160,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 25,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "混元无际"
    },
    %{
      "action" => "$N两掌一分，一式「晴空霹雳」，隐隐带有风雷之势，向$n劈去",
      "force" => 180,
      "attack" => 0,
      "parry" => 30,
      "dodge" => 20,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "晴空霹雳"
    },
    %{
      "action" => "$N身形一转，使出一式「混元刀」，但见$N右掌犹如一把利刀直下，劈向$n",
      "force" => 210,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "混元刀"
    },
    %{
      "action" => "$N突然飞身而起，使出一式「霹雳雨」，双掌连连而出，犹如暴雨般拍向$n全身",
      "force" => 250,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 40,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "霹雳雨"
    },
    %{
      "action" => "$N使一式「晴空万里」，双掌一分，猛地劈向$n的$l",
      "force" => 290,
      "attack" => 0,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 55,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "晴空万里"
    },
    %{
      "action" => "$N一招「烈炎飞空」，双掌带着萧瑟的烈炎之气，拍向$n的$l",
      "force" => 330,
      "attack" => 0,
      "parry" => 35,
      "dodge" => 30,
      "damage" => 70,
      "lvl" => 150,
      "damage_type" => "瘀伤",
      "skill_name" => "烈炎飞空"
    },
    %{
      "action" => "$N身法陡然一变，使出一式「混阳式」，掌影千变万幻，令$n无法躲闪",
      "force" => 350,
      "attack" => 0,
      "parry" => 45,
      "dodge" => 40,
      "damage" => 80,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "混阳式"
    },
    %{
      "action" => "$N清啸一声，一式「雄心万里」，双掌挥舞，气势非凡，击向$n的$l",
      "force" => 380,
      "attack" => 0,
      "parry" => 50,
      "dodge" => 45,
      "damage" => 130,
      "lvl" => 180,
      "damage_type" => "瘀伤",
      "skill_name" => "雄心万里"
    }
  ]

  @impl true
  def id(), do: "pili-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 6, neili: 64}

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
      "hun" => Kantele.Combat.Skills.Performs.PiliShou.Hun
    }
  end
end
