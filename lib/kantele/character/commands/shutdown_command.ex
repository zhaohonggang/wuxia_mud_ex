defmodule Kantele.Character.ShutdownCommand do
  @moduledoc """
  关机命令：`shutdown`（对应 LPC `cmds/arch/shutdown.c`）。

  W3 arch 巫师命令。本端口无系统停机 / 对象系统，显式回执未建模。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, _params ->
      WizArch.not_modeled(conn, "shutdown")
    end)
  end
end
