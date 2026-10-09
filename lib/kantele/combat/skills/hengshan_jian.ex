defmodule Kantele.Combat.Skills.HengshanJian do
  @moduledoc """
  武学实装「hengshan-jian」（源 hengshan-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 2 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/hengshan_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N提起$w，划了个半圈，斜斜向$n$l刺去",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N突然间将$w交左手，反手刺出",
      "force" => 140,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 25,
      "lvl" => 30,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "hengshan-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 25, neili: 14}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
