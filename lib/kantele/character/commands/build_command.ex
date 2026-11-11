defmodule Kantele.Character.BuildCommand do
  @moduledoc """
  建造命令：`build`（对应 LPC `cmds/arch/build.c`）。

  W3 arch 巫师命令。本端口无对象系统 / 建造引擎，显式回执未建模。

  后续阶段（B2 W3 对象引擎二期）实现，依赖房间编辑器、出口系统与区域文件写入，
  预留接口模块 `Kantele.World.Builder`。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, _params ->
      WizArch.not_modeled(conn, "build")
    end)
  end
end
