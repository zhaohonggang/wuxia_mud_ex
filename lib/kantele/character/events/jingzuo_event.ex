defmodule Kantele.Character.JingzuoEvent do
  @moduledoc """
  静坐醒来事件（对应 LPC jingzuo.c wakeup/2）

  静坐 45-90 秒后自动触发：消耗 jing，获得 combat_exp + potential。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kantele.Character.CharacterView
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.Stats

  def wakeup(conn, _event) do
    character = conn.character
    stats = character.meta.stats
    vitals = character.meta.vitals

    skillslvl = Stats.effective(stats, "force")
    exppot = div(stats.combat_exp, 100_000)
    intpot = div(stats.int, 10)

    skillslvl =
      cond do
        skillslvl > 100 -> div(skillslvl - 100, 2) + 100
        true -> skillslvl
      end

    exppot =
      cond do
        exppot > 150 -> div(exppot - 150, 4) + 100
        exppot > 50 -> div(exppot - 50, 2) + 50
        true -> exppot
      end

    addp = div(:rand.uniform(max(skillslvl, 1)), 5) + intpot
    addc = div(:rand.uniform(max(skillslvl, 1)), 3) + exppot

    vitals = Vitals.damage(vitals, :jing, 15)
    character = Map.put(character.meta, :vitals, vitals)

    stats = %{stats | potential: stats.potential + addp, combat_exp: stats.combat_exp + addc}
    character = Map.put(character, :meta, Map.put(character.meta, :stats, stats))

    # 记录静坐时间戳
    character =
      Map.put(
        character,
        :meta,
        Map.put(character.meta, :jingzuo_time, System.system_time(:second))
      )

    Records.save(character)

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: "你静坐完毕，缓缓睁眼，长长吐了一口气。\n你静坐完毕，感觉到好累。\n"})
    |> prompt(CommandView, "prompt", %{})
    |> render(CharacterView, "vitals")
  end
end
