defmodule Kantele.World.NpcActionHandlersTest do
  use ExUnit.Case, async: true

  alias Kantele.World.NpcActionHandlers

  describe "lookup/2" do
    test "tulong:huichang_back 的 yun → 已注册的 Yun handler" do
      assert {:ok, {Kantele.World.NpcActions.Yun, :run}} =
               NpcActionHandlers.lookup("tulong:huichang_back", "yun")
    end

    test "tulong:huichang 的 yun → 已注册的 Yun handler" do
      assert {:ok, {Kantele.World.NpcActions.Yun, :run}} =
               NpcActionHandlers.lookup("tulong:huichang", "yun")
    end

    test "tulong:jiulou 的 yun → 已注册的 Yun handler" do
      assert {:ok, {Kantele.World.NpcActions.Yun, :run}} =
               NpcActionHandlers.lookup("tulong:jiulou", "yun")
    end

    test "tulong:was_dayuan 的 yun → 已注册的 Yun handler" do
      assert {:ok, {Kantele.World.NpcActions.Yun, :run}} =
               NpcActionHandlers.lookup("tulong:was_dayuan", "yun")
    end

    test "未注册房间 → {:unimplemented, verb}" do
      assert {:unimplemented, "yun"} = NpcActionHandlers.lookup("nonexistent:room", "yun")
    end

    test "注册房间但未注册 verb（exert）→ {:unimplemented, verb}" do
      assert {:unimplemented, "exert"} =
               NpcActionHandlers.lookup("tulong:huichang_back", "exert")
    end

    test "非字符串房间 id / verb → {:unimplemented, :unknown}" do
      assert {:unimplemented, :unknown} = NpcActionHandlers.lookup(nil, "yun")
      assert {:unimplemented, :unknown} = NpcActionHandlers.lookup("tulong:huichang_back", nil)
    end
  end

  describe "registered?/2" do
    test "已注册房间 verb 返回 true" do
      assert NpcActionHandlers.registered?("tulong:huichang_back", "yun")
    end

    test "未注册返回 false" do
      assert not NpcActionHandlers.registered?("tulong:huichang_back", "exert")
      assert not NpcActionHandlers.registered?("nonexistent:room", "yun")
    end
  end

  describe "registered_rooms/0" do
    test "返回已注册房间 id 列表，包含 4 个 yun 房间" do
      rooms = NpcActionHandlers.registered_rooms()

      assert "tulong:huichang_back" in rooms
      assert "tulong:huichang" in rooms
      assert "tulong:jiulou" in rooms
      assert "tulong:was_dayuan" in rooms
      assert length(rooms) == 4
    end
  end
end
