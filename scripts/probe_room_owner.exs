# B7 验证：Room 结构体已加 room_owner/room_name/room_position/room_owner_id
# （均默认 nil；loader 仅 Map.get 读取，不产生行为变化）。
# 数据回填处于阻塞：源 .c 中 4 个 key 全在 `//**` 注释块里为模板占位符，
# 无激活的 set() 调用，暂无真实值可回填。
# Read-only; 容器内运行：
#   MSYS_NO_PATHCONV=1 docker exec -w /app wuxia_mud_dev-app-1 \
#     mix run --no-start scripts/probe_room_owner.exs

world = Kantele.World.Loader.load()

# 房间按 zone 组织：world.zones -> 各 zone.rooms
rooms =
  world.zones
  |> Enum.map(& &1.rooms)
  |> List.flatten()

IO.puts("rooms total : #{length(rooms)}")

# 取前 3 个 room 作为样本，确认 struct 带有 4 个字段且均为 nil
sample = Enum.take(rooms, 3)
Enum.each(sample, fn room ->
  IO.puts("  room : #{room.id}")
  IO.puts("    room_owner      : #{inspect(room.room_owner)}")
  IO.puts("    room_name       : #{inspect(room.room_name)}")
  IO.puts("    room_position   : #{inspect(room.room_position)}")
  IO.puts("    room_owner_id   : #{inspect(room.room_owner_id)}")
end)

# 断言：全库 4 个字段目前均为 nil（无源数据，未回填）
all_nil =
  Enum.all?(rooms, fn r ->
    is_nil(r.room_owner) and
      is_nil(r.room_name) and
      is_nil(r.room_position) and
      is_nil(r.room_owner_id)
  end)

IO.puts("all 4 fields nil on every room : #{all_nil}")

case all_nil do
  true ->
    IO.puts("RESULT : OK (Room 字段已加，loader 读取正常；数据回填阻塞，无源数据)")
  _ ->
    IO.puts("RESULT : UNEXPECTED (部分 room 字段非 nil)")
end
