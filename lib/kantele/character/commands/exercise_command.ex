defmodule Kantele.Character.ExerciseCommand do
  @moduledoc """
  打坐命令：`exercise <耗气量>` / `dazuo <耗气量>`（≥10）

  对应 LPC cmds/skill/exercise.c：耗气攒内力，busy 循环每跳
  qi→neili 转化，结束后内力蓄满 2×上限时尝试推高 max_neili
  （受 `Kantele.Character.NeiliLimit` 天花板约束）。
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
      get_session(conn, "exercise") != nil ->
        fail(conn, "你正盘膝打坐，心无二用。\n")

      Combat.busy?(character.meta.combat) ->
        fail(conn, "你现在正忙着呢。\n")

      Combat.fighting?(character.meta.combat) ->
        fail(conn, "战斗中不能练内功，会走火入魔。\n")

      is_nil(Stats.mapped(character.meta.stats, "force")) ->
        fail(conn, "你必须先用 enable 选择要运用的内功心法。\n")

      true ->
        start_exercise(conn, params["arg"], character)
    end
  end

  defp start_exercise(conn, arg, character) do
    vitals = character.meta.vitals

    cond do
      not valid_cost?(arg) ->
        fail(conn, "格式：exercise <数量>（耗费的气必须多于 #{@min_cost}）\n")

      cost(arg) < @min_cost ->
        fail(conn, "你的内功还没有达到那个境界！（至少耗费 #{@min_cost} 点气）\n")

      vitals.qi < cost(arg) ->
        fail(conn, "你现在的气太少了，无法产生内息运行全身经脉。\n")

      jing_ratio(vitals) < 70 ->
        fail(conn, "你现在精不够，无法控制内息的流动！\n")

      no_fight_room?(character.room_id) ->
        fail(conn, "你无法在这个地方安心打坐。\n")

      true ->
        schedule_first_tick()

        conn
        |> put_session("exercise", %{remaining: cost(arg)})
        |> render(CommandView, "text", %{text: "你盘膝坐下，运气用功，一股内息开始在体内流动。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  # 首跳调度（与 combat/tick 同款 foreman 自投递），后续由 ExerciseEvent 自续
  defp schedule_first_tick() do
    Process.send_after(
      self(),
      %Event{from_pid: self(), topic: "exercise/tick", data: %{}},
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

  # LPC exercise.c：jing*100/max_jing < 70 拒绝
  defp jing_ratio(%{jing: jing, max_jing: max_jing}) when max_jing > 0,
    do: div(jing * 100, max_jing)

  defp jing_ratio(_), do: 0

  # no_fight 房间默认禁打坐（A5 flags 联动；房间数据取自 ZoneCache 快照）
  defp no_fight_room?(room_id) do
    "no_fight" in Kantele.World.room_flags(room_id)
  end
end
