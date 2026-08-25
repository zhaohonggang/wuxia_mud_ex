defmodule Kantele.Character.ExerciseEvent do
  @moduledoc """
  打坐心跳（对应 LPC exercising/1 的 busy 循环）

  每 1s 一跳：`neili += gain` 同时 `qi -= gain`
  （gain = `1 + (有效force/5)/2 + random(有效force/5)`）。
  预定气量耗尽后判定：

  - `neili < 2×max_neili` → 普通结束
  - `max_neili ≥ NeiliLimit.current/1` → 瓶颈，内力压回上限
  - 否则 `max_neili + 1`（base 同步抬升防回复回蚀）并落盘

  战斗中/死亡时中断，内力按 LPC halt 规则钳到 2×max。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CharacterView
  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.NeiliLimit
  alias Kantele.Character.Records
  alias Kantele.Character.Stats

  @tick_interval 1000

  def tick(conn, _event) do
    character = conn.character

    case get_session(conn, "exercise") do
      %{remaining: remaining} when is_integer(remaining) ->
        combat = character.meta.combat

        if Combat.fighting?(combat) or combat.dead do
          interrupt(conn, character)
        else
          step(conn, character, remaining)
        end

      _ ->
        conn
    end
  end

  # ---- 单跳转化 ----

  defp step(conn, character, remaining) do
    vitals = character.meta.vitals

    gain = neili_gain(character.meta.stats)
    gain = if gain > remaining, do: remaining, else: gain

    # 气不够本跳转化时：只转剩余的气，并立即结束（对应 LPC exercise_cost 清零）
    {gain, remaining} =
      if gain > vitals.qi do
        {vitals.qi, 0}
      else
        {gain, remaining - gain}
      end

    vitals = %{vitals | qi: vitals.qi - gain, neili: vitals.neili + gain}
    character = put_vitals(character, vitals)

    if remaining > 0 and vitals.qi > 0 do
      conn
      |> put_session("exercise", %{remaining: remaining})
      |> put_character(character)
      |> schedule_next()
    else
      conn
      |> put_session("exercise", nil)
      |> put_character(character)
      |> finish(character)
    end
  end

  defp finish(conn, character) do
    vitals = character.meta.vitals
    limit = NeiliLimit.current(character.meta.stats)

    {vitals, text} =
      cond do
        vitals.neili < vitals.max_neili * 2 ->
          {vitals, "你运功完毕，深深吸了口气，站了起来。\n"}

        vitals.max_neili >= limit ->
          {%{vitals | neili: vitals.max_neili}, "你的内力修为似乎已经达到了瓶颈。\n"}

        true ->
          vitals = %{
            vitals
            | max_neili: vitals.max_neili + 1,
              base_neili: vitals.base_neili + 1,
              neili: vitals.max_neili + 1
          }

          {vitals, "你的内力增加了！！\n"}
      end

    character = put_vitals(character, vitals)

    # 上限成长需落盘（character_metadata.max_neili），失败不影响游戏
    Records.save(character)

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
    |> render(CharacterView, "vitals")
  end

  # 战斗中被打断：内力钳回 2×max（LPC halt_exercise）
  defp interrupt(conn, character) do
    vitals = character.meta.vitals
    vitals = %{vitals | neili: min(vitals.neili, vitals.max_neili * 2)}
    character = put_vitals(character, vitals)

    conn
    |> put_session("exercise", nil)
    |> put_character(character)
    |> render(CommandView, "text", %{text: "你将真气压回丹田，站了起来。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp put_vitals(character, vitals),
    do: %{character | meta: Map.put(character.meta, :vitals, vitals)}

  # 每跳转化量（LPC exercise.c exercising/1），房间 exercise_improve 忽略
  defp neili_gain(stats) do
    unit = div(Stats.effective(stats, "force"), 5)

    max(1, 1 + div(unit, 2) + lpc_random(unit))
  end

  # LPC random(n) 返回 0..n-1；n<=0 时为 0
  defp lpc_random(n) when n > 0, do: :rand.uniform(n) - 1
  defp lpc_random(_), do: 0

  defp schedule_next(conn) do
    Process.send_after(
      self(),
      %Event{from_pid: self(), topic: "exercise/tick", data: %{}},
      @tick_interval
    )

    conn
  end
end
