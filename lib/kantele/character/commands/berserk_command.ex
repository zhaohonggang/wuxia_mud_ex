defmodule Kantele.Character.BerserkCommand do
  @moduledoc """
  狂暴命令：`berserk` / `baofa`

  对应 LPC cmds/skill/berserk.c：
  运用内功控制情绪，大行发作，积蓄愤怒。但对自身有伤害。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Feature.Damage

  def run(conn, _params) do
    character = conn.character
    vitals = character.meta.vitals
    stats = character.meta.stats

    cond do
      vitals.neili < 1000 ->
        fail(conn, "你的内力不够充沛，难以控制自己的情绪。\n")

      stats.con < 35 and stats.str < 35 ->
        fail(conn, "你的身体素质还不够好，贸然发作有伤身体。\n")

      true ->
        do_berserk(conn, character, stats)
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp do_berserk(conn, character, stats) do
    force_level = Stats.skill(stats, "force")
    pts = div(1000 * :rand.uniform(force_level + 500), 1000)
    qi_damage = div(pts * 10, max(stats.con, 1))

    {:ok, character} = Damage.receive_damage(character, :qi, qi_damage)
    character = improve_craze(character, pts)

    new_conn = put_character(conn, character)

    new_conn
    |> render(CommandView, "text", %{text: "你嘿然冷笑，关节喀啦喀啦的响个不停，一股悍气油然而起。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp improve_craze(character, gain) do
    current_craze = query_craze(character)
    new_craze = current_craze + gain
    new_damage = Map.put(character.meta.damage || %{}, :craze, new_craze)
    %{character | meta: %{character.meta | damage: new_damage}}
  end

  defp query_craze(character) do
    (character.meta.damage || %{})[:craze] || 0
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
