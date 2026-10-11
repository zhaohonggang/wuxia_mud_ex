defmodule Kantele.Combat.Skills.PanguQishi do
  @moduledoc """
  武学实装「pangu-qishi」（源 pangu-qishi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/pangu_qishi/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左手单臂抡起$w，一招「开山」，夹杂着阵阵风声向$n$l砸去",
      "force" => 320,
      "attack" => 27,
      "parry" => -34,
      "dodge" => -30,
      "damage" => 62,
      "lvl" => 0,
      "damage_type" => "挫伤",
      "skill_name" => "开山"
    },
    %{
      "action" => "$N将手中$w划出一道半弧，一式「断岳」便如流星坠地，直轰$n",
      "force" => 460,
      "attack" => 38,
      "parry" => -45,
      "dodge" => -27,
      "damage" => 66,
      "lvl" => 40,
      "damage_type" => "挫伤",
      "skill_name" => "断岳"
    },
    %{
      "action" => "突然间$N手中$w挟着无上劲力，一招「劈天」施出，飞砍向$n而去",
      "force" => 500,
      "attack" => 43,
      "parry" => -47,
      "dodge" => -25,
      "damage" => 70,
      "lvl" => 80,
      "damage_type" => "挫伤",
      "skill_name" => "劈天"
    },
    %{
      "action" => "$N嗔目大喝，施一招「分海」，$w在劲力推动之下，向$n缓缓压来",
      "force" => 540,
      "attack" => 51,
      "parry" => -50,
      "dodge" => -45,
      "damage" => 75,
      "lvl" => 120,
      "damage_type" => "挫伤",
      "skill_name" => "分海"
    },
    %{
      "action" => "$N紧握$w，那势「还虚」的劲力便如同排山倒海般朝$n飞旋而出",
      "force" => 580,
      "attack" => 55,
      "parry" => -25,
      "dodge" => -20,
      "damage" => 80,
      "lvl" => 160,
      "damage_type" => "挫伤",
      "skill_name" => "还虚"
    },
    %{
      "action" => "$N高举$w，那势「破衲」的劲力便如同排山倒海般朝$n飞旋而出",
      "force" => 620,
      "attack" => 65,
      "parry" => -35,
      "dodge" => -40,
      "damage" => 98,
      "lvl" => 180,
      "damage_type" => "挫伤",
      "skill_name" => "破衲"
    },
    %{
      "action" => "$N反转$w，那势「克己」的劲力便如同排山倒海般朝$n飞旋而出",
      "force" => 640,
      "attack" => 69,
      "parry" => -33,
      "dodge" => -62,
      "damage" => 104,
      "lvl" => 200,
      "damage_type" => "挫伤",
      "skill_name" => "克己"
    }
  ]

  @impl true
  def id(), do: "pangu-qishi"

  @impl true
  def valid_enable(usage), do: usage in ["hammer", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 90, neili: 90}

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
      "kai" => Kantele.Combat.Skills.Performs.PanguQishi.Kai
    }
  end
end
