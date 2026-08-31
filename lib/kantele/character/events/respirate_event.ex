defmodule Kantele.Character.RespirateEvent do
  @moduledoc """
  吐纳心跳（对应 LPC respirate.c respirating/1 的 busy 循环）

  每 1s 一跳：jingli_gain = force/10 → 1 + gain/2 + random(gain)
  同时 jing -= gain, jingli += gain。
  预定精量耗尽后判定：

  - `jingli < 2×max_jingli` → 普通结束
  - `max_jingli ≥ jingli_limit` → 瓶颈，精力压回上限
  - 否则 `max_jingli + 1`（base 同步抬升）并落盘
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CharacterView
  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.Stats

  @tick_interval 1000

  def tick(conn, _event) do
    character = conn.character

    case get_session(conn, "respirate") do
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
    stats = character.meta.stats

    gain = jingli_gain(stats)
    gain = if gain > remaining, do: remaining, else: gain

    # 精不够本跳转化时：只转剩余的精，并立即结束
    {gain, remaining} =
      if gain > vitals.jing do
        {vitals.jing, 0}
      else
        {gain, remaining - gain}
      end

    vitals = %{vitals | jing: vitals.jing - gain, jingli: vitals.jingli + gain}
    character = put_vitals(character, vitals)

    if remaining > 0 and vitals.jing > 0 do
      conn
      |> put_session("respirate", %{remaining: remaining})
      |> put_character(character)
      |> schedule_next()
    else
      conn
      |> put_session("respirate", nil)
      |> put_character(character)
      |> finish(character)
    end
  end

  defp finish(conn, character) do
    vitals = character.meta.vitals

    # 精力上限 = jingli_limit（暂用 con×10 估算；后续可接入专门的 JingliLimit 模块）
    limit = jingli_limit(character.meta.stats)

    {vitals, text} =
      cond do
        vitals.jingli < vitals.max_jingli * 2 ->
          {vitals, "你吐纳完毕，睁开双眼，站了起来。\n"}

        vitals.max_jingli >= limit ->
          {%{vitals | jingli: vitals.max_jingli}, "你的精力修为似乎已经达到了瓶颈。\n"}

        true ->
          vitals = %{
            vitals
            | max_jingli: vitals.max_jingli + 1,
              jingli: vitals.max_jingli + 1
          }

          {vitals, "你的精力增加了！！\n"}
      end

    character = put_vitals(character, vitals)
    Records.save(character)

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
    |> render(CharacterView, "vitals")
  end

  # 战斗中被打断：精力不扣减（对应 LPC halt_respirate）
  defp interrupt(conn, character) do
    conn
    |> put_session("respirate", nil)
    |> render(CommandView, "text", %{text: "你将真气分压回丹田，站了起来。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp put_vitals(character, vitals),
    do: %{character | meta: Map.put(character.meta, :vitals, vitals)}

  # 每跳精力转化量（LPC respirate.c respirating/1）
  # jingli_gain = 1 + (force/10)/2 + random(force/10)
  defp jingli_gain(stats) do
    unit = div(Stats.effective(stats, "force"), 10)

    max(1, 1 + div(unit, 2) + lpc_random(unit))
  end

  # 精力上限（LPC query_current_jingli_limit）——暂用 con×10 估算
  defp jingli_limit(stats), do: stats.con * 10

  defp lpc_random(n) when n > 0, do: :rand.uniform(n) - 1
  defp lpc_random(_), do: 0

  defp schedule_next(conn) do
    Process.send_after(
      self(),
      %Event{from_pid: self(), topic: "respirate/tick", data: %{}},
      @tick_interval
    )

    conn
  end
end
