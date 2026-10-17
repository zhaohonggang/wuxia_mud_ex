defmodule Kantele.World.RoomActionsTest do
  @moduledoc """
  P5-1a：房间级 `actions`（verb→handler 映射）载入测试。

  只验证 loader 把 UCL `actions = { verb = "handler" }` 读入 `Room.actions`
  （P7：只加字段、零行为变化；消费端见 P5-1b）。不涉及分发逻辑。
  """
  use ExUnit.Case, async: true

  alias Kantele.World.Loader
  alias Kantele.World.Room

  # zone 仅需 id 字段（parse_room 用 "#{zone.id}:#{key}" 拼 room id）
  # parse_room 直接访问 name/description/x/y/z，故 fixture 需齐备这些键
  defp base_room_data(extra) do
    Map.merge(
      %{name: "测试房", description: "房", x: 0, y: 0, z: 0},
      extra
    )
  end

  defp parse(extra, zone_id \\ "test", key \\ "r1") do
    Loader.parse_room(%{id: zone_id}, key, base_room_data(extra), %{})
  end

  describe "P5-1a：房间 actions 载入（verb→handler 映射）" do
    test "actions map 被读入 room.actions（键归一化为字符串）" do
      {_key, room} = parse(%{actions: %{convert: "bian", climb: "pan"}})
      assert room.actions == %{"convert" => "bian", "climb" => "pan"}
    end

    test "无 actions 时默认 %{}（零行为变化，P7）" do
      {_key, room} = parse(%{})
      assert room.actions == %{}
    end

    test "非 map / 异常值回退 %{}（防御）" do
      {_key, room1} = parse(%{actions: "convert"})
      assert room1.actions == %{}

      {_key, room2} = parse(%{actions: ["convert", "bian"]})
      assert room2.actions == %{}
    end

    test "Room 结构体新增 actions 字段，默认 %{}" do
      assert %Room{}.actions == %{}
    end
  end
end
