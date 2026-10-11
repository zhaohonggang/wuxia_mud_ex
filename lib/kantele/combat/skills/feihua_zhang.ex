defmodule Kantele.Combat.Skills.FeihuaZhang do
  @moduledoc """
  武学实装「feihua-zhang」（源 feihua-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 3 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/feihua_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「飞雪式」，一掌直出，袭向$n$l",
      "force" => 60,
      "attack" => 15,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "飞雪式"
    },
    %{
      "action" => "$N左右双掌齐出，一招「落花式」，掌风呼呼，将$n笼罩",
      "force" => 85,
      "attack" => 17,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 43,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "落花式"
    },
    %{
      "action" => "$N两手虎口相对，往内一圈，一招「千变万化」往$n的$l拍出",
      "force" => 155,
      "attack" => 21,
      "parry" => 33,
      "dodge" => 31,
      "damage" => 68,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "千变万化"
    }
  ]

  @impl true
  def id(), do: "feihua-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 45}

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
      "fei" => Kantele.Combat.Skills.Performs.FeihuaZhang.Fei
    }
  end
end
