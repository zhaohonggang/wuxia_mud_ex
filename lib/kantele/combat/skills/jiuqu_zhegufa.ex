defmodule Kantele.Combat.Skills.JiuquZhegufa do
  @moduledoc """
  武学实装「jiuqu-zhegufa」（源 jiuqu-zhegufa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jiuqu_zhegufa/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一声冷哼，以掌化爪，五指如钩，直逼$n的膻中要穴",
      "force" => 130,
      "attack" => 65,
      "parry" => 40,
      "dodge" => 5,
      "damage" => 85,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手虚晃，右手上下直击，反扣$n的肩井大穴",
      "force" => 160,
      "attack" => 72,
      "parry" => 42,
      "dodge" => 10,
      "damage" => 92,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一矮身，掌指齐出，拍拿并施，拿向$n的三路要害",
      "force" => 180,
      "attack" => 81,
      "parry" => 45,
      "dodge" => 15,
      "damage" => 130,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手鹰抓，右手蛇举，身形微微晃动，双手疾扣$n的中节大脉",
      "force" => 230,
      "attack" => 85,
      "parry" => 46,
      "dodge" => 20,
      "damage" => 140,
      "lvl" => 90,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N上前一步，四面八方出现无数掌影，一爪突出，抓向$n的胸口",
      "force" => 240,
      "attack" => 93,
      "parry" => 54,
      "dodge" => 25,
      "damage" => 150,
      "lvl" => 120,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N大喝一声，两手环扣，全身关节啪啪作响，击向$n的$l",
      "force" => 270,
      "attack" => 98,
      "parry" => 58,
      "dodge" => 30,
      "damage" => 160,
      "lvl" => 150,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N身形一展，十指齐伸，遮天蔽日般地笼罩$n的全身要穴",
      "force" => 330,
      "attack" => 101,
      "parry" => 62,
      "dodge" => 35,
      "damage" => 170,
      "lvl" => 180,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N岳立霆峙，在一阵暴雷声中，双手同时拍向$n的全身各处",
      "force" => 380,
      "attack" => 127,
      "parry" => 65,
      "dodge" => 50,
      "damage" => 180,
      "lvl" => 210,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "jiuqu-zhegufa"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 100, neili: 100}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
