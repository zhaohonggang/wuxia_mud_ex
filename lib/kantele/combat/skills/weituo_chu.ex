defmodule Kantele.Combat.Skills.WeituoChu do
  @moduledoc """
  武学实装「weituo-chu」（源 weituo-chu.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/weituo_chu/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N跃在半空，一招「仙鹤展翅入灵山」，手中$w已化成无数棍影，令$n眼花缭乱，不知所措，连连倒退",
      "force" => 150,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 20,
      "damage_type" => "挫伤",
      "skill_name" => "仙鹤展翅入灵山"
    },
    %{
      "action" => "$N挺$w将$n的$W架住，顺势一招「玉马衔环拜仙宫」，$w上下左右飞快搅动，身随棍走，向$n压了下来",
      "force" => 180,
      "attack" => 0,
      "parry" => 15,
      "dodge" => 10,
      "damage" => 100,
      "lvl" => 40,
      "damage_type" => "挫伤",
      "skill_name" => "玉马衔环拜仙宫"
    },
    %{
      "action" => "$N一招「鸣鹿踏蹄觅仙草」，屈膝俯身，手中$w连点$n下盘，却未等招数用老，猛的一提，向$n的胸腹间戳去",
      "force" => 220,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 15,
      "damage" => 40,
      "lvl" => 60,
      "damage_type" => "挫伤",
      "skill_name" => "鸣鹿踏蹄觅仙草"
    },
    %{
      "action" => "$N突然滚到在地，$n错愕间，一招「金鲤跃水潜天池」，竟从$n的裆下窜过，更不回头，$w反手扫向$n的$l",
      "force" => 200,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 60,
      "lvl" => 80,
      "damage_type" => "挫伤",
      "skill_name" => "金鲤跃水潜天池"
    },
    %{
      "action" => "$N一招「灵猿献果赴蓬莱」，身形如电，绕着$n飞快奔跑，手中$w一招快似一招，刹那间向$n连打出十六棍",
      "force" => 280,
      "attack" => 0,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 80,
      "lvl" => 100,
      "damage_type" => "挫伤",
      "skill_name" => "灵猿献果赴蓬莱"
    },
    %{
      "action" => "$N大踏步上前，劲贯双臂，手中$w大开大阖，呼呼风声中一招「飞鹰盘旋扫乾坤」扫向$n的腰间",
      "force" => 220,
      "attack" => 0,
      "parry" => 40,
      "dodge" => 30,
      "damage" => 100,
      "lvl" => 120,
      "damage_type" => "挫伤",
      "skill_name" => "飞鹰盘旋扫乾坤"
    },
    %{
      "action" => "$N大喝一声，一招「天龙出水腾宇宙」，$w脱手飞出，夹着劲风射向$n的前心，随即抢到$n的身后，伸手又把$w抄在手中",
      "force" => 230,
      "attack" => 0,
      "parry" => 30,
      "dodge" => 20,
      "damage" => 80,
      "lvl" => 130,
      "damage_type" => "挫伤",
      "skill_name" => "天龙出水腾宇宙"
    },
    %{
      "action" => "$N双目圆睁，口中默诵真言，一招「白象卷云憾天柱」，$w似有千斤，缓缓举起，又缓缓向$n的当头砸落",
      "force" => 300,
      "attack" => 0,
      "parry" => 30,
      "dodge" => 20,
      "damage" => 100,
      "lvl" => 150,
      "damage_type" => "挫伤",
      "skill_name" => "白象卷云憾天柱"
    }
  ]

  @impl true
  def id(), do: "weituo-chu"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "staff"]

  @impl true
  def practice_cost(), do: %{qi: 0, neili: 20}

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
      "jishi" => Kantele.Combat.Skills.Performs.WeituoChu.Jishi
    }
  end
end
