defmodule Kantele.Combat.Skills.LiuyueJian do
  @moduledoc """
  武学实装「liuyue-jian」（源 liuyue-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/liuyue_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N向前斜跨一步，一招「剑气封喉」，手中$w直刺$n的喉部",
      "force" => 126,
      "attack" => 0,
      "parry" => 3,
      "dodge" => 5,
      "damage" => 21,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "剑气封喉"
    },
    %{
      "action" => "$N错步上前，一招「明月千里」，剑意若有若无，$w淡淡地向$n的$l挥去",
      "force" => 149,
      "attack" => 0,
      "parry" => 13,
      "dodge" => 10,
      "damage" => 25,
      "lvl" => 30,
      "damage_type" => "割伤",
      "skill_name" => "明月千里"
    },
    %{
      "action" => "$N一式「怀中抱月」，纵身飘开数尺，运发剑气，手中$w遥摇指向$n的$l",
      "force" => 167,
      "attack" => 0,
      "parry" => 12,
      "dodge" => 15,
      "damage" => 31,
      "lvl" => 50,
      "damage_type" => "刺伤",
      "skill_name" => "怀中抱月"
    },
    %{
      "action" => "$N纵身轻轻跃起，一式「大风起兮」，剑光如水，一泻千里，洒向$n全身",
      "force" => 187,
      "attack" => 0,
      "parry" => 23,
      "dodge" => 19,
      "damage" => 45,
      "lvl" => 70,
      "damage_type" => "割伤",
      "skill_name" => "大风起兮"
    },
    %{
      "action" => "$N错步上前，一招「明月千里」，剑意若有若无，$w淡淡地向$n的$l挥去",
      "force" => 197,
      "attack" => 0,
      "parry" => 31,
      "dodge" => 27,
      "damage" => 56,
      "lvl" => 90,
      "damage_type" => "割伤",
      "skill_name" => "明月千里"
    },
    %{
      "action" => "$N手中$w中宫直进，一式「定天一针」，无声无息地对准$n的$l刺出一剑",
      "force" => 218,
      "attack" => 0,
      "parry" => 49,
      "dodge" => 35,
      "damage" => 63,
      "lvl" => 110,
      "damage_type" => "刺伤",
      "skill_name" => "定天一针"
    },
    %{
      "action" => "$N手中$w一沉，一式「星归月向」，无声无息地滑向$n的$l",
      "force" => 239,
      "attack" => 0,
      "parry" => 52,
      "dodge" => 45,
      "damage" => 72,
      "lvl" => 130,
      "damage_type" => "刺伤",
      "skill_name" => "星归月向"
    },
    %{
      "action" => "$N手中$w斜指苍天，剑芒吞吐，一式「映月无声」，对准$n的$l斜斜击出",
      "force" => 257,
      "attack" => 0,
      "parry" => 55,
      "dodge" => 51,
      "damage" => 88,
      "lvl" => 150,
      "damage_type" => "刺伤",
      "skill_name" => "映月无声"
    },
    %{
      "action" => "$N左指凌空虚点，右手$w逼出丈许雪亮剑芒，一式「情连航慈」刺向$n的咽喉",
      "force" => 282,
      "attack" => 0,
      "parry" => 63,
      "dodge" => 55,
      "damage" => 105,
      "lvl" => 170,
      "damage_type" => "刺伤",
      "skill_name" => "情连航慈"
    },
    %{
      "action" => "$N合掌跌坐，一式「影玉徵辉」，$w自怀中跃出，如疾电般射向$n的胸口",
      "force" => 331,
      "attack" => 0,
      "parry" => 76,
      "dodge" => 65,
      "damage" => 122,
      "lvl" => 190,
      "damage_type" => "刺伤",
      "skill_name" => "影玉徵辉"
    }
  ]

  @impl true
  def id(), do: "liuyue-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 60}

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
      "liu" => Kantele.Combat.Skills.Performs.LiuyueJian.Liu,
      "sheng" => Kantele.Combat.Skills.Performs.LiuyueJian.Sheng
    }
  end
end
