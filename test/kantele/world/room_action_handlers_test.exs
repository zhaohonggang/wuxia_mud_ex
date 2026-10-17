defmodule Kantele.World.RoomActionHandlersTest do
  use ExUnit.Case, async: true

  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.Huashan.Lianhua.Tiao

  describe "lookup/2（房间级）" do
    test "已移植的房间 handler 解析成功" do
      assert {:ok, {Tiao, :run}} = RoomActionHandlers.lookup("huashan:lianhua", "do_tiao")
    end

    test "房间未注册 → {:unimplemented, name}" do
      assert {:unimplemented, "do_tiao"} = RoomActionHandlers.lookup("unknown:room", "do_tiao")
    end

    test "房间已注册但 handler 未在该房间移植 → {:unimplemented, name}" do
      assert {:unimplemented, "do_move"} = RoomActionHandlers.lookup("huashan:lianhua", "do_move")
      assert {:unimplemented, "do_tiao"} = RoomActionHandlers.lookup("baituo:neishi", "do_tiao")
    end

    test "非字符串参数安全降级（不崩溃）" do
      assert {:unimplemented, nil} = RoomActionHandlers.lookup(nil, nil)
      assert {:unimplemented, :do_tiao} = RoomActionHandlers.lookup("huashan:lianhua", :do_tiao)
    end
  end

  describe "registered?/2 与 registered_rooms/0" do
    test "当前仅 huashan:lianhua 的 do_tiao 已注册（P5-1b-3 样板）" do
      assert RoomActionHandlers.registered_rooms() == ["huashan:lianhua"]
      assert RoomActionHandlers.registered?("huashan:lianhua", "do_tiao")
      refute RoomActionHandlers.registered?("huashan:lianhua", "do_move")
      refute RoomActionHandlers.registered?("baituo:neishi", "do_move")
    end
  end
end
