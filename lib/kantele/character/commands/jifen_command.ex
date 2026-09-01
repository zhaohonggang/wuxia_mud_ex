defmodule Kantele.Character.JifenCommand do
  @moduledoc """
  积分查询命令：`jifen`

  对应 LPC cmds/usr/jifen.c；查询玩家积分（落盘 metadata.jifen）。

  注：LPC 的巫师 `jifen +|- <玩家> <点数>` 增减分支依赖管理员权限框架
  （P4 W1 权限地基），本期未迁移。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

  def run(conn, _params) do
    jifen = PlayerMeta.jifen(conn.character.meta)

    text =
      if jifen > 0 do
        "你在#{mud_name()}中的积分为#{jifen}点。\n"
      else
        "你在#{mud_name()}中尚无积分记录。\n"
      end

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp mud_name, do: Application.get_env(:kalevala, :mud_name, "江湖")
end
