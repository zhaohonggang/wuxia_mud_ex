defmodule Kantele.World.RoomActionHandlersTest do
  use ExUnit.Case, async: true

  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.Baituo.Neishi.Move
  alias Kantele.World.RoomActions.Changan.Kzsleep.Bed
  alias Kantele.World.RoomActions.Emei.Shierpan3.Clap
  alias Kantele.World.RoomActions.Hengyang.Furong1.Climb
  alias Kantele.World.RoomActions.Huashan.Lianhua.Tiao
  alias Kantele.World.RoomActions.Jueqing.Duanchang
  alias Kantele.World.RoomActions.Jueqing.Jianshi
  alias Kantele.World.RoomActions.Jueqing.Underya
  alias Kantele.World.RoomActions.Jueqing.Xiangfang1
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

    test "VisionMove 批量表十个房间解析成功" do
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("mingjiao:gudi3", "do_enter")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("gumu:taiyi1", "do_jump")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("gumu:taiyi2", "do_climb")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("emei:hcawest", "do_jump")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("emei:xiaoshulin1", "do_jump")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("emei:ssyb", "do_climb")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("wudu:minju7", "do_enter")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("mingjiao:tohsq3", "do_jump")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("wudu:dijiao", "do_move")
      assert {:ok, {VisionMove, :run}} = RoomActionHandlers.lookup("wudu:minju10", "do_move")
    end

    test "绝情谷硬房（P5-4aq-B）四个房间解析成功" do
      assert {:ok, {Duanchang, :run}} = RoomActionHandlers.lookup("jueqing:duanchang", "do_jump")
      assert {:ok, {Underya, :run}} = RoomActionHandlers.lookup("jueqing:underya", "do_bao")
      assert {:ok, {Underya, :run}} = RoomActionHandlers.lookup("jueqing:underya", "do_climb")
      assert {:ok, {Underya, :run}} = RoomActionHandlers.lookup("jueqing:underya", "do_jump")
      assert {:ok, {Xiangfang1, :run}} = RoomActionHandlers.lookup("jueqing:xiangfang1", "do_turn")
      assert {:ok, {Xiangfang1, :run}} = RoomActionHandlers.lookup("jueqing:xiangfang1", "do_jump")
      assert {:ok, {Jianshi, :run}} = RoomActionHandlers.lookup("jueqing:jianshi", "do_pull")
      assert {:ok, {Jianshi, :run}} = RoomActionHandlers.lookup("jueqing:jianshi", "do_pick")
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
                "beijing:aofu_shufang",
                "beijing:zhuang3",
                "changan:duchang",
                "changan:kzsleep",
                "changan:qunyuys8",
                "changan:xunbufang",
                "chengdu:eastroad3",
                "chengdu:guangchang",
                "city:bet",
                "city:eproom",
                "city:furong",
                "city:meigui",
                "city:mudan",
                "city:nproom",
                "city:qiyuan2",
                "city:qiyuan3",
                "city:qiyuan4",
                "city:sproom",
                "city:wproom",
                "emei:hcadadian",
                "emei:hcawest",
                "emei:shierpan3",
                "emei:ssyb",
                "emei:st0",
                "emei:st1",
                "emei:st2",
                "emei:xiaoshulin1",
                "foshan:pm_restroom",
                "fuzhou:houyuan",
                "fuzhou:laozhai",
                "guanwai:jingxiu",
                "guanwai:xiuxishi",
                "guiyun:matou",
                "guiyun:taihu",
                "gumu:mishi1",
                "gumu:mumen",
                "gumu:taiyi1",
                "gumu:taiyi2",
                "hangzhou:liuzhuang",
                "hangzhou:loveroom",
                "heimuya:huoting",
                "heimuya:up2",
                "heimuya:up3",
                "hengyang:furong1",
                "hengyang:inhole2",
                "hengyang:inzhushendong",
                "hengyang:liufugate",
                "hengyang:outzhushendong",
                "hengyang:outzigai",
                "hengyang:outzigai1",
                "hengyang:shuiliandong",
                "hengyang:xuanyadi",
                "hengyang:zigaihole",
                "huanggong:inwell",
                "huashan:chaoyang",
                "huashan:jianzhong",
                "huashan:lianhua",
                "huashan:sgyhole1",
                "huashan:xiaolu2",
                "huashan:xiuxishi",
                "jingzhou:houyuan",
                "jingzhou:luan2",
                "jinshe:shanbi",
                "jinshe:yongdao2",
                "jueqing:duanchang",
                "jueqing:eyutan1",
                "jueqing:eyutan2",
                "jueqing:eyutan3",
                "jueqing:jianshi",
                "jueqing:ontree1",
                "jueqing:ontree3",
                "jueqing:undertan",
                "jueqing:underya",
                "jueqing:underya2",
                "jueqing:xiangfang1",
                "kaifeng:hh_xiaozhu",
                "lingxiao:didi",
                "lingxiao:gate",
                "lingxiao:juegu",
                "lingxiao:shanya",
                "lingxiao:wave",
                "meizhuang:didao3",
                "meizhuang:gate",
                "meizhuang:tianjing",
                "mingjiao:gudi3",
                "mingjiao:shandong",
                "mingjiao:tohsq3",
                "quanzhen:diziju",
                "quanzhen:fu_woshi",
                "register:prison",
                "room:qianting",
                "room:zoudao",
                "shaolin:beilin2",
                "shaolin:guangchang1",
                "shaolin:putiyuan",
                "shaolin:smdian",
                "shaolin:zhonglou7",
                "shenfeng:shenfeng",
                "shenfeng:yongdao3",
                "shenfeng:yushi",
                "shenlong:lin1",
                "tiezhang:mishi",
                "tiezhang:wmfeng",
                "tulong:boat2",
                "wanjiegu:entrance",
                "wanjiegu:grassland",
                "wanjiegu:tree_hole",
                "wudang:nanyangong",
                "wudu:dijiao",
                "wudu:huating2",
                "wudu:minju10",
                "wudu:minju7",
                "wudu:mishi",
                "xiakedao:dating",
                "xiakedao:gudi",
                "xiakedao:midao4",
                "xiakedao:xiaowu",
                "xiakedao:yadi",
                "xueshan:chanshi",
                "yanziwu:lanyue",
                "yanziwu:tingyu",
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
      assert RoomActionHandlers.registered?("mingjiao:tohsq3", "do_jump")
      assert RoomActionHandlers.registered?("wudu:dijiao", "do_move")
      assert RoomActionHandlers.registered?("wudu:minju10", "do_move")
      # P5-4h：首个覆盖全局命令（get）的移植，另一 verb 为新增
      assert RoomActionHandlers.registered?("shaolin:putiyuan", "do_get")
      assert RoomActionHandlers.registered?("shaolin:putiyuan", "do_xian")
      # P5-4ae：动态出口消费端首批
      assert RoomActionHandlers.registered?("changan:xunbufang", "do_open")
      assert RoomActionHandlers.registered?("guanwai:xiuxishi", "do_open")
      assert RoomActionHandlers.registered?("guanwai:xiuxishi", "do_close")
      assert RoomActionHandlers.registered?("huashan:xiuxishi", "do_open")
      assert RoomActionHandlers.registered?("huashan:xiuxishi", "do_close")
      assert RoomActionHandlers.registered?("lingxiao:shanya", "do_open")
      assert RoomActionHandlers.registered?("foshan:pm_restroom", "do_open")
      assert RoomActionHandlers.registered?("foshan:pm_restroom", "do_close")
      assert RoomActionHandlers.registered?("meizhuang:didao3", "do_open")
      # 剑冢埋剑谜题（P5-4i）
      assert RoomActionHandlers.registered?("huashan:jianzhong", "do_move")
      assert RoomActionHandlers.registered?("huashan:jianzhong", "do_pick")
      assert RoomActionHandlers.registered?("huashan:jianzhong", "do_jump")
      # 峨眉深潭「四处张望」（P5-4ag）
      assert RoomActionHandlers.registered?("emei:st0", "do_wang")
      assert RoomActionHandlers.registered?("emei:st1", "do_wang")
      assert RoomActionHandlers.registered?("emei:st2", "do_wang")
      # 砸墙/砸门一批（P5-4ah）
      assert RoomActionHandlers.registered?("beijing:zhuang3", "do_break")
      assert RoomActionHandlers.registered?("chengdu:eastroad3", "do_break")
      assert RoomActionHandlers.registered?("fuzhou:houyuan", "do_break")
      assert RoomActionHandlers.registered?("fuzhou:laozhai", "do_break")
      assert RoomActionHandlers.registered?("huashan:sgyhole1", "do_break")
      assert RoomActionHandlers.registered?("jinshe:shanbi", "do_break")
      assert RoomActionHandlers.registered?("lingxiao:wave", "do_break")
      assert RoomActionHandlers.registered?("mingjiao:shandong", "do_break")
      assert RoomActionHandlers.registered?("xiakedao:midao4", "do_break")
      assert RoomActionHandlers.registered?("shenfeng:yongdao3", "do_break")
      assert RoomActionHandlers.registered?("yanziwu:tingyu", "do_break")
      assert RoomActionHandlers.registered?("tulong:boat2", "do_break")
      # 推门/推石壁/推草丛/推大床一批（P5-4aj）
      assert RoomActionHandlers.registered?("guanwai:jingxiu", "do_push")
      assert RoomActionHandlers.registered?("huashan:xiaolu2", "do_push")
      assert RoomActionHandlers.registered?("hengyang:liufugate", "do_push")
      assert RoomActionHandlers.registered?("lingxiao:didi", "do_push")
      assert RoomActionHandlers.registered?("wanjiegu:entrance", "do_push")
      assert RoomActionHandlers.registered?("xiakedao:dating", "do_push")
      assert RoomActionHandlers.registered?("xiakedao:yadi", "do_push")
      assert RoomActionHandlers.registered?("changan:qunyuys8", "do_push")
      # do_open/do_close 收尾（P5-4ak）
      assert RoomActionHandlers.registered?("hangzhou:loveroom", "do_open")
      assert RoomActionHandlers.registered?("hangzhou:loveroom", "do_close")
      assert RoomActionHandlers.registered?("meizhuang:tianjing", "do_open")
      # 敲门/拉柜开门一批（P5-4al）
      assert RoomActionHandlers.registered?("shaolin:guangchang1", "do_knock")
      assert RoomActionHandlers.registered?("shaolin:zhonglou7", "do_knock")
      assert RoomActionHandlers.registered?("wanjiegu:grassland", "do_knock")
      assert RoomActionHandlers.registered?("meizhuang:gate", "do_knock")
      assert RoomActionHandlers.registered?("quanzhen:diziju", "do_pull")
      assert RoomActionHandlers.registered?("quanzhen:fu_woshi", "do_pull")
      assert RoomActionHandlers.registered?("wanjiegu:tree_hole", "do_pull")
      # 触发器型一批（P5-4am）
      assert RoomActionHandlers.registered?("heimuya:huoting", "do_circle")
      assert RoomActionHandlers.registered?("shenlong:lin1", "do_kan")
      assert RoomActionHandlers.registered?("xiakedao:gudi", "do_mai")
      assert RoomActionHandlers.registered?("beijing:aofu_shufang", "do_turn")
      assert RoomActionHandlers.registered?("xueshan:chanshi", "do_turn")
      assert RoomActionHandlers.registered?("jingzhou:houyuan", "do_unlock")
      assert RoomActionHandlers.registered?("hengyang:inhole2", "do_use")
      assert RoomActionHandlers.registered?("gumu:mishi1", "do_ci")
      assert RoomActionHandlers.registered?("gumu:mishi1", "do_zhan")
      # 移像/推石/推桌一批（P5-4an）
      assert RoomActionHandlers.registered?("emei:hcadadian", "do_move")
      assert RoomActionHandlers.registered?("gumu:mumen", "do_move")
      assert RoomActionHandlers.registered?("jingzhou:luan2", "do_move")
      assert RoomActionHandlers.registered?("tiezhang:wmfeng", "do_move")
      assert RoomActionHandlers.registered?("jinshe:yongdao2", "do_move")
      assert RoomActionHandlers.registered?("kaifeng:hh_xiaozhu", "do_move")
      assert RoomActionHandlers.registered?("shaolin:beilin2", "do_move")
      assert RoomActionHandlers.registered?("shenfeng:yushi", "do_move")
      assert RoomActionHandlers.registered?("wudang:nanyangong", "do_move")
      assert RoomActionHandlers.registered?("wudu:huating2", "do_move")
      assert RoomActionHandlers.registered?("hengyang:outzigai1", "do_push")
      # 神峰清沙 + 推门（P5-4ap）
      assert RoomActionHandlers.registered?("shenfeng:shenfeng", "do_move")
      assert RoomActionHandlers.registered?("shenfeng:shenfeng", "do_push")
      # 盘龙居前庭<->走道双向木门（P5-4ap）
      assert RoomActionHandlers.registered?("room:qianting", "do_push")
      assert RoomActionHandlers.registered?("room:qianting", "do_close")
      assert RoomActionHandlers.registered?("room:zoudao", "do_push")
      assert RoomActionHandlers.registered?("room:zoudao", "do_close")
      # 地形穿越类一批（P5-4aq-A）：11 间房共用 TerrainMove
      assert RoomActionHandlers.registered?("hengyang:outzhushendong", "do_climb")
      assert RoomActionHandlers.registered?("hengyang:outzigai", "do_climb")
      assert RoomActionHandlers.registered?("hengyang:outzigai", "do_tiao")
      assert RoomActionHandlers.registered?("hengyang:shuiliandong", "do_tiao")
      assert RoomActionHandlers.registered?("hengyang:xuanyadi", "do_climb")
      assert RoomActionHandlers.registered?("jueqing:eyutan1", "do_cross")
      assert RoomActionHandlers.registered?("jueqing:eyutan2", "do_swim")
      assert RoomActionHandlers.registered?("jueqing:eyutan3", "do_cross")
      assert RoomActionHandlers.registered?("jueqing:ontree1", "do_jump")
      assert RoomActionHandlers.registered?("jueqing:ontree3", "do_climb")
      assert RoomActionHandlers.registered?("jueqing:undertan", "do_climb")
      assert RoomActionHandlers.registered?("jueqing:underya2", "do_jump")
      # 绝情谷「硬房」消费端（P5-4aq-B）：duanchang/underya/xiangfang1/jianshi 四房
      assert RoomActionHandlers.registered?("jueqing:duanchang", "do_jump")
      assert RoomActionHandlers.registered?("jueqing:underya", "do_bao")
      assert RoomActionHandlers.registered?("jueqing:underya", "do_climb")
      assert RoomActionHandlers.registered?("jueqing:underya", "do_jump")
      assert RoomActionHandlers.registered?("jueqing:xiangfang1", "do_turn")
      assert RoomActionHandlers.registered?("jueqing:xiangfang1", "do_jump")
      assert RoomActionHandlers.registered?("jueqing:jianshi", "do_pull")
      assert RoomActionHandlers.registered?("jueqing:jianshi", "do_pick")
      # 拱猪四房（P5-4ad）
      assert RoomActionHandlers.registered?("city:eproom", "do_play")
      assert RoomActionHandlers.registered?("city:wproom", "do_claim")
      # 赌场（P5-9 #9 一次性场景）
      assert RoomActionHandlers.registered?("city:bet", "do_bet")
      assert RoomActionHandlers.registered?("changan:duchang", "do_bet")
      # 醉仙楼宴厅承办酒席（P5-9 #9 一次性场景）
      assert RoomActionHandlers.registered?("city:furong", "do_order")
      assert RoomActionHandlers.registered?("city:furong", "do_broadcast")
      assert RoomActionHandlers.registered?("city:meigui", "do_order")
      assert RoomActionHandlers.registered?("city:mudan", "do_order")
      refute RoomActionHandlers.registered?("huashan:lianhua", "do_move")
      refute RoomActionHandlers.registered?("baituo:neishi", "do_climb")
      # do_climb 在 hengyang:furong1、gumu:taiyi2 与 P5-4aq-A 的地形房（outzhushendong/
      # outzigai/xuanyadi/ontree3/undertan）移植，其余房间不应串
      refute RoomActionHandlers.registered?("lingxiao:juegu", "do_climb")
      refute RoomActionHandlers.registered?("gumu:taiyi1", "do_climb")
    end
  end
end
