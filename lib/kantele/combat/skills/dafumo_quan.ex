defmodule Kantele.Combat.Skills.DafumoQuan do
  @moduledoc """
  武学实装「dafumo-quan」（源 dafumo-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, query_effect_parry, valid_damage, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/dafumo_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「伏魔式」，双手猛地袭向$n$l",
      "force" => 250,
      "attack" => 55,
      "parry" => 60,
      "dodge" => 70,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左拳直出，钢劲有力，一招「天玄式」砸$n的$l",
      "force" => 270,
      "attack" => 60,
      "parry" => 80,
      "dodge" => 80,
      "damage" => 35,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左右双拳齐出，风声呼呼，一招「游龙式」击向$n$l",
      "force" => 310,
      "attack" => 75,
      "parry" => 100,
      "dodge" => 100,
      "damage" => 50,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一拳挥出，招式简单之极，但是这招却使得不卑不亢，气势雄浑，一招「魔惊式」拍向$n的$l",
      "force" => 330,
      "attack" => 75,
      "parry" => 100,
      "dodge" => 110,
      "damage" => 55,
      "lvl" => 90,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N使一招「大伏魔式」，$n心中一惊，已被$N双拳笼罩",
      "force" => 350,
      "attack" => 80,
      "parry" => 120,
      "dodge" => 130,
      "damage" => 66,
      "lvl" => 120,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N拳法顿快，使出「无诲式」，转眼间，数拳已袭向$n",
      "force" => 380,
      "attack" => 85,
      "parry" => 130,
      "dodge" => 140,
      "damage" => 80,
      "lvl" => 150,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "dafumo-quan"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 60}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
