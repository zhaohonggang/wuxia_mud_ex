defmodule Kantele.Character.PrepareCommand do
  @moduledoc """
  组合拳术与预备绝招：`prepare` / `备招`

  两种模式：
  1. 组合拳术（对照 LPC cmds/skill/prepare.c）：`prepare <拳术1> <拳术2>`、`prepare none`
     - `<拳术1>`/`<拳术2>` 为拳术种类（finger/hand/cuff/claw/strike/unarmed），
       需先通过 `enable` 将对应技能映射到该种类。
     - 组合合法性由 `Kantele.Combat.SkillCombos.valid_combine?/2` 判定（LPC
       `SKILL_D(skill)->valid_combine(other)` 等价），当前仅 `taiji-quan` 声明
       可与 `wudang-zhang`、`paiyun-shou` 组合。
  2. 预备绝招（D4 prepare_skill，对照 LPC `prepare <skill>`）：
     - `prepare <技能>` 查看当前预备
     - `prepare <技能> <绝招>` 预备指定绝招
     - `prepare <技能> none` 取消该技能预备
     - `prepare none` 取消全部预备
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Combat.SkillCombos
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

    # 显示已组合的拳术技能
    combos = Enum.filter(Stats.prepared(stats), fn {usage, _perform_id} ->
      usage in Map.keys(@valid_types)
    end)

    unarmed_text =
      if combos == [] do
        "你目前没有组合任何特殊拳术技能。\n使用 `prepare ?` 查看可组合种类。\n"
      else
        Enum.map(combos, fn {usage, skill_id} ->
          "  #{@valid_types[usage]} (#{usage}): #{skill_id}"
        end)
        |> Enum.join("\n")
        |> Kernel.<>("当前组合的拳术技能：\n")
        |> Kernel.<>("\n")
      end

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

    new_stats =
      Enum.reduce(Map.keys(Stats.prepared(stats)), stats, fn usage, s ->
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
    stats = conn.character.meta.stats

    skill1 = Stats.mapped(stats, type1)
    skill2 = Stats.mapped(stats, type2)

    cond do
      type1 == type2 ->
        error(conn, "不能组合同一种类的拳术。\n")

      is_nil(skill1) ->
        error(conn, "「#{type1}」尚未激发任何技能，无法组合。\n")

      is_nil(skill2) ->
        error(conn, "「#{type2}」尚未激发任何技能，无法组合。\n")

      not SkillCombos.valid_combine?(skill1, skill2) ->
        error(conn, "「#{skill1}」与「#{skill2}」不能组合。\n")

      true ->
        new_prepared =
          Map.put(Map.put(Stats.prepared(stats), type1, skill1), type2, skill2)

        new_stats = %{stats | prepared: new_prepared}

        conn
        |> put_character(%{conn.character | meta: %{conn.character.meta | stats: new_stats}})
        |> render(CommandView, "text", %{text: "完成技能准备：#{type1} -> #{skill1}，#{type2} -> #{skill2}\n"})
        |> prompt(CommandView, "prompt", %{})
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
            # D4: prepare_skill 门槛校验（对应 LPC prepare_skill notify_fail）
            case module.prepare_skill(skill, conn.character) do
              :ok ->
                case Map.get(module.perform_list(), arg2) do
                  nil ->
                    error(conn, "该技能没有名为 #{arg2} 的绝招。\n")

                  _perform_module ->
                    usage = infer_usage_from_skill(skill)

                    case Stats.prepare_perform(conn.character.meta.stats, usage, "#{skill}/#{arg2}") do
                      {:ok, new_stats} ->
                        conn
                        |> put_character(%{
                          conn.character
                          | meta: %{conn.character.meta | stats: new_stats}
                        })
                        |> render(CommandView, "text", %{text: "预备成功：#{usage} -> #{arg2}\n"})
                        |> prompt(CommandView, "prompt", %{})

                      {:error, reason} ->
                        error(conn, reason)
                    end
                end

              {:error, reason} ->
                error(conn, reason)
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
      nil ->
        "sword"

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
