defmodule Kantele.Combat.Skills.YujianShu do
  @moduledoc """
  武学实装「yujian-shu」（源 yujian-shu.c，由 translate_skill.exs 生成）

  已自动化：静态招式 9 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yujian_shu/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N剑势忽缓而不疏，剑意有余而不尽，化数剑为一剑，向$n慢慢推去",
      "force" => 20,
      "attack" => 65,
      "parry" => 60,
      "dodge" => 65,
      "damage" => 25,
      "lvl" => 21,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N剑意突焕气象森严，便似千军万马奔驰而来，剑势击向$n",
      "force" => 20,
      "attack" => 70,
      "parry" => 65,
      "dodge" => 60,
      "damage" => 30,
      "lvl" => 28,
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
    }
  ]

  @impl true
  def id(), do: "yujian-shu"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
