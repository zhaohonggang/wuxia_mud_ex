defmodule Kantele.Combat.Skills.QiulinShiye do
  @moduledoc """
  秋林师业（对照 `kungfu/skill/qiulin-shiye.c`）

  空手/轻功载体：`valid_enable("unarmed")` / `valid_enable("dodge")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/qiulin_shiye/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 为 `return 1`（无门槛），本版同样放行；
  - LPC `practice_skill` 已迁移：qi<40 时拒（由 practice 流程的体力检查把关），扣 qi 30、不耗 neili；
  - 招式表未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "qiulin-shiye"

  @impl true
  def valid_enable(usage), do: usage in ["unarmed", "dodge", "parry"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "练招消耗：LPC practice_skill 扣 qi 30（不耗 neili）"
  @impl true
  def practice_cost(), do: %{qi: 30, neili: 0}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"wu" => Kantele.Combat.Skills.Performs.QiulinShiye.Wu}
  end
end
