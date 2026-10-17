defmodule Kantele.World.RoomActionHandlersTest do
  use ExUnit.Case, async: true

  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.Baituo.Neishi.Move
  alias Kantele.World.RoomActions.Changan.Kzsleep.Bed
  alias Kantele.World.RoomActions.Emei.Shierpan3.Clap
  alias Kantele.World.RoomActions.Hengyang.Furong1.Climb
  alias Kantele.World.RoomActions.Huashan.Lianhua.Tiao
  alias Kantele.World.RoomActions.Lingxiao.Juegu.Pan
  alias Kantele.World.RoomActions.MessageOnly
  alias Kantele.World.RoomActions.VisionMove
  alias Kantele.World.RoomActions.Xiakedao.Xiaowu.Move, as: XiaowuMove

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

    test "位移样板（me->move）四个房间解析成功" do
      assert {:ok, {Pan, :run}} = RoomActionHandlers.lookup("lingxiao:juegu", "do_pan")
      assert {:ok, {Climb, :run}} = RoomActionHandlers.lookup("hengyang:furong1", "do_climb")
      assert {:ok, {Bed, :run}} = RoomActionHandlers.lookup("changan:kzsleep", "do_bed")
      assert {:ok, {XiaowuMove, :run}} = RoomActionHandlers.lookup("xiakedao:xiaowu", "do_move")
    end

    test "VisionMove 批量表七个房间解析成功" do
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("mingjiao:gudi3", "do_enter")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("gumu:taiyi1", "do_jump")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("gumu:taiyi2", "do_climb")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("emei:hcawest", "do_jump")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("emei:xiaoshulin1", "do_jump")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("emei:ssyb", "do_climb")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("wudu:minju7", "do_enter")
    end

    test "房间未注册 → {:unimplemented, name}" do
      assert {:unimplemented, "do_tiao"} = RoomActionHandlers.lookup("unknown:room", "do_tiao")
    end

    test "房间已注册但 handler 未在该房间移植 → {:unimplemented, name}" do
      assert {:unimplemented, "do_move"} = RoomActionHandlers.lookup("huashan:lianhua", "do_move")
      assert {:unimplemented, "do_tiao"} = RoomActionHandlers.lookup("baituo:neishi", "do_tiao")
      # 同为 do_move，但只在 xiakedao:xiaowu 移植，不会串到 baituo:neishi
      assert {:ok, {Move, :run}} = RoomActionHandlers.lookup("baituo:neishi", "do_move")
      assert {:ok, {XiaowuMove, :run}} = RoomActionHandlers.lookup("xiakedao:xiaowu", "do_move")
    end

    test "非字符串参数安全降级（不崩溃）" do
      assert {:unimplemented, nil} = RoomActionHandlers.lookup(nil, nil)
      assert {:unimplemented, :do_tiao} = RoomActionHandlers.lookup("huashan:lianhua", :do_tiao)
    end
  end

  describe "registered?/2 与 registered_rooms/0" do
    test "已注册房间与 handler 覆盖（样板 + MessageOnly + Move + 全局覆盖 + 位移 + VisionMove 两批）" do
      assert Enum.sort(RoomActionHandlers.registered_rooms()) ==
               [
                 "baituo:neishi",
                 "changan:kzsleep",
                 "chengdu:guangchang",
                 "emei:hcawest",
                 "emei:shierpan3",
                 "emei:ssyb",
                 "emei:xiaoshulin1",
                 "gumu:taiyi1",
                 "gumu:taiyi2",
                 "hangzhou:liuzhuang",
                 "hengyang:furong1",
                 "huanggong:inwell",
                 "huashan:lianhua",
                 "lingxiao:juegu",
                 "mingjiao:gudi3",
                 "register:prison",
                 "wudu:minju7",
                 "xiakedao:xiaowu"
               ]

      assert RoomActionHandlers.registered?("huashan:lianhua", "do_tiao")
      assert RoomActionHandlers.registered?("emei:shierpan3", "do_clap")
      assert RoomActionHandlers.registered?("hangzhou:liuzhuang", "do_knock")
      assert RoomActionHandlers.registered?("huanggong:inwell", "do_reach")
      assert RoomActionHandlers.registered?("baituo:neishi", "do_move")
      assert RoomActionHandlers.registered?("chengdu:guangchang", "do_drink")
      assert RoomActionHandlers.registered?("register:prison", "do_drop")
      assert RoomActionHandlers.registered?("lingxiao:juegu", "do_pan")
      assert RoomActionHandlers.registered?("hengyang:furong1", "do_climb")
      assert RoomActionHandlers.registered?("changan:kzsleep", "do_bed")
      assert RoomActionHandlers.registered?("xiakedao:xiaowu", "do_move")
      assert RoomActionHandlers.registered?("mingjiao:gudi3", "do_enter")
      assert RoomActionHandlers.registered?("gumu:taiyi1", "do_jump")
      assert RoomActionHandlers.registered?("gumu:taiyi2", "do_climb")
      assert RoomActionHandlers.registered?("emei:hcawest", "do_jump")
      assert RoomActionHandlers.registered?("emei:xiaoshulin1", "do_jump")
      assert RoomActionHandlers.registered?("emei:ssyb", "do_climb")
      assert RoomActionHandlers.registered?("wudu:minju7", "do_enter")
      refute RoomActionHandlers.registered?("huashan:lianhua", "do_move")
      refute RoomActionHandlers.registered?("baituo:neishi", "do_climb")
      # do_climb 只在 hengyang:furong1 与 gumu:taiyi2 移植
      refute RoomActionHandlers.registered?("lingxiao:juegu", "do_climb")
      refute RoomActionHandlers.registered?("gumu:taiyi1", "do_climb")
    end
  end
end
