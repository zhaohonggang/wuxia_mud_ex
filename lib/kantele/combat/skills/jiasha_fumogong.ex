defmodule Kantele.Combat.Skills.JiashaFumogong do
  @moduledoc """
  武学实装「jiasha-fumogong」（源 jiasha-fumogong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jiasha_fumogong/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左手虚按，右腿使一招「一步等天」，向$n的$l踢去",
      "force" => 70,
      "attack" => 30,
      "parry" => 99,
      "dodge" => 42,
      "damage" => 22,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "一步等天"
    },
    %{
      "action" => "$N左手虚出，右手使一招「袈裟拦雀」，向$n的$l袭去",
      "force" => 85,
      "attack" => 40,
      "parry" => 102,
      "dodge" => 81,
      "damage" => 42,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "袈裟拦雀"
    },
    %{
      "action" => "$N使一招「直冲拳」，左手回撤，有拳向$n的$l直击而去",
      "force" => 100,
      "attack" => 50,
      "parry" => 105,
      "dodge" => 88,
      "damage" => 44,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "直冲拳"
    },
    %{
      "action" => "$N忽地分开右手上左手下，一招「双风贯耳」，向$n的$l和面门打去",
      "force" => 125,
      "attack" => 30,
      "parry" => 119,
      "dodge" => 86,
      "damage" => 45,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "双风贯耳"
    },
    %{
      "action" => "$N左手由胸前向下，右臂微曲，使一招「伏魔式」，向$n的$l推去",
      "force" => 150,
      "attack" => 56,
      "parry" => 115,
      "dodge" => 94,
      "damage" => 52,
      "lvl" => 180,
      "damage_type" => "瘀伤",
      "skill_name" => "伏魔式"
    },
    %{
      "action" => "$N双手回收，一式「反云手」，向$n的$l推去",
      "force" => 185,
      "attack" => 54,
      "parry" => 122,
      "dodge" => 102,
      "damage" => 83,
      "lvl" => 200,
      "damage_type" => "瘀伤",
      "skill_name" => "反云手"
    },
    %{
      "action" => "$N身体向后腾出，左手略直，右臂微曲，使一招「镇魔拳」，向$n的$l和面门打去",
      "force" => 215,
      "attack" => 70,
      "parry" => 0,
      "dodge" => 132,
      "damage" => 82,
      "lvl" => 220,
      "damage_type" => "瘀伤",
      "skill_name" => "镇魔拳"
    },
    %{
      "action" => "$N双手伸开，招「镇魂式」，将$n浑身上下都笼罩在重重掌影之中",
      "force" => 260,
      "attack" => 81,
      "parry" => 145,
      "dodge" => 154,
      "damage" => 92,
      "lvl" => 230,
      "damage_type" => "瘀伤",
      "skill_name" => "镇魂式"
    },
    %{
      "action" => "$N双手握拳，左手猛地向前推出，一招「荡魔式」，直奔$n心窝而去",
      "force" => 285,
      "attack" => 90,
      "parry" => 175,
      "dodge" => 166,
      "damage" => 100,
      "lvl" => 240,
      "damage_type" => "瘀伤",
      "skill_name" => "荡魔式"
    },
    %{
      "action" => "$N飞身而起，半空中双拳翻滚而出，一招「降妖伏魔」，一股劲风直逼$n",
      "force" => 340,
      "attack" => 120,
      "parry" => 185,
      "dodge" => 178,
      "damage" => 120,
      "lvl" => 250,
      "damage_type" => "瘀伤",
      "skill_name" => "降妖伏魔"
    }
  ]

  @impl true
  def id(), do: "jiasha-fumogong"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 59}

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
      "zhe" => Kantele.Combat.Skills.Performs.JiashaFumogong.Zhe
    }
  end
end
