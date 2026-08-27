defmodule Kantele.Character.UnrideCommand do
  @moduledoc """
  下马：`unride` / `xia`（cmds/std/unride.c）

  清除运行态 `meta.riding`；坐骑物品仍在背包。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    case Map.get(conn.character.meta, :riding) do
      nil ->
        conn
        |> render(CommandView, "text", %{text: "你下什么下！根本就没座骑！\n"})
        |> prompt(CommandView, "prompt", %{})

      _riding ->
        character = conn.character

        conn
        |> put_character(%{character | meta: %{character.meta | riding: nil}})
        |> render(CommandView, "text", %{text: "你从坐骑上飞身跳下。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end
end
