defmodule Kantele.Combat.Skills.JinwuGoufa do
  @moduledoc """
  武学实装「jinwu-goufa」（源 jinwu-goufa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jinwu_goufa/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w一抖，一式「灵蛇吐信」，闪电般的疾刺向$n的$l",
      "force" => 50,
      "attack" => 15,
      "parry" => 25,
      "dodge" => 10,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N身形突闪，招式陡变，手中$w从一个绝想不到的方位斜刺向$n的$l",
      "force" => 93,
      "attack" => 25,
      "parry" => 30,
      "dodge" => 25,
      "damage" => 5,
      "lvl" => 10,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N一式「柔丝轻系」，剑意绵绵不绝，化做一张无形的大网将$n困在当中",
      "force" => 135,
      "attack" => 33,
      "parry" => 32,
      "dodge" => 22,
      "damage" => 20,
      "lvl" => 20,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N一声阴笑，飞身纵起，一式「张牙舞爪」，手中$w狂舞，幻出千万条手臂，合身扑向$n",
      "force" => 189,
      "attack" => 39,
      "parry" => 35,
      "dodge" => 40,
      "damage" => 35,
      "lvl" => 30,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N身形一旋看似欲走，手中$w却倏的从腋下穿过，疾刺向$n的$l，好一式「天蝎藏针」",
      "force" => 221,
      "attack" => 43,
      "parry" => 40,
      "dodge" => 60,
      "damage" => 48,
      "lvl" => 40,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N脚步踉跄，身形忽的向前跌倒，一式「井底望月」，掌中$w自下而上直刺$n的小腹",
      "force" => 263,
      "attack" => 51,
      "parry" => 45,
      "dodge" => 50,
      "damage" => 63,
      "lvl" => 70,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N身形一晃，一式「金蛇缠腕」，手中$w如附骨之蛆般无声无息地刺向$n的手腕",
      "force" => 285,
      "attack" => 62,
      "parry" => 47,
      "dodge" => 40,
      "damage" => 87,
      "lvl" => 100,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N一声厉啸，身形冲天而起，一式「神蟾九变」，掌中$w如鬼魅般连刺$n全身九道大穴",
      "force" => 291,
      "attack" => 71,
      "parry" => 52,
      "dodge" => 30,
      "damage" => 91,
      "lvl" => 110,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N缓缓低首，手中$w中宫直进，一式「蜈化龙形」，迅捷无比地往$n的$l刺去",
      "force" => 313,
      "attack" => 85,
      "parry" => 54,
      "dodge" => 20,
      "damage" => 95,
      "lvl" => 130,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N深吸一口起，招演「万毒至尊」，$w尖端透出一条强劲的黑气，闪电般的袭向$n",
      "force" => 328,
      "attack" => 88,
      "parry" => 62,
      "dodge" => 30,
      "damage" => 117,
      "lvl" => 160,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "jinwu-goufa"

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
end
