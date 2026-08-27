defmodule Kantele.Character.ClosedCommand do
  @moduledoc """
  闭关修行：`closed` / `闭关`

  对应 LPC cmds/skill/closed.c：大宗师玩法。
  需潜能≥10000、qi/jing≥90%、sleep_room+no_fight 房间。
  周期消耗潜能增技能等级。

  注意：Kantele 当前没有 ultrap（大宗师）判定，本命令暂时为占位实现，
  检查基础条件后提示功能尚未完全开放。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  @min_potential 10_000

  def run(conn, _params) do
    character = conn.character
    vitals = character.meta.vitals
    stats = character.meta.stats
    family = Map.get(character.meta, :family)

    cond do
      Combat.busy?(character.meta.combat) ->
        fail(conn, "你现在正忙着呢。\n")

      Combat.fighting?(character.meta.combat) ->
        fail(conn, "战斗中不能闭关。\n")

      family == nil ->
        fail(conn, "你还没有拜师，无法闭关修行。\n")

      Stats.available_potential(stats) < @min_potential ->
        fail(conn, "你的潜能不够，没法闭关修行。（需要至少 10000 潜能）\n")

      qi_ratio(vitals) < 90 ->
        fail(conn, "你现在的气太少了，无法静心闭关。\n")

      jing_ratio(vitals) < 90 ->
        fail(conn, "你现在的精太少了，无法静心闭关。\n")

      not no_fight_room?(character.room_id) ->
        fail(conn, "在这里闭关？不太安全吧？\n")

      true ->
        # 占位：完整闭关系统需要 CLOSE_D 离线修行支持，本期暂提示
        fail(conn, "闭关修行功能尚未完全开放。大宗师闭关需要离线修行系统支持，请期待后续版本。\n")
    end
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp qi_ratio(%{qi: qi, max_qi: max_qi}) when max_qi > 0,
    do: div(qi * 100, max_qi)
  defp qi_ratio(_), do: 0

  defp jing_ratio(%{jing: jing, max_jing: max_jing}) when max_jing > 0,
    do: div(jing * 100, max_jing)
  defp jing_ratio(_), do: 0

  defp no_fight_room?(room_id) do
    "no_fight" in Kantele.World.room_flags(room_id)
  end
end
