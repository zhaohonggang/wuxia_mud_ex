defmodule Kantele.Combat.Performs do
  @moduledoc """
  绝招/运功实现模块的注册与目标侧分派

  注册表不单独维护：由 `Kantele.Combat.Skills` 各门武学的 `perform_list/0`
  反查得到。`perform_id` 形如 `"<skill-id>/<move>"`（如 `"huashan-jian/jie"`），
  即 `Skills.get("huashan-jian").perform_list()["jie"]`。

  目标侧分派 `resolve_incoming/5` 让攻击型绝招把结算逻辑放在各自模块内，
  取代 `CombatEvent` 中按 `perform_id` 逐个硬编码的分支。
  """

  alias Kalevala.Event
  alias Kantele.Combat.Skills

  @doc "按 `perform_id` 反查实现模块；未注册或格式不合法返回 nil"
  def lookup(perform_id) when is_binary(perform_id) do
    with [skill_id, move] <- String.split(perform_id, "/", parts: 2),
         skill when not is_nil(skill) <- Skills.get(skill_id),
         target when not is_nil(target) <- skill.perform_list()[move] do
      target
    else
      _ -> nil
    end
  end

  def lookup(_), do: nil

  @doc """
  目标侧结算分派（供 `CombatEvent.perform_incoming/2` 调用）

  查到实现模块且其导出 `resolve_incoming/4` 时调用之，否则原样返回 `conn`。
  """
  def resolve_incoming(conn, perform_id, character, attacker, data) do
    case lookup(perform_id) do
      nil ->
        conn

      module ->
        if Code.ensure_loaded?(module) and function_exported?(module, :resolve_incoming, 4) do
          module.resolve_incoming(conn, character, attacker, data)
        else
          conn
        end
    end
  end

  @doc """
  攻击型绝招回执：通知攻击方补扣内力并进入忙乱

  对应 LPC 在攻击方对象上的 `add("neili", -cost)` 与 `start_busy`；因攻击方
  与目标分处两个进程，改由 `combat/perform-feedback` 事件回传。
  """
  def feedback(attacker, neili_cost, busy) do
    feedback(attacker, %{neili_cost: neili_cost, busy: busy})
  end

  @doc """
  攻击型绝招回执（完整数据版）

  `data` 至少含 `:neili_cost` 与 `:busy`，可选 `:gain_neili` / `:gain_qi` /
  `:gain_jing` 供吸取类绝招把从目标处得到的气血/内力回补攻击方。
  """
  def feedback(attacker, data) when is_map(data) or is_list(data) do
    data = Enum.into(data, %{})

    if Process.alive?(attacker.pid) do
      send(attacker.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-feedback",
        data: data
      })
    end
  end
end
