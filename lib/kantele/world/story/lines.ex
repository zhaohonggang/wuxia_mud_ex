defmodule Kantele.World.Story.Lines do
  @moduledoc """
  普通逐行剧情的最小样板：把文案列表转成 `step/2` 推进，支持行内 `$N`/`$ID`/`$F` 替换。
  """

  alias Kantele.World.Story.Behaviour

  @doc """
  按 `index` 推进 `lines` 中的条目：

  - 字符串：`{:text, substituted, inner}`
  - `{:action, fun}`：`{:action, fun, inner}`
  - 越界：`{:done, inner}`

  替换模板来自 `inner`（如 `%{name: "..."}`），供 `$N`/`$ID`/`$F` 使用。
  """
  def step_lines(lines, index, inner, replacements \\ %{}) do
    case Enum.at(lines, index) do
      nil ->
        {:done, inner}

      entry when is_binary(entry) ->
        {:text, substitute(entry, inner, replacements), inner}

      {:action, fun} ->
        {:action, fun, inner}

      fun when is_function(fun, 0) ->
        {:action, fun, inner}
    end
  end

  @doc "把文案中的 $N/$ID/$F 按 inner 替换（对应 LPC replace_string）"
  def substitute(text, inner, replacements) do
    text
    |> String.replace("$N", Map.get(inner, :name, Map.get(replacements, :name, "路人甲")))
    |> String.replace("$ID", Map.get(inner, :id, Map.get(replacements, :id, "none")))
    |> String.replace("$F", Map.get(inner, :family, Map.get(replacements, :family, "无名")))
  end
end