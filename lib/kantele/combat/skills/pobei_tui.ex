defmodule Kantele.Combat.Skills.PobeiTui do
  @moduledoc """
  武学实装「pobei-tui」（源 pobei-tui.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/pobei_tui/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双手虚晃，左脚猛地飞起，一式「开山腿」，踢向$n的$l",
      "force" => 80,
      "attack" => 10,
      "parry" => 15,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "开山腿"
    },
    %{
      "action" => "$N左脚顿地，身形猛转，右脚一式「劈碑腿」，猛踹$n的$l",
      "force" => 100,
      "attack" => 20,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "劈碑腿"
    },
    %{
      "action" => "$N右脚飞一般踹出，既猛且准，一式「碎石腿」，踢向的$n",
      "force" => 140,
      "attack" => 30,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 18,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "碎石腿"
    },
    %{
      "action" => "$N双足连环圈转，一式「裂地腿」，足带风尘，攻向$n的全身",
      "force" => 160,
      "attack" => 35,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 20,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "裂地腿"
    },
    %{
      "action" => "$N双脚交叉踢起，一式「钻天腿」，脚脚不离$n的面门左右",
      "force" => 180,
      "attack" => 35,
      "parry" => 40,
      "dodge" => 40,
      "damage" => 25,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "钻天腿"
    }
  ]

  @impl true
  def id(), do: "pobei-tui"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 60}

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
      "kai" => Kantele.Combat.Skills.Performs.PobeiTui.Kai
    }
  end
end
