defmodule Kantele.Character.AnimaoutCommand do
  @moduledoc """
  元婴出世命令：`animaout`

  对应 LPC `cmds/skill/animaout.c`：打通任督二脉后在安全地点闭关修炼元婴。
  LPC 是 `call_out` 循环，每轮 `add("learned_points", 1)`，9/10 概率原样续轮，
  1/10 概率掷 `random(40000) < con`；命中即 `set("animaout", 1)` +
  `add("max_jingli", 1500)` + 传闻。

  Ex 是一次性命令，每次调用等价于 LPC 的一轮循环。**判定抽成
  `try_animaout/2`**（可注入随机函数），既保留 LPC 的原始概率，又让
  `animaout` 这道前置可被定向测试覆盖 —— 此前本命令只打印「开始闭关」，
  从不写 `meta.env[:animaout]`，导致阎罗 `ask_zhuan` 的 `animaout` 门
  在 Ex 里永远为假。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Records
  alias Kantele.Communication

  @meditate_msgs [
    "你练精还虚，不住的提升自己的精力。\n",
    "你将精力化回元神，试图神游三界。\n",
    "你试图将元神逼出七窍，然后周游四处复又收回。\n",
    "你缓缓呼吸吐纳，将空气中水露皆收为己用。\n"
  ]

  def run(conn, _params) do
    character = conn.character
    vitals = character.meta.vitals

    cond do
      is_no_fight_room?(character.room_id) == false ->
        fail(conn, "这里不能战斗。\n")

      Combat.busy?(character.meta.combat) ->
        fail(conn, "你现在正忙着呢。\n")

      vitals.qi * 100 / max(vitals.max_qi, 1) < 90 ->
        fail(conn, "你现在的气太少了，无法静心闭关。\n")

      vitals.jing * 100 / max(vitals.max_jing, 1) < 90 ->
        fail(conn, "你现在的精太少了，无法静心闭关。\n")

      vitals.jingli * 100 / max(vitals.max_jingli, 1) < 90 ->
        fail(conn, "你现在的精力太少了，无法静心闭关。\n")

      vitals.max_jingli < 2000 ->
        fail(conn, "你觉得精力颇有不足，看来目前还难以修炼元婴出世。\n")

      true ->
        do_animaout(conn, character, vitals)
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  @doc """
  LPC `animaout.c:108-125` 的一轮判定。

  - `:continue` —— `random(10) != 0`（9/10）：继续闭关，无状态变化
  - `:meditate` —— 掷中 1/10 但 `random(40000) >= con`：练精还虚四选一
  - `:success`  —— 修成元婴出世，写出 `env[:animaout]`

  `rand` 注入形如 `fn n -> 1 end` 可强制走 `:success` 分支。
  """
  def try_animaout(character, rand \\ &:rand.uniform/1) do
    stats = Map.get(Map.get(character, :meta) || %{}, :stats) || %{}
    con = Map.get(stats, :con) || 0

    cond do
      rand.(10) != 1 -> :continue
      rand.(40_000) < con -> :success
      true -> :meditate
    end
  end

  defp is_no_fight_room?(room_id) do
    "no_fight" in Kantele.World.room_flags(room_id)
  end

  defp do_animaout(conn, character, vitals) do
    stats = character.meta.stats
    available_potential =
      (Map.get(stats, :potential) || 0) - (Map.get(stats, :learned_points) || 0)

    if available_potential < 1000 do
      fail(conn, "你的潜能不够，没法闭关修行以修炼元婴出世。\n")
    else
      character = %{character | meta: bump_learned_points(character.meta)}

      case try_animaout(character) do
        :success -> succeed(conn, character, vitals)
        :meditate -> meditate(conn, character)
        :continue -> meditate(conn, character)
      end
    end
  end

  @doc """
  LPC `me->set("animaout", 1)` + `me->add("max_jingli", 1500)` 的落地。
  抽成公开函数供定向测试覆盖（阎罗 `ask_zhuan` 依赖这个 env 标志）。
  """
  def grant_animaout(character, vitals) do
    meta = character.meta
    env = Map.put(meta.env || %{}, :animaout, true)

    new_vitals =
      case vitals do
        %{} -> Map.put(vitals, :max_jingli, (Map.get(vitals, :max_jingli) || 0) + 1500)
        _ -> vitals
      end

    %{character | meta: %{meta | env: env, vitals: new_vitals}}
  end

  defp succeed(conn, character, vitals) do
    character = grant_animaout(character, vitals)
    Records.save(character)

    Communication.announce(
      "rumor",
      "听说#{character.name}经过闭关苦修，终于修成正果，练得元婴出世。\n"
    )

    conn
    |> put_character(character)
    |> render(
      CommandView,
      "text",
      %{
        text:
          "只见你头上现出万朵金莲，光华四射，一时间麝香扑鼻、氤氲遍地！\n" <>
            "你觉得精力源源而生，忽然心如止水，如身出天际，无源无尽、登时大彻大悟。\n"
      }
    )
    |> prompt(CommandView, "prompt", %{})
  end

  defp meditate(conn, character) do
    conn
    |> put_character(character)
    |> render(
      CommandView,
      "text",
      %{
        text:
          "你盘膝坐下，开始冥神运功，闭关修行。\n" <> Enum.random(@meditate_msgs)
      }
    )
    |> prompt(CommandView, "prompt", %{})
  end

  defp bump_learned_points(%{stats: stats} = meta) when is_map(stats) do
    Map.put(meta, :stats, Map.put(stats, :learned_points, (Map.get(stats, :learned_points) || 0) + 1))
  end

  defp bump_learned_points(meta), do: meta

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
