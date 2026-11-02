defmodule Kantele.Combat.Skills.ChuixiaoJifa do
  @moduledoc """
  武学实装「chuixiao-jifa」（源 chuixiao-jifa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/chuixiao_jifa/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "chuixiao-jifa"

  # TODO(migrate) valid_enable 未识别（源可能用变量/组合判断）
  @impl true
  def valid_enable(_usage), do: false

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  @doc """
  学习门槛（对照 `chuixiao-jifa.c` valid_learn）

  `me->query("int") < 24 && me->query_int() < 35` 二者同义（均为派生命理），
  取 `Stats.query_int(stats) < 24`。LPC 以 `return 1` 收尾（无 `::valid_learn` 回落）。
  """
  @impl true
  def valid_learn(stats) do
    if Stats.query_int(stats) < 24 do
      {:error, "就你那悟性？五音不全，学什么吹箫？\n"}
    else
      :ok
    end
  end

  def actions(), do: @actions
end
