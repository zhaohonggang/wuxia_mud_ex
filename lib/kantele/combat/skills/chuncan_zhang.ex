defmodule Kantele.Combat.Skills.ChuncanZhang do
  @moduledoc """
  武学实装「chuncan-zhang」（源 chuncan-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/chuncan_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一式「破茧出笼」，双掌间升起一团淡淡的白雾，缓缓推向$n的$l",
      "force" => 30,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 15,
      "damage" => 1,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "破茧出笼"
    },
    %{
      "action" => "$N使一式「锦绸抽丝」，左掌凝重，右掌轻盈，同时向$n的$l击去",
      "force" => 55,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 28,
      "damage" => 3,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "锦绸抽丝"
    },
    %{
      "action" => "$N突地一招「蚕丝绵绵」，双掌挟着一阵风雷之势，猛地劈往$n的$l",
      "force" => 70,
      "attack" => 0,
      "parry" => 38,
      "dodge" => 42,
      "damage" => 9,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "蚕丝绵绵"
    },
    %{
      "action" => "$N一式「千丝万缕」，双掌缦妙地一阵挥舞，不觉已击到$n的$l上",
      "force" => 91,
      "attack" => 0,
      "parry" => 49,
      "dodge" => 53,
      "damage" => 12,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "千丝万缕"
    },
    %{
      "action" => "$N一式「碧蚕春生」，身形凝立不动，双掌一高一低，看似简单，却令$n无法躲闪",
      "force" => 102,
      "attack" => 0,
      "parry" => 57,
      "dodge" => 61,
      "damage" => 18,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "碧蚕春生"
    }
  ]

  @impl true
  def id(), do: "chuncan-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 25}

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
      "jian" => Kantele.Combat.Skills.Performs.ChuncanZhang.Jian
    }
  end
end
