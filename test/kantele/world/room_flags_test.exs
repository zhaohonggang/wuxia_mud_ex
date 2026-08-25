defmodule Kantele.World.RoomFlagsTest do
  use ExUnit.Case, async: true

  @moduletag :world_data

  test "练武场带 no_fight/outdoors flags（A5/D2）" do
    room = find_room("liuxi:lianwuchang")

    assert room.flags == ["no_fight", "outdoors"]
  end

  test "未配置 flags 的房间默认为空列表" do
    room = find_room("liuxi:shanlu")

    assert room.flags == []
  end

  defp find_room(room_id) do
    world = Kantele.World.Loader.load()

    Enum.find(world.rooms, &(&1.id == room_id))
  end
end
