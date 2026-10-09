defmodule Kantele.Combat.Skills.DulongShenzhua do
  @moduledoc """
  武学实装「dulong-shenzhua」（源 dulong-shenzhua.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/dulong_shenzhua/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N全身骨骼暴响，一式「天邪爪」，迅猛地抓向$n的$l",
      "force" => 100,
      "attack" => 20,
      "parry" => 15,
      "dodge" => 5,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N单腿直立，双臂平伸，一式「蛟龙爪」，双爪一前一后拢向$n的$l",
      "force" => 120,
      "attack" => 40,
      "parry" => 22,
      "dodge" => 10,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N一式「毒龙爪」，全身向斜里平飞，右腿一绷，双爪搭向$n的肩头",
      "force" => 150,
      "attack" => 50,
      "parry" => 28,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 60,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N双爪翻腾而出，使一式「双龙戏」，分别袭向$n左右腋空门",
      "force" => 180,
      "attack" => 55,
      "parry" => 35,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N飞身而起，一式「飞龙爪」，自天而下，抓向$n的胸口",
      "force" => 220,
      "attack" => 65,
      "parry" => 38,
      "dodge" => 20,
      "damage" => 45,
      "lvl" => 100,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N一式「地蛇爪」，上手袭向膻中大穴，下手反抓$n的裆部",
      "force" => 250,
      "attack" => 60,
      "parry" => 45,
      "dodge" => 25,
      "damage" => 60,
      "lvl" => 120,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N左右手掌爪齐出，一式「划长空」，双爪划空而过，抓向$n",
      "force" => 290,
      "attack" => 75,
      "parry" => 52,
      "dodge" => 25,
      "damage" => 85,
      "lvl" => 140,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N腾空而起，一式「万里神爪」，天空中顿时显出一个巨灵爪影，罩向$n",
      "force" => 320,
      "attack" => 80,
      "parry" => 60,
      "dodge" => 40,
      "damage" => 80,
      "lvl" => 160,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "dulong-shenzhua"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 67}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
