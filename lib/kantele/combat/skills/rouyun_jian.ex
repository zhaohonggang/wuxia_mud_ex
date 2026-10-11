defmodule Kantele.Combat.Skills.RouyunJian do
  @moduledoc """
  武学实装「rouyun-jian」（源 rouyun-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 11 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/rouyun_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N面露微笑，手中$w一抖，一招「杏花春雨」，剑光顿时暴长，洒向$n的$l",
      "force" => 50,
      "attack" => 15,
      "parry" => 25,
      "dodge" => 10,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "杏花春雨"
    },
    %{
      "action" => "$N身形突闪，剑招陡变，手中$w从一个绝想不到的方位斜刺向$n的$l",
      "force" => 70,
      "attack" => 25,
      "parry" => 30,
      "dodge" => 25,
      "damage" => 5,
      "lvl" => 10,
      "damage_type" => "刺伤",
      "skill_name" => "春云乍展"
    },
    %{
      "action" => "$N暴退数尺，低首抚剑，随后手中$w骤然穿上，正是一招「朝天一柱香」，刺向$n",
      "force" => 75,
      "attack" => 33,
      "parry" => 32,
      "dodge" => 22,
      "damage" => 20,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "朝天一柱香"
    },
    %{
      "action" => "$N身形一晃，疾掠而上，一招「白云苍狗」，手中$w龙吟一声，对准$n的$l连递数剑",
      "force" => 90,
      "attack" => 39,
      "parry" => 35,
      "dodge" => 40,
      "damage" => 25,
      "lvl" => 30,
      "damage_type" => "刺伤",
      "skill_name" => "白云苍狗"
    },
    %{
      "action" => "$N神色微变，一招「满天花雨」，剑招顿时变得凌厉无比，手中$w如匹链般洒向$n的$l",
      "force" => 180,
      "attack" => 71,
      "parry" => 52,
      "dodge" => 30,
      "damage" => 40,
      "lvl" => 70,
      "damage_type" => "刺伤",
      "skill_name" => "满天花雨"
    },
    %{
      "action" => "$N缓缓低首，接着一招「秋风袭人」，手中$w中宫直进，迅捷无比地往$n的$l刺去",
      "force" => 200,
      "attack" => 85,
      "parry" => 54,
      "dodge" => 20,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "秋风袭人"
    },
    %{
      "action" => "$N矮身侧步，一招「寒月当空照」，手中$w反手疾挑而出，“唰”的一声往$n的$l刺去",
      "force" => 240,
      "attack" => 91,
      "parry" => 65,
      "dodge" => 65,
      "damage" => 58,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "寒月当空照"
    },
    %{
      "action" => "$N蓦地疾退一步，又冲前三步，一招「辰星点缀」，手中$w化为一道弧光往$n的$l刺去",
      "force" => 265,
      "attack" => 93,
      "parry" => 68,
      "dodge" => 40,
      "damage" => 72,
      "lvl" => 110,
      "damage_type" => "刺伤",
      "skill_name" => "辰星点缀"
    },
    %{
      "action" => "$N纵身跃起，一招「云涌四方」，不见踪影，接着却又从半空中穿下，$w直逼$n的$l",
      "force" => 290,
      "attack" => 97,
      "parry" => 72,
      "dodge" => 60,
      "damage" => 78,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "云涌四方"
    },
    %{
      "action" => "$N一招「银河横空」，手中$w遥指苍空，猛然划出一道剑芒，往$n的$l刺去",
      "force" => 310,
      "attack" => 100,
      "parry" => 75,
      "dodge" => 45,
      "damage" => 86,
      "lvl" => 130,
      "damage_type" => "刺伤",
      "skill_name" => "银河横空"
    },
    %{
      "action" => "$N一招「天外来云」，左手虚击，右手$w猛的自下方挑起，激起一股劲风反挑$n的$l",
      "force" => 330,
      "attack" => 105,
      "parry" => 82,
      "dodge" => 50,
      "damage" => 95,
      "lvl" => 140,
      "damage_type" => "刺伤",
      "skill_name" => "天外来云"
    }
  ]

  @impl true
  def id(), do: "rouyun-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 0, neili: 62}

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
      "tao" => Kantele.Combat.Skills.Performs.RouyunJian.Tao
    }
  end
end
