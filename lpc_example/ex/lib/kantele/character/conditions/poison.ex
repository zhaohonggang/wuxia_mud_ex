defmodule ExKantele.Character.Conditions.Poison do
  @moduledoc """
  中毒状态（对照 lpc_example/condition/condition_poison.c）

  结论：这是**框架逻辑**，对应 Kalevala 的 Buff/状态机制
  （existing `Kantele.Character.Combat.Buff` / `StatusTracker`），
  **不是**单文件世界数据。需要动底层状态系统才能落地。

  原文要点（condition_poison.c）：
  - 中毒按等级 `damage = ((int)(damage/10)) + random(damage)` 逐 tick 扣 qi/wound
  - `update_condition` 每 tick 触发一次，中毒到期自动解除
  - 可被特定手段（医生/丹药/内功）清除
  """

  import Kalevala.Character.Conn

  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff

  @key "poison"

  @spec apply_to(any(), non_neg_integer(), non_neg_integer()) :: any()
  def apply_to(conn, level, damage) do
    tick = div(damage, 10) + :rand.uniform(damage)
    duration_ms = level * 1000

    # 需要一个“每 tick 副作用 + 到期解除”的状态，当前 Buff 只有单次到期。
    # 需底层把 Buff 扩展为可周期 tick 的 “Condition”。
    Process.send_after(self(), %Kalevala.Event{
      from_pid: self(),
      topic: "condition/tick",
      data: %{key: @key, tick_damage: tick, expires: duration_ms}
    }, 1000)

    conn
  end

  def tick(conn, tick_damage) do
    # 应用伤害到 vitals.qi / eff_qi
    # 需底层提供 receive_wound/receive_damage 的等效落点函数
    conn
  end

  def remove(conn) do
    conn
  end
end
