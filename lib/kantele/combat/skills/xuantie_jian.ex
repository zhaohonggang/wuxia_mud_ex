defmodule Kantele.Combat.Skills.XuantieJian do
  @moduledoc """
  武学实装「xuantie-jian」（源 xuantie-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xuantie_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中的$w荡出，就如大江东去，威力势不可挡",
      "force" => 250,
      "attack" => 170,
      "parry" => 70,
      "dodge" => 30,
      "damage" => 230,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N踏上一步，手中$w舞出一道剑光劈向$n的$l",
      "force" => 310,
      "attack" => 280,
      "parry" => 79,
      "dodge" => 33,
      "damage" => 224,
      "lvl" => 40,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w一抖，一剑刺出，攻向$n的$l，没有半点花巧",
      "force" => 330,
      "attack" => 290,
      "parry" => 85,
      "dodge" => 41,
      "damage" => 235,
      "lvl" => 80,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w微微颤动，忽然刺出，一道剑光射向$n的$l",
      "force" => 360,
      "attack" => 295,
      "parry" => 92,
      "dodge" => 45,
      "damage" => 239,
      "lvl" => 120,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N横过$w，蓦然横扫$n，气势如虹，荡气回肠",
      "force" => 340,
      "attack" => 297,
      "parry" => 99,
      "dodge" => 47,
      "damage" => 248,
      "lvl" => 160,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中的$w连削带刺，夹带着一阵旋风掠过$n全身",
      "force" => 380,
      "attack" => 300,
      "parry" => 100,
      "dodge" => 50,
      "damage" => 300,
      "lvl" => 200,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "xuantie-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 70}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
