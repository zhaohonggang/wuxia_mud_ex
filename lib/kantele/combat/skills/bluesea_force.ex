defmodule Kantele.Combat.Skills.BlueseaForce do
  @moduledoc """
  武学实装「bluesea-force」（源 bluesea-force.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, perform_action_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/bluesea_force/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "bluesea-force"

  # TODO(migrate) valid_enable 未识别（源可能用变量/组合判断）
  @impl true
  def valid_enable(_usage), do: false

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "bo" => Kantele.Combat.Skills.Performs.BlueseaForce.Bo,
      "jue" => Kantele.Combat.Skills.Performs.BlueseaForce.Jue,
      "lu" => Kantele.Combat.Skills.Performs.BlueseaForce.Lu,
      "mie" => Kantele.Combat.Skills.Performs.BlueseaForce.Mie,
      "xuan" => Kantele.Combat.Skills.Performs.BlueseaForce.Xuan,
      "zhan" => Kantele.Combat.Skills.Performs.BlueseaForce.Zhan,
      "zhu" => Kantele.Combat.Skills.Performs.BlueseaForce.Zhu
    }
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.BlueseaForce.Powerup,
      "shield" => Kantele.Combat.Skills.Performs.BlueseaForce.Shield
    }
  end
end
