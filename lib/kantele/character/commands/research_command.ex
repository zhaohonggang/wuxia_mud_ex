defmodule Kantele.Character.ResearchCommand do
  @moduledoc """
  研修命令：`research|yanjiu <技能> [次数]`
  对应 LPC cmds/skill/research.c。
  研究技能的疑难问题，靠相关技能加成和悟性提升技能，需要 skill>=180 且非知识技能。
  消耗精力（jing）并消耗潜能（learned_points）。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Records
  alias Kantele.Character.Stats

  @max_times 100
  @min_skill_level 180
  @base_jing_cost_per_int 1000

  def run(conn, %{"arg" => arg}) do
    character = conn.character

    cond do
      Combat.busy?(character.meta.combat) ->
        fail(conn, "你现在正忙着呢。\n")

      true ->
        case parse_args(arg) do
          {:ok, skill_name, times} ->
            start_research(conn, character, skill_name, times)

          :error ->
            fail(conn, "research|yanjiu <技能> <次数>\n")
        end
    end
  end

  def run(conn, %{}) do
    fail(conn, "research|yanjiu <技能> <次数>\n")
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  @impl true
  def yanjiu_run(conn, params) do
    run(conn, params)
  end

  defp parse_args(arg) do
    parts = String.split(String.trim(arg || ""), ~r/\s+/, parts: 2)
    skill_name = Enum.at(parts, 0, "")
    times_str = Enum.at(parts, 1, "1")

    if skill_name == "" do
      :error
    else
      times = case Integer.parse(times_str) do
        {n, _} -> n
        :error -> 1
      end
      {:ok, skill_name, times}
    end
  end

  defp start_research(conn, character, skill_name, times) do
    stats = character.meta.stats
    vitals = character.meta.vitals

    if times < 1 or times > @max_times do
      fail(conn, "研究次数最少一次，最多也不能超过一百次。\n")
    else
      skill_id = canonical_skill_name(skill_name)
      skill_level = Stats.skill(stats, skill_id)

      cond do
        skill_level < @min_skill_level ->
          fail(conn, "你对#{chinese_skill(skill_id)}的掌握程度还未到研究的程度。\n")

        true ->
          do_research(conn, character, skill_id, times)
      end
    end
  end

  defp do_research(conn, character, skill_id, requested_times) do
    stats = character.meta.stats
    vitals = character.meta.vitals
    jing_cost_per = max(div(@base_jing_cost_per_int, max(stats.int, 1)), 10)

    # Related skill bonuses
    related_bonus = compute_related_bonus(stats, skill_id)

    # Scale formula
    skill_level = Stats.skill(stats, skill_id)

    improve_per =
      if skill_level >= 500 do
        div(related_bonus, 2)
      else
        related_bonus
      end

    improve = max(div(improve_per, 15 * 100), 1)

    # Intelligence bonus
    improve =
      if skill_level >= 500 do
        improve + div(skill_level, 50) + :rand.uniform(div(stats.int, 6))
      else
        improve + div(skill_level, 50) + :rand.uniform(div(stats.int, 12))
      end

    # Cap at learned_points availability
    available = Stats.available_potential(stats)

    times = min(requested_times, available)

    if times < 1 do
      fail(conn, "你的潜能不够研究这么多次了。\n")
    else
      {stats, vitals, times_done, _improve} =
        Enum.reduce_while(1..times, {stats, vitals, 0, improve}, fn _i, {stats, vitals, acc, imp} ->
          jing = vitals.jing

          if jing < jing_cost_per do
            {:halt, {stats, vitals, acc, imp}}
          else
            vitals = %{vitals | jing: jing - jing_cost_per}
            stats = Stats.spend_potential(stats, 1)
            {stats, _} = Stats.improve_skill(stats, skill_id)
            {:cont, {stats, vitals, acc + 1, imp}}
          end
        end)

      new_character = %{character | meta: %{character.meta | stats: stats, vitals: vitals}}
      new_conn = put_character(conn, new_character)

      cond do
        times_done == 0 ->
          fail(conn, "你今天太累了，结果什么也没有研究成。\n")

        times_done < requested_times ->
          text = "你觉得太累了，研究了#{chinese_number(times_done)}次后只好停下来休息。\n"
          new_conn |> render(CommandView, "text", %{text: text}) |> prompt(CommandView, "prompt", %{}) |> save()

        true ->
          text = "你研究了一会儿，似乎对「#{chinese_skill(skill_id)}」有些新的领悟。\n"
          new_conn |> render(CommandView, "text", %{text: text}) |> prompt(CommandView, "prompt", %{}) |> save()
      end
    end
  end

  defp compute_related_bonus(stats, skill_id) do
    skill_ids = Map.keys(stats.skills)

    Enum.reduce(skill_ids, 0, fn other_id, acc ->
      if other_id == skill_id do
        acc
      else
        other_level = Stats.skill(stats, other_id)

        if other_level > 0 do
          acc + other_level
        else
          acc
        end
      end
    end)
  end

  defp canonical_skill_name(name) do
    String.downcase(String.trim(name))
  end

  defp chinese_skill("force"), do: "内功"
  defp chinese_skill("sword"), do: "剑法"
  defp chinese_skill("dodge"), do: "轻功"
  defp chinese_skill("parry"), do: "招架"
  defp chinese_skill("unarmed"), do: "拳脚"
  defp chinese_skill("strike"), do: "掌法"
  defp chinese_skill("cuff"), do: "拳法"
  defp chinese_skill("finger"), do: "指法"
  defp chinese_skill("hand"), do: "手法"
  defp chinese_skill("claw"), do: "爪法"
  defp chinese_skill("blade"), do: "刀法"
  defp chinese_skill("staff"), do: "杖法"
  defp chinese_skill("whip"), do: "鞭法"
  defp chinese_skill("literate"), do: "读书"
  defp chinese_skill("magic"), do: "魔法"
  defp chinese_skill(s), do: s

  defp chinese_number(1), do: "一"
  defp chinese_number(2), do: "二"
  defp chinese_number(3), do: "三"
  defp chinese_number(4), do: "四"
  defp chinese_number(5), do: "五"
  defp chinese_number(6), do: "六"
  defp chinese_number(7), do: "七"
  defp chinese_number(8), do: "八"
  defp chinese_number(9), do: "九"
  defp chinese_number(10), do: "十"
  defp chinese_number(n) when n > 10 and n <= 19, do: "十" <> chinese_number(n - 10)
  defp chinese_number(n) when n >= 20, do: "#{div(n, 10)}十" <> chinese_number(rem(n, 10))
  defp chinese_number(n), do: to_string(n)

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Records.save(conn.character)
    conn
  end
end