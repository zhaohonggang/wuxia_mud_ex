defmodule Kantele.Character.YanlianCommand do
  @moduledoc """
  演练命令：`yanlian <技能>`

  对应 LPC cmds/skill/yanlian.c：
  将某些武功的子技能合而为一，成为一种强大的新技能。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat

  def run(conn, params) do
    character = conn.character
    skill_name = params["arg"] || ""

    cond do
      skill_name == "" ->
        fail(conn, "你想演练什么？\n")

      Combat.busy?(character.meta.combat) ->
        fail(conn, "你现在正忙着呢。\n")

      is_no_fight_room?(character.room_id) ->
        fail(conn, "你在这里演练也不怕吵到别人？\n")

      true ->
        do_yanlian(conn, character, skill_name)
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp is_no_fight_room?(room_id) do
    "no_fight" in Kantele.World.room_flags(room_id)
  end

  defp do_yanlian(conn, _character, skill_name) do
    conn
    |> render(CommandView, "text", %{text: "你需要演练一个已有子技能的武功。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
