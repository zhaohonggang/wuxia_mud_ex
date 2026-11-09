defmodule Kantele.Character.GrantCommand do
  @moduledoc """
  授权命令：`grant`（对应 LPC `cmds/arch/grant.c`）。

  W3 arch 巫师命令。本端口无权限授予 / 对象系统，显式回执未建模。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, _params ->
      WizArch.not_modeled(conn, "grant")
    end)
  end
end
