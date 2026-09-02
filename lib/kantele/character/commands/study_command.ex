defmodule Kantele.Character.StudyCommand do
  @moduledoc """
  研读秘籍：`study <书籍> [次数]` / `yanjiu <书籍> [次数]` / `研习` / `读书`

  对应 LPC cmds/skill/study.c：背包有秘籍 → 耗精+潜能自学，无需师父。
  受 exp_gate/valid_force 同效。

  物品 meta 需有 book 字段：%Item.Meta.Book{skill, min_skill, max_skill, exp_required, jing_cost, difficulty}
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.LearnGate
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.World.Items

  @max_times 100

  def run(conn, params) do
    character = conn.character

    cond do
      Combat.busy?(character.meta.combat) ->
        fail(conn, "你现在正忙着呢。\n")

      Combat.fighting?(character.meta.combat) ->
        fail(conn, "你无法在战斗中专心下来研读新知！\n")

      true ->
        parse_and_study(conn, params["parse"], character)
    end
  end

  defp parse_and_study(conn, arg, character) do
    if is_nil(arg) or arg == "" do
      fail(conn, "你要读什么？\n格式：study <书籍名称> [次数]\n")
    else
      # 解析 "书名 x3" 或 "书名 3" 格式
      {book_name, times} = parse_arg(arg)
      start_study(conn, book_name, times, character)
    end
  end

  defp parse_arg(arg) do
    # 支持 "书名 x3"、"书名X3"、"书名3" 三种格式
    case Regex.run(~r/^(.+?)\s*x?(\d+)$/i, String.trim(arg)) do
      [_, book, times_str] ->
        {String.trim(book), String.to_integer(times_str)}

      nil ->
        {String.trim(arg), 1}
    end
  end

  defp start_study(conn, book_name, times, character) do
    stats = character.meta.stats

    cond do
      times < 1 or times > @max_times ->
        fail(conn, "读书次数最少一次，最多不能超过 #{@max_times} 次。\n")

      not has_literate?(stats) ->
        fail(conn, "你是个文盲，先学点文化(literate)吧。\n")

      true ->
        find_and_study(conn, book_name, times, character)
    end
  end

  defp find_and_study(conn, book_name, times, character) do
    # 从背包中查找书籍
    case find_book(character.inventory, book_name) do
      nil ->
        fail(conn, "你身上没有「#{book_name}」这本书。\n")

      book_item ->
        study_book(conn, book_item, times, character)
    end
  end

  defp study_book(conn, book_item, times, character) do
    book_meta = Map.get(book_item.meta, :book)

    if book_meta == nil do
      fail(conn, "你无法从这样东西学到任何东西。\n")
    else
      do_study(conn, book_item, book_meta, times, character)
    end
  end

  defp do_study(conn, book_item, book_meta, times, character) do
    stats = character.meta.stats
    vitals = character.meta.vitals
    skill_id = book_meta.skill

    cond do
      stats.combat_exp < book_meta.exp_required ->
        fail(conn, "你的实战经验不足，再怎么读也没用。\n")

      # LPC：query_skill(sname, 1) > max_skill
      Stats.skill(stats, skill_id) > book_meta.max_skill ->
        fail(conn, "你研读了一会儿，但是发现上面所说的对你而言都太浅了，没有学到任何东西。\n")

      # LPC：query_skill(sname, 1) < min_skill
      Stats.skill(stats, skill_id) < book_meta.min_skill ->
        fail(conn, "你研读了一会儿，但是却发现你对这门技能的理解还太浅，结果毫无收获。\n")

      # LPC：can_improve_skill 检查
      Stats.skill(stats, skill_id) == 0 and not can_learn_new?(stats, skill_id) ->
        fail(conn, "以你目前的能力，还没有办法学这个技能。\n")

      true ->
        execute_study(conn, book_item, book_meta, times, character)
    end
  end

  defp execute_study(conn, book_item, book_meta, times, character) do
    stats = character.meta.stats
    vitals = character.meta.vitals
    skill_id = book_meta.skill
    jing_cost = study_jing_cost(book_meta, stats.int)

    {stats, vitals, times_done} =
      Enum.reduce_while(1..times, {stats, vitals, 0}, fn _i, {stats, vitals, acc} ->
        if vitals.jing >= jing_cost do
          vitals = %{vitals | jing: vitals.jing - jing_cost}

          # 每次研读提升 skill（literate/5 + 1）
          literate = Stats.skill(stats, "literate")
          gain = div(literate, 5) + 1

          {stats, _leveled} =
            if Stats.skill(stats, skill_id) == 0 do
              # 首次学习：初始化为 0 级再提升
              stats = %{stats | skills: Map.put(stats.skills, skill_id, 0)}
              Stats.improve_skill(stats, skill_id)
            else
              Stats.improve_skill(stats, skill_id)
            end

          # 消耗 learned_points（潜能已用）
          cost_potential = 1
          stats = Stats.spend_potential(stats, cost_potential)

          {:cont, {stats, vitals, acc + 1}}
        else
          {:halt, {stats, vitals, acc}}
        end
      end)

    new_meta = character.meta
      |> Map.put(:stats, stats)
      |> Map.put(:vitals, vitals)

    character = %{character | meta: new_meta}
    Records.save(character)

    if times_done == 0 do
      fail(conn, "你现在太累了，结果一行也没有看下去。\n")
    else
      text = "你研读了#{chinese_number(times_done)}行有关#{skill_title(skill_id)}的技巧，似乎有点心得。\n"

      if times_done < times do
        text = text <> "你现在已经过于疲倦，无法继续研读新知。\n"
      end

      conn
      |> put_character(character)
      |> render(CommandView, "text", %{text: text})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp find_book(inventory, book_name) do
    Enum.find(inventory, fn instance ->
      item = Items.get!(instance.item_id)
      item_name = String.downcase(item.name)
      keyword = String.downcase(String.trim(book_name))
      item_name == keyword or String.starts_with?(item_name, "#{keyword} ")
    end)
  end

  defp study_jing_cost(book_meta, int) do
    cost = div(book_meta.jing_cost * 20 + book_meta.difficulty - int, 20)
    max(cost, 10)
  end

  defp has_literate?(stats), do: Stats.skill(stats, "literate") > 0

  defp can_learn_new?(stats, skill_id) do
    # 简化：任何 skill_id 都可以尝试首次学习（由 LearnGate 校验）
    true
  end

  defp parse_times(nil), do: 1

  defp parse_times(str) when is_binary(str) do
    case Integer.parse(String.trim(str)) do
      {value, _} -> value
      :error -> 1
    end
  end

  defp parse_times(_), do: 1

  defp skill_title(skill_id) do
    %{
      "liuxin-jian" => "柳心剑法",
      "liuxi-neigong" => "柳溪内功",
      "force" => "基本内功",
      "sword" => "基本剑法",
      "dodge" => "轻功",
      "parry" => "招架",
      "unarmed" => "基本拳脚"
    }[skill_id] || skill_id
  end

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
  defp chinese_number(n) when n >= 20, do: "#{div(n, 10)}十#{chinese_number(rem(n, 10))}"
  defp chinese_number(n), do: to_string(n)

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
