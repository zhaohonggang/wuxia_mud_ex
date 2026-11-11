defmodule Kantele.Character.RebootCommand do
  @moduledoc """
  重启命令：`reboot [延迟秒]`

  对应 LPC `cmds/arch/reboot.c`。

  应用层受限版本：经 `WizArch.system_action/4` 调度一次系统重启。真实重启仅在
  `W3ObjectEngine` 的 `allow_system_actions` 配置为真时执行，否则仅记录调度意图
  并返回确认文案（dry-run），不触达 OS / 容器。

  仅巫师可用。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, params ->
      rest = Map.get(params, "rest", "")
      WizArch.system_action(conn, :reboot, "重启", rest)
    end)
  end
end
