defmodule Kantele.Character.PrepareCommand do
  @moduledoc """
  组合拳术与预备绝招：`prepare` / `备招`

  两种模式：
  1. 组合拳术（对照 LPC cmds/skill/prepare.c）：`prepare <拳术1> <拳术2>`、`prepare none`
  2. 预备绝招（D4 prepare_skill，对照 LPC `prepare <skill>`）：
     - `prepare <技能>` 查看当前预备
     - `prepare <技能> <绝招>` 预备指定绝招
     - `prepare <技能> none` 取消该技能预备
     - `prepare none` 取消全部预备

  注意：Kantele 当前仅有 liuxin-jian（剑法）和 liuxi-neigong（内功），
  均不属于拳术类（finger/hand/cuff/claw/strike/unarmed），
  此命令拳术组合部分暂为占位实现。
  待拳术类技能添加后需补充 valid_combine 逻辑。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  @valid_types %{
    "finger" => "指法",
    "hand" => "手法",
    "cuff" => "拳法",
    "claw" => "爪法",
    "strike" => "掌法",
    "unarmed" => "拳脚"
  }

  def run(conn, params) do
    arg = String.trim(params["action"] || "")

    case arg do
      "" ->
        show_current(conn)

      "none" ->
        clear_all_preparation(conn)

      "?" ->
        show_available_types(conn)

      _ ->
        parse_and_prepare(conn, arg)
    end
  end

  defp show_current(conn) do
    stats = conn.character.meta.stats

    # 显示拳术组合（占位）
    unarmed_text = "你目前没有组合任何特殊拳术技能。\n使用 `prepare ?` 查看可组合种类。\n"

    # 显示绝招预备状态
    prepare_text = 
      if map_size(Stats.prepared(stats)) == 0 do
        "当前没有预备任何绝招。\n"
      else
        Enum.map(Stats.prepared(stats), fn {usage, perform_id} ->
          "  #{usage}: #{perform_id}"
        end)
        |> Enum.join("\n")
        |> Kernel.<>("当前预备的绝招：\n")
        |> Kernel.<>("\n")
      end

    text = unarmed_text <> "\n" <> prepare_text

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp clear_all_preparation(conn) do
    stats = conn.character.meta.stats
    new_stats = Enum.reduce(Map.keys(Stats.prepared(stats)), stats, fn usage, s ->
      Stats.unprepare_perform(s, usage)
    end)

    conn
    |> put_character(%{conn.character | meta: %{conn.character.meta | stats: new_stats}})
    |> render(CommandView, "text", %{text: "取消全部技能预备。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp show_available_types(conn) do
    types_str =
      @valid_types
      |> Enum.sort_by(fn {_, name} -> name end)
      |> Enum.map(fn {id, name} -> "  #{name} (#{id})" end)
      |> Enum.join("\n")

    text = "以下是可使用特殊拳术技能的种类：\n#{types_str}\n"

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp parse_and_prepare(conn, arg) do
    parts = String.split(arg)

    case length(parts) do
      2 ->
        [type1, type2] = parts

        # 检查是否是拳术组合
        if type1 in Map.keys(@valid_types) and type2 in Map.keys(@valid_types) do
          try_prepare(conn, type1, type2)
        else
          try_prepare_skill(conn, type1, type2)
        end

      1 ->
        [arg1] = parts

        cond do
          arg1 == "none" ->
            clear_all_preparation(conn)

          arg1 in Map.keys(@valid_types) ->
            try_prepare_single(conn, arg1)

          Skills.known?(arg1) ->
            try_show_skill_prepare(conn, arg1)

          true ->
            error(conn, "「#{arg1}」不是有效的拳术种类。使用 `prepare ?` 查看可组合种类。\n")
        end

      _ ->
        error(conn, "指令格式：prepare [<技能> <绝招> | <拳术1> <拳术2> | <技能> | none | ?]\n")
    end
  end

  defp try_prepare(conn, type1, type2) do
    cond do
      type1 not in Map.keys(@valid_types) ->
        error(conn, "「#{type1}」不是有效的拳术种类。使用 `prepare ?` 查看可组合种类。\n")

      type2 not in Map.keys(@valid_types) ->
        error(conn, "「#{type2}」不是有效的拳术种类。使用 `prepare ?` 查看可组合种类。\n")

      type1 == type2 ->
        error(conn, "不能组合同一种类的拳术。\n")

      true ->
        error(conn, "这两种拳术技能暂未实装组合逻辑（Kantele 待添加拳术类技能后完善）。\n")
    end
  end

  defp try_prepare_single(conn, type) do
    if type in Map.keys(@valid_types) do
      error(conn, "「#{type}」需要指定第二种拳术来组合。格式：prepare #{type} <第二种类>\n")
    else
      error(conn, "「#{type}」不是有效的拳术种类。使用 `prepare ?` 查看可组合种类。\n")
    end
  end

  # === D4: 绝招预备相关函数 ===

  defp try_prepare_skill(conn, skill, arg2) do
    cond do
      not Skills.known?(skill) ->
        error(conn, "未知的技能：#{skill}\n")

      arg2 == "none" ->
        clear_skill_preparation(conn, skill)

      true ->
        case Skills.get(skill) do
          nil ->
            error(conn, "该技能未实装绝招列表。\n")

          module ->
            case Map.get(module.perform_list(), arg2) do
              nil ->
                error(conn, "该技能没有名为 #{arg2} 的绝招。\n")

              _perform_module ->
                usage = infer_usage_from_skill(skill)

                case Stats.prepare_perform(conn.character.meta.stats, usage, "#{skill}/#{arg2}") do
                  {:ok, new_stats} ->
                    conn
                    |> put_character(%{conn.character | meta: %{conn.character.meta | stats: new_stats}})
                    |> render(CommandView, "text", %{text: "预备成功：#{usage} -> #{arg2}\n"})
                    |> prompt(CommandView, "prompt", %{})
                  {:error, reason} ->
                    error(conn, reason)
                end
            end
        end
    end
  end

  defp clear_skill_preparation(conn, skill) do
    stats = conn.character.meta.stats

    new_stats =
      Stats.prepared(stats)
      |> Enum.filter(fn {_usage, perform_id} -> String.starts_with?(perform_id, "#{skill}/") end)
      |> Enum.reduce(stats, fn {usage, _perform_id}, s -> Stats.unprepare_perform(s, usage) end)

    conn
    |> put_character(%{conn.character | meta: %{conn.character.meta | stats: new_stats}})
    |> render(CommandView, "text", %{text: "已取消 #{skill} 的预备。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp try_show_skill_prepare(conn, skill) do
    stats = conn.character.meta.stats
    prepared = Stats.prepared(stats)

    skill_prepared =
      Enum.filter(prepared, fn {_usage, perform_id} ->
        String.starts_with?(perform_id, "#{skill}/")
      end)

    text =
      if skill_prepared == [] do
        "技能 #{skill} 当前没有预备任何绝招。\n"
      else
        Enum.map(skill_prepared, fn {usage, perform_id} ->
          "  #{usage}: #{perform_id}"
        end)
        |> Enum.join("\n")
        |> Kernel.<>("技能 #{skill} 当前预备的绝招：\n")
        |> Kernel.<>("\n")
      end

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  @usages ~w(sword blade whip staff club hammer spear finger hand cuff claw strike unarmed force parry dodge)

  defp infer_usage_from_skill(skill) do
    case Skills.get(skill) do
      nil -> "sword"
      module ->
        case Enum.find(@usages, &valid_enable?(module, &1)) do
          nil -> "sword"
          usage -> usage
        end
    end
  end

  defp valid_enable?(module, usage) do
    Code.ensure_loaded?(module) and function_exported?(module, :valid_enable, 1) and
      module.valid_enable(usage)
  end

  defp error(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end