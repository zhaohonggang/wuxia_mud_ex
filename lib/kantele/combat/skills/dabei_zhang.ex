defmodule Kantele.Combat.Skills.DabeiZhang do
  @moduledoc """
  武学实装「dabei-zhang」（源 dabei-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/dabei_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N身形急晃，施出大悲掌「",
      "force" => 180,
      "attack" => 23,
      "parry" => 17,
      "dodge" => 25,
      "damage" => 19,
      "lvl" => 0,
      "damage_type" => "内伤",
      "skill_name" => "浪涛势"
    },
    %{
      "action" => "$N一招「",
      "force" => 240,
      "attack" => 41,
      "parry" => 27,
      "dodge" => 25,
      "damage" => 25,
      "lvl" => 30,
      "damage_type" => "内伤",
      "skill_name" => "深渊势"
    },
    %{
      "action" => "$N平掌为刀施展「",
      "force" => 330,
      "attack" => 58,
      "parry" => 35,
      "dodge" => 36,
      "damage" => 39,
      "lvl" => 60,
      "damage_type" => "内伤",
      "skill_name" => "鲸吞势"
    },
    %{
      "action" => "$N反转右掌陡然施一招「",
      "force" => 410,
      "attack" => 96,
      "parry" => 62,
      "dodge" => 81,
      "damage" => 53,
      "lvl" => 90,
      "damage_type" => "内伤",
      "skill_name" => "破穹势"
    },
    %{
      "action" => "$N手腕一翻，挥出一道无比凌厉的掌劲直斩$n，正是「",
      "force" => 460,
      "attack" => 125,
      "parry" => 47,
      "dodge" => 35,
      "damage" => 78,
      "lvl" => 120,
      "damage_type" => "内伤",
      "skill_name" => "翻海势"
    },
    %{
      "action" => "$N施出「",
      "force" => 520,
      "attack" => 110,
      "parry" => 40,
      "dodge" => 45,
      "damage" => 85,
      "lvl" => 150,
      "damage_type" => "内伤",
      "skill_name" => "滔天势"
    }
  ]

  @impl true
  def id(), do: "dabei-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 80}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
  @doc "当前等级对应的最高招式名（query_skill_name）"
  def query_skill_name(level) do
    @actions
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> Map.get(action, "skill_name")
    end
  end


  @impl true
  def perform_list() do
    %{
      "bei" => Kantele.Combat.Skills.Performs.DabeiZhang.Bei
    }
  end
end
