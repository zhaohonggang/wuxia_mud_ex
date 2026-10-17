defmodule Kantele.World.RoomActionHandlersTest do
  use ExUnit.Case, async: true

  alias Kantele.World.RoomActionHandlers

  describe "lookup/1" do
    test "未注册 handler 返回 {:unimplemented, name}" do
      assert {:unimplemented, "do_move"} = RoomActionHandlers.lookup("do_move")
      assert {:unimplemented, "do_climb"} = RoomActionHandlers.lookup("do_climb")
    end

    test "非字符串参数也走 unimplemented 分支（不崩溃）" do
      assert {:unimplemented, nil} = RoomActionHandlers.lookup(nil)
      assert {:unimplemented, :do_move} = RoomActionHandlers.lookup(:do_move)
    end
  end

  describe "registered?/1 与 registered_names/0" do
    test "初始注册表为空（handler 待 P5-1b-3 逐个移植）" do
      assert RoomActionHandlers.registered_names() == []
      refute RoomActionHandlers.registered?("do_move")
    end
  end
end
