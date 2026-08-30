defmodule Kantele.Character.AbandonCommand do
  @moduledoc """
  放弃技能：`abandon|fangqi <技能名> | exp`

  对应 LPC cmds/skill/abandon.c
  放弃战斗经验或某项技能，成功率与天赋相关。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  def run(conn, %{"skill" => skill}) do
    character = conn.character

    cond do
      skill == "exp" ->
        abandon_exp(conn, character)

      true ->
        abandon_skill(conn, character, skill)
    end
  end

  defp abandon_exp(conn, character) do
    stats = character.meta.stats
    combat_exp = stats.combat_exp

    if combat_exp < 1000 do
      render_error(conn, "你发现自己现在对武学简直就是一无所知。\n")
    else
      lost = Enum.random(1..max(1, div(combat_exp, 100)))

      new_stats = %{stats | combat_exp: max(0, combat_exp - lost)}

      conn
      |> put_character(%{character | meta: %{character.meta | stats: new_stats}})
      |> render(CommandView, "text", %{
        text: "你不再想拳脚兵器轻功内功，只是一门心思忘记武功。\n"
      })
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp abandon_skill(conn, character, skill) do
    stats = character.meta.stats
    skills = stats.skills || %{}

    skill_level = Map.get(skills, skill, 0)

    if skill_level == 0 do
      new_skills = Map.delete(skills, skill)
      new_stats = %{stats | skills: new_skills}

      conn
      |> put_character(%{character | meta: %{character.meta | stats: new_stats}})
      |> render(CommandView, "text", %{text: "好了。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      new_level = Enum.random(0..(skill_level - 1))
      new_skills = Map.put(skills, skill, new_level)
      new_stats = %{stats | skills: new_skills}

      conn
      |> put_character(%{character | meta: %{character.meta | stats: new_stats}})
      |> render(CommandView, "text", %{
        text: "你集中精力不再想#{skill}，结果有所效果。\n"
      })
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
