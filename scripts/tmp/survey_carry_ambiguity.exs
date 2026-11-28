# UG-06 survey 2: 未解 carry 引用的歧义度分析
# 用法: mix run --no-start scripts/tmp/survey_carry_ambiguity.exs
alias Kantele.World.Loader

world = Loader.load()

# 每个 zone 的 items key 集合
zone_item_keys =
  Map.new(world.zones, fn zone ->
    keys = MapSet.new(Enum.map(zone.items || [], fn it -> String.split(it.id, ":", parts: 2) |> List.last() end))
    {zone.id, keys}
  end)

clone_keys = Map.get(zone_item_keys, "clone_lib", MapSet.new())

raw_refs =
  world.characters
  |> Enum.flat_map(fn char ->
    meta = char.meta
    carry = (is_struct(meta) and meta.carry) || (is_map(meta) and Map.get(meta, :carry)) || []

    carry
    |> Enum.filter(&is_binary/1)
    |> Enum.reject(&String.contains?(&1, ":"))
    |> Enum.map(fn ref ->
      zone = (is_struct(meta) and meta.zone_id) || (is_map(meta) and Map.get(meta, :zone_id)) || "?"
      {zone, char.name, ref}
    end)
  end)

keys =
  raw_refs
  |> Enum.map(fn {_, _, ref} ->
    case String.split(ref, ".") do
      ["items", key, "id"] -> key
      _ -> nil
    end
  end)
  |> Enum.reject(&is_nil/1)
  |> Enum.uniq()
  |> Enum.sort()

IO.puts("distinct failing keys: #{length(keys)}")

stats =
  Enum.map(keys, fn key ->
    defining =
      Enum.filter(zone_item_keys, fn {zid, ks} -> zid != "clone_lib" and MapSet.member?(ks, key) end)
      |> Enum.map(&elem(&1, 0))

    {key, defining}
  end)

uniq = Enum.filter(stats, fn {_, d} -> length(d) == 1 end)
multi = Enum.filter(stats, fn {_, d} -> length(d) > 1 end)
none = Enum.filter(stats, fn {_, d} -> d == [] end)

IO.puts("unique defining zone: #{length(uniq)}")
IO.puts("multiple defining zones: #{length(multi)}")
IO.puts("no defining zone (incl. clone-only?): #{length(none)}")

IO.puts("\n-- unique (可直接回退) 样例 --")
Enum.take(uniq, 10) |> Enum.each(fn {k, d} -> IO.puts("#{k} -> #{hd(d)}") end)

IO.puts("\n-- ambiguous (歧义) 全量 --")
Enum.each(multi, fn {k, d} -> IO.puts("#{k} -> #{Enum.join(d, ", ")}") end)

IO.puts("\n-- nowhere (任何 zone 都没有) 全量 --")
Enum.each(none, fn {k, _} ->
  in_clone = MapSet.member?(clone_keys, k)
  IO.puts("#{k}  clone_lib=#{in_clone}")
end)

IO.puts("\n-- 空 key (items..id) 出现的 zone:name --")

raw_refs
|> Enum.filter(fn {_, _, ref} -> ref == "items..id" end)
|> Enum.uniq()
|> Enum.each(fn {z, n, _} -> IO.puts("#{z}:#{n}") end)
