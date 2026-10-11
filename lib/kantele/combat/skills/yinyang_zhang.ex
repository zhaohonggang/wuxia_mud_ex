defmodule Kantele.Combat.Skills.YinyangZhang do
  @moduledoc """
  武学实装「yinyang-zhang」（源 yinyang-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yinyang_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出一招「山阴手」，运掌如飞，招招直打$n的$l",
      "force" => 60,
      "attack" => 25,
      "parry" => 16,
      "dodge" => 10,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "山阴手"
    },
    %{
      "action" => "$N使出一招「千层刃」，双掌急运内力，带着凛冽的掌风直拍$n的$l",
      "force" => 80,
      "attack" => 55,
      "parry" => 19,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "千层刃"
    },
    %{
      "action" => "$N惨然一声长啸，一招「消魂刀」，双掌猛然击下，直扑$n的要脉",
      "force" => 100,
      "attack" => 45,
      "parry" => 18,
      "dodge" => 20,
      "damage" => 50,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "消魂刀"
    },
    %{
      "action" => "$N骨骼暴响，双臂忽然暴长数尺，一招「离魂掌」直直攻向$n的$l",
      "force" => 130,
      "attack" => 40,
      "parry" => 23,
      "dodge" => 20,
      "damage" => 65,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "离魂掌"
    },
    %{
      "action" => "$N施展出一招「夺魂手」，双掌缤纷拍出，陡然间双掌已至$n跟前",
      "force" => 150,
      "attack" => 61,
      "parry" => 35,
      "dodge" => 32,
      "damage" => 80,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "夺魂手"
    }
  ]

  @impl true
  def id(), do: "yinyang-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 48}

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
      "qian" => Kantele.Combat.Skills.Performs.YinyangZhang.Qian
    }
  end
end
