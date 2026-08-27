defmodule Kantele.Character.PrepareCommand do
  @moduledoc """
  组合拳术：`prepare` / `备招`

  对照 LPC cmds/skill/prepare.c。
  设置/取消组合拳术：`prepare finger strike`、`prepare none`

  注意：Kantele 当前仅有 liuxin-jian（剑法）和 liuxi-neigong（内功），
  均不属于拳术类（finger/hand/cuff/claw/strike/unarmed），此命令暂为占位实现。
  待拳术类技能添加后需补充 valid_combine 逻辑。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

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
        clear_preparation(conn)

      "?" ->
        show_available_types(conn)

      _ ->
        parse_and_prepare(conn, arg)
    end
  end

  defp show_current(conn) do
    # Kantele 暂未实现 prepare_skill 状态，显示提示
    text = "你目前没有组合任何特殊拳术技能。\n使用 `prepare ?` 查看可组合种类。\n"

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp clear_preparation(conn) do
    text = "取消全部技能准备。\n"

    conn
    |> render(CommandView, "text", %{text: text})
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
        try_prepare(conn, type1, type2)

      1 ->
        [type1] = parts
        try_prepare_single(conn, type1)

      _ ->
        error(conn, "指令格式：prepare [<技能名称一> <技能名称二>]\n")
    end
  end

  defp try_prepare(conn, type1, type2) do
    character = conn.character
    stats = character.meta.stats

    cond do
      type1 not in Map.keys(@valid_types) ->
        error(conn, "「#{type1}」不是有效的拳术种类。使用 `prepare ?` 查看可组合种类。\n")

      type2 not in Map.keys(@valid_types) ->
        error(conn, "「#{type2}」不是有效的拳术种类。使用 `prepare ?` 查看可组合种类。\n")

      type1 == type2 ->
        error(conn, "不能组合同一种类的拳术。\n")

      true ->
        # Kantele 暂未实现 valid_combine，显示占位提示
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

  defp error(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
