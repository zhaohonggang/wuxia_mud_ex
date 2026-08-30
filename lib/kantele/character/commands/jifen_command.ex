defmodule Kantele.Character.JifenCommand do
  @moduledoc """
  积分查询命令：`jifen`

  对应 LPC cmds/usr/jifen.c
  查询玩家积分。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character
    jifen = Map.get(character.meta, :jifen, 0) || 0

    if jifen > 0 do
      conn
      |> render(CommandView, "text", %{text: "你在#{Application.get_env(:kalevala, :mud_name, "江湖")}中的积分为#{jifen}点。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
      |> render(CommandView, "text", %{text: "你在#{Application.get_env(:kalevala, :mud_name, "江湖")}中尚无积分记录。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end
end
