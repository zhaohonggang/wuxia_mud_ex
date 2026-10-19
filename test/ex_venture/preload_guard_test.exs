defmodule ExVenture.PreloadGuardTest do
  use ExUnit.Case, async: true

  @moduledoc """
  护栏：禁止 `Repo.preload/2` 一次传多条顶层关联。

  `ecto` 3.6.2 的 `Ecto.Repo.Preloader.maybe_pmap/3` 在顶层 preload 条目 >= 2 时
  会调用 `adapter.checked_out?/1` 来决定能否并行加载，而本仓库锁定的 `ecto_sql`
  3.6.1 没有实现该回调（3.6.2 才补上），于是抛 `UndefinedFunctionError`，
  把调用方整个炸掉——`Zones.get/1` 和 `Rooms.get/1` 都踩过。

  规避方式是拆成多次单条 preload：

      Repo.preload(:staged_changes) |> Repo.preload(rooms: [:staged_changes])

  本测试扫描 `lib/` 下所有源码，防止有人再写出多条目形式。
  若将来把 `ecto_sql` 升到 >= 3.6.2，这条护栏即可删除。

  不在护栏范围：
  - `Ecto.Query.preload/3`（`Model |> preload([a, b]) |> Repo.all()`）走查询内
    join，不经过 `maybe_pmap/3`，多条目是安全的；
  - 变量形式的 `repo.preload(...)`（如 `ExVenture.StagedChanges`）不匹配；
  - preload 规格是变量而非字面量列表时无法静态判断。
  """

  @lib_root "lib"

  test "没有任何 Repo.preload 调用一次传多条顶层关联" do
    offenders =
      source_files()
      |> Enum.flat_map(fn path ->
        path
        |> preload_entry_counts()
        |> Enum.filter(fn {_line, count} -> count > 1 end)
        |> Enum.map(fn {line, count} -> "  #{path}:#{line} — #{count} 条顶层关联" end)
      end)

    assert offenders == [], """
    发现一次传多条顶层关联的 Repo.preload 调用：

    #{Enum.join(offenders, "\n")}

    请拆成多次单条 preload，例如：

        Repo.preload(:staged_changes) |> Repo.preload(rooms: [:staged_changes])

    原因见 docs/session-prompts-npc-actions-continuation.zh-CN.md 续做 50。
    """
  end

  defp source_files do
    "#{@lib_root}/**/*.ex"
    |> Path.wildcard()
    |> Enum.filter(&(File.read!(&1) =~ "Repo.preload"))
  end

  # 返回 [{行号, 该次调用的顶层 preload 条目数}]
  defp preload_entry_counts(path) do
    with {:ok, ast} <- Code.string_to_quoted(File.read!(path)) do
      {_, acc} =
        Macro.prewalk(ast, [], fn node, acc ->
          case preload_call(node) do
            {line, count} -> {node, [{line, count} | acc]}
            nil -> {node, acc}
          end
        end)

      Enum.reverse(acc)
    else
      _ -> []
    end
  end

  defp preload_call({{:., _, [{:__aliases__, _, [:Repo]}, :preload]}, meta, args})
       when is_list(args) do
    case preload_spec(args) do
      nil -> nil
      spec -> {Keyword.get(meta, :line, 0), length(spec)}
    end
  end

  defp preload_call(_), do: nil

  # 定位 preload 规格那个参数：管道形式 `x |> Repo.preload(spec, opts)` 时在第 0 位，
  # 直接调用 `Repo.preload(queryable, spec, opts)` 时在第 1 位。
  # 用「第 0 个参数是不是字面量列表」来区分，避免把 opts 误当成规格。
  defp preload_spec([first | _] = args) do
    cond do
      is_list(first) -> first
      match?([_, second | _] when is_list(second), args) -> Enum.at(args, 1)
      true -> nil
    end
  end

  defp preload_spec(_), do: nil
end
