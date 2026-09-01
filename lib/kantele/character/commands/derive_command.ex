defmodule Kantele.Character.DeriveCommand do
  @moduledoc """
  汲取命令：`derive [<点数>]`

  对应 LPC cmds/skill/derive.c：
  吸收实战中的体会，提升武学修养 (martial-cognize)。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat

  def run(conn, params) do
    character = conn.character
    vitals = character.meta.vitals
    stats = character.meta.stats

    cond do
      Combat.busy?(character.meta.combat) ->
        fail(conn, "你现在正忙着呢。\n")

      Combat.fighting?(character.meta.combat) ->
        fail(conn, "战斗中还是好好的凝神对敌吧。\n")

      (stats.combat_exp || 0) < 30000 ->
        fail(conn, "你的实战经验太浅，还无法领会通过实战获得的心得。\n")

      vitals.qi * 100 / max(vitals.max_qi, 1) < 70 ->
        fail(conn, "你现在没有充足的体力用来吸收实战的心得。\n")

      vitals.jing * 100 / max(vitals.max_jing, 1) < 70 ->
        fail(conn, "你现在精神不济，难以抓住实战体会中的秘要！\n")

      true ->
        do_derive(conn, character, vitals, stats)
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp do_derive(conn, character, vitals, stats) do
    conn
    |> render(CommandView, "text", %{text: "你默默的想了想先前一段时间和对手交手时的情形，开始吸收汲取其中的心得。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
