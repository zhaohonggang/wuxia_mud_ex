defmodule Kantele.Character.AnimaoutCommand do
  @moduledoc """
  元婴出世命令：`animaout`

  对应 LPC cmds/skill/animaout.c：
  打通任督二脉后，在安全地点闭关修炼元婴，可大幅提升精力上限。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat

  def run(conn, _params) do
    character = conn.character
    vitals = character.meta.vitals

    cond do
      is_no_fight_room?(character.room_id) == false ->
        fail(conn, "这里不能战斗。\n")

      Combat.busy?(character.meta.combat) ->
        fail(conn, "你现在正忙着呢。\n")

      vitals.qi * 100 / max(vitals.max_qi, 1) < 90 ->
        fail(conn, "你现在的气太少了，无法静心闭关。\n")

      vitals.jing * 100 / max(vitals.max_jing, 1) < 90 ->
        fail(conn, "你现在的精太少了，无法静心闭关。\n")

      vitals.jingli * 100 / max(vitals.max_jingli, 1) < 90 ->
        fail(conn, "你现在的精力太少了，无法静心闭关。\n")

      vitals.max_jingli < 2000 ->
        fail(conn, "你觉得精力颇有不足，看来目前还难以修炼元婴出世。\n")

      true ->
        do_animaout(conn, character, vitals)
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp is_no_fight_room?(room_id) do
    "no_fight" in Kantele.World.room_flags(room_id)
  end

  defp do_animaout(conn, character, vitals) do
    stats = character.meta.stats
    available_potential = (stats.potential || 0) - (stats.learned_points || 0)

    if available_potential < 1000 do
      fail(conn, "你的潜能不够，没法闭关修行以修炼元婴出世。\n")
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
