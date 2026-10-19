# 扫描「同一房间内多个有货商人」的情况。
#
# 背景：未指名的 `buy` 会由 Room.ShopRequestEvent 广播给房间内所有非玩家角色，
# 玩家侧 ShopEvent.buy_result 只要 buyer_id 是自己就成交扣钱。
# 若两个商人卖同一件货，一次 buy 会被扣两次钱。
# LPC 里同名 add_action 只会由第一个返回非 0 的对象处理，故这是转换后新增的偏差。
#
# 用法（容器内）：mix run scripts/tmp/shop_multi_vendor_scan.exs

world = Kantele.World.Loader.load()

rooms = world.zones |> Enum.flat_map(fn zone -> zone.rooms end)

goods_of = fn character ->
  case Map.get(Map.get(character, :meta) || %{}, :goods) do
    goods when is_list(goods) -> goods
    _ -> []
  end
end

vendor_rooms =
  rooms
  |> Enum.map(fn room ->
    vendors =
      (Map.get(room, :characters) || [])
      |> Enum.filter(fn c -> goods_of.(c) != [] end)

    {room, vendors}
  end)
  |> Enum.filter(fn {_room, vendors} -> vendors != [] end)

IO.puts("房间总数：#{length(rooms)}")
IO.puts("有商人的房间：#{length(vendor_rooms)}")

multi = Enum.filter(vendor_rooms, fn {_room, vs} -> length(vs) > 1 end)

IO.puts("其中多商人房间：#{length(multi)}")

overlapping =
  multi
  |> Enum.map(fn {room, vs} ->
    sets = Enum.map(vs, fn v -> MapSet.new(goods_of.(v)) end)
    common = Enum.reduce(sets, &MapSet.intersection/2)
    {room, vs, MapSet.to_list(common)}
  end)
  |> Enum.filter(fn {_room, _vs, common} -> common != [] end)

IO.puts("多商人且货物有重叠（会重复扣钱）：#{length(overlapping)}")

Enum.each(overlapping, fn {room, vs, common} ->
  IO.puts("  #{room.id}  商人=#{Enum.map_join(vs, "/", & &1.name)}")
  IO.puts("    重叠货物=#{Enum.join(common, ", ")}")
end)

IO.puts("")
IO.puts("未指名 list 会收到多份货单的房间（清单，最多 15 条）：")

multi
|> Enum.take(15)
|> Enum.each(fn {room, vs} ->
  IO.puts("  #{room.id}  商人=#{Enum.map_join(vs, "/", & &1.name)}")
end)
