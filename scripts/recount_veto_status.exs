alias Kantele.World.{Loader, LpcCondition}

world = Loader.load()

rows =
  for room <- world.rooms,
      veto <- room.exit_vetoes,
      cond_str = veto.condition,
      is_binary(cond_str) and cond_str != "" do
    all_dirs? = Map.get(veto, :all_dirs) == true

    status =
      cond do
        not match?({:ok, _}, LpcCondition.parse(cond_str)) -> "解析失败"
        all_dirs? -> "生效"
        not LpcCondition.direction_scoped?(cond_str) -> "跳过：未限定方向"
        not LpcCondition.supported?(cond_str) -> "跳过：缺运行时数据"
        not LpcCondition.enforceable?(cond_str) -> "跳过：未实现的函数"
        true -> "生效"
      end

    {status, room.id, cond_str, Map.get(veto, :direction)}
  end

IO.puts("条件总数: #{length(rows)}\n")

IO.puts("=== 跳过的 33 条（带房间 ID） ===")

rows
|> Enum.filter(fn {s, _, _, _} -> String.starts_with?(s, "跳过") end)
|> Enum.sort_by(fn {s, rid, _, _} -> {s, rid} end)
|> Enum.each(fn {s, rid, c, d} ->
  IO.puts("  [#{String.replace_prefix(s, "跳过：", "")}] #{rid} dir=#{inspect(d)}")
  IO.puts("        #{String.slice(c, 0, 76)}")
end)

IO.puts("\n=== 交叉统计（不管被哪道门拦下，只看条件内容） ===")

gender =
  Enum.filter(rows, fn {_, _, c, _} -> String.contains?(c, "gender") end)

custom =
  Enum.filter(rows, fn {_, _, c, _} ->
    String.contains?(c, "check_dirs") or String.contains?(c, "check_out") or
      String.contains?(c, "->refuse(")
  end)

this_player =
  Enum.filter(rows, fn {_, _, c, _} -> String.contains?(c, "this_player()") end)

IO.puts("  引用 gender 的条件: #{length(gender)}")
IO.puts("  调自定义函数的条件: #{length(custom)}")
IO.puts("    check_dirs: #{Enum.count(custom, fn {_, _, c, _} -> String.contains?(c, "check_dirs") end)}")
IO.puts("    check_out : #{Enum.count(custom, fn {_, _, c, _} -> String.contains?(c, "check_out") end)}")
IO.puts("    ob->refuse: #{Enum.count(custom, fn {_, _, c, _} -> String.contains?(c, "->refuse(") end)}")
IO.puts("  用 this_player() 的条件: #{length(this_player)}")

IO.puts("\n=== 按门分类 ===")

rows
|> Enum.group_by(&elem(&1, 0))
|> Enum.sort_by(fn {s, _} -> if s == "生效", do: 0, else: 1 end)
|> Enum.each(fn {s, items} -> IO.puts("  #{s}: #{length(items)}") end)