defmodule Kantele.Combat.Skills.WuyunJianfa do
  @moduledoc """
  武学实装「wuyun-jianfa」（源 wuyun-jianfa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wuyun_jianfa/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左小指轻弹，一招「宫韵」悄然划向$n的后心",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N右手无名指若有若无的一划，将琴弦并做一处，[商韵]已将$n笼罩",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 30,
      "lvl" => 20,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N五指疾挥，一式[角韵]无形的刺向$n的左肋",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 40,
      "lvl" => 40,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N将手中剑横扫，同时左右手如琵琶似的疾弹，正是一招[支韵]",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 50,
      "lvl" => 60,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N使出「羽韵」，将剑提至唇边，如同清音出箫，剑掌齐出，划向$n的$l",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 60,
      "lvl" => 80,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "wuyun-jianfa"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 38}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
