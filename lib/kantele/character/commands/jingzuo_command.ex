defmodule Kantele.Character.JingzuoCommand do
  @moduledoc """
  静坐冥想：`jingzuo` / `静坐`

  对应 LPC cmds/skill/jingzuo.c：峨嵋派专属，需大乘般若功≥40。
  静坐 45-90 秒后获得 combat_exp + potential，消耗 jing。
  有冷却时间（120 秒）。

  注意：Kantele 当前没有 mahayana（大乘般若功）技能，
  本命令暂时改为通用版本（无门派限制），待 mahayana 技能添加后恢复门派校验。
  """

  use Kalevala.Character.Command

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  @cooldown_seconds 120
  @min_jing 50

  def run(conn, _params) do
    character = conn.character
    vitals = character.meta.vitals
    family = Map.get(character.meta, :family)

    cond do
      Combat.busy?(character.meta.combat) ->
        fail(conn, "你正忙着呢！\n")

      Combat.fighting?(character.meta.combat) ->
        fail(conn, "战斗中想静坐？你不要命啦！\n")

      family == nil or Map.get(family, :name) != "峨嵋派" ->
        fail(conn, "只有峨嵋派弟子才会静坐！\n")

      vitals.jing < @min_jing ->
        fail(conn, "你受伤太重，无法定心静坐。\n")

      no_fight_room?(character.room_id) ->
        fail(conn, "这里太纷杂，你没法安心静坐。\n")

      # LPC：query("jingzuo_time") 冷却检查
      on_cooldown?(character) ->
        fail(conn, "你刚才静坐过，现在头脑一片空白。\n")

      # LPC：query_skill("mahayana", 1) < 40（暂改为 force 等效 40）
      Stats.effective(character.meta.stats, "force") < 40 ->
        fail(conn, "你的内功修为还不够，没法静心静坐。\n")

      true ->
        start_jingzuo(conn, character)
    end
  end

  defp start_jingzuo(conn, character) do
    # 45-90 秒
    duration = :rand.uniform(46) + 44

    Process.send_after(
      self(),
      %Event{from_pid: self(), topic: "jingzuo/wakeup", data: %{}},
      duration * 1000
    )

    conn
    |> render(CommandView, "text", %{text: "你往床上盘膝一坐，开始静坐。\n不一会儿，你神游天外，物我两忘。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp on_cooldown?(character) do
    case Map.get(character.meta, :jingzuo_time) do
      nil -> false
      last -> System.system_time(:second) - last < @cooldown_seconds
    end
  end

  defp no_fight_room?(room_id) do
    "no_fight" in Kantele.World.room_flags(room_id)
  end
end
