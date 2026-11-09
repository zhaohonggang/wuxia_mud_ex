defmodule Kantele.Character.RebootCommand do
  @moduledoc """
  重启命令：`reboot`（对应 LPC `cmds/arch/reboot.c`）。

  W3 arch 巫师命令。本端口无系统重启 / 对象系统，显式回执未建模。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, _params ->
      WizArch.not_modeled(conn, "reboot")
    end)
  end
end
