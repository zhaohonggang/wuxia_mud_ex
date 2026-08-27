defmodule Kantele.Character.Aliases do
  @moduledoc """
  玩家自定义命令别名的展开（cmds/usr/alias.c）

  `expand/2` 把输入文本开头的动词用 `alias_commands` 映射替换，
  模板中 `$1`/`$2`…/`$*` 占位由别名尾随参数代入后交给命令路由器。
  无占位的模板则整串替换（忽略尾参）。
  """

  @doc """
  展开输入文本开头的别名动词。

  返回 `{expanded_text, expanded?}`：无别名匹配时原样返回。
  """
  def expand(text, alias_map) when is_map(alias_map) and map_size(alias_map) == 0 do
    {text, false}
  end

  def expand(text, alias_map) when is_binary(text) do
    case split_verb(text) do
      nil ->
        {text, false}

      {verb, trailing} ->
        case Map.get(alias_map, verb) do
          nil -> {text, false}
          template -> {substitute(template, trailing), true}
        end
    end
  end

  def expand(text, _alias_map), do: {text, false}

  defp split_verb(text) do
    case String.trim(text) |> String.split(~r/\s+/, parts: 2) do
      [verb] -> {verb, ""}
      [verb, trailing] -> {verb, trailing}
    end
  end

  defp substitute(template, trailing) do
    trimmed = String.trim(trailing)

    cond do
      String.contains?(template, "$*") ->
        String.replace(template, "$*", trimmed)

      String.contains?(template, "$") ->
        args = if trimmed == "", do: [], else: String.split(trimmed, ~r/\s+/)
        substitute_args(template, args)

      true ->
        template
    end
  end

  defp substitute_args(template, args, n \\ 1)

  defp substitute_args(template, _args, n) when n > 20, do: template

  defp substitute_args(template, args, n) do
    case Enum.at(args, n - 1) do
      nil ->
        template

      arg ->
        template
        |> String.replace("$#{n}", arg)
        |> substitute_args(args, n + 1)
    end
  end
end
