defmodule Kantele.Character.CallCommand do
  @moduledoc """
  召唤命令：`call`（对应 LPC `cmds/arch/call.c`）。

  W3 arch 巫师命令。本端口无进程呼叫 / 对象系统，显式回执未建模。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, _params ->
      WizArch.not_modeled(conn, "call")
    end)
  end
end
