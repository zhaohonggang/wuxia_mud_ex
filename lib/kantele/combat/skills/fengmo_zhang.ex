defmodule Kantele.Combat.Skills.FengmoZhang do
  @moduledoc """
  武学实装「fengmo-zhang」（源 fengmo-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/fengmo_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N微一躬身，$w携带着刺耳的飕飕风声，擦地扫向$n的脚踝",
      "force" => 70,
      "attack" => 10,
      "parry" => 9,
      "dodge" => -5,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N右手托住杖端，左掌居中一击，令其凭惯性倒向$n的肩头",
      "force" => 101,
      "attack" => 15,
      "parry" => 15,
      "dodge" => -10,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N一声狂喝，举起$w乒乒乓乓地满地乱敲，让$n左闪右避，狼狈不堪",
      "force" => 122,
      "attack" => 20,
      "parry" => 19,
      "dodge" => -5,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N飞身跃起，身下$w往横里直打而出，挥向$n的裆部",
      "force" => 168,
      "attack" => 45,
      "parry" => 55,
      "dodge" => -5,
      "damage" => 50,
      "lvl" => 130,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N高举$w，身形如鬼魅般飘出，对准$n的天灵盖一杖打下",
      "force" => 189,
      "attack" => 51,
      "parry" => 62,
      "dodge" => -5,
      "damage" => 60,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N双眼发红，将手中$w舞成千百根相似，根根砸向$n全身各处要害",
      "force" => 212,
      "attack" => 55,
      "parry" => 67,
      "dodge" => -5,
      "damage" => 60,
      "lvl" => 0,
      "damage_type" => "挫伤"
    }
  ]

  @impl true
  def id(), do: "fengmo-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "staff"]

  @impl true
  def practice_cost(), do: %{qi: 70, neili: 69}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "luan" => Kantele.Combat.Skills.Performs.FengmoZhang.Luan
    }
  end
end
