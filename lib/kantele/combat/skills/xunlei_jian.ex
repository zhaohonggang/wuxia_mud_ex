defmodule Kantele.Combat.Skills.XunleiJian do
  @moduledoc """
  武学实装「xunlei-jian」（源 xunlei-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 15 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xunlei_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N剑尖向右，绕身一周，一式「仙人指路」，$w突然向$n的$l刺去，",
      "force" => 35,
      "attack" => 2,
      "parry" => -40,
      "dodge" => -40,
      "damage" => 3,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "仙人指路"
    },
    %{
      "action" => "$N使出一式「鹞子翻身」，身体凌空侧翻，一剑从身下刺出",
      "force" => 49,
      "attack" => 3,
      "parry" => -35,
      "dodge" => -35,
      "damage" => 4,
      "lvl" => 10,
      "damage_type" => "刺伤",
      "skill_name" => "鹞子翻身"
    },
    %{
      "action" => "$N左手剑指血指，右手$w使出一招「海底寻针」，由上至下猛向$n的$l劈刺",
      "force" => 57,
      "attack" => 5,
      "parry" => -23,
      "dodge" => -23,
      "damage" => 7,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "海底寻针"
    },
    %{
      "action" => "$N撤步缩身，$w按藏于臂下，一招「灵猿探洞」，快如闪电般刺向$n的$l",
      "force" => 63,
      "attack" => 9,
      "parry" => -18,
      "dodge" => -18,
      "damage" => 10,
      "lvl" => 30,
      "damage_type" => "刺伤",
      "skill_name" => "灵猿探洞"
    },
    %{
      "action" => "$N踏步向前，一式「拨草寻蛇」，手中长剑摆动，剑尖刺向$n的$l",
      "force" => 67,
      "attack" => 11,
      "parry" => -9,
      "dodge" => -9,
      "damage" => 12,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "拨草寻蛇"
    },
    %{
      "action" => "$N一招「斜插神枝」，身体背转，手中$w由右肩上方反手向下刺出",
      "force" => 79,
      "attack" => 13,
      "parry" => -5,
      "dodge" => -5,
      "damage" => 14,
      "lvl" => 50,
      "damage_type" => "劈伤",
      "skill_name" => "斜插神枝"
    },
    %{
      "action" => "$N一式「电闪雷动」，剑走中锋，气势威严，将$n笼罩于重重剑气之中",
      "force" => 87,
      "attack" => 15,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 16,
      "lvl" => 60,
      "damage_type" => "劈伤",
      "skill_name" => "电闪雷动"
    },
    %{
      "action" => "$N向前弯身，一招「夫子揖手」，$w忽然从身下刺出，快如流星闪电",
      "force" => 90,
      "attack" => 18,
      "parry" => 10,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 70,
      "damage_type" => "刺伤",
      "skill_name" => "夫子揖手"
    },
    %{
      "action" => "$N横握$w，左右晃动，一招「玉带缠腰」，剑气直逼$n的腰部要害",
      "force" => 105,
      "attack" => 20,
      "parry" => 14,
      "dodge" => 14,
      "damage" => 24,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "玉带缠腰"
    },
    %{
      "action" => "$N双手持剑，将$w当做刀使，一招「举火烧天」，由身后向$n的前上方劈去",
      "force" => 110,
      "attack" => 24,
      "parry" => 18,
      "dodge" => 18,
      "damage" => 28,
      "lvl" => 90,
      "damage_type" => "刺伤",
      "skill_name" => "举火烧天"
    },
    %{
      "action" => "$N侧身向$n，使出一招「败马斩蹄」，挥动手中$w，直劈$n的下三路",
      "force" => 120,
      "attack" => 26,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 30,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "败马斩蹄"
    },
    %{
      "action" => "$N手中$w由右自左，一招「玉女穿针」，$w突然反手刺向$n的$l",
      "force" => 135,
      "attack" => 30,
      "parry" => 24,
      "dodge" => 24,
      "damage" => 35,
      "lvl" => 110,
      "damage_type" => "刺伤",
      "skill_name" => "玉女穿针"
    },
    %{
      "action" => "$N跳步向前，剑尖上指，一招「灵猿登枝」，$w挑向$n的头部要害",
      "force" => 140,
      "attack" => 31,
      "parry" => 26,
      "dodge" => 26,
      "damage" => 36,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "灵猿登枝"
    },
    %{
      "action" => "$N一招「苏武挥鞭」，$w随身走，犹如一条白龙，将$n全身上下笼罩",
      "force" => 145,
      "attack" => 33,
      "parry" => 28,
      "dodge" => 28,
      "damage" => 38,
      "lvl" => 130,
      "damage_type" => "刺伤",
      "skill_name" => "苏武挥鞭"
    },
    %{
      "action" => "$N剑尖向下，一招「挑灯看剑」，$w忽然急转直上，剑气将$n的上身要害团团围住",
      "force" => 150,
      "attack" => 35,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 40,
      "lvl" => 140,
      "damage_type" => "刺伤",
      "skill_name" => "挑灯看剑"
    }
  ]

  @impl true
  def id(), do: "xunlei-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 45}

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
      "xun" => Kantele.Combat.Skills.Performs.XunleiJian.Xun
    }
  end
end
