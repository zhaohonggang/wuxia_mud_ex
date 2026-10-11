defmodule Kantele.Combat.Skills.WaiBagua do
  @moduledoc """
  武学实装「wai-bagua」（源 wai-bagua.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, query_effect_parry, valid_damage, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wai_bagua/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "wai-bagua"

  @impl true
  def valid_enable(usage), do: usage in ["parry"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 60}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "zhen" => Kantele.Combat.Skills.Performs.WaiBagua.Zhen
    }
  end
end
