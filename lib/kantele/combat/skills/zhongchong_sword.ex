defmodule Kantele.Combat.Skills.ZhongchongSword do
  @moduledoc """
  武学实装「zhongchong-sword」（源 zhongchong-sword.c，由 translate_skill.exs 生成）

  已自动化：静态招式 1 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/zhongchong_sword/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N右手中指一竖，“中冲剑”向前刺出。真气鼓荡，嗤然声响，",
      "force" => 490,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -15,
      "damage" => 110,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "中冲剑"
    }
  ]

  @impl true
  def id(), do: "zhongchong-sword"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 80}

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
