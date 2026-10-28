defmodule Kantele.World.RoomActionHandlers do
  @moduledoc """
  房间 `add_action` handler 注册表（P5-1b）。

  LPC 房间通过 `add_action("verb", "handler")` 注册自定义动词，handler 是 LPC
  函数名（如 `do_move`、`do_climb`）。回填（P5-1a2）已把 304 个房间的
  `verb → handler` 写入 UCL `Room.actions`。本模块负责把 **handler 名** 解析为
  可执行的 Elixir `{module, function}`，由 P5-1b-2 的对象级分发路由调用。

  ## 移植策略（P5-1b-3 重大修正）
  LPC 同名 handler（`do_move`/`do_climb`/...）在**每个房间 `.c` 是各自独立的函数体**，
  绝非共享（例：`d/baituo/neishi.c` 的 `do_move` 开密道、`d/death/lunhuisi.c` 的
  `do_move` 推石桌，互不相干）。因此注册表必须是**房间级**：`lookup(room_id, handler_name)`
  按 `room_id` 区分同名 handler。每个房间移植其独有 `do_*` 为一个
  `use Kantele.World.RoomAction` 的模块，注册到下方 `@registry` 的对应房间桶。

  ## 注册示例
      @registry %{
        "baituo:neishi" => %{
          "do_move" => {Kantele.World.RoomActions.Baituo.Neishi.Move, :run}
        }
      }

  ## 安全性（P7）
  未注册的房间/handler 经 `lookup/2` 返回 `{:unimplemented, name}`，分发路由据此
  给出 `:not_handled` 放行全局命令，**对全局命令零行为影响**。仅当某房间某 verb 的
  handler 被真正移植并注册后，该房间的该动作才被拦截激活。
  """
  # 房间级注册表：room_id -> (handler_name -> {module, function})。
  # 绝大多数已注册动词**不在全局命令表**，激活后不影响任何全局命令：
  #   - huashan:lianhua do_tiao：纯 write 文本（专用模块 Tiao）
  #   - emei:shierpan3 do_clap：message_vision 房间广播（专用模块 Clap）
  #   - hangzhou:liuzhuang do_knock / huanggong:inwell do_reach：纯消息/分支
  #     （数据驱动 MessageOnly，见 room_actions/message_only.ex）
  #   - baituo:neishi do_move：状态变更（开/关 down 密道）专用模块 Move
  #
  # **唯一例外**是 shaolin:putiyuan 的 do_get（P5-4h）：`get` 是核心全局命令，
  # 该 handler 必须把「不认识的输入」全部 `:not_handled` 放行（LPC 原文三处
  # `return 0`），只接管 `book/jing from|in hole`。改动它时务必保住这个契约。

  # 拱猪房（P5-4ad）：`inherit/room/pigroom.c` 的 `init()` 里 add_action 了十个动词，
  # 四间房（eproom/nproom/sproom/wproom）完全共用，故先抽成一份再挂四份。
  # 全部 handler 名都进同一个模块，靠 `params.verb` 再分派（见 PigRoom.dispatch/4）。
  # 注意 `sell` 与 `bid` 在 LPC 里就是同一个 `do_bid`。
  @pig_actions %{
    "do_sit" => {Kantele.World.RoomActions.City.PigRoom, :run},
    "do_leave" => {Kantele.World.RoomActions.City.PigRoom, :run},
    "do_deal" => {Kantele.World.RoomActions.City.PigRoom, :run},
    "do_bid" => {Kantele.World.RoomActions.City.PigRoom, :run},
    "do_pass" => {Kantele.World.RoomActions.City.PigRoom, :run},
    "do_play" => {Kantele.World.RoomActions.City.PigRoom, :run},
    "do_refresh" => {Kantele.World.RoomActions.City.PigRoom, :run},
    "do_skip" => {Kantele.World.RoomActions.City.PigRoom, :run},
    "do_claim" => {Kantele.World.RoomActions.City.PigRoom, :run}
  }

  # 棋苑围棋/五子棋（P5-9 #9）：`qiyuan2/3/4` 三间棋室 `init()` 共用七动词，
  # 抽一份挂三份；对局状态在房间 state["qiyuan"]，棋盘规则在 `Kantele.World.Weiqi`。
  @qiyuan_actions %{
    "do_sit" => {Kantele.World.RoomActions.City.Qiyuan, :run},
    "do_leave" => {Kantele.World.RoomActions.City.Qiyuan, :run},
    "do_play" => {Kantele.World.RoomActions.City.Qiyuan, :run},
    "do_pass" => {Kantele.World.RoomActions.City.Qiyuan, :run},
    "do_new" => {Kantele.World.RoomActions.City.Qiyuan, :run},
    "do_undo" => {Kantele.World.RoomActions.City.Qiyuan, :run},
    "do_refresh" => {Kantele.World.RoomActions.City.Qiyuan, :run}
  }

  @registry %{
    "huashan:lianhua" => %{
      "do_tiao" => {Kantele.World.RoomActions.Huashan.Lianhua.Tiao, :run}
    },
    # 剑冢：`move big stone` / `pick fir|sec|thi sword` / `jump lianhua` 与
    # `look fen` 组成独孤求败埋剑谜题（P5-4i）。
    "huashan:jianzhong" => %{
      "do_move" => {Kantele.World.RoomActions.Huashan.Jianzhong.Move, :run},
      "do_pick" => {Kantele.World.RoomActions.Huashan.Jianzhong.Pick, :run},
      "do_jump" => {Kantele.World.RoomActions.Huashan.Jianzhong.Jump, :run}
    },
    # 朝阳峰：`la teng` 抓住青藤 → `jump ya` 跳崖（没拉藤且 dex<30 会摔死进 xuanya，
    # 否则进 jinshedong 金蛇洞）。UCL 已写 `actions = { la, jump }`，零 UCL 改动。
    "huashan:chaoyang" => %{
      "do_la" => {Kantele.World.RoomActions.Huashan.Chaoyang, :run},
      "do_jump" => {Kantele.World.RoomActions.Huashan.Chaoyang, :run}
    },
    "emei:shierpan3" => %{
      "do_clap" => {Kantele.World.RoomActions.Emei.Shierpan3.Clap, :run}
    },
    # 纯消息 / 简单分支：走数据驱动的 MessageOnly（见 room_actions/message_only.ex）
    "hangzhou:liuzhuang" => %{
      "do_knock" => {Kantele.World.RoomActions.MessageOnly, :run}
    },
    "huanggong:inwell" => %{
      "do_reach" => {Kantele.World.RoomActions.MessageOnly, :run}
    },
    # 状态变更样板：开/关密道（set/delete("exits/down") + 查 born_family + 广播）
    "baituo:neishi" => %{
      "do_move" => {Kantele.World.RoomActions.Baituo.Neishi.Move, :run}
    },
    # 房间动作覆盖全局命令的样板（完整移植，非残缺）：禁止吃喝/给/扔/自杀
    "chengdu:guangchang" => %{
      "do_drink" => {Kantele.World.RoomActions.MessageOnly, :run},
      "do_eat" => {Kantele.World.RoomActions.MessageOnly, :run}
    },
    "register:prison" => %{
      "do_eat" => {Kantele.World.RoomActions.MessageOnly, :run},
      "do_drink" => {Kantele.World.RoomActions.MessageOnly, :run},
      "do_suicide" => {Kantele.World.RoomActions.MessageOnly, :run},
      "do_give" => {Kantele.World.RoomActions.MessageOnly, :run},
      "do_drop" => {Kantele.World.RoomActions.MessageOnly, :run}
    },
    # 位移样板（me->move(__DIR__"x") → Helpers.move_to/2 → Teleport.teleport/2）
    "lingxiao:juegu" => %{
      "do_pan" => {Kantele.World.RoomActions.Lingxiao.Juegu.Pan, :run}
    },
    "hengyang:furong1" => %{
      "do_climb" => {Kantele.World.RoomActions.Hengyang.Furong1.Climb, :run},
      "do_pull" => {Kantele.World.RoomActions.Hengyang.Furong1.Pull, :run}
    },
    "hengyang:zigaihole" => %{
      "do_move" => {Kantele.World.RoomActions.Hengyang.Zigaihole.Move, :run}
    },
    "changan:kzsleep" => %{
      "do_bed" => {Kantele.World.RoomActions.Changan.Kzsleep.Bed, :run}
    },
    "xiakedao:xiaowu" => %{
      "do_move" => {Kantele.World.RoomActions.Xiakedao.Xiaowu.Move, :run}
    },
    # 批量机制 #2：数据驱动「文案 + 位移 + 文案」（VisionMove 表）
    "mingjiao:gudi3" => %{
      "do_enter" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    "gumu:taiyi1" => %{
      "do_jump" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    "gumu:taiyi2" => %{
      "do_climb" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    "emei:hcawest" => %{
      "do_jump" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    "emei:xiaoshulin1" => %{
      "do_jump" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    # VisionMove 第二批：LPC 用 message(..., ({me})) 排除行动者的两处
    "emei:ssyb" => %{
      "do_climb" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    "wudu:minju7" => %{
      "do_enter" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    # VisionMove 第三批：无参/空参分支（arg: :none / empty_arg）
    "mingjiao:tohsq3" => %{
      "do_jump" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    "wudu:dijiao" => %{
      "do_move" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    "wudu:minju10" => %{
      "do_move" => {Kantele.World.RoomActions.VisionMove, :run}
    },
    # 状态变更：刮去山壁尘土（set_temp("gua")）解锁 look bi/pic1..3
    "hengyang:inzhushendong" => %{
      "do_gua" => {Kantele.World.RoomActions.Hengyang.Inzhushendong.Gua, :run}
    },
    # 首个**覆盖全局命令**的移植：do_get 只在 `book/jing from|in hole` 且洞已开时
    # 接管，其余输入一律 `:not_handled` 交回全局 GetCommand（LPC 的三处 `return 0`）。
    # do_xian 不在全局命令表，纯新增。详见 P5-4h（菩提院取易筋经）。
    "shaolin:putiyuan" => %{
      "do_get" => {Kantele.World.RoomActions.Shaolin.Putiyuan.Get, :run},
      "do_xian" => {Kantele.World.RoomActions.Shaolin.Putiyuan.Xian, :run}
    },
    # 拱猪四房：十个动词全部由 PigRoom 接管（牌局状态在房间 state["pig_game"]）。
    "city:eproom" => @pig_actions,
    "city:nproom" => @pig_actions,
    "city:sproom" => @pig_actions,
    "city:wproom" => @pig_actions,
    # 赌场（P5-9 #9 一次性场景）：`bet` 动词（UCL 映射 do_bet）由 City.Bet 接管，
    # 骰局状态在房间 state["casino"]；庄家 NPC（changan_zhuangjia）由 UCL room_characters 载入。
    "city:bet" => %{
      "do_bet" => {Kantele.World.RoomActions.City.Bet, :run}
    },
    # 长安赌场大堂（`changan:duchang`，移植自 `d/changan/duchang.c`）是同一套骰局的
    # 第二个实例：UCL 同样挂 `actions = { bet = "do_bet" }` 并载入 `characters.zhuangjia`
    # 庄家，骰局状态各自按 room_id 隔离在 state["casino"]。复用 City.Bet，零 UCL 改动。
    "changan:duchang" => %{
      "do_bet" => {Kantele.World.RoomActions.City.Bet, :run}
    },
    # 醉仙楼宴厅「承办酒席」（P5-9 #9 一次性场景）：`order`/`broadcast` 由 Banquet 接管，
    # 宴会状态在房间 state["banquet"]。三厅 LPC（furong/meigui/mudan）逻辑完全一致，
    # 仅「厅名」不同；UCL 已挂 `actions = { order = "do_order", broadcast = "do_broadcast" }`，
    # 零 UCL 改动。
    "city:furong" => %{
      "do_order" => {Kantele.World.RoomActions.Banquet, :run},
      "do_broadcast" => {Kantele.World.RoomActions.Banquet, :run}
    },
    "city:meigui" => %{
      "do_order" => {Kantele.World.RoomActions.Banquet, :run},
      "do_broadcast" => {Kantele.World.RoomActions.Banquet, :run}
    },
    "city:mudan" => %{
      "do_order" => {Kantele.World.RoomActions.Banquet, :run},
      "do_broadcast" => {Kantele.World.RoomActions.Banquet, :run}
    },
    # 棋苑围棋/五子棋（P5-9 #9 一次性场景）：三间棋室七动词全部由 Qiyuan 接管。
    "city:qiyuan2" => @qiyuan_actions,
    "city:qiyuan3" => @qiyuan_actions,
    "city:qiyuan4" => @qiyuan_actions,
    # ---- 动态出口消费端首批（P5-4ae）----
    # LPC `set/delete("exits/<dir>", ...)` 的玩家触发路径。共用
    # `RoomActions.DynamicExit`（判在 / 开 / 关 / 定时关）。
    # 注意 handler 名以 UCL `actions` 的值为准（转换器抽的是 `add_action` 的第二个
    # 参数，不是函数名）：`meizhuang:didao3` 的 `pull` 动词挂的是 `do_open`。
    # `open`/`close` 是全局命令，这些房间都没有 `doors` 配置，遮蔽不损失既有功能，
    # 且与 LPC `add_action` 优先级一致。
    "changan:xunbufang" => %{
      "do_open" => {Kantele.World.RoomActions.Changan.Xunbufang.Open, :run}
    },
    "guanwai:xiuxishi" => %{
      "do_open" => {Kantele.World.RoomActions.Guanwai.Xiuxishi.Open, :run},
      "do_close" => {Kantele.World.RoomActions.Guanwai.Xiuxishi.Close, :run}
    },
    "huashan:xiuxishi" => %{
      "do_open" => {Kantele.World.RoomActions.Huashan.Xiuxishi.Open, :run},
      "do_close" => {Kantele.World.RoomActions.Huashan.Xiuxishi.Close, :run}
    },
    "lingxiao:shanya" => %{
      "do_open" => {Kantele.World.RoomActions.Lingxiao.Shanya.Open, :run}
    },
    "foshan:pm_restroom" => %{
      "do_open" => {Kantele.World.RoomActions.Foshan.PmRestroom.Open, :run},
      "do_close" => {Kantele.World.RoomActions.Foshan.PmRestroom.Close, :run}
    },
    "meizhuang:didao3" => %{
      "do_open" => {Kantele.World.RoomActions.Meizhuang.Didao3.Pull, :run}
    },
    # ---- 动态出口消费端第二批（P5-4ag）----    # 峨眉舍身崖下「深潭」三连房：`wang`（四处张望）随机冒出四向出口、3 秒后自灭；
    # 只有 `st2` 的 north 有 1/4 概率通向 `emei:ssyb`（脱困唯一出路）。
    # 三房共用同一模块，按 room_id 查出口表。
    "emei:st0" => %{
      "do_wang" => {Kantele.World.RoomActions.Emei.Shentan.Wang, :run}
    },
    "emei:st1" => %{
      "do_wang" => {Kantele.World.RoomActions.Emei.Shentan.Wang, :run}
    },
    "emei:st2" => %{
      "do_wang" => {Kantele.World.RoomActions.Emei.Shentan.Wang, :run}
    },
    # 凌霄内门吊桥（`shanya` 的另一端）与少林山门殿大门：双向门 + 10 秒自动关，
    # `close` 走同一回调但延迟 2 秒（LPC `remove_call_out` 顶掉 `open` 的定时器）。
    "lingxiao:gate" => %{
      "do_open" => {Kantele.World.RoomActions.Lingxiao.Gate.Open, :run},
      "do_close" => {Kantele.World.RoomActions.Lingxiao.Gate.Close, :run}
    },
    "shaolin:smdian" => %{
      "do_open" => {Kantele.World.RoomActions.Shaolin.Smdian.Open, :run},
      "do_close" => {Kantele.World.RoomActions.Shaolin.Smdian.Close, :run}
    },
    # ---- 动态出口消费端（P5-4ak）：do_open/do_close 收尾（2 房）----
    # `hangzhou:loveroom`：`open`/`close` 动词，开/关 `down`→`hangzhou:jiulou`
    # （单向、无定时关，出口常开；附带 `temp["plugin"]` 置位 + 江湖通告广播）。
    # `meizhuang:tianjing`：`open` 动词，开 `south`→`meizhuang:gate` 双向门 + 10s
    # 定时自关（`close_gate` 定时器，无玩家手动 close）。
    "hangzhou:loveroom" => %{
      "do_order" => {Kantele.World.RoomActions.Hangzhou.Loveroom.Order, :run},
      "do_open" => {Kantele.World.RoomActions.Hangzhou.Loveroom.Open, :run},
      "do_close" => {Kantele.World.RoomActions.Hangzhou.Loveroom.Close, :run}
    },
    "meizhuang:tianjing" => %{
      "do_open" => {Kantele.World.RoomActions.Meizhuang.Tianjing.Open, :run}
    },
    # ---- 门/容器第二批（P5-6）：开石盒/石匣发秘籍（2 房）----
    # `tiezhang:mishi`：`open he|shi he` 取铁掌掌谱（`present` 判重，可重复获得
    # 的条件是身上没有）。`wudu:mishi`：`open xia` 取千蛛万毒手秘笈 —— 房间状态
    # `mishi_book` + 玩家 `can_learn/qianzhu-wandushou` 双门控（该 flag 全语料无
    # set 点，发秘笈分支当前不可达，见模块 moduledoc），其它参数 `:not_handled`
    # 放行全局 `open`。
    "tiezhang:mishi" => %{
      "do_open" => {Kantele.World.RoomActions.Tiezhang.Mishi.Open, :run}
    },
    "wudu:mishi" => %{
      "do_open" => {Kantele.World.RoomActions.Wudu.Mishi.Open, :run}
    },
    # `shaolin:zhonglou7`：`knock bell` 敲钟（扣 qi 20 + 广播 + random(2) 加减
    # combat_exp；LPC 文案含繁体「麽」，逐字保留）。
    "shaolin:zhonglou7" => %{
      "do_knock" => {Kantele.World.RoomActions.Shaolin.Zhonglou7.Knock, :run}
    },
    # ---- 动态出口消费端第三批（P5-4ah）----
    # `do_break` 砸墙/砸门/砸冰壁/劈石门一类：10 个房间共用 `RoomActions.Break`
    # 共享原语（内力/最大内力/武力门控、开出口、扣内力、定时关、昏厥、扣 qi、
    # 卸武器），各房只留「参数校验 + 条件门控 + 文案」。守卫统一用
    # `Break.open?/2`（出口是否已开）等价 LPC `query("break")`，因为 break 标志与
    # 出口存在在本批各房里 1:1 同步。
    "beijing:zhuang3" => %{
      "do_break" => {Kantele.World.RoomActions.Beijing.Zhuang3.Break, :run}
    },
    "chengdu:eastroad3" => %{
      "do_break" => {Kantele.World.RoomActions.Chengdu.Eastroad3.Break, :run}
    },
    "fuzhou:houyuan" => %{
      "do_break" => {Kantele.World.RoomActions.Fuzhou.Houyuan.Break, :run}
    },
    "fuzhou:laozhai" => %{
      "do_break" => {Kantele.World.RoomActions.Fuzhou.Laozhai.Break, :run}
    },
    "huashan:sgyhole1" => %{
      "do_break" => {Kantele.World.RoomActions.Huashan.Sgyhole1.Break, :run}
    },
    "jinshe:shanbi" => %{
      "do_break" => {Kantele.World.RoomActions.Jinshe.Shanbi.Break, :run}
    },
    "lingxiao:wave" => %{
      "do_break" => {Kantele.World.RoomActions.Lingxiao.Wave.Break, :run}
    },
    "mingjiao:shandong" => %{
      "do_break" => {Kantele.World.RoomActions.Mingjiao.Shandong.Break, :run}
    },
    "xiakedao:midao4" => %{
      "do_break" => {Kantele.World.RoomActions.Xiakedao.Midao4.Break, :run}
    },
    "shenfeng:yongdao3" => %{
      "do_break" => {Kantele.World.RoomActions.Shenfeng.Yongdao3.Break, :run}
    },
    # ---- 门/容器收尾批（P5-6）：瑶琴暗器 + 砸船桅杆 ----
    #   - yanziwu:tingyu：break qin → 梅花镖，qi<200 死、否则昏厥（无出口变化）
    #   - tulong:boat2：break boat/船（需背包持 stone）→ 3s 后桅杆尽倒 +
    #     房间 state "dao" + "long" 运行期房述覆盖（Room.LookEvent.long_description/1）
    "yanziwu:tingyu" => %{
      "do_break" => {Kantele.World.RoomActions.Yanziwu.Tingyu.Break, :run}
    },
    "tulong:boat2" => %{
      "do_break" => {Kantele.World.RoomActions.Tulong.Boat2.Break, :run}
    },
    # ---- 动态出口消费端第四批（P5-4aj）----
    # `do_push` 推门/推石壁/推草丛/推大床一类：8 个房间共用 `RoomActions.Push`
    # 共享原语（内力/最大内力/臂力/技能门控、开出口、扣内力、定时关、邻居占用判定）。
    # 各房只留「参数校验 + 条件门控 + 文案」。
    #   - guanwai:jingxiu / huashan:xiaolu2：双向门 + 邻居 xiuxishi 占用判定 + 10s 自关
    #   - hengyang:liufugate：需玩家临时标记 marks + 5s 自关
    #   - lingxiao:didi：max_neili>=500 + 5s 自关（无参，恒拦截）
    #   - wanjiegu:entrance：草丛/grass + 10s 自关
    #   - xiakedao:dating：neili>=100 开屏风后甬道、扣 100、5s 自关
    #   - xiakedao:yadi：需 yadi_swim 临时标记 + neili>150、扣 150、5s 自关
    #   - changan:qunyuys8：query_str>=30 开床下暗格、5s 自关
    "guanwai:jingxiu" => %{
      "do_push" => {Kantele.World.RoomActions.Guanwai.Jingxiu.Push, :run},
      # P5-6 收尾：do_knock 与 guanwai:jingxiu 的 do_push 同房，共用 RestKnock 原语
      "do_knock" => {Kantele.World.RoomActions.Guanwai.Jingxiu.Knock, :run}
    },
    "huashan:xiaolu2" => %{
      "do_push" => {Kantele.World.RoomActions.Huashan.Xiaolu2.Push, :run},
      # P5-6 收尾：do_knock 与 huashan:xiaolu2 的 do_push 同房，共用 RestKnock 原语
      "do_knock" => {Kantele.World.RoomActions.Huashan.Xiaolu2.Knock, :run}
    },
    "hengyang:liufugate" => %{
      "do_push" => {Kantele.World.RoomActions.Hengyang.Liufugate.Push, :run},
      # P5-6 收尾：knock 写 marks/liufu，正是本房 do_push 的开门条件
      "do_knock" => {Kantele.World.RoomActions.Hengyang.Liufugate.Knock, :run}
    },
    # P5-6 收尾：揽月居暗语谜题入口（whisper/do_say 已实现）
    "yanziwu:lanyue" => %{
      "do_knock" => {Kantele.World.RoomActions.Yanziwu.Lanyue.Knock, :run},
      "do_say" => {Kantele.World.RoomActions.Yanziwu.Lanyue.Say, :run}
    },
    "lingxiao:didi" => %{
      "do_push" => {Kantele.World.RoomActions.Lingxiao.Didi.Push, :run}
    },
    "wanjiegu:entrance" => %{
      "do_push" => {Kantele.World.RoomActions.Wanjiegu.Entrance.Push, :run}
    },
    "xiakedao:dating" => %{
      "do_push" => {Kantele.World.RoomActions.Xiakedao.Dating.Push, :run}
    },
    "xiakedao:yadi" => %{
      "do_push" => {Kantele.World.RoomActions.Xiakedao.Yadi.Push, :run}
    },
    "changan:qunyuys8" => %{
      "do_push" => {Kantele.World.RoomActions.Changan.Qunyuys8.Push, :run}
    },
    # ---- 动态出口消费端第五批（P5-4al）：do_knock / do_pull ----
    # 敲门/拉柜一类「参数命中即开单向或双向出口 + 定时关」的开门机关，共用
    # `RoomActions.KnockPull` 共享原语。`knock`/`pull` 均非全局命令，遮蔽不损失既有功能。
    #   - shaolin:guangchang1：knock gate/north 开 north↔smdian 双向门 + 10s 自关
    #   - wanjiegu:grassland：knock 段/duan 开 north→xiaoting 单向 + 10s 自关
    #   - quanzhen:diziju：pull cabinet 开 down→mishi 单向 + 8s 自关
    #   - quanzhen:fu_woshi：pull drawer 开 down→fu-midao 单向 + 5s 自关
    #   - wanjiegu:tree_hole：pull 大铁环/ring 开 enter→tunnel1 单向 + 10s 自关
    #   - meizhuang:gate：knock 铜环暗号 4-2-5-3 集齐后开 north↔tianjing 双向门 + 10s 自关
    #     （与 meizhuang:tianjing 的 open 打通同一组双向出口；暗号进度存 meta.temp["knock_step"]）
    "shaolin:guangchang1" => %{
      "do_knock" => {Kantele.World.RoomActions.Shaolin.Guangchang1.Knock, :run}
    },
    "wanjiegu:grassland" => %{
      "do_knock" => {Kantele.World.RoomActions.Wanjiegu.Grassland.Knock, :run}
    },
    "quanzhen:diziju" => %{
      "do_pull" => {Kantele.World.RoomActions.Quanzhen.Diziju.Pull, :run}
    },
    "quanzhen:fu_woshi" => %{
      "do_pull" => {Kantele.World.RoomActions.Quanzhen.FuWoshi.Pull, :run}
    },
    "wanjiegu:tree_hole" => %{
      "do_pull" => {Kantele.World.RoomActions.Wanjiegu.TreeHole.Pull, :run}
    },
    "meizhuang:gate" => %{
      "do_knock" => {Kantele.World.RoomActions.Meizhuang.Gate.Knock, :run}
    },
    # ---- 动态出口消费端第六批（P5-4am）：触发器型 do_circle/do_kan/do_mai/do_turn/do_unlock/do_use/do_zhan ----
    # 「参数命中 + 条件门控（臂力/内力/武器/钥匙/火折/临时标记）→ 开出口（多数定时自关）」
    # 型房间，共用 `RoomActions.Trigger` 共享原语。
    #   - heimuya:huoting：circle wan（str>=12）旋碗开/关 down↔didao1 双向，无定时关
    #   - shenlong:lin1：kan bush（持刀/剑 + neili>100，扣 50）开 north→lin2 + 20s 自关
    #   - xiakedao:gudi：mai/bury gu（neili>100，扣 100）开 east→midao6 + 5s 自关
    #   - beijing:aofu_shufang：turn bashou（marks/画2）开 down→aofu_mishi + 8s 自关
    #   - xueshan:chanshi：turn lunpan 开 down→midao + 8s 自关
    #   - jingzhou:houyuan：unlock men/east（须持 guifang key，钥匙消耗）开 east→dongxiang，无定时关
    #   - hengyang:inhole2：use fire（须持 fire）开 west→zigai1 + north→zigai2，无定时关
    #   - gumu:mishi1：ci brick（须持兵器，置 tmarks/砖）+ zhan brick（tmarks/砖>=1）
    #     开 down→houting + 5s 自关；do_ci 虽不改出口，但是 do_zhan 的前置门槛，一并移植
    # 跳过：huanggong:shufang（press desk 的暗门目标 huanggong:mishi 在 LPC 源中不存在，
    # 空目标死内容）。
    "heimuya:huoting" => %{
      "do_circle" => {Kantele.World.RoomActions.Heimuya.Huoting.Circle, :run}
    },
    "shenlong:lin1" => %{
      "do_kan" => {Kantele.World.RoomActions.Shenlong.Lin1.Kan, :run}
    },
    "xiakedao:gudi" => %{
      "do_mai" => {Kantele.World.RoomActions.Xiakedao.Gudi.Mai, :run}
    },
    "beijing:aofu_shufang" => %{
      "do_turn" => {Kantele.World.RoomActions.Beijing.AofuShufang.Turn, :run}
    },
    "xueshan:chanshi" => %{
      "do_turn" => {Kantele.World.RoomActions.Xueshan.Chanshi.Turn, :run}
    },
    "jingzhou:houyuan" => %{
      "do_unlock" => {Kantele.World.RoomActions.Jingzhou.Houyuan.Unlock, :run}
    },
    "hengyang:inhole2" => %{
      "do_use" => {Kantele.World.RoomActions.Hengyang.Inhole2.Use, :run}
    },
    "gumu:mishi1" => %{
      "do_ci" => {Kantele.World.RoomActions.Gumu.Mishi1.Ci, :run},
      "do_zhan" => {Kantele.World.RoomActions.Gumu.Mishi1.Zhan, :run}
    },
    # ---- 动态出口消费端第七批（P5-4an）：移像/推石/推桌型 do_move + do_push ----
    # 「参数命中 + 属性门控（臂力/内力/最大内力/基本内功/基本拳）→ 推开出口（多数定时自关）」
    # 型房间，共用 `RoomActions.MoveStone` 共享原语。
    #   - emei:hcadadian：move xiang 开 down→midao + 8s
    #   - gumu:mumen：move shi 开 south→qianting + 5s
    #   - jingzhou:luan2 / tiezhang:wmfeng：move bei（str>=30 + force>=100）开 enter→tomb/shijie_1
    #     + 10s；玩家 write + 房间广播（排除行动者）
    #   - jinshe:yongdao2：move stone（neili>=1500 + str>=35，扣 1000）开 north→shandong + 5s
    #   - kaifeng:hh_xiaozhu：move zhuo（max_neili>=1000；非红花会且余鱼同在席被喝退）
    #     开 down→hh_mishi + 10s；成功也清内力
    #   - shaolin:beilin2：move stone（max_neili>=1000）开 down→beilin3，无定时关
    #   - shenfeng:yushi：move table（须 marks/爬1，读完即删）开 enter↔yongdao5 双向，无定时关
    #   - wudang:nanyangong：move xiang 开 down↔nanyan0 双向 + 3s（两侧播报、只删本房）
    #   - wudu:huating2：move lu 开 down→midao + 8s
    #   - hengyang:outzigai1：push/tui bi（neili>=1500 + unarmed>=80）开 enter↔zigaihole 双向
    #     + 13s；房间级 temp marks/推 同步回收（look bi 的 room_temp_tiers 依赖它）
    #   - shenfeng:shenfeng：move sand 清沙 6 层（房间 mark/sand 计数 + busy 2）；
    #     push gate（force>=300 + sand>=5 + neili>=1500）开 enter↔yongdao1 双向并扣 1000 内力，
    #     失败则震落山脚（move + receive_wound("qi",200) + unconcious）
    "shenfeng:shenfeng" => %{
      "do_move" => {Kantele.World.RoomActions.Shenfeng.Shenfeng.Sand, :run},
      "do_push" => {Kantele.World.RoomActions.Shenfeng.Shenfeng.Push, :run}
    },
    "emei:hcadadian" => %{
      "do_move" => {Kantele.World.RoomActions.Emei.Hcadadian.Move, :run}
    },
    "gumu:mumen" => %{
      "do_move" => {Kantele.World.RoomActions.Gumu.Mumen.Move, :run}
    },
    "jingzhou:luan2" => %{
      "do_move" => {Kantele.World.RoomActions.Jingzhou.Luan2.Move, :run}
    },
    "tiezhang:wmfeng" => %{
      "do_move" => {Kantele.World.RoomActions.Tiezhang.Wmfeng.Move, :run}
    },
    "jinshe:yongdao2" => %{
      "do_move" => {Kantele.World.RoomActions.Jinshe.Yongdao2.Move, :run}
    },
    "kaifeng:hh_xiaozhu" => %{
      "do_move" => {Kantele.World.RoomActions.Kaifeng.HhXiaozhu.Move, :run}
    },
    "shaolin:beilin2" => %{
      "do_move" => {Kantele.World.RoomActions.Shaolin.Beilin2.Move, :run}
    },
    "shenfeng:yushi" => %{
      "do_move" => {Kantele.World.RoomActions.Shenfeng.Yushi.Move, :run}
    },
    "wudang:nanyangong" => %{
      "do_move" => {Kantele.World.RoomActions.Wudang.Nanyangong.Move, :run}
    },
    "wudu:huating2" => %{
      "do_move" => {Kantele.World.RoomActions.Wudu.Huating2.Move, :run}
    },
    "hengyang:outzigai1" => %{
      "do_push" => {Kantele.World.RoomActions.Hengyang.Outzigai1.Push, :run}
    },
    "room:qianting" => %{
      "do_push" => {Kantele.World.RoomActions.Room.Panlong.Qianting.Push, :run},
      "do_close" => {Kantele.World.RoomActions.Room.Panlong.Qianting.Close, :run}
    },
    "room:zoudao" => %{
      "do_push" => {Kantele.World.RoomActions.Room.Panlong.Zoudao.Push, :run},
      "do_close" => {Kantele.World.RoomActions.Room.Panlong.Zoudao.Close, :run}
    },
    # ---- 地形穿越类消费端（P5-4aq-A）：攀爬/跳跃/渡水/穿潭 ----
    # 11 间房共用 `RoomActions.TerrainMove` 数据驱动 handler（按 {room_id, 归一化动词}
    # 查表）。动词别名在 handler 内归一：pa→climb、tiao→jump、you→swim。
    #   - hengyang:outzhushendong：climb teng（qi<100 摔落）
    #   - hengyang:outzigai：climb stone（静默提示+位移）/ tiao stone（必摔晕）
    #   - hengyang:shuiliandong：tiao pubu/瀑布（按轻功分三档）
    #   - hengyang:xuanyadi：climb teng（qi 门控）/ tree（静默位移）
    #   - jueqing:eyutan1/eyutan3：cross tan（轻功>120 过潭/落深潭）
    #   - jueqing:eyutan2：swim bank（游回岸上）
    #   - jueqing:ontree1：jump down（跳下枣树）/ ontree3：climb teng（爬出石窟）
    #   - jueqing:undertan：climb tree（爬上枣树）/ underya2：jump tan（入潭到寒潭尽头）
    "hengyang:outzhushendong" => %{
      "do_climb" => {Kantele.World.RoomActions.TerrainMove, :run}
    },
    "hengyang:outzigai" => %{
      "do_climb" => {Kantele.World.RoomActions.TerrainMove, :run},
      "do_tiao" => {Kantele.World.RoomActions.TerrainMove, :run}
    },
    "hengyang:shuiliandong" => %{
      "do_tiao" => {Kantele.World.RoomActions.TerrainMove, :run}
    },
    "hengyang:xuanyadi" => %{
      "do_climb" => {Kantele.World.RoomActions.TerrainMove, :run}
    },
    "jueqing:eyutan1" => %{
      "do_cross" => {Kantele.World.RoomActions.TerrainMove, :run}
    },
    "jueqing:eyutan2" => %{
      "do_swim" => {Kantele.World.RoomActions.TerrainMove, :run}
    },
    "jueqing:eyutan3" => %{
      "do_cross" => {Kantele.World.RoomActions.TerrainMove, :run}
    },
    "jueqing:ontree1" => %{
      "do_jump" => {Kantele.World.RoomActions.TerrainMove, :run}
    },
    "jueqing:ontree3" => %{
      "do_climb" => {Kantele.World.RoomActions.TerrainMove, :run}
    },
    "jueqing:undertan" => %{
      "do_climb" => {Kantele.World.RoomActions.TerrainMove, :run}
    },
    "jueqing:underya2" => %{
      "do_jump" => {Kantele.World.RoomActions.TerrainMove, :run}
    },
    # ---- 绝情谷「硬房」消费端（P5-4aq-B）：duanchang/underya/xiangfang1/jianshi ----
    # 这 4 间房 LPC 的 `do_*` 含「延时移动（call_out）」「房间 state 机关位」
    # 「单例物品实例化」三类语义，无法走数据驱动的 TerrainMove，各写一个专用模块。
    #   - duanchang：do_jump（tiao/jump）两步跳崖 → 延时 trap/effect 落到 underya + 昏厥
    #   - underya：do_bao（抱石）/do_climb（爬藤）/do_jump（潜水）含延时出水回岸
    #   - xiangfang1：do_turn（转花盆开/关暗道房间 state marks/转）/do_jump（跳洞
    #     须机关已开，延时落到 eyutan2，并跨房向 eyutan1 广播）
    #   - jianshi：do_pull（拉画置 marks/拉）/do_pick（取君子剑/淑女剑，单例物品实例化）
    "jueqing:duanchang" => %{
      "do_jump" => {Kantele.World.RoomActions.Jueqing.Duanchang, :run}
    },
    "jueqing:underya" => %{
      "do_bao" => {Kantele.World.RoomActions.Jueqing.Underya, :run},
      "do_climb" => {Kantele.World.RoomActions.Jueqing.Underya, :run},
      "do_jump" => {Kantele.World.RoomActions.Jueqing.Underya, :run}
    },
    "jueqing:xiangfang1" => %{
      "do_turn" => {Kantele.World.RoomActions.Jueqing.Xiangfang1, :run},
      "do_jump" => {Kantele.World.RoomActions.Jueqing.Xiangfang1, :run}
    },
    "jueqing:jianshi" => %{
      "do_pull" => {Kantele.World.RoomActions.Jueqing.Jianshi, :run},
      "do_pick" => {Kantele.World.RoomActions.Jueqing.Jianshi, :run}
    },
    # ---- P5-8 通信中继·载具：`on_board` 定时载具（heimuya 吊篮 / guiyun 渡船）----
    # 这 4 间房 UCL 已有 `actions`（insert / yell / cross / shang），转换器直写出
    # handler 名；本批把它们统一接到 `Vehicle.Trigger`（数据驱动，按 room_id 查配置
    # 启动 check_trigger→on_board→arrive→close_passage 四步定时链路）。详见
    # `room_actions/vehicle.ex` 与 `room_actions/vehicle_trigger.ex`。
    #   - heimuya:up2 / up3：insert 吊篮（basket）→ up3 / up4
    #   - guiyun:taihu / matou：yell / cross / shang 渡船（duchuan）→ matou / taihu
    "heimuya:up2" => %{
      "do_insert" => {Kantele.World.RoomActions.Vehicle.Trigger, :run}
    },
    "heimuya:up3" => %{
      "do_insert" => {Kantele.World.RoomActions.Vehicle.Trigger, :run}
    },
    "guiyun:taihu" => %{
      "do_yell" => {Kantele.World.RoomActions.Vehicle.Trigger, :run},
      "do_cross" => {Kantele.World.RoomActions.Vehicle.Trigger, :run}
    },
    "guiyun:matou" => %{
      "do_yell" => {Kantele.World.RoomActions.Vehicle.Trigger, :run},
      "do_cross" => {Kantele.World.RoomActions.Vehicle.Trigger, :run},
      "do_shang" => {Kantele.World.RoomActions.Vehicle.Trigger, :run}
    },
    # ---- 郭府打工闭环（P5 补全 yelvqi 打工闭环）：五工作房动词 ----
    # 各房 `actions` 由 UCL 绑定 verb→handler 名（sao/chu/jiao/pi/ju），全部复用
    # 同一配置驱动模块 `Wuguan.Work`，按 room_id 查配置（job/参数词/进度 mark/
    # 完成 mark/管事）。柴房(guofu_chaifang) 与木房(guofu_mufang) 的 verb 都映射
    # 到 handler 名 "do_pi"，房间级注册表各自指向本模块即可。
    "wuguan:guofu_mafang" => %{
      "do_sao" => {Kantele.World.RoomActions.Wuguan.Work, :run}
    },
    "wuguan:guofu_caidi1" => %{
      "do_chu" => {Kantele.World.RoomActions.Wuguan.Work, :run}
    },
    "wuguan:guofu_caidi2" => %{
      "do_jiao" => {Kantele.World.RoomActions.Wuguan.Work, :run}
    },
    "wuguan:guofu_chaifang" => %{
      "do_pi" => {Kantele.World.RoomActions.Wuguan.Work, :run}
    },
    "wuguan:guofu_mufang" => %{
      "do_pi" => {Kantele.World.RoomActions.Wuguan.Work, :run}
    }
  }

  @doc """
  解析 (room_id, handler_name) 到 Elixir `{module, function}`。

  返回 `{:ok, {module, function}}` 或 `{:unimplemented, handler_name}`。
  房间不存在 / handler 未在该房间移植 → 均视为未实现（安全降级）。
  """
  def lookup(room_id, handler_name) when is_binary(room_id) and is_binary(handler_name) do
    case Map.get(@registry, room_id) do
      nil ->
        {:unimplemented, handler_name}

      room_map ->
        case Map.get(room_map, handler_name) do
          nil -> {:unimplemented, handler_name}
          {module, function} -> {:ok, {module, function}}
        end
    end
  end

  def lookup(_room_id, handler_name), do: {:unimplemented, handler_name}

  @doc "该房间的 handler 是否已有 Elixir 实现（已注册）。"
  def registered?(room_id, handler_name), do: match?({:ok, _}, lookup(room_id, handler_name))

  @doc "当前已注册的房间 id 列表，用于覆盖度统计。"
  def registered_rooms(), do: Map.keys(@registry)
end
