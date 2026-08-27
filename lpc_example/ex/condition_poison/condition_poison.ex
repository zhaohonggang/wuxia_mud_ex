defmodule ExKantele.Character.Conditions.Poison do
  @moduledoc """
  对应原文件: lpc_example/condition/condition_poison.c (中毒, 13759B)

  迁移判定: C —— **框架逻辑**。对应 Kalevala 的 Buff/状态机制，非世界数据。
  需底层把 Buff 扩展为“可周期 tick、到期解除、可被清除”的 Condition：
    - 原文按等级每 tick: damage = (damage/10)+random(damage) 扣 eff_qi(wound)
    - 到期自动解除；可由医生/丹药/内功清除
  """

  import Kalevala.Character.Conn

  @key "poison"

  def apply_to(conn, level, damage) do
    tick = div(damage, 10) + :rand.uniform(damage)
    duration_ms = level * 1000

    Process.send_after(self(), %Kalevala.Event{
      from_pid: self(),
      topic: "condition/tick",
      data: %{key: @key, tick_damage: tick, expires: duration_ms}
    }, 1000)

    conn
  end

  def remove(conn), do: conn

  # 现有 Buff 只支持“单次到期”，无每 tick 副作用 —— 需扩展(Buff -> Condition)
  @unsupported [periodic_tick: "Buff 需支持每 tick 回调与到期解除"]
end
