defmodule Kantele.World.NpcActionHandlersTest do
  use ExUnit.Case, async: true

  alias Kantele.World.NpcActionHandlers

  describe "lookup/2" do
    test "tulong:huichang_back 的 yun → 已注册的 Yun handler" do
      assert {:ok, {Kantele.World.NpcActions.Yun, :run}} =
               NpcActionHandlers.lookup("tulong:huichang_back", "yun")
    end

    test "tulong:huichang_back 的 bi → 已注册的 Bi handler" do
      assert {:ok, {Kantele.World.NpcActions.Bi, :run}} =
               NpcActionHandlers.lookup("tulong:huichang_back", "bi")
    end

    test "tulong:huichang_back 的 get → 已注册的 Bi handler" do
      assert {:ok, {Kantele.World.NpcActions.Bi, :run}} =
               NpcActionHandlers.lookup("tulong:huichang_back", "get")
    end

    test "tulong:huichang 的 yun → 已注册的 Yun handler" do
      assert {:ok, {Kantele.World.NpcActions.Yun, :run}} =
               NpcActionHandlers.lookup("tulong:huichang", "yun")
    end

    test "tulong:huichang 的 bi → 已注册的 Bi handler" do
      assert {:ok, {Kantele.World.NpcActions.Bi, :run}} =
               NpcActionHandlers.lookup("tulong:huichang", "bi")
    end

    test "tulong:huichang 的 get → 已注册的 Bi handler" do
      assert {:ok, {Kantele.World.NpcActions.Bi, :run}} =
               NpcActionHandlers.lookup("tulong:huichang", "get")
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

    test "xiangyang:qianzhuang 的 decide → 已注册的 Decide handler" do
      assert {:ok, {Kantele.World.NpcActions.Decide, :run}} =
               NpcActionHandlers.lookup("xiangyang:qianzhuang", "decide")
    end

    test "guiyun:taihu 的 decide → 已注册的 Decide handler" do
      assert {:ok, {Kantele.World.NpcActions.Decide, :run}} =
               NpcActionHandlers.lookup("guiyun:taihu", "decide")
    end

    test "xiangyang:qianzhuang 的 join/unjoin → 已注册的 Decide handler" do
      assert {:ok, {Kantele.World.NpcActions.Decide, :run}} =
               NpcActionHandlers.lookup("xiangyang:qianzhuang", "join")

      assert {:ok, {Kantele.World.NpcActions.Decide, :run}} =
               NpcActionHandlers.lookup("xiangyang:qianzhuang", "unjoin")
    end

    test "meizhuang:chufang 的 serve → 已注册的 Serve handler" do
      assert {:ok, {Kantele.World.NpcActions.Serve, :run}} =
               NpcActionHandlers.lookup("meizhuang:chufang", "serve")
    end

    test "wuguan:guofu_fanting 的 serve → 已注册的 Serve handler" do
      assert {:ok, {Kantele.World.NpcActions.Serve, :run}} =
               NpcActionHandlers.lookup("wuguan:guofu_fanting", "serve")
    end

    test "beijing:wenmiao 的 puzzle → 已注册的 Puzzle handler" do
      assert {:ok, {Kantele.World.NpcActions.Puzzle, :run}} =
               NpcActionHandlers.lookup("beijing:wenmiao", "puzzle")
    end

    test "wuguan:guofu_dayuan2 的 task → 已注册的 Task handler" do
      assert {:ok, {Kantele.World.NpcActions.Task, :run}} =
               NpcActionHandlers.lookup("wuguan:guofu_dayuan2", "task")
    end

    test "city:wuguan 的 txbw → 已注册的 Txbw handler" do
      assert {:ok, {Kantele.World.NpcActions.Txbw, :run}} =
               NpcActionHandlers.lookup("city:wuguan", "txbw")
    end

    test "city:kedian 的 exchange/duihuan → 已注册的 Exchange handler" do
      assert {:ok, {Kantele.World.NpcActions.Exchange, :run}} =
               NpcActionHandlers.lookup("city:kedian", "exchange")

      assert {:ok, {Kantele.World.NpcActions.Exchange, :run}} =
               NpcActionHandlers.lookup("city:kedian", "duihuan")
    end

    test "city:zhujuan 的 choose → 已注册的 Choose handler" do
      assert {:ok, {Kantele.World.NpcActions.Choose, :run}} =
               NpcActionHandlers.lookup("city:zhujuan", "choose")
    end

    test "pk:entry 的 sign → 已注册的 Sign handler" do
      assert {:ok, {Kantele.World.NpcActions.Sign, :run}} =
               NpcActionHandlers.lookup("pk:entry", "sign")
    end

    test "jobs 族五房间（copy×2/sew/mine×2/move）→ 已注册的 Jobs handler" do
      for {room, verb} <- [
            {"guiyun:shufang", "copy"},
            {"city:shuyuan", "copy"},
            {"city:garments", "sew"},
            {"guanwai:shichang", "mine"},
            {"guanwai:shichang", "move"},
            {"hangzhou:kuangshan", "mine"}
          ] do
        assert {:ok, {Kantele.World.NpcActions.Jobs, :run}} =
                 NpcActionHandlers.lookup(room, verb)
      end
    end

    test "铁匠五连（gu/dapi/cuihuo/repair/xiuli）→ 已注册的 Smith handler" do
      for verb <- ["gu", "dapi", "cuihuo", "repair", "xiuli"] do
        assert {:ok, {Kantele.World.NpcActions.Smith, :run}} =
                 NpcActionHandlers.lookup("xiangyang:tiejiangpu", verb)
      end
    end

    test "倚天链两房间（was_lou4 / jiulou）→ 已注册的 Yitian handler" do
      for room <- ["tulong:was_lou4", "tulong:jiulou"] do
        assert {:ok, {Kantele.World.NpcActions.Yitian, :run}} =
                 NpcActionHandlers.lookup(room, "bi")
      end
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
    # 明细（共 27 个房间）：4 yun、1 ride*、2 bi/get、3 yao、2 decide(+join/unjoin)、
    # 2 serve、1 puzzle、1 task、1 txbw、1 exchange(+duihuan)、1 choose、1 sign、
    # 5 jobs(copy×2/sew/mine×2/move)、1 yitian、1 kneel、1 peiyao、1 smith、
    # 1 gongxian(list+duihuan，changan:qunyulou2 浮云门贡商人)。
    #
    # ⚠️ 测试名不要写太长：ExUnit 会把 "test <名字>" 转成 atom，而 BEAM 原子表的长度
    # 字段只有 8 位（上限 255 字节，不是 255 个字符——中文按 UTF-8 每字 3 字节）。
    # 原名 281 字节，编译期直接让 OTP 25 的 beam_asm 崩在
    # `*** argument 1: not an iolist term`，整个测试套件无法启动。
    # 该崩溃与平台无关（Linux 容器同样复现），不是 Windows 独有。
    test "返回已注册房间 id 列表（27 个）" do
      rooms = NpcActionHandlers.registered_rooms()

      assert "tulong:huichang_back" in rooms
      assert "tulong:huichang" in rooms
      assert "tulong:jiulou" in rooms
      assert "tulong:was_dayuan" in rooms
      assert "beijing:majuan" in rooms
      assert "xiangyang:qianzhuang" in rooms
      assert "wudu:chufang" in rooms
      assert "beijing:bingqi" in rooms
      assert "guiyun:taihu" in rooms
      assert "meizhuang:chufang" in rooms
      assert "wuguan:guofu_fanting" in rooms
      assert "beijing:wenmiao" in rooms
      assert "wuguan:guofu_dayuan2" in rooms
      assert "city:wuguan" in rooms
      assert "city:kedian" in rooms
      assert "city:zhujuan" in rooms
      assert "pk:entry" in rooms
      assert "guiyun:shufang" in rooms
      assert "city:shuyuan" in rooms
      assert "city:garments" in rooms
      assert "guanwai:shichang" in rooms
      assert "hangzhou:kuangshan" in rooms
      assert "tulong:was_lou4" in rooms
      assert "hangzhou:liuhe9" in rooms
      assert "kaifeng:yaopu" in rooms
      assert "xiangyang:tiejiangpu" in rooms
      assert "changan:qunyulou2" in rooms
      assert length(rooms) == 27
    end
  end
end
