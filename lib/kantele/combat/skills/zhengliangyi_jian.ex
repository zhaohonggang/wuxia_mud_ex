defmodule Kantele.Combat.Skills.ZhengliangyiJian do
  @moduledoc """
  武学实装「zhengliangyi-jian」（源 zhengliangyi-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 12 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/zhengliangyi_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一式「顺水推舟」，$N手中$w指向自己左胸口，剑柄斜斜向右外，缓缓划向$n的$l",
      "force" => 85,
      "attack" => 31,
      "parry" => 35,
      "dodge" => 35,
      "damage" => 23,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "顺水推舟"
    },
    %{
      "action" => "$N身形微侧，左手后摆，右手$w一招「横扫千军」，直向$n的腰间挥去",
      "force" => 109,
      "attack" => 33,
      "parry" => 43,
      "dodge" => 41,
      "damage" => 24,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "横扫千军"
    },
    %{
      "action" => "$N纵身近前，$w斗然弯弯弹出，剑光爆长，一招「峭壁断云」，猛地刺向$n的胸口",
      "force" => 121,
      "attack" => 35,
      "parry" => 45,
      "dodge" => 43,
      "damage" => 27,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "峭壁断云"
    },
    %{
      "action" => "$N左手捏个剑决，平推而出，决指上仰，右手剑朝天不动，一招「仙人指路」，刺向$n",
      "force" => 135,
      "attack" => 37,
      "parry" => 47,
      "dodge" => 48,
      "damage" => 31,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "仙人指路"
    },
    %{
      "action" => "$N剑招忽变，使出一招「雨打飞花」，全走斜势，但七八招斜势中偶尔又挟着一招正势，教人极难捉摸",
      "force" => 143,
      "attack" => 41,
      "parry" => 59,
      "dodge" => 57,
      "damage" => 32,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "雨打飞花"
    },
    %{
      "action" => "$N手中$w剑刃竖起，锋口向下，一招「大漠平沙」，剑走刀势，劈向$n的$l",
      "force" => 153,
      "attack" => 43,
      "parry" => 68,
      "dodge" => 63,
      "damage" => 34,
      "lvl" => 100,
      "damage_type" => "劈伤",
      "skill_name" => "大漠平沙"
    },
    %{
      "action" => "$N一招「木叶萧萧」，$N横提$w，剑尖斜指向天，由上而下，劈向$n的$l",
      "force" => 167,
      "attack" => 45,
      "parry" => 71,
      "dodge" => 69,
      "damage" => 36,
      "lvl" => 120,
      "damage_type" => "劈伤",
      "skill_name" => "木叶萧萧"
    },
    %{
      "action" => "$N抢前一步，$w微微抖动，剑光点点，一招「江河不竭」，终而复始，绵绵不绝刺向$n",
      "force" => 185,
      "attack" => 48,
      "parry" => 78,
      "dodge" => 73,
      "damage" => 37,
      "lvl" => 140,
      "damage_type" => "刺伤",
      "skill_name" => "江河不竭"
    },
    %{
      "action" => "$N左手剑鞘一举，快逾电光石光，一招「高塔挂云」，用剑鞘套住$n手中兵器，$w直指$n的咽喉",
      "force" => 205,
      "attack" => 49,
      "parry" => 85,
      "dodge" => 78,
      "damage" => 38,
      "lvl" => 160,
      "damage_type" => "刺伤",
      "skill_name" => "高塔挂云"
    },
    %{
      "action" => "$N翻身回剑，剑诀斜引，一招「百丈飞瀑」，剑锋从半空中直泻下来，罩住$n上方",
      "force" => 243,
      "attack" => 51,
      "parry" => 91,
      "dodge" => 82,
      "damage" => 39,
      "lvl" => 180,
      "damage_type" => "刺伤",
      "skill_name" => "百丈飞瀑"
    },
    %{
      "action" => "$N一式「雪拥蓝桥」，$N手中剑花团团，一条白练疾风般向卷向$n",
      "force" => 271,
      "attack" => 53,
      "parry" => 95,
      "dodge" => 87,
      "damage" => 41,
      "lvl" => 200,
      "damage_type" => "刺伤",
      "skill_name" => "雪拥蓝桥"
    },
    %{
      "action" => "$N腾空而起，突然使出一招「悄然无声」，悄无声息地疾向$n的背部刺去",
      "force" => 285,
      "attack" => 57,
      "parry" => 107,
      "dodge" => 95,
      "damage" => 43,
      "lvl" => 220,
      "damage_type" => "刺伤",
      "skill_name" => "悄然无声"
    }
  ]

  @impl true
  def id(), do: "zhengliangyi-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 75}

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
      "sui" => Kantele.Combat.Skills.Performs.ZhengliangyiJian.Sui,
      "wu" => Kantele.Combat.Skills.Performs.ZhengliangyiJian.Wu
    }
  end
end
