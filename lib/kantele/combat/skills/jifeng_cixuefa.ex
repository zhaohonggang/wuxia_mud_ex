defmodule Kantele.Combat.Skills.JifengCixuefa do
  @moduledoc """
  武学实装「jifeng-cixuefa」（源 jifeng-cixuefa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jifeng_cixuefa/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N身形一展，施出一招「蝎尾针」，手中$w疾风般刺向$n的$l",
      "force" => 30,
      "attack" => 15,
      "parry" => 12,
      "dodge" => 10,
      "damage" => 25,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "蝎尾针"
    },
    %{
      "action" => "$N一声叱喝，$w如灵蛇吞吐，施一招「蛾眉刺」向$n的$l刺去",
      "force" => 53,
      "attack" => 21,
      "parry" => 13,
      "dodge" => 12,
      "damage" => 37,
      "lvl" => 10,
      "damage_type" => "刺伤",
      "skill_name" => "蛾眉刺"
    },
    %{
      "action" => "$N飞身一跃而起，手中$w使出「电光劲」，三刺连环，射向$n$l",
      "force" => 71,
      "attack" => 24,
      "parry" => 22,
      "dodge" => 15,
      "damage" => 45,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "电光劲"
    },
    %{
      "action" => "$N手中$w闪电般一晃，陡然使出一招「回峰蜿蜒势」，飕的刺向$n$l",
      "force" => 98,
      "attack" => 35,
      "parry" => 13,
      "dodge" => 15,
      "damage" => 54,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "回峰蜿蜒势"
    },
    %{
      "action" => "$N飞身跃起，一式「九转连环势」，手中$w连环九刺，尽数射向$n而去",
      "force" => 140,
      "attack" => 46,
      "parry" => 9,
      "dodge" => 11,
      "damage" => 65,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "九转连环势"
    }
  ]

  @impl true
  def id(), do: "jifeng-cixuefa"

  @impl true
  def valid_enable(usage), do: usage in ["dagger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 62}

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
      "cang" => Kantele.Combat.Skills.Performs.JifengCixuefa.Cang
    }
  end
end
