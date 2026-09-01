defmodule Kantele.Character.BreakupCommand do
  @moduledoc """
  打通任督二脉命令：`breakup`

  对应 LPC cmds/skill/breakup.c：
  闭关修行以打通任督二脉，需要大宗师境界和深厚的内力功底。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat

  def run(conn, _params) do
    character = conn.character
    vitals = character.meta.vitals
    stats = character.meta.stats

    cond do
      is_no_fight_room?(character.room_id) == false ->
        fail(conn, "在这里打通任督二脉？不太安全吧？\n")

      Combat.busy?(character.meta.combat) ->
        fail(conn, "你现在正忙着呢。\n")

      stats.skills["force"] < 450 ->
        fail(conn, "你觉得自己的内功火候还有限，看来需要先锻炼好内功才行。\n")

      vitals.max_neili < 5000 ->
        fail(conn, "你觉得内力颇有不足，看来目前还难以打通任督二脉。\n")

      vitals.neili * 100 / max(vitals.max_neili, 1) < 90 ->
        fail(conn, "你现在的内力太少了，无法静心闭关。\n")

      vitals.qi * 100 / max(vitals.max_qi, 1) < 90 ->
        fail(conn, "你现在的气太少了，无法静心闭关。\n")

      vitals.jing * 100 / max(vitals.max_jing, 1) < 90 ->
        fail(conn, "你现在的精太少了，无法静心闭关。\n")

      true ->
        do_breakup(conn, character, stats)
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp is_no_fight_room?(room_id) do
    "no_fight" in Kantele.World.room_flags(room_id)
  end

  defp do_breakup(conn, character, stats) do
    available_potential = (stats.potential || 0) - (stats.learned_points || 0)

    if available_potential < 1000 do
      fail(conn, "你的潜能不够，没法闭关修行以打通任督二脉。\n")
    else
      conn
      |> render(CommandView, "text", %{text: "你盘膝坐下，开始冥神运功，闭关修行。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
