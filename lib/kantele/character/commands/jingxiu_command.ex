defmodule Kantele.Character.JingxiuCommand do
  @moduledoc """
  静修命令：`jingxiu`

  对应 LPC cmds/skill/jingxiu.c：
  少林派弟子静修参禅，提升佛学技能。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Feature.Damage

  def run(conn, _params) do
    character = conn.character
    vitals = character.meta.vitals
    stats = character.meta.stats

    cond do
      not is_shaolin?(character) ->
        fail(conn, "")

      Combat.fighting?(character.meta.combat) ->
        fail(conn, "战斗中怎么静修？\n")

      Combat.busy?(character.meta.combat) ->
        fail(conn, "你正忙着呢！\n")

      vitals.jing < 50 ->
        fail(conn, "你精神不济，无法定心静修。\n")

      Stats.skill(stats, "buddhism") < 200 ->
        fail(conn, "你的佛学还不够深厚，难以通过静修参悟禅理。\n")

      true ->
        do_jingxiu(conn, character, vitals, stats)
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp is_shaolin?(character) do
    family = character.meta.family
    family && family["family_name"] == "少林派"
  end

  defp do_jingxiu(conn, character, vitals, stats) do
    jing_cost = 40 + :rand.uniform(10)
    {:ok, character} = Damage.receive_damage(character, :jing, jing_cost)

    skill_gain = 5 + :rand.uniform(max(stats.int, 1))
    character = improve_skill(character, "buddhism", skill_gain)
    busy_time = 1 + :rand.uniform(3)
    character = set_busy(character, busy_time)

    new_conn = put_character(conn, character)

    new_conn
    |> render(CommandView, "text", %{text: "你对禅宗心法有所心得。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp improve_skill(character, skill_name, gain) do
    current_level = Stats.skill(character.meta.stats, skill_name)
    new_skills = Map.put(character.meta.stats.skills, skill_name, current_level + gain)
    new_stats = %{character.meta.stats | skills: new_skills}
    %{character | meta: %{character.meta | stats: new_stats}}
  end

  defp set_busy(character, rounds) do
    combat = character.meta.combat
    new_combat = %{combat | busy: max(combat.busy, rounds)}
    %{character | meta: %{character.meta | combat: new_combat}}
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
