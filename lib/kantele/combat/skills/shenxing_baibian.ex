defmodule Kantele.Combat.Skills.ShenxingBaibian do
  @moduledoc """
  神行百变（对照 `kungfu/skill/shenxing-baibian.c`）

  轻功载体：`valid_enable("dodge")` / `valid_enable("move")`。

  绝招实现见 `lib/kantele/combat/skills/performs/shenxing_baibian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 无门槛（return 1），本版同样放行；
  - LPC `practice_skill` 已迁移：qi<50 / neili<30 时拒（由 practice 流程的体力检查把关），
    扣 qi 40；LPC 内力侧写作 `me->add("neill", -14)`（**拼写错误 `neill`**，该键不存在，
    内力实际不减），故 `practice_cost` 的 neili 记 0 —— 原样 bug 保真；
  - 招式表未建模（`query_action` 返回空）。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "shenxing-baibian"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "move"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "练招消耗：LPC practice_skill 扣 qi 40（内力侧因 `neill` 拼写 bug 实际不减，记 0）"
  @impl true
  def practice_cost(), do: %{qi: 40, neili: 0}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"piao" => Kantele.Combat.Skills.Performs.ShenxingBaibian.Piao}
  end
end
