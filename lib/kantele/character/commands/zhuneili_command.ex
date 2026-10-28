defmodule Kantele.Character.ZhuneiliCommand do
  @moduledoc """
  注内力：`注内力`

  对应 LPC ganjiang.c 工作步骤中的“注入内力”环节。
  玩家在干将锻造会话处于 status="inputing" 且 can_help=true 时，注入内力助炉，
  提升武器锻造点数，单次生效（can_help -> false）。

  门控：
    - 会话存在且 status == "inputing" 且 can_help == true
  体力门槛：
    - jing >= 180, qi >= 300, neili >= 800, max_neili >= 1000
  扣除：
    - jing - 180, qi - 300, neili - 200, max_neili - 200
  点数：
    - point += point * force / 800 （force = 玩家内功等级）
  单次限制：
    - can_help -> false
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Forging

  @jing_cost 180
  @qi_cost 300
  @neili_cost 200
  @neili_min 800
  @max_neili_cost 200
  @max_neili_min 1000

  def run(conn, %{}) do
    character = conn.character
    session = Forging.get(character.id)

    cond do
      is_nil(session) ->
        fail(conn, "你当前没有进行中的锻造会话。\n")

      session.status != "inputing" ->
        fail(conn, "炉火尚未备好，暂时无法注内力。\n")

      not session.can_help ->
        fail(conn, "本次锻造已无法再注入内力。\n")

      true ->
        handle_zhuneili(conn, character, session)
    end
  end

  defp handle_zhuneili(conn, character, session) do
    vitals = character.meta.vitals
    stats = character.meta.stats

    cond do
      vitals.jing < @jing_cost ->
        fail(conn, "你的精不足，无法注入内力。\n")

      vitals.qi < @qi_cost ->
        fail(conn, "你的气不足，无法注入内力。\n")

      vitals.neili < @neili_min ->
        fail(conn, "你的内力不足，无法注入内力。\n")

      vitals.max_neili < @max_neili_min ->
        fail(conn, "你的最大内力不足，无法注入内力。\n")

      true ->
        force = Stats.effective(stats, "force")
        new_point = session.point + div(session.point * force, 800)

        new_max_neili = vitals.max_neili - @max_neili_cost
        new_vitals = %Vitals{
          vitals |
          jing: vitals.jing - @jing_cost,
          qi: vitals.qi - @qi_cost,
          neili: min(vitals.neili - @neili_cost, new_max_neili),
          max_neili: new_max_neili
        }

        new_meta = %{character.meta | vitals: new_vitals}
        new_character = %{character | meta: new_meta}

        new_session = %{session | can_help: false, point: new_point}
        Forging.put(character.id, new_session)

        Records.save(new_character)

        conn
        |> put_character(new_character)
        |> render(CommandView, "text", %{
          text:
            "你凝神运气，将内力缓缓注入炉火，炉火骤然炽盛。\n" <>
            "武器锻造点数提升至 #{new_point}；本次锻造已无法再注入内力。\n"
        })
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
