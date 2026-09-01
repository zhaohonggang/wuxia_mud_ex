defmodule Kantele.Character.BurningCommand do
  @moduledoc """
  燃烧命令：`burning` / `fenu`

  对应 LPC cmds/skill/burning.c：
  将积蓄的愤怒发泄出来，提升攻击能力。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character

    cond do
      get_temp(character, "burning_up") ->
        fail(conn, "你现在正在怒火中，没有必要再发作一次。\n")

      query_craze(character) < 1000 ->
        fail(conn, "你现在还不够愤怒，无法让自己怒火燃烧。\n")

      true ->
        do_burning(conn, character)
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp do_burning(conn, character) do
    force_level = character.meta.stats.skills["force"] || 0
    count = div(force_level, 5)
    craze_cost = 500 + :rand.uniform(300)

    character = cost_craze(character, craze_cost)
    character = set_temp(character, "burning_up", count)

    new_conn = put_character(conn, character)

    new_conn
    |> render(CommandView, "text", %{text: "你一声大吼，两目登时精光四射，咄咄逼人，势不可挡。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp query_craze(character) do
    (character.meta.damage || %{})[:craze] || 0
  end

  defp cost_craze(character, amount) do
    damage = character.meta.damage || %{}
    current_craze = damage[:craze] || 0
    new_damage = Map.put(damage, :craze, max(0, current_craze - amount))
    %{character | meta: %{character.meta | damage: new_damage}}
  end

  defp get_temp(character, key) do
    character.meta.temp[key]
  end

  defp set_temp(character, key, value) do
    new_temp = Map.put(character.meta.temp || %{}, key, value)
    %{character | meta: %{character.meta | temp: new_temp}}
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
