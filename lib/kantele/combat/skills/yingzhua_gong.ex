defmodule Kantele.Combat.Skills.YingzhuaGong do
  @moduledoc """
  武学实装「yingzhua-gong」（源 yingzhua-gong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yingzhua_gong/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N全身拔地而起，半空中一个筋斗，一式「苍鹰袭兔」，迅猛地抓向$n的$l",
      "force" => 100,
      "attack" => 20,
      "parry" => 15,
      "dodge" => 5,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N单腿直立，双臂平伸，一式「雄鹰展翅」，双爪一前一后拢向$n的$l",
      "force" => 120,
      "attack" => 40,
      "parry" => 22,
      "dodge" => 10,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N一式「拔翅横飞」，全身向斜里平飞，右腿一绷，双爪搭向$n的肩头",
      "force" => 150,
      "attack" => 50,
      "parry" => 28,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 60,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N双爪交错上举，使一式「迎风振翼」，一拔身，分别袭向$n左右腋空门",
      "force" => 180,
      "attack" => 55,
      "parry" => 35,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N全身滚动上前，一式「飞龙献爪」，右爪突出，鬼魅般抓向$n的胸口",
      "force" => 220,
      "attack" => 65,
      "parry" => 38,
      "dodge" => 20,
      "damage" => 45,
      "lvl" => 100,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N伏地滑行，一式「拨云瞻日」，上手袭向膻中大穴，下手反抓$n的裆部",
      "force" => 250,
      "attack" => 60,
      "parry" => 45,
      "dodge" => 25,
      "damage" => 50,
      "lvl" => 120,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N左右手掌爪互逆，一式「搏击长空」，无数道劲气破空而出，迅疾无比地击向$n",
      "force" => 280,
      "attack" => 75,
      "parry" => 52,
      "dodge" => 25,
      "damage" => 55,
      "lvl" => 140,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N腾空高飞三丈，一式「鹰扬万里」，天空中顿时显出一个巨灵爪影，缓缓罩向$n",
      "force" => 310,
      "attack" => 80,
      "parry" => 60,
      "dodge" => 40,
      "damage" => 60,
      "lvl" => 160,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "yingzhua-gong"

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

  @impl true
  def perform_list() do
    %{
      "chumo" => Kantele.Combat.Skills.Performs.YingzhuaGong.Chumo
    }
  end
end
