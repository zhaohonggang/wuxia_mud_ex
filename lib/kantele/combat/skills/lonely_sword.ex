defmodule Kantele.Combat.Skills.LonelySword do
  @moduledoc """
  武学实装「lonely-sword」（源 lonely-sword.c，由 translate_skill.exs 生成）

  已自动化：静态招式 24 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/lonely_sword/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "但见$N挺身而上，$w一旋，一招仿佛泰山剑法的「",
      "force" => 10,
      "attack" => 62,
      "parry" => 45,
      "dodge" => 45,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N奇诡地向$n挥出「",
      "force" => 10,
      "attack" => 65,
      "parry" => 45,
      "dodge" => 50,
      "damage" => 15,
      "lvl" => 7,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N剑随身转，续而刺出十九剑，竟然是华山「",
      "force" => 10,
      "attack" => 60,
      "parry" => 60,
      "dodge" => 65,
      "damage" => 20,
      "lvl" => 14,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N剑势忽缓而不疏，剑意有余而不尽，化恒山剑法为一剑，向$n慢慢推去",
      "force" => 20,
      "attack" => 65,
      "parry" => 60,
      "dodge" => 65,
      "damage" => 25,
      "lvl" => 21,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N剑意突焕气象森严，便似千军万马奔驰而来，长枪大戟，黄沙千里，尽括嵩山剑势击向$n",
      "force" => 20,
      "attack" => 70,
      "parry" => 65,
      "dodge" => 60,
      "damage" => 30,
      "lvl" => 28,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "却见$N身随剑走，左边一拐，右边一弯，剑招也是越转越加狠辣，竟化「",
      "force" => 30,
      "attack" => 73,
      "parry" => 65,
      "dodge" => 70,
      "damage" => 30,
      "lvl" => 35,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N剑招突变，使出衡山的「",
      "force" => 40,
      "attack" => 75,
      "parry" => 70,
      "dodge" => 75,
      "damage" => 40,
      "lvl" => 42,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N吐气开声，一招似是「",
      "force" => 50,
      "attack" => 72,
      "parry" => 70,
      "dodge" => 80,
      "damage" => 50,
      "lvl" => 49,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w越转越快，使的居然是衡山的「",
      "force" => 60,
      "attack" => 71,
      "parry" => 70,
      "dodge" => 80,
      "damage" => 60,
      "lvl" => 56,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N含笑抱剑，气势庄严，$w轻挥，尽融「",
      "force" => 70,
      "attack" => 80,
      "parry" => 65,
      "dodge" => 90,
      "damage" => 70,
      "lvl" => 63,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N举起$w运使「",
      "force" => 80,
      "attack" => 77,
      "parry" => 70,
      "dodge" => 90,
      "damage" => 80,
      "lvl" => 70,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N神声凝重，$w上劈下切左右横扫，挟雷霆万钧之势逼往$n，「",
      "force" => 90,
      "attack" => 70,
      "parry" => 70,
      "dodge" => 75,
      "damage" => 90,
      "lvl" => 77,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "却见$N突然虚步提腰，使出酷似武当「",
      "force" => 110,
      "attack" => 75,
      "parry" => 75,
      "dodge" => 90,
      "damage" => 100,
      "lvl" => 84,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N运剑如风，剑光霍霍中反攻$n的$l，尝试逼$n自守，剑招似是「",
      "force" => 120,
      "attack" => 80,
      "parry" => 85,
      "dodge" => 90,
      "damage" => 110,
      "lvl" => 91,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N突然运剑如狂，一手关外的「",
      "force" => 150,
      "attack" => 90,
      "parry" => 95,
      "dodge" => 70,
      "damage" => 120,
      "lvl" => 98,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N满场游走，东刺一剑，西刺一剑，令$n莫明其妙，分不出$N剑法的虚实",
      "force" => 180,
      "attack" => 100,
      "parry" => 105,
      "dodge" => 70,
      "damage" => 130,
      "lvl" => 105,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N抱剑旋身，转到$n身后，杂乱无章地向$n刺出一剑，不知使的是什么剑法",
      "force" => 210,
      "attack" => 110,
      "parry" => 95,
      "dodge" => 75,
      "damage" => 140,
      "lvl" => 112,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N突然一剑点向$n的$l，虽一剑却暗藏无数后着，$n手足无措，不知如何是好",
      "force" => 230,
      "attack" => 115,
      "parry" => 95,
      "dodge" => 90,
      "damage" => 150,
      "lvl" => 119,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N剑挟刀势，大开大阖地乱砍一通，但招招皆击在$n攻势的破绽，迫得$n不得不守",
      "force" => 250,
      "attack" => 120,
      "parry" => 95,
      "dodge" => 95,
      "damage" => 160,
      "lvl" => 126,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N反手横剑刺向$n的$l，这似有招似无招的一剑，威力竟然奇大，$n难以看清剑招来势",
      "force" => 270,
      "attack" => 125,
      "parry" => 95,
      "dodge" => 85,
      "damage" => 170,
      "lvl" => 133,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N举剑狂挥，迅速无比地点向$n的$l，却令人看不出其所用是什么招式",
      "force" => 300,
      "attack" => 130,
      "parry" => 80,
      "dodge" => 115,
      "damage" => 180,
      "lvl" => 140,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N随手一剑指向$n，落点正是$n的破绽所在，端的是神妙无伦，不可思议",
      "force" => 330,
      "attack" => 140,
      "parry" => 100,
      "dodge" => 95,
      "damage" => 190,
      "lvl" => 147,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N脸上突现笑容，似乎已看破$n的武功招式，胸有成竹地一剑刺向$n的$l",
      "force" => 350,
      "attack" => 150,
      "parry" => 100,
      "dodge" => 110,
      "damage" => 200,
      "lvl" => 154,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N将$w随手一摆，但见$n自己向$w撞将上来，神剑之威，实人所难测",
      "force" => 380,
      "attack" => 155,
      "parry" => 105,
      "dodge" => 115,
      "damage" => 230,
      "lvl" => 180,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "lonely-sword"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "jue" => Kantele.Combat.Skills.Performs.LonelySword.Jue,
      "po" => Kantele.Combat.Skills.Performs.LonelySword.Po,
      "yi" => Kantele.Combat.Skills.Performs.LonelySword.Yi
    }
  end
end
