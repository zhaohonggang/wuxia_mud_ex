defmodule Kantele.Character.SmashCommand do
  @moduledoc """
  击碎命令：`smash`（对应 LPC `cmds/arch/smash.c`）。

  W3 arch 巫师命令。本端口无物品销毁 / 对象系统，显式回执未建模。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, _params ->
      WizArch.not_modeled(conn, "smash")
    end)
  end
end
