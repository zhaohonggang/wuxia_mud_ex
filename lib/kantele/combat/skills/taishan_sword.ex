defmodule Kantele.Combat.Skills.TaishanSword do
  @moduledoc """
  武学实装「taishan-sword」（源 taishan-sword.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/taishan_sword/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w一晃，向右滑出三步，一招“朗月无云”，转过身来，身",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 12,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "朗月无云"
    },
    %{
      "action" => "$N手中$w圈转，一招「峻岭横空」去势奇疾，无数剑光刺向$n的$l",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "刺伤",
      "skill_name" => "峻岭横空"
    },
    %{
      "action" => "$N展开剑势，身随剑走，左边一拐，右边一弯，越转越急。猛地",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 20,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "泰山十八盘"
    },
    %{
      "action" => "$N手中$w倏地刺出，一连五剑，每一剑的剑招皆苍然有古意。招数",
      "force" => 140,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 45,
      "damage" => 30,
      "lvl" => 90,
      "damage_type" => "刺伤",
      "skill_name" => "五大夫剑"
    },
    %{
      "action" => "$N右手$w斜指而下，左手五指正在屈指而数，从一数到五，握而成拳，又",
      "force" => 220,
      "attack" => 100,
      "parry" => 0,
      "dodge" => 80,
      "damage" => 80,
      "lvl" => 180,
      "damage_type" => "刺伤",
      "skill_name" => "岱宗如何"
    }
  ]

  @impl true
  def id(), do: "taishan-sword"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 11}

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
