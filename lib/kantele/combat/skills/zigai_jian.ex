defmodule Kantele.Combat.Skills.ZigaiJian do
  @moduledoc """
  武学实装「zigai-jian」（源 zigai-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/zigai_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左晃右蹿，手中$w突然刺向$n$l，正是一招「峰回路转」",
      "force" => 45,
      "attack" => 10,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "峰回路转"
    },
    %{
      "action" => "$N越攻越猛，突然间手中$w剑光暴涨，一招「姹紫嫣红」已然使出\\n",
      "force" => 90,
      "attack" => 24,
      "parry" => 40,
      "dodge" => 26,
      "damage" => 35,
      "lvl" => 25,
      "damage_type" => "刺伤",
      "skill_name" => "姹紫嫣红"
    },
    %{
      "action" => "$N以攻为守，以进为退，手中$w刷的一剑「蜻蜓点水」，向$n$l刺去",
      "force" => 110,
      "attack" => 30,
      "parry" => 40,
      "dodge" => 35,
      "damage" => 40,
      "lvl" => 50,
      "damage_type" => "刺伤",
      "skill_name" => "蜻蜓点水"
    },
    %{
      "action" => "$N轻啸一声，$w径直向$n$w，这一剑虽无任何招式，但是$N却使得不\\n",
      "force" => 120,
      "attack" => 35,
      "parry" => 45,
      "dodge" => 48,
      "damage" => 48,
      "lvl" => 75,
      "damage_type" => "刺伤",
      "skill_name" => "千山暮雪"
    },
    %{
      "action" => "$N将$w一挥，长啸一声，腾空而起，使出一式「鹤翔紫盖」！这一招来得又\\n",
      "force" => 160,
      "attack" => 55,
      "parry" => 66,
      "dodge" => 82,
      "damage" => 60,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "鹤翔紫盖"
    }
  ]

  @impl true
  def id(), do: "zigai-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 50}

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
      "hui" => Kantele.Combat.Skills.Performs.ZigaiJian.Hui
    }
  end
end
