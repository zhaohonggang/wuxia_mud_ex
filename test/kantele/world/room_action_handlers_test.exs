defmodule Kantele.World.RoomActionHandlersTest do
  use ExUnit.Case, async: true

  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.Baituo.Neishi.Move
  alias Kantele.World.RoomActions.Emei.Shierpan3.Clap
  alias Kantele.World.RoomActions.Huashan.Lianhua.Tiao
  alias Kantele.World.RoomActions.MessageOnly

  describe "lookup/2（房间级）" do
    test "已移植的房间 handler 解析成功" do
      assert {:ok, {Tiao, :run}} = RoomActionHandlers.lookup("huashan:lianhua", "do_tiao")
      assert {:ok, {Clap, :run}} = RoomActionHandlers.lookup("emei:shierpan3", "do_clap")
      assert {:ok, {MessageOnly, :run}} = RoomActionHandlers.lookup("hangzhou:liuzhuang", "do_knock")
      assert {:ok, {MessageOnly, :run}} = RoomActionHandlers.lookup("huanggong:inwell", "do_reach")
      assert {:ok, {Move, :run}} = RoomActionHandlers.lookup("baituo:neishi", "do_move")
      assert {:ok, {MessageOnly, :run}} = RoomActionHandlers.lookup("chengdu:guangchang", "do_drink")
      assert {:ok, {MessageOnly, :run}} = RoomActionHandlers.lookup("register:prison", "do_drop")
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
    test "已注册房间与 handler 覆盖（样板 + MessageOnly + Move + 全局覆盖）" do
      assert Enum.sort(RoomActionHandlers.registered_rooms()) ==
               [
                 "baituo:neishi",
                 "chengdu:guangchang",
                 "emei:shierpan3",
                 "hangzhou:liuzhuang",
                 "huanggong:inwell",
                 "huashan:lianhua",
                 "register:prison"
               ]

      assert RoomActionHandlers.registered?("huashan:lianhua", "do_tiao")
      assert RoomActionHandlers.registered?("emei:shierpan3", "do_clap")
      assert RoomActionHandlers.registered?("hangzhou:liuzhuang", "do_knock")
      assert RoomActionHandlers.registered?("huanggong:inwell", "do_reach")
      assert RoomActionHandlers.registered?("baituo:neishi", "do_move")
      assert RoomActionHandlers.registered?("chengdu:guangchang", "do_drink")
      assert RoomActionHandlers.registered?("register:prison", "do_drop")
      refute RoomActionHandlers.registered?("huashan:lianhua", "do_move")
      refute RoomActionHandlers.registered?("baituo:neishi", "do_climb")
    end
  end
end
