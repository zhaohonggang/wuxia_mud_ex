defmodule Kantele.Combat.Skills.KuangfengBlade do
  @moduledoc """
  武学实装「kuangfeng-blade」（源 kuangfeng-blade.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/kuangfeng_blade/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w轻挥，一招",
      "force" => 60,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "风平浪静"
    },
    %{
      "action" => "$N一招",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 20,
      "lvl" => 10,
      "damage_type" => "割伤",
      "skill_name" => "风起云涌"
    },
    %{
      "action" => "$N一招",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 25,
      "lvl" => 20,
      "damage_type" => "割伤",
      "skill_name" => "风卷残云"
    },
    %{
      "action" => "$N一招",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 45,
      "damage" => 35,
      "lvl" => 30,
      "damage_type" => "割伤",
      "skill_name" => "风流云散"
    },
    %{
      "action" => "$N侧身滑步而上，一招",
      "force" => 140,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 25,
      "lvl" => 45,
      "damage_type" => "割伤",
      "skill_name" => "风声鹤唳"
    },
    %{
      "action" => "$N快速挥舞$w，使出一招",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 65,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "割伤",
      "skill_name" => "风中残烛"
    },
    %{
      "action" => "$N一招",
      "force" => 160,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 70,
      "damage" => 35,
      "lvl" => 70,
      "damage_type" => "割伤",
      "skill_name" => "风刀霜剑"
    },
    %{
      "action" => "$N使一招",
      "force" => 170,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 75,
      "damage" => 45,
      "lvl" => 85,
      "damage_type" => "割伤",
      "skill_name" => "风驰电掣"
    },
    %{
      "action" => "$N一招",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 80,
      "damage" => 55,
      "lvl" => 100,
      "damage_type" => "割伤",
      "skill_name" => "风雨飘摇"
    },
    %{
      "action" => "$N挪步小退，一招",
      "force" => 190,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 100,
      "damage" => 60,
      "lvl" => 120,
      "damage_type" => "割伤",
      "skill_name" => "风花雪月"
    }
  ]

  @impl true
  def id(), do: "kuangfeng-blade"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 15}

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

end
