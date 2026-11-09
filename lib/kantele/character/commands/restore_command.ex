defmodule Kantele.Character.RestoreCommand do
  @moduledoc """
  恢复命令：`restore`（对应 LPC `cmds/arch/restore.c`）。

  W3 arch 巫师命令。本端口无对象恢复 / 存档系统，显式回执未建模。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, _params ->
      WizArch.not_modeled(conn, "restore")
    end)
  end
end
