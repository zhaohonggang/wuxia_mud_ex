defmodule Kantele.Character.SuicideCommand do
  @moduledoc """
  自杀：`suicide` / `suicide -f`（cmds/usr/suicide.c）

  Batch 6 为占位（Stub）：仅实现确认与告别流程，**不删除角色档案**。
  LPC 的 15 秒倒计时 `halt` 回旋窗口、管理密码校验、`UPDATE_D->remove_user`
  连锁删除，均在本期子系统中明确定为不实现项（见迁移文档）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    if rest == "-f" do
      farewell(conn)
    else
      conn
      |> render(CommandView, "text", %{
        text:
          "您选择永远死掉的自杀方式，这个角色的资料将永远删除，请务必\n考虑清楚，确定的话请输入完整的自杀(suicide -f)指令。\n\n（注：当前为占位实现，实际不会删除档案。）\n"
      })
      |> prompt(CommandView, "prompt", %{})
    end
  end

  def run(conn, _params), do: run(conn, %{"rest" => ""})

  defp farewell(conn) do
    conn
    |> assign(:prompt, false)
    |> render(CommandView, "text", %{
      text: "既然如此…那就……永别了，#{conn.character.name}。\n欢迎您能够以新的身份再次光临。\n"
    })
    |> halt()
  end
end
