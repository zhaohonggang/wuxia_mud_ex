defmodule Kantele.Combat.Skills.TianjueDao do
  @moduledoc """
  武学实装「tianjue-dao」（源 tianjue-dao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tianjue_dao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w忽地斜砍，嗡嗡作响，一式「天刀式」，袭向$n$l",
      "force" => 20,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 28,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "砍伤",
      "skill_name" => "天刀式"
    },
    %{
      "action" => "$N手中$w反转，踏步向前，一式「风刀式」，砍向$n$l",
      "force" => 40,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 24,
      "damage" => 20,
      "lvl" => 25,
      "damage_type" => "砍伤",
      "skill_name" => "风刀式"
    },
    %{
      "action" => "$N怒喝一声，飞身跃起，一式「灭刀式」，$w嗡嗡两声，已到$n$l",
      "force" => 60,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 24,
      "damage" => 18,
      "lvl" => 50,
      "damage_type" => "砍伤",
      "skill_name" => "灭刀式"
    },
    %{
      "action" => "$N手中$w坐砍右劈，一式「平刀式」，平平挥向$n",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 25,
      "lvl" => 75,
      "damage_type" => "砍伤",
      "skill_name" => "平刀式"
    },
    %{
      "action" => "$N将$w横于胸前，猛地劈出，一式「绝刀式」，砍向$n$l",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 38,
      "damage" => 35,
      "lvl" => 100,
      "damage_type" => "砍伤",
      "skill_name" => "绝刀式"
    }
  ]

  @impl true
  def id(), do: "tianjue-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 30}

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
      "suo" => Kantele.Combat.Skills.Performs.TianjueDao.Suo
    }
  end
end
