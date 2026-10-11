defmodule Kantele.Combat.Skills.JiuyangShengong do
  @moduledoc """
  武学实装「jiuyang-shengong」（源 jiuyang-shengong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, hit_ob, perform_action_file, practice_skill, query_effect_parry, valid_damage, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jiuyang_shengong/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "jiuyang-shengong"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "force", "parry", "sword", "unarmed"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "hun" => Kantele.Combat.Skills.Performs.JiuyangShengong.Hun,
      "jiu" => Kantele.Combat.Skills.Performs.JiuyangShengong.Jiu,
      "pi" => Kantele.Combat.Skills.Performs.JiuyangShengong.Pi,
      "po" => Kantele.Combat.Skills.Performs.JiuyangShengong.Po,
      "ri" => Kantele.Combat.Skills.Performs.JiuyangShengong.Ri
    }
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.JiuyangShengong.Powerup,
      "roar" => Kantele.Combat.Skills.Performs.JiuyangShengong.Roar,
      "shield" => Kantele.Combat.Skills.Performs.JiuyangShengong.Shield
    }
  end
end
