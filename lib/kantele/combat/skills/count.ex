defmodule Kantele.Combat.Skills.Count do
  @moduledoc """
  武学实装「count」（源 count.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：valid_learn（已迁移）
  - perform/exert 路由骨架见 tmp/perf_out/count/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "count"

  # TODO(migrate) valid_enable 未识别（源可能用变量/组合判断）
  @impl true
  def valid_enable(_usage), do: false

  # LPC `valid_learn(object me)`（源 count.c）
  # 门派微调：桃花岛弟子门槛更低（gift 35→30、mat 300→200）。
  # 源内被注释掉的「左右互搏分心」门不迁移（源码本身已注释）。
  @impl true
  def valid_learn(stats, character) do
    family_name = family_name_of(character)
    {gift, mat} = if family_name == "桃花岛", do: {30, 200}, else: {35, 300}
    lvl = Stats.skill(stats, id())

    cond do
      Stats.int(stats) < gift ->
        {:error, "你的先天悟性不足，难以领会阴阳八卦的奥妙。\n"}

      Stats.skill(stats, "mathematics") < mat ->
        {:error, "你的算术知识太差，无法理解阴阳八卦的奥妙。\n"}

      Stats.skill(stats, "mathematics") < lvl ->
        {:error, "你的算术知识有限，无法理解更深奥的阴阳八卦。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  # LPC `me->query("family/family_name")`：无门派时 LPC 返回 0，
  # `0 != "少林派"` 为真 → 拦；nil 行为一致，无需额外守卫。
  defp family_name_of(%{meta: %{family: family}}) when is_map(family),
    do: Map.get(family, :name) || Map.get(family, "name")
  defp family_name_of(_character), do: nil
end
