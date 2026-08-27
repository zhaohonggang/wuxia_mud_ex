defmodule Kantele.Character.RespirateCommand do
  @moduledoc """
  吐纳炼精：`respirate <耗精量>` / `tuna <耗精量>` / `吐纳` / `炼精`

  对应 LPC cmds/skill/respirate.c：耗精炼精力上限。
  每轮将 force/10 的精转化为精力（jingli），直到精尽或参数耗完。
  jingli 为独立修为线，不自然回复，只能通过吐纳提升。
  """

  use Kalevala.Character.Command

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  @min_cost 10
  @tick_interval 1000

  def run(conn, params) do
    character = conn.character

    cond do
      get_session(conn, "respirate") != nil ->
        fail(conn, "你正闭目吐纳，心无二用。\n")

      Combat.busy?(character.meta.combat) ->
        fail(conn, "你现在正忙着呢。\n")

      Combat.fighting?(character.meta.combat) ->
        fail(conn, "战斗中吐纳，好像只有神仙才能做到。\n")

      is_nil(Stats.mapped(character.meta.stats, "force")) ->
        fail(conn, "你必须先用 enable 选择要运用的内功心法。\n")

      true ->
        start_respirate(conn, params["arg"], character)
    end
  end

  defp start_respirate(conn, arg, character) do
    vitals = character.meta.vitals

    cond do
      not valid_cost?(arg) ->
        fail(conn, "你要花多少精修行？（格式：respirate <数量>，至少 #{@min_cost}）\n")

      cost(arg) < @min_cost ->
        fail(conn, "吐纳量至少 #{@min_cost} 点精。\n")

      cost(arg) > vitals.jing ->
        fail(conn, "你现在精不足，无法修行精力！\n")

      qi_ratio(vitals) < 70 ->
        fail(conn, "你现在身体状况太差了，无法集中精神！\n")

      no_fight_room?(character.room_id) ->
        fail(conn, "你无法在这个地方安心吐纳。\n")

      true ->
        schedule_first_tick()

        conn
        |> put_session("respirate", %{remaining: cost(arg)})
        |> render(CommandView, "text", %{text: "你闭上眼睛开始吐纳。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp schedule_first_tick() do
    Process.send_after(
      self(),
      %Event{from_pid: self(), topic: "respirate/tick", data: %{}},
      @tick_interval
    )
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp valid_cost?(arg), do: cost(arg) != nil

  defp cost(arg) when is_binary(arg) do
    case Integer.parse(String.trim(arg)) do
      {value, _rest} when value > 0 -> value
      _ -> nil
    end
  end

  defp cost(_), do: nil

  # LPC respirate.c：qi*100/max_qi < 70 拒绝
  defp qi_ratio(%{qi: qi, max_qi: max_qi}) when max_qi > 0,
    do: div(qi * 100, max_qi)

  defp qi_ratio(_), do: 0

  defp no_fight_room?(room_id) do
    "no_fight" in Kantele.World.room_flags(room_id)
  end
end
