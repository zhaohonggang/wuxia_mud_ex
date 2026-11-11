defmodule Kantele.Character.ShutdownCommand do
  @moduledoc """
  关机命令：`shutdown [延迟秒]`

  对应 LPC `cmds/arch/shutdown.c`。

  应用层受限版本：经 `WizArch.system_action/4` 调度一次系统停机。真实停机仅在
  `W3ObjectEngine` 的 `allow_system_actions` 配置为真时执行，否则仅记录调度意图
  并返回确认文案（dry-run），不触达 OS / 容器。

  仅巫师可用。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, params ->
      rest = Map.get(params, "rest", "")
      WizArch.system_action(conn, :shutdown, "停机", rest)
    end)
  end
end
