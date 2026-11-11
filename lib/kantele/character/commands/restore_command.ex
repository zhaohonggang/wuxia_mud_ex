defmodule Kantele.Character.RestoreCommand do
  @moduledoc """
  恢复命令：`restore`（对应 LPC `cmds/arch/restore.c`）。

  W3 arch 巫师命令。本端口无对象恢复 / 存档系统，显式回执未建模。

  后续阶段（B2 W3 对象引擎二期）实现，依赖持久化 / 存档系统与数据验证，
  预留接口模块 `Kantele.World.ObjectRestore`。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, _params ->
      WizArch.not_modeled(conn, "restore")
    end)
  end
end
