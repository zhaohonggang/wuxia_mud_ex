defmodule Kantele.Combat.Skills.KongmingQuan do
  @moduledoc """
  武学实装「kongming-quan」（源 kongming-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, query_effect_parry, valid_damage, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/kongming_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「空屋住人」，双手轻飘飘地箍向$n$l",
      "force" => 250,
      "attack" => 55,
      "parry" => 60,
      "dodge" => 70,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左掌一平，右掌一伸，一招「空碗盛饭」直拍$n的$l",
      "force" => 270,
      "attack" => 60,
      "parry" => 80,
      "dodge" => 80,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N身形绕$n一转，双手上撩,一招「空钵装水」击向$n$l",
      "force" => 300,
      "attack" => 75,
      "parry" => 100,
      "dodge" => 100,
      "damage" => 20,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左掌一按，右掌一挥,一招「虚怀若谷」拍向$n的$l",
      "force" => 320,
      "attack" => 75,
      "parry" => 100,
      "dodge" => 110,
      "damage" => 25,
      "lvl" => 90,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N使一招「空山鸟语」，$n的$l已围在$N的重重掌影之下",
      "force" => 340,
      "attack" => 80,
      "parry" => 120,
      "dodge" => 130,
      "damage" => 30,
      "lvl" => 120,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N神色一敛，使出「我心空明」，围绕$n的$l接连出掌",
      "force" => 370,
      "attack" => 85,
      "parry" => 130,
      "dodge" => 140,
      "damage" => 40,
      "lvl" => 150,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "kongming-quan"

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
