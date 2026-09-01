defmodule Kantele.Character.SynCommand do
  @moduledoc """
  融合命令：`syn <物品>`

  对应 LPC cmds/skill/syn.c：
  与自己的兵器融合，提升魔法力和融合度。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, params) do
    character = conn.character
    item_name = params["arg"] || ""

    cond do
      item_name == "" ->
        fail(conn, "你要与什么物品融合？\n")

      true ->
        do_syn(conn, character, item_name)
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp do_syn(conn, character, _item_name) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < vitals.max_neili * 9 / 10 ->
        fail(conn, "你现在内力并不充沛，怎敢贸然与之融合？\n")

      vitals.jingli < vitals.max_jingli * 9 / 10 ->
        fail(conn, "你现在精力不济，无法与之融合！\n")

      vitals.qi < vitals.max_qi * 9 / 10 ->
        fail(conn, "你现在气血不足，无法与之融合！\n")

      true ->
        conn
        |> render(CommandView, "text", %{text: "你需要提供一件已经与你有契约的圣物。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
