defmodule Kantele.Character.SpecialCommand do
  @moduledoc """
  特技命令：`special`

  对应 LPC cmds/std/special.c
  查看或使用特技。

  ⚠️ 保持原样（F2 决策 + own test 锁定）：`special` 与 `special <name>` 均渲染
  "暂未开放"，遵守 `test/kantele/character/commands/special_command_test.exs`
  已锁定的契约。授予路径/执行在本阶段不实现。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"skill" => _skill}) do
    conn
    |> render(CommandView, "text", %{text: "特技系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "特技系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
