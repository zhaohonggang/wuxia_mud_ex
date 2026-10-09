defmodule Kantele.Combat.Skills.CanheZhi do
  @moduledoc """
  武学实装「canhe-zhi」（源 canhe-zhi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, skill_improved, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/canhe_zhi/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双指并拢虚点而出，合「",
      "force" => 480,
      "attack" => 110,
      "parry" => 90,
      "dodge" => 95,
      "damage" => 160,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N双指齐点而出，合「",
      "force" => 460,
      "attack" => 100,
      "parry" => 90,
      "dodge" => 115,
      "damage" => 180,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "只见$N十指箕张，随手指指点点，将「",
      "force" => 460,
      "attack" => 100,
      "parry" => 135,
      "dodge" => 125,
      "damage" => 180,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "只见$N纵身跃起，长啸一声，凌空而下，「",
      "force" => 460,
      "attack" => 100,
      "parry" => 115,
      "dodge" => 145,
      "damage" => 200,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N伸出两指，弹指无声，陡见两缕紫气由指尖透出，「",
      "force" => 460,
      "attack" => 120,
      "parry" => 130,
      "dodge" => 125,
      "damage" => 200,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "遥见$N伸出一指轻轻拂向$n，指未到，「",
      "force" => 480,
      "attack" => 120,
      "parry" => 150,
      "dodge" => 165,
      "damage" => 240,
      "lvl" => 0,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "canhe-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 100, neili: 0}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
