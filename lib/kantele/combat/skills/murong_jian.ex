defmodule Kantele.Combat.Skills.MurongJian do
  @moduledoc """
  武学实装「murong-jian」（源 murong-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/murong_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N向前跨上一步，一招「横扫千军」，手中$w自左向右横斩$n的$l",
      "force" => 120,
      "attack" => 55,
      "parry" => 0,
      "dodge" => 70,
      "damage" => 70,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "横扫千军"
    },
    %{
      "action" => "$N左手剑诀，右手一抖，$w剑芒闪耀，一式「千钧一发」直劈$n的$l",
      "force" => 180,
      "attack" => 69,
      "parry" => 0,
      "dodge" => 85,
      "damage" => 115,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "千钧一发"
    },
    %{
      "action" => "$N一招「万马奔腾」，$w闪起无数道寒光，罩住$n的$l",
      "force" => 210,
      "attack" => 97,
      "parry" => 0,
      "dodge" => 100,
      "damage" => 150,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "万马奔腾"
    },
    %{
      "action" => "$N一招「气吞万里」，手中$w似扫似劈，琢磨不定的攻向$n的$l",
      "force" => 250,
      "attack" => 145,
      "parry" => 0,
      "dodge" => 125,
      "damage" => 170,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "气吞万里"
    },
    %{
      "action" => "$N使出「阳关三叠」，$w挽出三个剑花，源源不断划向$n的$l",
      "force" => 260,
      "attack" => 152,
      "parry" => 0,
      "dodge" => 120,
      "damage" => 180,
      "lvl" => 110,
      "damage_type" => "刺伤",
      "skill_name" => "阳关三叠"
    },
    %{
      "action" => "$N一招「一夫当关」，右手$w大开大合，自上而下如雷霆万钧般",
      "force" => 280,
      "attack" => 158,
      "parry" => 0,
      "dodge" => 165,
      "damage" => 165,
      "lvl" => 130,
      "damage_type" => "刺伤",
      "skill_name" => "一夫当关"
    },
    %{
      "action" => "$N一招「沙场点兵」，手中的$w指指戳戳，剑光登时笼罩了$n",
      "force" => 300,
      "attack" => 163,
      "parry" => 0,
      "dodge" => 170,
      "damage" => 185,
      "lvl" => 140,
      "damage_type" => "刺伤",
      "skill_name" => "沙场点兵"
    },
    %{
      "action" => "$N身影急动, 一招「逐鹿中原」，手中的$w去势快得异常，疾刺$n的$l",
      "force" => 330,
      "attack" => 220,
      "parry" => 0,
      "dodge" => 185,
      "damage" => 189,
      "lvl" => 160,
      "damage_type" => "刺伤",
      "skill_name" => "逐鹿中原"
    }
  ]

  @impl true
  def id(), do: "murong-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 38, neili: 33}

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
      "xing" => Kantele.Combat.Skills.Performs.MurongJian.Xing
    }
  end
end
