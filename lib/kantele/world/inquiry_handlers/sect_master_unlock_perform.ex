defmodule Kantele.World.InquiryHandlers.SectMasterUnlockPerform do
  @moduledoc """
  门派师父以潜能解锁绝招变式（`kind = "sect_master_unlock_perform"`）。

  移植 `kungfu/class/huashan/feng.c accept_ask` 的独孤九剑八破式：先会独孤九剑，
  再问具体破式；潜能余量不足则清空 `learned_points` 并回「潜能不够」；
  余量足够则扣 10 点，`random(2)` 半数只回「颇有心得」不授予，另一半授予
  `dugu-jiujian/po` 并提升 sword / dugu-jiujian / martial-cognize。

  > 与 LPC 的已知差异：原版按武器类型在 `can_perform/dugu-jiujian` 数组里逐项
  > 记录（破剑式/破刀式…），Elixir 的 `dugu-jiujian/po` 以 `perform_known?`
  > 代理（见该 perform 模块 moduledoc）。因此首次任一破式即授予完整「总破式」，
  > 不逐类型细分；此项已登记 GAP #743，不静默简化。

  ## UCL 配置

      value = {
        kind = "sect_master_unlock_perform"
        perform_id = "dugu-jiujian/po"
        skill = "dugu-jiujian"
        min_potential = 10
        random_success = true       # 测试可设 false 走确定性成功分支
        learned = "你学会了独孤九剑之「破剑式」。\n"
      }
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4, put_character: 2]

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.SectMaster

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    cond do
      not is_binary(Map.get(config, "perform_id")) ->
        conn

      Map.get(data, :asker_id) != character.id ->
        conn

      true ->
        run_for(conn, character, config)
    end
  end

  def run(conn, _config, _data), do: conn

  defp run_for(conn, character, config) do
    case SectMaster.unlock_perform(character.meta.stats, config) do
      {:error, msg} ->
        reply(conn, msg)

      {:exhausted, msg} ->
        stats = %{character.meta.stats | learned_points: stats_value(character.meta.stats, :potential)}
        save_and_reply(conn, character, stats, msg)

      {:ok, perform_id, learned_points} ->
        stats =
          character.meta.stats
          |> Map.put(:learned_points, learned_points)
          |> Stats.learn_perform(perform_id)

        if random_success?(config) and :rand.uniform(2) == 1 do
          save_and_reply(
            conn,
            character,
            stats,
            Map.get(config, "random_fail") || "你听了风清扬的教导，颇有心得。\n"
          )
        else
          stats = improve_all(stats, Map.get(config, "improve_skills") || [])
          text = Map.get(config, "learned") || "你学会了这一式。\n"
          save_and_reply(conn, character, stats, text)
        end
    end
  end

  defp improve_all(stats, skills) when is_list(skills) do
    Enum.reduce(skills, stats, fn skill, acc ->
      {acc, _improved?} = Stats.improve_skill(acc, skill)
      acc
    end)
  end

  defp random_success?(config) do
    case Map.get(config, "random_success") do
      false -> false
      "false" -> false
      _ -> true
    end
  end

  defp stats_value(stats, key) do
    value = Map.get(stats, key)
    if is_integer(value), do: value, else: 0
  end

  defp save_and_reply(conn, character, stats, text) do
    character = %{character | meta: %{character.meta | stats: stats}}
    Records.save(character)

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
