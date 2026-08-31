defmodule Kantele.Item.Autoload do
  @moduledoc """
  人物重登装备自动装载（对应 `feature/autoload.c` from ES2/XKX）

  - `save/2`: 遍历背包 + hire 物品，收集 `query_autoload` 非 nil 的项
    （格式 `file` 或 `file:param`，param 取自 autoload 字段如 "worn"/"wielded"/"kept"）
  - `parse_entry/1`: 解析 ``file:param`` -> `%{file:, param:}`
  - `restore_plan/2`: 依据 autoload 表生成恢复计划（含 无克隆独占 过滤）

  纯逻辑；实际 clone/move/autoload 副作用由宿主执行。
  """

  @doc "save_autoload：由 inventory 列表生成 autoload 表"
  def save(inventory, opts \\ %{}) do
    hire = Map.get(opts, :hire, [])

    (inventory ++ hire)
    |> Enum.filter(&(Map.get(&1, :autoload) != nil))
    |> Enum.map(fn item ->
      base = Map.get(item, :file)
      param = Map.get(item, :autoload)
      if is_binary(param), do: "#{base}:#{param}", else: base
    end)
  end

  @doc "解析 ``file:param``（无冒号则 param=nil）"
  def parse_entry(entry) when is_binary(entry) do
    case String.split(entry, ":", parts: 2) do
      [file, param] -> %{file: file, param: param}
      [file] -> %{file: file, param: nil}
    end
  end

  def parse_entry(_), do: nil

  @doc """
  restore_autoload 决策层

  对每个 entry，依据文件是否存在/是否 no_clone 独占/是否属于我，
  决定动作：`{:restore, file, param}` | `{:drop, file}` | `{:skip, file}`。

  opts: `%{file_exists: fun, is_no_clone: fun, is_belong_me: fun, has_dropped: bool}`
  """
  def restore_plan(entries, opts) do
    has_dropped = Map.get(opts, :has_dropped, false)

    {plan, has_dropped} =
      Enum.reduce(entries, {[], has_dropped}, fn raw, {acc, dropped} ->
        case parse_entry(raw) do
          nil ->
            {acc, dropped}

          %{file: file} = entry ->
            exists = opts.file_exists.(file)
            no_clone = opts.is_no_clone.(file)
            env_of_obj = opts.obj_environment.(file)

            cond do
              not exists ->
                {acc, dropped}

              no_clone and env_of_obj != nil ->
                # 无克隆对象已存在（别处有环境）
                {put_drop(acc, file, dropped), set_dropped(dropped)}

              no_clone and not opts.is_belong_me.(file) ->
                {put_drop(acc, file, dropped), set_dropped(dropped)}

              true ->
                {acc ++ [restore_action(entry, no_clone)], dropped}
            end
        end
      end)

    {plan, has_dropped}
  end

  defp restore_action(entry, no_clone) do
    if no_clone do
      {:reuse, entry.file, entry.param}
    else
      {:clone, entry.file, entry.param}
    end
  end

  defp put_drop(acc, file, dropped) do
    if dropped do
      acc
    else
      acc ++ [{:drop, file}]
    end
  end

  defp set_dropped(true), do: true
  defp set_dropped(false), do: true
end
