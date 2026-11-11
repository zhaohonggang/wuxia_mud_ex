defmodule Kantele.Character.PossessCommand do
  @moduledoc """
  附身命令：`possess`（对应 LPC `cmds/arch/possess.c`）。

  W3 arch 巫师命令。本端口无附身 / 对象系统，显式回执未建模。

  后续阶段（B2 W3 对象引擎二期）实现，依赖角色进程迁移、会话绑定与权限继承，
  预留接口模块 `Kantele.World.Possession`。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, _params ->
      WizArch.not_modeled(conn, "possess")
    end)
  end
end
