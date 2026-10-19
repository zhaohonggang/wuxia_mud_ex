defmodule Kantele.World.NpcActionHandlers do
  @moduledoc """
  NPC `add_action` handler 注册表(P5-1c)。

  LPC NPC 通过 `add_action("verb", "do_*")` 注册自定义动词，handler 是 LPC
  函数名。回填(P5-1a)已把 NPC 的 `init.add_actions` 写入 UCL。本模块负责
  把 **handler 名** 解析为可执行的 Elixir `{module, function}`，由 P5-1c-2
  的对象级分发路由调用。

  ## 注册策略

  registry 是**房间级**：`room_id => %{verb => {module, function}}`。
  `room_id` 为 UCL 房间 id（`zone:key`，重启不变），**不使用**
  `Character.generate_id()`（重启后会变动）。按房间区分，避免不同房间
  同名 NPC 的动词互相干扰。

  ## 注册示例

      @registry %{
        "tulong:huichang_back" => %{
          "yun" => {Kantele.World.NpcActions.Yun, :run}
        }
      }

  ## 安全性(P7)

  未注册的房间/verb 经 `lookup/2` 返回 `{:unimplemented, verb}`，分发路由
  据此给出 `:not_handled` 放行全局命令，**对全局命令零行为影响**。
  仅当某房间某 NPC verb 的 handler 被真正移植并注册后，该动作才被
  拦截激活。

  ## 已注册(P5-1c-3)

  - `yun`：纯输出动作（`arg == "roar"` 广播一条 vision 文案，否则 `return 0`
    放行），零状态变更，四个 NPC 注册了它：
    - 殷素素：tulong:huichang_back、tulong:huichang
    - 赵一伤：tulong:jiulou、tulong:was_dayuan

  - `ride*` 十连：beijing 马童快速旅行（八卦门专属），10 个动词复用
    `Kantele.World.NpcActions.Ride`，注册于 `beijing:majuan`：
    - rideyz, ridedl, rideem, ridefs, ridefz, ridehz, ridesz, ridexy, rideyd, rideyl

  - `bi` / `get`：屠龙刀扬刀立威会场四关（常金鹏/元广波/麦鲸/过三拳），
    `Kantele.World.NpcActions.Bi`，注册于 tulong 会场两房间：
    - tulong:huichang_back、tulong:huichang（bi、get）

  - `yao` 要物三连：黄真（xiangyang:qianzhuang，发商令）/ 田嫂（wudu:chufang，
    发两个蛇肉包子）/ 钱正伦（beijing:bingqi，发兵器护甲）复用
    `Kantele.World.NpcActions.Yao`，按 room_id 分派。钱正伦的共享发放上限依赖
    `Kantele.World.NpcActions.Counters`（按 room_id 计数）。

  - `decide` 二连：陆小凤（guiyun:taihu，发引荐书信）/ 黄真
    （xiangyang:qianzhuang，商业协会入退）复用
    `Kantele.World.NpcActions.Decide`，按 room_id 分派。海公公
    （beijing:dongchang，昏迷红区）/ 水笙（register:entry，邮箱注册）暂未移植。

  - `serve` 二连：梅庄/郭府厨师（`meizhuang:chufang`、`wuguan:guofu_fanting`），
    `Kantele.World.NpcActions.Serve`，两份 LPC 实现逐字相同，复用一份
    handler：身上/地上已有饭+茶 → 拒绝；否则发饭 + 茶。

  - `puzzle` 单连：李瘦辞（`beijing:wenmiao`，`Kantele.World.NpcActions.Puzzle`）：
    外部灯谜 API 无部署 → 仅降级提示（@todo：HTTP 出题 + GIFT_D 奖励）。

  - `join` / `unjoin`：黄真（xiangyang:qianzhuang）商业协会入/退的入口标记
    （落 `want_join` / `want_tuoli`，由同房间 `decide` 消费）。`join` 按 verb
    粒度虽在 survey 死功能排除项内（依据天地会），但黄真分支是活的，此处为
    房间级例外（仅此一间命中）。

  - `task` 单连：耶律齐（`wuguan:guofu_dayuan2`，郭府大院），
    `Kantele.World.NpcActions.Task`：`task ok` 覆命领赏的四个守门分支
    （未领工/活没干完/工期内太快/工具未还）+ 成功路径 @todo（银两/经验/
    潜能发放被 P2/P9 与无银两 item 阻塞，暂只播 NPC 台词）。

  - `txbw` 单连：天下布武使者（`city:wuguan`），`Kantele.World.NpcActions.Txbw`：
    花 5000 gold 存款学 29 种入门武功之一的五级守门（用法/经验/存款/
    清单外/已掌握）+ 成功路径 @todo（`improve_skill` 直升语义与 P9 学习
    系统不匹配，暂静默消费）。

  - `exchange` / `duihuan` 二连（积分兑换，店小二，`city:kedian`）：
    `Kantele.World.NpcActions.Exchange`，整链落地——32 种兑换表、积分
    读写（`PlayerMeta.jifen`）、扣分 + 发物（`Helpers.give_item`）；14 种
    世界数据缺失的礼品落 LPC `!ob` 分支文案（不扣分），数据补齐后自动可兑；
    rumor 频道 @todo。

  - `choose` 单连（宠物店老板，`city:zhujuan`）：`Kantele.World.NpcActions.Choose`，
    驭兽术 < 30 / 未付 `pet/money`（say 报价）两道守门；宠物定制链
    （input_to 四步 + 模板落盘）不可移植，且原世界该分支即不可达
    （无任何文件写 `pet/money`），落静默 @todo。

  - `sign` 单连（乌老大，`pk:entry`）：`Kantele.World.NpcActions.Sign`，
    打招呼广播 + 经验 < 1 万拒绝；PK_D 未建模 → 落地其「无赛事」态文案，
    赛事流程（骑马/携人检查/传送准备室）@todo。

  - `copy` 二连 / `sew` / `mine` 二连 / `move`（打工类守门族，书童
    `guiyun:shufang`、朱熹 `city:shuyuan`、曾柔 `city:garments`、监工
    `guanwai:shichang` + `hangzhou:kuangshan`）：`Kantele.World.NpcActions.Jobs`，
    LPC 五份同构 handler（`is_busy` → `job/*` temp → 拒绝/多轮干活）的
    共享守门落地——未领活时按各 NPC 文案拒绝（抄书系广播、监工系渲染），
    多轮 `start_busy` 干活流程 @todo（`ask_job` 未移植，该分支不可达）。

  - `bi` 倚天万安寺四关（`tulong:was_lou4` 何太冲/阿三/阿二/阿大 +
    `tulong:jiulou` 阿大单挑）：`Kantele.World.NpcActions.Yitian`，
    链条守卫（`win_he`/`win_asan`/`win_aer` 击杀标记 + 兵器/空手判定，
    跳过已倒下 NPC）与开场文案完整落地；胜负经 8~10 拍脚本结算
    （`CallOut` → `Down.mark_dead` + `yitian/result` 落标记/广播死亡
    文案）；@todo：倚天剑 `move`/`wield`（物品态 API 缺 + UCL 未把剑
    放进剑架）、阿大倒后鹤笔翁/鹿杖客动态 spawn、窗口内真实击杀无
    `win_*`（战斗死亡钩子属红区）、社交动作 heng/grin/nod/shake
    （`emoted.c` 无定义，原世界即静默）。
  """
  # 房间级注册表：room_id -> (verb -> {module, function})。
  @registry %{
    "tulong:huichang_back" => %{
      "yun" => {Kantele.World.NpcActions.Yun, :run},
      "bi" => {Kantele.World.NpcActions.Bi, :run},
      "get" => {Kantele.World.NpcActions.Bi, :run}
    },
    "tulong:huichang" => %{
      "yun" => {Kantele.World.NpcActions.Yun, :run},
      "bi" => {Kantele.World.NpcActions.Bi, :run},
      "get" => {Kantele.World.NpcActions.Bi, :run}
    },
    "tulong:jiulou" => %{
      "yun" => {Kantele.World.NpcActions.Yun, :run},
      "bi" => {Kantele.World.NpcActions.Yitian, :run}
    },
    "tulong:was_dayuan" => %{
      "yun" => {Kantele.World.NpcActions.Yun, :run}
    },
    "beijing:majuan" => %{
      "rideyz" => {Kantele.World.NpcActions.Ride, :run},
      "ridedl" => {Kantele.World.NpcActions.Ride, :run},
      "rideem" => {Kantele.World.NpcActions.Ride, :run},
      "ridefs" => {Kantele.World.NpcActions.Ride, :run},
      "ridefz" => {Kantele.World.NpcActions.Ride, :run},
      "ridehz" => {Kantele.World.NpcActions.Ride, :run},
      "ridesz" => {Kantele.World.NpcActions.Ride, :run},
      "ridexy" => {Kantele.World.NpcActions.Ride, :run},
      "rideyd" => {Kantele.World.NpcActions.Ride, :run},
      "rideyl" => {Kantele.World.NpcActions.Ride, :run}
    },
    "xiangyang:qianzhuang" => %{
      "yao" => {Kantele.World.NpcActions.Yao, :run},
      "decide" => {Kantele.World.NpcActions.Decide, :run},
      "join" => {Kantele.World.NpcActions.Decide, :run},
      "unjoin" => {Kantele.World.NpcActions.Decide, :run}
    },
    "guiyun:taihu" => %{
      "decide" => {Kantele.World.NpcActions.Decide, :run}
    },
    "wudu:chufang" => %{
      "yao" => {Kantele.World.NpcActions.Yao, :run}
    },
    "beijing:bingqi" => %{
      "yao" => {Kantele.World.NpcActions.Yao, :run}
    },
    "meizhuang:chufang" => %{
      "serve" => {Kantele.World.NpcActions.Serve, :run}
    },
    "wuguan:guofu_fanting" => %{
      "serve" => {Kantele.World.NpcActions.Serve, :run}
    },
    "wuguan:guofu_dayuan2" => %{
      "task" => {Kantele.World.NpcActions.Task, :run}
    },
    "city:wuguan" => %{
      "txbw" => {Kantele.World.NpcActions.Txbw, :run}
    },
    "city:kedian" => %{
      "exchange" => {Kantele.World.NpcActions.Exchange, :run},
      "duihuan" => {Kantele.World.NpcActions.Exchange, :run}
    },
    "city:zhujuan" => %{
      "choose" => {Kantele.World.NpcActions.Choose, :run}
    },
    "pk:entry" => %{
      "sign" => {Kantele.World.NpcActions.Sign, :run}
    },
    "guiyun:shufang" => %{
      "copy" => {Kantele.World.NpcActions.Jobs, :run}
    },
    "city:shuyuan" => %{
      "copy" => {Kantele.World.NpcActions.Jobs, :run}
    },
    "city:garments" => %{
      "sew" => {Kantele.World.NpcActions.Jobs, :run}
    },
    "guanwai:shichang" => %{
      "mine" => {Kantele.World.NpcActions.Jobs, :run},
      "move" => {Kantele.World.NpcActions.Jobs, :run}
    },
    "hangzhou:kuangshan" => %{
      "mine" => {Kantele.World.NpcActions.Jobs, :run}
    },
    "tulong:was_lou4" => %{
      "bi" => {Kantele.World.NpcActions.Yitian, :run}
    },
    "beijing:wenmiao" => %{
      "puzzle" => {Kantele.World.NpcActions.Puzzle, :run}
    },
    "hangzhou:liuhe9" => %{
      "kneel" => {Kantele.World.NpcActions.Kneel, :run}
    },
    "kaifeng:yaopu" => %{
      "peiyao" => {Kantele.World.NpcActions.Peiyao, :run}
    }
  }

  @doc """
  解析 (room_id, verb) 到 Elixir `{module, function}`。

  返回 `{:ok, {module, function}}` 或 `{:unimplemented, verb}`。
  房间未注册 / verb 未在该房间移植 → 均视为未实现（安全降级）。
  """
  def lookup(room_id, verb) when is_binary(room_id) and is_binary(verb) do
    case Map.get(@registry, room_id) do
      nil ->
        {:unimplemented, verb}

      room_map ->
        case Map.get(room_map, verb) do
          nil -> {:unimplemented, verb}
          {module, function} -> {:ok, {module, function}}
        end
    end
  end

  def lookup(_room_id, _verb), do: {:unimplemented, :unknown}

  @doc "该房间的 verb 是否已有 Elixir 实现（已注册）。"
  def registered?(room_id, verb), do: match?({:ok, _}, lookup(room_id, verb))

  @doc "当前已注册的房间 id 列表，用于覆盖度统计。"
  def registered_rooms(), do: Map.keys(@registry)
end
