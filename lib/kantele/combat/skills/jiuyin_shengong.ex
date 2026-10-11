defmodule Kantele.Combat.Skills.JiuyinShengong do
  @moduledoc """
  武学实装「jiuyin-shengong」（源 jiuyin-shengong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, hit_ob, perform_action_file, practice_skill, valid_damage, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jiuyin_shengong/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "jiuyin-shengong"

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
      "quan" => Kantele.Combat.Skills.Performs.JiuyinShengong.Quan,
      "shou" => Kantele.Combat.Skills.Performs.JiuyinShengong.Shou,
      "xin" => Kantele.Combat.Skills.Performs.JiuyinShengong.Xin,
      "zhang" => Kantele.Combat.Skills.Performs.JiuyinShengong.Zhang,
      "zhen" => Kantele.Combat.Skills.Performs.JiuyinShengong.Zhen,
      "zhi" => Kantele.Combat.Skills.Performs.JiuyinShengong.Zhi,
      "zhua" => Kantele.Combat.Skills.Performs.JiuyinShengong.Zhua
    }
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.JiuyinShengong.Powerup,
      "roar" => Kantele.Combat.Skills.Performs.JiuyinShengong.Roar,
      "shield" => Kantele.Combat.Skills.Performs.JiuyinShengong.Shield
    }
  end
end
