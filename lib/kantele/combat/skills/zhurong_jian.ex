defmodule Kantele.Combat.Skills.ZhurongJian do
  @moduledoc """
  武学实装「zhurong-jian」（源 zhurong-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/zhurong_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N身法迅捷，连出两剑，分袭$n面门和$w，正是一招「横空出世」",
      "force" => 70,
      "attack" => 10,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 35,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "横空出世"
    },
    %{
      "action" => "$N以剑画弧，前脚跨出，一式「风扫落叶」，横剑砍向$n$l，",
      "force" => 110,
      "attack" => 20,
      "parry" => 40,
      "dodge" => 40,
      "damage" => 45,
      "lvl" => 25,
      "damage_type" => "砍伤",
      "skill_name" => "风扫落叶"
    },
    %{
      "action" => "$N手中$w斜出，径直指向$n$l，正是一招「气冲云霄」",
      "force" => 160,
      "attack" => 30,
      "parry" => 45,
      "dodge" => 30,
      "damage" => 55,
      "lvl" => 50,
      "damage_type" => "刺伤",
      "skill_name" => "气冲云霄"
    },
    %{
      "action" => "$N手中$w忽地转动，一式「引火上身」，已顺势刺向$n$l",
      "force" => 180,
      "attack" => 35,
      "parry" => 50,
      "dodge" => 45,
      "damage" => 60,
      "lvl" => 75,
      "damage_type" => "刺伤",
      "skill_name" => "引火上身"
    },
    %{
      "action" => "$N长啸一声，单脚点地，忽地跃起，挺剑刺向$n$l，正是一招「雁回祝融」",
      "force" => 240,
      "attack" => 45,
      "parry" => 60,
      "dodge" => 80,
      "damage" => 80,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "雁回祝融"
    }
  ]

  @impl true
  def id(), do: "zhurong-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 60}

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
