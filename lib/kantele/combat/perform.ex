defmodule Kantele.Combat.Perform do
  @moduledoc """
  绝招/运功实现模块的 behaviour

  攻击方在自身进程调用 `run/1`：校验门槛、扣资源、放出主文案，必要时把
  `combat/perform-incoming` 事件发给目标。

  攻击型绝招另可实现 `resolve_incoming/4`：由目标进程以自身完整状态结算
  命中/闪避/效果（对应 LPC 在受害者对象上执行 `receive_damage`/`final`）。
  分派见 `Kantele.Combat.Performs`。
  """

  @type conn :: Kalevala.Character.Conn.t()

  @doc "攻击方入口：门槛校验 + 施放"
  @callback run(conn()) :: conn()

  @doc """
  目标侧结算（可选）

  入参为目标自身的 `conn`/`character`、攻击方快照 `attacker` 与事件 `data`；
  返回结算后的 `conn`。未实现者由分派层原样透传。
  """
  @callback resolve_incoming(conn(), map(), map(), map()) :: conn()

  @optional_callbacks resolve_incoming: 4
end
