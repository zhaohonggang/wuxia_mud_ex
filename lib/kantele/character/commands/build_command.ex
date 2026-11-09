defmodule Kantele.Character.BuildCommand do
  @moduledoc """
  建造命令：`build`（对应 LPC `cmds/arch/build.c`）。

  W3 arch 巫师命令。本端口无对象系统 / 建造引擎，显式回执未建模。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, _params ->
      WizArch.not_modeled(conn, "build")
    end)
  end
end
