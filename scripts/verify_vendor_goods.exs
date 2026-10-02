# 商品引用完整性检查（P0a 及后续商品补齐的验收工具）
#
# 用真实 Loader 加载世界，统计 NPC goods 的解引用情况：
#   - 已解析：引用 -> "<区>:<名>"，可直接买卖
#   - 同区悬空：items.<名>.id 保留原样 -> 该区还没有这个物品（待建清单）
#   - 跨区悬空：<区>.items.<名>.id 保留原样 -> 解引用坏了，必须为 0
#
# 用法：mix run --no-start scripts/verify_vendor_goods.exs

alias Kantele.World.Loader

world = Loader.load()
items = Map.new(world.items, fn item -> {item.id, item} end)

vendors = Enum.filter(world.characters, fn ch -> (ch.meta && ch.meta.goods) || [] != [] end)

total = Enum.reduce(vendors, 0, fn ch, acc -> acc + length(ch.meta.goods) end)

resolved =
  Enum.flat_map(vendors, fn ch -> Enum.filter(ch.meta.goods, &Map.has_key?(items, &1)) end)

dangling =
  Enum.flat_map(vendors, fn ch ->
    ch.meta.goods
    |> Enum.reject(&Map.has_key?(items, &1))
    |> Enum.map(fn id -> {ch.name, ch.meta.zone_id, id} end)
  end)

cross? = fn id -> String.match?(id, ~r/^[a-z0-9_]+\.items\./) end

cross_dangling = Enum.filter(dangling, fn {_n, _z, id} -> cross?.(id) end)
same_dangling = Enum.reject(dangling, fn {_n, _z, id} -> cross?.(id) end)

IO.puts("world items: #{map_size(items)}")
IO.puts("vendors with goods: #{length(vendors)}")
IO.puts("total goods refs: #{total}")
IO.puts("resolved: #{length(resolved)}")
IO.puts("dangling same-zone: #{length(same_dangling)}  (#{Enum.uniq(Enum.map(same_dangling, &elem(&1, 2))) |> length()} 个不同物品)")
IO.puts("dangling cross-zone: #{length(cross_dangling)}")

if cross_dangling == [] do
  IO.puts("\nOK: 无跨区悬空引用（loader 跨区解引用正常）")
else
  IO.puts("\nFAIL: 跨区引用未能解引用：")

  cross_dangling
  |> Enum.uniq()
  |> Enum.each(fn {name, zone, id} -> IO.puts("  #{zone}/#{name}: #{id}") end)
end

answer = IO.gets("列出同区待建物品清单？[y/N] ")

if is_binary(answer) and String.match?(answer, ~r/^y/i) do
  IO.puts("\n同区待建物品（<名> 出现次数）：")

  same_dangling
  |> Enum.group_by(fn {_n, _z, id} -> id end)
  |> Enum.sort()
  |> Enum.each(fn {id, group} ->
    name = id |> String.replace_prefix("items.", "") |> String.replace_suffix(".id", "")
    IO.puts("  #{name} (#{length(group)} 次)")
  end)
end