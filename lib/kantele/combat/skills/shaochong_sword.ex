defmodule Kantele.Combat.Skills.ShaochongSword do
  @moduledoc """
  武学实装「shaochong-sword」（源 shaochong-sword.c，由 translate_skill.exs 生成）

  已自动化：静态招式 1 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shaochong_sword/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N右手反指，小指伸出，真气自少冲穴激荡而出，“少冲剑”",
      "force" => 330,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 90,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少冲剑"
    }
  ]

  @impl true
  def id(), do: "shaochong-sword"

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
