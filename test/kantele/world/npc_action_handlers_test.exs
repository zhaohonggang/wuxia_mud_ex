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

    test "beijing:majuan 的 rideyz → 已注册的 Ride handler" do
      assert {:ok, {Kantele.World.NpcActions.Ride, :run}} =
               NpcActionHandlers.lookup("beijing:majuan", "rideyz")
    end

    test "beijing:majuan 的 ridedl → 已注册的 Ride handler" do
      assert {:ok, {Kantele.World.NpcActions.Ride, :run}} =
               NpcActionHandlers.lookup("beijing:majuan", "ridedl")
    end

    test "beijing:majuan 的 rideem → 已注册的 Ride handler" do
      assert {:ok, {Kantele.World.NpcActions.Ride, :run}} =
               NpcActionHandlers.lookup("beijing:majuan", "rideem")
    end

    test "beijing:majuan 的 ridefs → 已注册的 Ride handler" do
      assert {:ok, {Kantele.World.NpcActions.Ride, :run}} =
               NpcActionHandlers.lookup("beijing:majuan", "ridefs")
    end

    test "beijing:majuan 的 ridefz → 已注册的 Ride handler" do
      assert {:ok, {Kantele.World.NpcActions.Ride, :run}} =
               NpcActionHandlers.lookup("beijing:majuan", "ridefz")
    end

    test "beijing:majuan 的 ridehz → 已注册的 Ride handler" do
      assert {:ok, {Kantele.World.NpcActions.Ride, :run}} =
               NpcActionHandlers.lookup("beijing:majuan", "ridehz")
    end

    test "beijing:majuan 的 ridesz → 已注册的 Ride handler" do
      assert {:ok, {Kantele.World.NpcActions.Ride, :run}} =
               NpcActionHandlers.lookup("beijing:majuan", "ridesz")
    end

    test "beijing:majuan 的 ridexy → 已注册的 Ride handler" do
      assert {:ok, {Kantele.World.NpcActions.Ride, :run}} =
               NpcActionHandlers.lookup("beijing:majuan", "ridexy")
    end

    test "beijing:majuan 的 rideyd → 已注册的 Ride handler" do
      assert {:ok, {Kantele.World.NpcActions.Ride, :run}} =
               NpcActionHandlers.lookup("beijing:majuan", "rideyd")
    end

    test "beijing:majuan 的 rideyl → 已注册的 Ride handler" do
      assert {:ok, {Kantele.World.NpcActions.Ride, :run}} =
               NpcActionHandlers.lookup("beijing:majuan", "rideyl")
    end

    test "xiangyang:qianzhuang 的 yao → 已注册的 Yao handler" do
      assert {:ok, {Kantele.World.NpcActions.Yao, :run}} =
               NpcActionHandlers.lookup("xiangyang:qianzhuang", "yao")
    end

    test "wudu:chufang 的 yao → 已注册的 Yao handler" do
      assert {:ok, {Kantele.World.NpcActions.Yao, :run}} =
               NpcActionHandlers.lookup("wudu:chufang", "yao")
    end

    test "beijing:bingqi 的 yao → 已注册的 Yao handler" do
      assert {:ok, {Kantele.World.NpcActions.Yao, :run}} =
               NpcActionHandlers.lookup("beijing:bingqi", "yao")
    end

    test "未注册房间 → {:unimplemented, verb}" do
      assert {:unimplemented, "yun"} = NpcActionHandlers.lookup("nonexistent:room", "yun")
    end

    test "注册房间但未注册 verb（exert）→ {:unimplemented, verb}" do
      assert {:unimplemented, "exert"} =
               NpcActionHandlers.lookup("tulong:huichang_back", "exert")
    end

    test "beijing:majuan 未注册 verb（yun）→ {:unimplemented, verb}" do
      assert {:unimplemented, "yun"} =
               NpcActionHandlers.lookup("beijing:majuan", "yun")
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
    test "返回已注册房间 id 列表，包含 4 个 yun 房间、1 个 ride* 房间与 3 个 yao 房间" do
      rooms = NpcActionHandlers.registered_rooms()

      assert "tulong:huichang_back" in rooms
      assert "tulong:huichang" in rooms
      assert "tulong:jiulou" in rooms
      assert "tulong:was_dayuan" in rooms
      assert "beijing:majuan" in rooms
      assert "xiangyang:qianzhuang" in rooms
      assert "wudu:chufang" in rooms
      assert "beijing:bingqi" in rooms
      assert length(rooms) == 8
    end
  end
end
