defmodule Kantele.Character.FuseCommand do
  @moduledoc """
  熔炼命令：`fuse <物品>`

  对应 LPC cmds/skill/fuse.c：
  将某些物品熔化，获得灵慧 (magic_points)。
  """
  use Kalevala.Character.Command

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat

  def run(conn, params) do
    character = conn.character
    item_name = params["arg"] || ""

    cond do
      item_name == "" ->
        fail(conn, "你要熔炼什么物品？\n")

      Combat.busy?(character.meta.combat) ->
        fail(conn, "先忙完了你的事情再做这件事情吧。\n")

      Combat.fighting?(character.meta.combat) ->
        fail(conn, "你现在正在打架，没时间做这些事情。\n")

      true ->
        do_fuse(conn, character, item_name)
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp do_fuse(conn, character, _item_name) do
    vitals = character.meta.vitals

    cond do
      (character.meta.stats.skills["force"] || 0) < 300 ->
        fail(conn, "你的内功修为不够，难以熔炼物品。\n")

      vitals.max_neili < 5000 ->
        fail(conn, "你的内力修为不够，难以熔炼物品。\n")

      vitals.neili < 3000 ->
        fail(conn, "你现在的内力不足，难以熔炼物品。\n")

      true ->
        conn
        |> render(CommandView, "text", %{text: "你需要提供可熔炼的物品。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
