defmodule Kantele.Combat.Skills.ShedaoQigong do
  @moduledoc """
  武学实装「shedao-qigong」（源 shedao-qigong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shedao_qigong/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「仙鹤梳翎」手中$w一提，插向$n的$l",
      "force" => 90,
      "attack" => 0,
      "parry" => 40,
      "dodge" => 0,
      "damage" => 25,
      "lvl" => 0,
      "damage_type" => "挫伤",
      "skill_name" => "仙鹤梳翎"
    },
    %{
      "action" => "$N使出「灵蛇出洞」，身形微弓，手中$w倏的向$n的$l戳去",
      "force" => 140,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 20,
      "damage" => 30,
      "lvl" => 30,
      "damage_type" => "刺伤",
      "skill_name" => "灵蛇出洞"
    },
    %{
      "action" => "$N身子微曲，左足反踢，乘势转身，使一招「贵妃回眸」，右手$w已戳向$n$l",
      "force" => 190,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 30,
      "damage" => 40,
      "lvl" => 70,
      "damage_type" => "刺伤",
      "skill_name" => "贵妃回眸"
    },
    %{
      "action" => "$N使一式「飞燕回翔」，背对着$n，右足一勾，顺势在$w上一点，$w陡然向自己咽喉疾射，接着$N身子往下一缩，$w掠过其咽喉，急奔$n急射而来",
      "force" => 230,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 45,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "飞燕回翔"
    },
    %{
      "action" => "$N忽的在地上一个筋斗，使一招「小怜横陈」，从$n胯下钻过，手中$w直击$n",
      "force" => 270,
      "attack" => 0,
      "parry" => 30,
      "dodge" => 40,
      "damage" => 55,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "小怜横陈"
    },
    %{
      "action" => "$N大吼一声，使一招「子胥举鼎」，反手擒拿$n极泉要穴，欲将$n摔倒在地",
      "force" => 330,
      "attack" => 0,
      "parry" => -10,
      "dodge" => 45,
      "damage" => 60,
      "lvl" => 140,
      "damage_type" => "内伤",
      "skill_name" => "子胥举鼎"
    },
    %{
      "action" => "$N双腿一缩，似欲跪拜，一招「鲁达拨柳」左手抓向$n右脚足踝，右手$w直击$n小腹",
      "force" => 370,
      "attack" => 0,
      "parry" => -10,
      "dodge" => 50,
      "damage" => 65,
      "lvl" => 160,
      "damage_type" => "内伤",
      "skill_name" => "鲁达拨柳"
    },
    %{
      "action" => "$N突然一个倒翻筋斗，一招「狄青降龙」，双腿一分，跨在肩头，双掌直击$n",
      "force" => 400,
      "attack" => 0,
      "parry" => 30,
      "dodge" => 70,
      "damage" => 75,
      "lvl" => 180,
      "damage_type" => "内伤",
      "skill_name" => "狄青降龙"
    }
  ]

  @impl true
  def id(), do: "shedao-qigong"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "staff", "sword", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 67}

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
