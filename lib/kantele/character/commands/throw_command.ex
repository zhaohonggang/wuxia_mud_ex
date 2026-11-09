defmodule Kantele.Character.ThrowCommand do
  @moduledoc """
  投掷命令：`throw`（对应 LPC `cmds/arch/throw.c`）。

  W3 arch 巫师命令。本端口无投掷 / 对象系统，显式回执未建模。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, _params ->
      WizArch.not_modeled(conn, "throw")
    end)
  end
end
