defmodule Kantele.Combat.Skills.LiuxingChui do
  @moduledoc """
  武学实装「liuxing-chui」（源 liuxing-chui.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/liuxing_chui/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「星光灿烂」，$w连连闪动，攻向$n的$l",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 2,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "星光灿烂"
    },
    %{
      "action" => "$N一招「流星赶月」，$w气势如虹，击向$n的$l",
      "force" => 140,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 12,
      "damage" => 5,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "流星赶月"
    },
    %{
      "action" => "$N身影飘动，一招「星过长空」，$w快速砸向$n的$l",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 16,
      "damage" => 15,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "星过长空"
    },
    %{
      "action" => "$N一招「群星闪烁」，$w数分数合，$n只觉无处躲避",
      "force" => 160,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 18,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "群星闪烁"
    },
    %{
      "action" => "$N突然猛跨两步，$w陡出，迅如崩雷，一招「流星火雨」击向$n的前胸",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 22,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "流星火雨"
    }
  ]

  @impl true
  def id(), do: "liuxing-chui"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "whip"]

  @impl true
  def practice_cost(), do: %{qi: 36, neili: 18}

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
