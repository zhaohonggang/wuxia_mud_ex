defmodule Kantele.Combat.Skills.KuihuaXinfa do
  @moduledoc """
  武学实装「kuihua-xinfa」（源 kuihua-xinfa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：exert_function_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/kuihua_xinfa/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "kuihua-xinfa"

  @impl true
  def valid_enable(usage), do: usage in ["force"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc """
  学习门槛（对照 `kuihua-xinfa.c` valid_learn）

  仅性别门：非「无性」→「欲练神功，挥刀自宫！」。其余回落 `skill.c` 默认放行
  （LPC 以 `return ::valid_learn(me)` 收尾，父类的 valid_learn 仅返回 1，无新增门槛）。
  """
  @impl true
  def valid_learn(stats, character) do
    cond do
      gender_of(character) != "无性" ->
        {:error, "欲练神功，挥刀自宫！\n"}

      true ->
        valid_learn(stats)
    end
  end

  @impl true
  def valid_learn(_stats), do: :ok

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"
end
