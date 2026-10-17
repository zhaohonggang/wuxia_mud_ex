defmodule Kantele.World.RoomDynamicExitTest do
  use ExUnit.Case, async: true

  alias Kalevala.World.Exit
  alias Kantele.World.Room

  defp static_exit(name, target) do
    %Exit{id: "z:r:#{name}", exit_name: name, start_room_id: "z:r", end_room_id: target}
  end

  defp room(exits) do
    %Room{id: "z:r", key: "r", zone_id: "z", exits: exits}
  end

  describe "put_exit/3 / remove_exit/2 / has_exit?/2（struct 级纯函数）" do
    test "put_exit 追加一个新方向出口" do
      r = room([static_exit("up", "z:top")])

      r2 = Room.put_exit(r, "down", "z:cellar")

      assert Room.has_exit?(r2, "down")
      assert Room.has_exit?(r2, "up")
      assert Enum.find(r2.exits, &(&1.exit_name == "down")).end_room_id == "z:cellar"
    end

    test "put_exit 覆盖同方向（不产生重复）" do
      r = room([static_exit("down", "z:old")])

      r2 = Room.put_exit(r, "down", "z:new")

      downs = Enum.filter(r2.exits, &(&1.exit_name == "down"))
      assert length(downs) == 1
      assert hd(downs).end_room_id == "z:new"
    end

    test "remove_exit 移除指定方向，其余保留" do
      r = room([static_exit("up", "z:top"), static_exit("down", "z:cellar")])

      r2 = Room.remove_exit(r, "down")

      refute Room.has_exit?(r2, "down")
      assert Room.has_exit?(r2, "up")
    end

    test "has_exit? 对 nil exits / 非字符串方向安全降级" do
      refute Room.has_exit?(%Room{id: "z:r"}, "down")
      refute Room.has_exit?(room([]), nil)
    end
  end

  describe "set_exit/3 等运行期包装（无房间进程 → 安全降级）" do
    test "房间进程不存在时返回 :error / false，不崩溃" do
      assert Room.set_exit("nonexistent:room", "down", "x:y") == :error
      assert Room.delete_exit("nonexistent:room", "down") == :error
      refute Room.has_exit_by_id?("nonexistent:room", "down")
    end

    test "非字符串参数安全降级" do
      assert Room.set_exit(nil, "down", "x:y") == :error
      refute Room.has_exit_by_id?(nil, "down")
    end
  end
end
