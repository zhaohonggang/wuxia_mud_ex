defmodule Kantele.Character.ChangeuserCommand do
  @moduledoc """
  切换用户命令：`changeuser`（对应 LPC `cmds/arch/changeuser.c`）。

  W3 arch 巫师命令。本端口无多用户切换 / 对象系统，显式回执未建模。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, _params ->
      WizArch.not_modeled(conn, "changeuser")
    end)
  end
end
