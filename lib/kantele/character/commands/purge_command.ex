defmodule Kantele.Character.PurgeCommand do
  @moduledoc """
  净化命令：`purge`（对应 LPC `cmds/arch/purge.c`）。

  W3 arch 巫师命令。本端口无进程 / 对象系统，显式回执未建模。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, _params ->
      WizArch.not_modeled(conn, "purge")
    end)
  end
end
