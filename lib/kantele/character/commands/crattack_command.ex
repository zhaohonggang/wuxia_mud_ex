defmodule Kantele.Character.CrattackCommand do
  @moduledoc """
  愤怒一击命令：`crattack <对象>`

  对应 LPC cmds/skill/crattack.c：
  利用愤怒状态对战斗中的对手进行致命打击。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat

  def run(conn, params) do
    character = conn.character
    arg = params["arg"] || ""

    cond do
      not is_no_fight_room?(character.room_id) == false ->
        fail(conn, "这里不能战斗。\n")

      Combat.busy?(character.meta.combat) ->
        fail(conn, "你上一个动作还没有完成，不能施用愤怒一击。\n")

      true ->
        do_crattack(conn, character, arg)
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp is_no_fight_room?(room_id) do
    "no_fight" in Kantele.World.room_flags(room_id)
  end

  defp do_crattack(conn, character, arg) do
    craze = query_craze(character)
    vitals = character.meta.vitals

    cond do
      craze < 500 ->
        fail(conn, "你现在心平气和，谈不上什么愤怒。\n")

      craze < 1000 ->
        fail(conn, "你现在还不够愤怒，无法施展愤怒必杀绝技。\n")

      vitals.qi * 100 / max(vitals.max_qi, 1) < 50 ->
        fail(conn, "你现在体力太虚弱，无法施展愤怒必杀绝技。\n")

      vitals.qi < 200 ->
        fail(conn, "你现在气息不够强，难以施展爆烈的愤怒必杀绝技。\n")

      true ->
        conn
        |> render(CommandView, "text", %{text: "你怒火中烧，发出愤怒一击！\n"})
        |> prompt(CommandView, "prompt", %{})
    end
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
