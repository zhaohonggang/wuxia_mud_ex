defmodule Kantele.Util.TreeMap do
  @moduledoc """
  路径式嵌套 map（对应 `feature/treemap.c` 的 _query/_set/_delete）

  `parts` 是原子/字符串路径列表（如 `[:a, :b, :c]` 或 `["a", "b"]`），
  key 一致即可混用。语义忠实移植：

  - `query`：沿路径取最深命中值；若中途遇到非 map 即返回该值；路径缺失返回 nil
  - `set`：沿路径写入并自动创建缺失的中间 map（LPC 会先建 `%{下一key => 0}`）
  - `delete`：只剩最后一段时删除并返回 true；中间段非 map 时返回 false
  """

  @doc "取路径值（treemap _query）"
  def query(_map, []), do: nil

  def query(map, [head | rest]) when is_map(map) do
    case Map.get(map, head) do
      nil -> nil
      value when is_map(value) and rest != [] -> query(value, rest)
      value -> value
    end
  end

  def query(map, _parts), do: map

  @doc "写路径值（treemap _set），中间 map 自动创建，返回新 map"
  def set(map, [head], value) do
    Map.put(map, head, value)
  end

  def set(map, [head | rest], value) when is_map(map) do
    next =
      case Map.get(map, head) do
        m when is_map(m) and rest != [] -> m
        _ -> empty_at(rest)
      end

    Map.put(map, head, set(next, rest, value))
  end

  def set(map, _parts, _value), do: map

  @doc "删路径值（treemap _delete）；返回 `{new_map, success?}`"
  def delete(map, [head]), do: {Map.delete(map, head), true}

  def delete(map, [head | rest]) when is_map(map) do
    case Map.get(map, head) do
      m when is_map(m) ->
        {inner, result} = delete(m, rest)
        {Map.put(map, head, inner), result}

      _ ->
        {map, false}
    end
  end

  def delete(map, _parts), do: {map, false}

  # LPC: 中间缺失时建 `%{parts[1] => 0}`
  defp empty_at([next | _]), do: %{next => 0}
end
