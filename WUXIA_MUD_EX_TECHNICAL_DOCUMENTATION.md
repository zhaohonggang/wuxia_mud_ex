# wuxia_mud_ex 技术文档

---

## 1. 项目概览

### 1.1 项目背景与定位
**wuxia_mud_ex** 是一个基于 **Elixir/OTP** 的武侠题材 MUD（Multi-User Dungeon）游戏引擎。项目源于 [ExVenture](https://github.com/oestrich/ex_venture)，在其基础上集成了 **Kalevala** MUD 框架，并大幅扩展了武侠核心玩法：内功/招式/经脉/门派/江湖恩怨/动态世界事件。

**核心特性**：
- **多协议接入**：原生 Telnet（支持 GMCP、NAWS、ANSI 颜色）+ WebSocket（React 前端）
- **Actor 模型架构**：每个玩家一个 Foreman 进程，房间/频道/战斗/任务均为独立 GenServer
- **事件驱动**：基于 `Kalevala.Event` 的发布/订阅总线，跨进程解耦
- **热更新友好**：代码热重载、数据库迁移、UCL 配置热加载
- **武侠系统完备**：内功心法、招式组合、经脉冲穴、门派传承、师徒/帮派/结义、装备强化镶嵌注灵

### 1.2 技术栈
| 层级 | 技术 | 版本/来源 |
|------|------|-----------|
| 语言/运行时 | Elixir / Erlang OTP | 1.11+ / 23+ |
| Web 框架 | Phoenix | 1.5 |
| MUD 核心框架 | Kalevala | 本地 `vendor/kalevala` (fork) |
| 数据库 | PostgreSQL + Ecto | 12+ / 3.1 |
| 前端 | React + Redux + Webpack | 17+ / assets/ |
| 实时通信 | Phoenix Channels + WebSocket | Cowboy 2 |
| 文本协议 | Telnet (RFC 854/855) + GMCP | 自研扩展 |
| 配置格式 | UCL (Universal Config Language) | `stein` 解析器 |
| 容器化 | Docker + Docker Compose | multi-stage build |
| 测试 | ExUnit + Ecto Sandbox | 2342+ cases |
| 代码质量 | Credo + Dialyzer | CI 集成 |

### 1.3 架构设计理念
1. **进程隔离**：每个玩家会话、每个房间、每场战斗、每个任务守护进程均为独立 GenServer，故障域隔离，避免单点崩溃波及全服
2. **事件总线解耦**：`Kalevala.Event` + `Phoenix.PubSub` 实现跨节点消息路由，业务逻辑通过 `Event.Router` 声明式订阅
3. **不可变数据流**：玩家状态（Character/Stats/Vitals）采用结构化更新，配合 Ecto 变更集持久化
4. **配置即代码**：世界/房间/NPC/机器人/帮派均以 UCL 文件定义，支持热加载与版本控制
5. **双端同构渲染**：服务端 `~i` 模板 + `Kalevala.Output.Tags` 生成 ANSI/Tag 树，Telnet 端转 ANSI，Web 端转 React 组件树

---

## 2. 核心架构

### 2.1 Kalevala 框架集成
`vendor/kalevala` 作为核心依赖（`mix.exs:54`），提供：
- **Character/Conn/Foreman**：玩家会话生命周期
- **Controller/Router**：命令控制器链（Login → Command → Combat → Quest）
- **Event/Router**：声明式事件路由（`scope/module/event` 三级）
- **Communication/Channel**：频道发布/订阅（`general`/`rumor`/`rooms:`/`characters:`）
- **Output/Tags**：`{color...}` 标签解析 → ANSI / Tag 树 / 纯文本
- **Telnet/WebSocket 协议适配器**：统一 `{:send, iodata}` 推送接口

**项目侧扩展点**（`lib/kantele/`）：
```elixir
# 典型集成方式
defmodule ExVenture.Application.KalevalaSupervisor do
  def foreman_options() do
    [
      supervisor_name: Kantele.Character.Foreman.Supervisor,
      communication_module: Kantele.Communication,  # 自定义频道
      initial_controller: Kantele.Character.LoginController,
      presence_module: Kantele.Character.Presence,
      quit_view: {Kantele.Character.QuitView, "disconnected"}
    ]
  end
end
```

### 2.2 进程模型
```
┌─────────────────────────────────────────────────────────────┐
│                      Erlang VM (BEAM)                        │
├─────────────────────────────────────────────────────────────┤
│  Supervision Tree                                           │
│  ├─ Kantele.Config (全局配置缓存)                            │
│  ├─ Kantele.Communication (频道 Supervisor)                 │
│  ├─ Kantele.World (World Supervisor)                        │
│  │   ├─ Kantele.World.QuestDaemon (任务守护)                 │
│  │   ├─ Kantele.World.GameTime (游戏时钟)                    │
│  │   ├─ Kantele.World.Weather (天气系统)                     │
│  │   ├─ Kantele.World.Story (全服剧情调度)                   │
│  │   └─ Kantele.World.Invasion (入侵事件)                    │
│  ├─ Kantele.Character.Foreman.Supervisor (玩家会话池)       │
│  │   └─ Foreman (每玩家一个)                                 │
│  │       ├─ Controller Chain: Login → Command → Combat      │
│  │       └─ State: Character + Stats + Vitals + Meta        │
│  ├─ Room Processes (每房间一个 GenServer)                   │
│  │   ├─ Room Channel (rooms:room_id)                        │
│  │   └─ NPC/Item Spawns                                     │
│  ├─ Combat Processes (每战斗实例一个)                        │
│  └─ Channel Processes (general/rumor/bill/waidi + 私有)     │
└─────────────────────────────────────────────────────────────┘
```

**关键进程**：
- **Foreman** (`vendor/kalevala/lib/kalevala/character/foreman.ex`)：玩家会话根进程，持有 `Conn` 状态，管理控制器链
- **Room** (`lib/kantele/world/room.ex`)：区域容器，管理角色进出、NPC 漫游、战斗触发
- **Combat** (`lib/kantele/combat/engine.ex`)：战斗实例，独立进程处理回合/招式/Buff
- **QuestDaemon** (`lib/kantele/world/quest_daemon.ex`)：任务调度器，驱动任务流程图

### 2.3 事件总线
**核心模块**：`vendor/kalevala/lib/kalevala/event.ex` + `lib/kantele/character/events.ex`

**事件定义**：
```elixir
# lib/kantele/character/events.ex
scope(Kantele.Character) do
  module(CombatEvent) do
    event("combat/start", :start)
    event("combat/tick", :tick)
    event(Message, :echo, interested?: &CombatEvent.interested?/1)
  end
  
  module(ChannelEvent) do
    event(Message, :echo, interested?: &ChannelEvent.interested?/1)
  end
end
```

**事件流向**：
```
[源] → publish(event) → [Channel/PubSub] → [订阅者 Foreman] → handle_info({:event, event})
                                      ↓
                               Event.Router.call(conn, event)
                                      ↓
                               对应 Module.function(conn, event)
```

**核心事件类型**：
| 事件 Topic | 用途 | 典型载荷 |
|------------|------|----------|
| `combat/start` | 战斗开始 | `{attacker, defender, room_id}` |
| `combat/tick` | 战斗回合推进 | `{combat_pid, round}` |
| `rooms:room_id` | 房间广播 | `{character, text, type}` |
| `characters:char_id` | 私信/定向 | `{from, text, meta}` |
| `general`/`rumor` | 公共频道 | `{channel, character, text}` |
| `skills/teach` | 师徒传功 | `{teacher, student, skill}` |
| `quest/turnin-request` | 任务交付 | `{quest_id, items}` |

### 2.4 命令解析与路由
**技术栈**：`NimbleParsec` + `Kalevala.Character.Command.Router` (DSL)

**定义示例** (`lib/kantele/character/commands.ex:6-10`)：
```elixir
module(ChannelCommand) do
  parse("general", :general, fn command ->
    command |> spaces() |> text(:text)
  end)
end
```

**解析流程**：
```
用户输入 "general hello"
    ↓
Kalevala.Output.Tags.escape (转义 { } 防注入，channel_command 例外)
    ↓
Commands.call(conn, data) → Router.parse(text)
    ↓
NimbleParsec 匹配 "general" → {:ok, %ParsedCommand{module: ChannelCommand, function: :general, params: %{text: "hello"}}}
    ↓
apply(ChannelCommand, :general, [conn, params])
    ↓
ChannelCommand.general/2 → publish_message("general", "hello")
```

**命令层级**：
- **内置别名** (`lib/kantele/character/aliases.ex`)：玩家自定义短命令
- **动态命令** (`Kalevala.Character.Command.DynamicCommand`): 运行时注册
- **控制器链**：`LoginController` → `CommandController` → `CombatController` → `QuestController`

---

## 3. 关键子系统

### 3.1 角色系统
**核心文件**：
- `lib/kantele/character.ex` - 角色结构体与门面函数
- `lib/kantele/character/records.ex` - Ecto Schema + Repo 操作
- `lib/kantele/character/stats.ex` - 属性计算（潜能/学点/技能等级）
- `lib/kantele/character/vitals.ex` - 气/血/内力/精实时值与回复
- `lib/kantele/character/attributes.ex` - 扩展属性（门派/称号/成就）
- `lib/kantele/character/conditions.ex` - 状态效应（中毒/封穴/眩晕）

**角色数据模型**：
```elixir
# 核心结构体
%Kantele.Character{
  id: "uuid",
  name: "玩家名",
  stats: %Stats{str: 25, dex: 22, con: 20, int: 24, ...},
  vitals: %Vitals{hp: 500, max_hp: 500, qi: 300, max_qi: 300, neili: 200, ...},
  skills: %{"force" => 30, "sword" => 25, "dodge" => 20, ...},
  learned_points: 15,          # 已用学点
  potential: 100,              # 可用潜能
  meta: %{
    family: "华山派",           # 门派
    master: "风清扬",           # 师父
    title: "剑宗大弟子",         # 称号
    channels: ["general"],      # 收听频道
    alias_commands: %{}         # 个人别名
  }
}
```

**核心计算** (`lib/kantele/character/stats.ex`)：
- **潜能转化**：`available_potential/1` = `potential - learned_points * 2`
- **技能上限**：`can_improve?(skill, level)` 受 `enable_exp_gate` + `combat_exp` 限制
- **经脉/内力上限**：`neili_limit.ex` 基于内功等级 + 根骨 + 突破境界

### 3.2 战斗系统
**核心文件**：
- `lib/kantele/combat/engine.ex` - 战斗引擎（回合驱动、招式队列、Buff 管理）
- `lib/kantele/combat/skills.ex` - 招式/内功数据定义 + 效果计算
- `lib/kantele/combat/force.ex` - 内功心法（激发/互备/特效）
- `lib/kantele/combat/broadcast.ex` - 战斗消息广播（彩色/结构化）
- `lib/kantele/character.combat.ex` - 角色战斗接口（进入/离开/招式选择）

**战斗模型**：
- **回合制 + 实时 Tick**：`CombatEngine` 每秒 `tick`，处理招式出招、Buff 倒计时、气血回复
- **招式系统**：主动招式 (`perform`)、被动招式 (`parry`/`dodge`)、组合连招 (`combo`)
- **内功心法**：`enable force` 激活，提供属性加成 + 特殊效果（吸内/反震/疗伤）
- **经脉冲穴**：`jingmai` 进阶解锁招式威力/内力上限/特殊被动

**战斗事件**：
```elixir
# 进入战斗
CombatEvent.start(conn, %{enemy: enemy_pid, room_id: room_id})

# 每回合 Tick
CombatEvent.tick(conn, %{round: 3, actions: [%{actor: self, skill: "sword", target: enemy}]})

# 战斗结束
CombatEvent.halt(conn, %{reason: :victory|:flee|:death})
```

### 3.3 世界/房间系统
**核心文件**：
- `lib/kantele/world/room.ex` - 房间 GenServer（生命周期、角色进出、NPC 管理）
- `lib/kantele/world/zone.ex` - 区域定义加载（UCL → 结构体）
- `lib/kantele/world/loader.ex` - 世界启动加载器（区域/房间/NPC/物品/传送点）
- `lib/kantele/world/weather.ex` - 天气系统（季节/时辰/随机事件）
- `lib/kantele/world/game_time.ex` - 游戏时钟（倍率可配、事件触发）

**房间模型** (`data/world/liuxi.ucl`)：
```ucl
rooms "shanlu" {
  name = "山路"
  description = "一条蜿蜒的山路..."
  exits = { north = "shanlu2" east = "cave" }
  npcs = [{ id = "bandit" count = 3 respawn = 300 }]
  items = [{ id = "herb" chance = 0.1 }]
  flags = ["outdoor" "no_fight"]
}
```

**动态特性**：
- **NPC 漫游** (`lib/kantele/character/actions/wander_action.ex`)：按路径/随机巡逻
- **入侵事件** (`lib/kantele/world/invasion.ex`)：定时/触发式 BOSS 刷新
- **镜像副本** (`lib/kantele/world/mirror_daemon.ex`)：单人/组队实例化房间

### 3.4 任务系统
**核心文件**：
- `lib/kantele/quest.ex` - 任务结构体 + 状态机
- `lib/kantele/world/quest_daemon.ex` - 任务守护进程（调度/超时/奖励）
- `lib/kantele/character/events/quest_event.ex` - 任务事件处理
- `lib/kantele/quest/generator.ex` - 动态任务生成器（护送/悬赏/收集）
- `data/help/quests.ucl` - 静态任务定义

**任务流程图**：
```
[可接取] → ask NPC → [进行中] → 目标完成 → turnin NPC → [已完成] → 奖励发放
                    ↓
              [失败/放弃] → 冷却期 → 可重新接取
```

**任务类型**：
| 类型 | 触发方式 | 典型目标 |
|------|----------|----------|
| 主线 | NPC 对话/进入区域 | 剧情推进、门派考核 |
| 日常 | 定时刷新/帮派发布 | 杀怪/收集/护送 |
| 动态 | 世界事件/玩家行为 | 入侵击退/奇遇触发 |
| 师门 | 师父传授 | 学习招式/心法/门派贡献 |

### 3.5 社交/帮派系统
**核心文件**：
- `lib/kantele/character/family.ex` - 师徒/门派/帮派数据模型
- `lib/kantele/character/league.ex` - 帮派（盟会）管理
- `lib/kantele/character/team.ex` - 组队（队长/阵法/经验分享）
- `lib/kantele/character/commands/pai_commands.ex` - 门派命令
- `lib/kantele/sects.ex` - 门派定义（技能树/禁制/声望）

**关系图**：
```
门派 (Sect) ← 师徒 → 角色
    ↓
帮派 (League) ← 成员 → 角色
    ↓
结义 (Swear) ← 义兄弟 → 角色
    ↓
组队 (Team) ← 队员 → 角色
```

**关键机制**：
- **师徒传功** (`lib/kantele/character/events/skills_event.ex`)：`skills/teach` → `learn_gate` 检查 → `learned_points` 增加
- **帮派技能/建设** (`lib/kantele/sects.ex`)：帮派资金/资材 → 升级技能/开放功能
- **结义/婚姻** (`lib/kantele/character/commands/swear_command.ex` / `engage_command.ex`)：特殊称号/传送/共享属性

### 3.6 NPC/AI 系统
**核心文件**：
- `lib/kantele/npc/` - NPC 行为树（Brain/Decision/Action）
- `lib/kantele/bot.ex` - 机器人玩家（自动练功/寻路/学习）
- `lib/kantele/character/controllers/spawn_controller.ex` - NPC 生成器（Brain + 事件订阅）
- `lib/kantele/world/invasion.ex` - 世界 BOSS 入侵调度
- `data/brains/*.ucl` - NPC AI 定义

**Brain 结构** (`vendor/kalevala/lib/kalevala/brain.ex`)：
```elixir
%Kantele.Brain{
  root: %Decision{condition: &has_enemy?/1, true: %Action{...}, false: %Wander{...}},
  state: %{}
}
```

**典型 NPC 类型**：
| 类型 | Brain 策略 | 典型行为 |
|------|------------|----------|
| 守卫 | 巡逻 + 拦截 | 固定路径巡逻，发现红名拦截 |
| 商人 | 静止 + 交易 | `shop/list` + `shop/buy` 事件响应 |
| 师父 | 静止 + 传功 | `skills/teach` 事件处理 + 学习门限检查 |
| 世界 BOSS | 仇恨 + 技能轮换 | 多阶段 AI、全服广播、掉落稀有 |

### 3.7 物品/装备系统
**核心文件**：
- `lib/kantele/item.ex` - 物品基础模块
- `lib/kantele/item/` - 装备/消耗/材料/任务物品子类型
- `lib/kantele/character/commands/imbue_command.ex` - 注灵
- `lib/kantele/character/commands/enchase_command.ex` - 镶嵌
- `lib/kantele/character/commands/combine_command.ex` - 合成/熔炼

**装备属性体系**：
```elixir
%Item{
  id: "sword_001",
  type: :weapon,
  slot: :weapon,
  base_stats: %{atk: 120, hit: 10},
  enchase_slots: 3,           # 镶嵌孔数
  imbue_level: 2,             # 注灵等级
  imbue_attrs: %{crit: 5},    # 注灵属性
  durability: 100/100,
  bound: true                 # 绑定状态
}
```

**强化链路**：
```
基础装备 → 强化(+1~+10) → 镶嵌宝石(攻击/防御/气血) → 注灵(随机词条) → 觉醒(套装效果)
```

### 3.8 经济/商店系统
**核心文件**：
- `lib/kantele/economy/money.ex` - 货币系统（铜/银/金/元宝）
- `lib/kantele/economy/shop.ex` - NPC 商店（刷新/库存/价格波动）
- `lib/kantele/economy/auction.ex` - 拍卖行（寄售/竞拍/税收）
- `lib/kantele/economy/stall.ex` - 摆摊（离线挂售）
- `lib/kantele/character/commands/baitan_command.ex` - 摆摊命令

**货币换算**：
```
1 金 = 100 银 = 10000 铜
元宝 (充值货币) 可兑换金币，比例由配置控制
```

**商店刷新机制** (`lib/kantele/economy/shop.ex`)：
- 定时刷新（配置 `refresh_interval`）
- 玩家购买触发补货（概率性）
- 稀有物品限购/竞拍

---

## 4. 通信层

### 4.1 Telnet 协议
**核心模块**：`vendor/kalevala/lib/kalevala/telnet/protocol.ex`

**特性**：
- **GMCP 支持**：`Core.Hello`、`Char.Vitals`、`Room.Info`、`Comm.Channel`
- **NAWS 协商**：窗口大小自适应
- **颜色标签**：`{color foreground="red"}文本{/color}` → ANSI 转义序列
- **提示行**：`CommandView.render("prompt")` 定时推送
- **转义处理**：`Tags.escape/1` 防止用户注入标签（`general`/`waidi` 例外）

**典型交互**：
```
Client → Server: "general {color foreground=\"red\"}你好{/color}"
Server → 解析命令 → ChannelCommand.general/2
Server → publish_message("general", text)
ChannelEvent.echo/2 → render(ChannelView, "listen") → EventText
TelnetProtocol.push_text/2 → Output.process(text, [Tags, TagColors])
Client ← ANSI: "\e[31m你好\e[0m"
```

### 4.2 WebSocket 协议
**核心模块**：
- `vendor/kalevala/lib/kalevala/websocket/handler.ex` - Cowboy WebSocket 处理
- `lib/web/socket_handler.ex` - Phoenix Endpoint 集成
- `lib/web/channels/user_socket.ex` - 认证/心跳/重连

**消息格式**：
```json
// 客户端 → 服务端
{"topic": "system/send", "data": {"text": "general hello"}}

// 服务端 → 客户端 (system/event-text)
{
  "topic": "system/event-text",
  "data": {
    "topic": "Channel.Broadcast",
    "data": {"channel_name": "general", "character": {...}, "text": "hello"},
    "text": [{"name": "color", "attributes": {"foreground": "green"}, "children": ["hi"]}]
  }
}
```

**Web 端渲染管线** (`assets/js/kalevala/parseText.js`)：
```
Tag 树 (JSON) → parseTag() → React 元素树 → Terminal 组件渲染
```

### 4.3 频道系统
**频道类型** (`lib/kantele/communication.ex:17-23`)：
```elixir
def initial_channels() do
  [
    {"general", Kantele.Communication.BroadcastChannel, []},  // 全服聊天
    {"rumor", Kantele.Communication.BroadcastChannel, []},    // 传闻/系统公告
    {"bill", Kantele.Communication.BroadcastChannel, []},     // 公告栏
    {"waidi", Kantele.Communication.WaidiChannel, []}         // 外地/跨服
  ]
end
```

**动态频道**：
- `rooms:room_id` - 房间本地聊天（说/表情/战斗）
- `characters:char_id` - 私聊/密语
- `teams:team_id` - 组队频道

**频道事件处理** (`lib/kantele/character/events/channel_event.ex`)：
```elixir
def interested?(event) do
  event.data.type == "announcement" || match?("general", event.data.channel_name)
end

def echo(conn, event) do
  conn
  |> assign(:text, event.data.text)
  |> render(ChannelView, template(event))
  |> prompt(CommandView, "prompt", %{character: character})
end
```

**系统公告模板** (`lib/kantele/character/views/channel_view.ex:47-65`)：
```elixir
def render("system", %{channel_name: channel_name, text: text}) do
  %EventText{
    text: [
      render("name", %{name: channel_name}),
      ~i( {color foreground="yellow"}#{character.name}:{/color} {text}\n)
    ]
  }
end
```

---

## 5. 数据层

### 5.1 Ecto / PostgreSQL
**Repo 配置** (`lib/ex_venture/repo.ex`)：
```elixir
defmodule ExVenture.Repo do
  use Ecto.Repo, otp_app: :ex_venture, adapter: Ecto.Adapters.Postgres
end
```

**主要 Schema** (`lib/kantele/character/records.ex`)：
```elixir
schema "characters" do
  field :name, :string
  field :stats, :map          # %{str: 25, dex: 22, ...}
  field :vitals, :map         # %{hp: 500, qi: 300, ...}
  field :skills, :map         # %{"force" => 30, "sword" => 25}
  field :learned_points: , integer, default: 0
  field :potential: , integer, default: 0
  field :combat_exp: , integer, default: 0
  field :meta: , map           # 门派/师父/称号/频道/别名
  timestamps()
end
```

**迁移与种子**：
- `priv/repo/migrations/` - 表结构演进
- `priv/repo/seeds.exs` - 初始数据（门派/技能/区域/帮派）

### 5.2 UCL 配置系统
**解析器**：`stein` + `stein_storage` (`mix.exs:64-65`)

**配置层级**：
```
data/
├── config.ucl           # 全局开关 (exp_gate, jing_learn_cost 等)
├── verbs.ucl            # 动词/命令别名定义
├── emotes.ucl           # 表情动作库
├── world/
│   ├── global.ucl       # 全局区域设置
│   ├── liuxi.ucl        # 柳溪区域 (房间/NPC/物品/传送点)
│   └── *.ucl            # 其他区域
├── bots/
│   └── demo.ucl         # 机器人配置 (自动练功/学习脚本)
├── brains/
│   ├── heihu.ucl        # 黑虎 NPC AI
│   └── *.ucl            # 其他 NPC 大脑
└─ help/
    └── quests.ucl       # 任务帮助文本
```

**UCL 示例** (`data/world/liuxi.ucl`)：
```ucl
rooms "shanlu" {
  name = "山路"
  description = "一条蜿蜒的山路..."
  x = 0 y = 0 z = 0
  exits = { north = "shanlu2" east = "cave" }
  npcs = [
    { id = "bandit" count = 3 respawn = 300 level = { min = 10 max = 20 } }
  ]
  items = [
    { id = "herb" chance = 0.1 }
  ]
  flags = ["outdoor" "no_fight"]
}
```

**加载器** (`lib/kantele/world/loader.ex`)：
- 启动时递归读取 `data/world/*.ucl`
- 解析为 `%Zone{}`, `%Room{}`, `%NPC{}`, `%Item{}` 结构体
- 缓存到 `Kantele.World.ZoneCache` (ETS)，支持热重载

### 5.3 ETS 运行时状态
**主要表**：
| 表名 | 用途 | Key 结构 |
|------|------|----------|
| `kantele_channel_subscribers` | 频道订阅者 | `{channel_name, pid, options}` |
| `kantele_zone_cache` | 区域/房间缓存 | `zone_name → %Zone{}` |
| `kantele_combat_sessions` | 战斗会话 | `combat_pid → %Combat{}` |
| `kantele_mini_map` | 小地图缓存 | `room_id → %{exits, npcs, items}` |
| `kantele_character_presence` | 在线角色 | `char_id → {pid, node}` |

**缓存失效**：区域热重载时 `Kantele.World.ZoneCache.reload/0` 重建 ETS

---

## 6. 运维与部署

### 6.1 Docker 部署架构
**开发环境** (`docker-compose.dev.yml`)：
```yaml
services:
  db:           # PostgreSQL 12-alpine
    ports: ["127.0.0.1:15432:5432"]
    healthcheck: pg_isready
    volumes: [postgres_data]

  setup:        # 一次性初始化
    command: mix deps.get && yarn install && mix ecto.setup

  app:          # Phoenix + Telnet
    command: elixir --sname app -S mix phx.server
    ports: ["4000:4000", "4646:4646"]
    volumes: [.:/app, app_deps, app_build, app_node_modules]
```

**生产环境** (`docker-compose.yml` + `Dockerfile`)：
- Multi-stage build：`builder` (编译) → `releaser` (Release) → `runtime` (Distillery/Release)
- `RELEASE_NODE=app@${HOSTNAME}` + `RELEASE_COOKIE` 分布式集群
- `Vapor` 配置注入（`lib/web/endpoint.ex:58-97`）

### 6.2 热升级与发布
```bash
# 本地构建 Release
MIX_ENV=prod mix release

# 热升级 (Distillery/Release)
bin/ex_venture upgrade 0.1.1

# 或 Docker 重新部署
docker compose build app && docker compose up -d app
```

**配置注入** (`lib/web/endpoint.ex:58-97`)：
```elixir
vapor_config = Config.endpoint()
websocket_config = %{
  handler: [
    output_processors: [
      Kalevala.Output.Tags,
      Kantele.Output.AdminTags,
      Kantele.Output.SemanticColors,
      Kantele.Output.Tooltips,
      Kantele.Output.Commands,
      Kalevala.Output.Tables,
      Kalevala.Output.Websocket
    ]
  ],
  foreman: KalevalaSupervisor.foreman_options()
}
```

### 6.3 日志与遥测
**Logger 配置** (`config/dev.exs`)：
```elixir
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :character_id]

config :logster, level: :info
```

**Telemetry** (`lib/ex_venture/telemetry.ex`)：
```elixir
:telemetry.attach("phoenix-request", [:phoenix, :request], &MyApp.Telemetry.handle_request/4)
:telemetry.attach("ecto-query", [:ecto, :repo, :query], &MyApp.Telemetry.handle_query/4)
```

**关键指标**：
- `phoenix.request.duration` - HTTP/WebSocket 请求延迟
- `ecto.repo.query.duration` - 数据库查询耗时
- `kalevala.command.duration` - 命令处理耗时
- `kalevala.combat.tick.duration` - 战斗 Tick 耗时

### 6.4 测试体系
**测试命令**：
```bash
# 完整测试 (需测试数据库)
MIX_ENV=test mix test

# 单模块测试
MIX_ENV=test mix test test/kantele/character/records_test.exs

# 只运行特定 Tag
MIX_ENV=test mix test --only integration
```

**测试基础设施** (`test/support/`)：
- `ConnCase` - Conn/Foreman 模拟
- `DataCase` - Ecto Sandbox + 固定数据
- `BotCase` - 机器人行为测试

**关键测试覆盖**：
- 命令解析/路由 (`test/kantele/character/commands_test.exs`)
- 战斗引擎 (`test/kantele/combat/engine_test.exs`)
- 学习/经脉门限 (`test/kantele/character/learn_gate_test.exs`)
- 频道/通信 (`test/kantele/communication_test.exs`)
- 任务流程 (`test/kantele/quest_test.exs`)

---

## 7. 开发指南

### 7.1 新增命令标准流程
1. **定义解析** (`lib/kantele/character/commands.ex`)：
```elixir
module(MyCommand) do
  parse("mycmd", :run, fn command ->
    command |> spaces() |> word(:target) |> optional(spaces() |> text(:arg))
  end)
end
```

2. **实现模块** (`lib/kantele/character/commands/my_command.ex`)：
```elixir
defmodule Kantele.Character.Commands.MyCommand do
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"target" => target, "arg" => arg}) do
    # 业务逻辑
    conn
    |> render(CommandView, "text", %{text: "执行完成\n"})
    |> assign(:prompt, true)
  end
end
```

3. **注册视图** (`lib/kantele/character/views/command_view.ex`)：
```elixir
def render("mycmd_result", %{text: text}) do
  ~i(#{text}\n)
end
```

4. **编写测试** (`test/kantele/character/commands/my_command_test.exs`)

### 7.2 新增事件/频道
1. **定义事件** (`lib/kantele/character/events.ex`)：
```elixir
module(MyEvent) do
  event("my/custom", :handle)
  event(Message, :echo, interested?: &MyEvent.interested?/1)
end
```

2. **实现处理器** (`lib/kantele/character/events/my_event.ex`)：
```elixir
defmodule Kantele.Character.Events.MyEvent do
  use Kalevala.Character.Event

  def interested?(event), do: event.data.type == "my_type"

  def handle(conn, event) do
    # 处理逻辑
  end
end
```

### 7.3 新增房间/区域
1. **编写 UCL** (`data/world/new_area.ucl`) - 参考 `liuxi.ucl`
2. **注册区域** - 确保 `data/world/global.ucl` 包含区域入口
3. **热重载** - `Kantele.World.ZoneCache.reload()` 或重启

### 7.4 新增 NPC/AI
1. **定义 Brain** (`data/brains/my_npc.ucl`)：
```ucl
brain "guard" {
  root = "patrol"
  states {
    patrol { action = "wander" next = "check_enemy" }
    check_enemy { condition = "has_enemy" true = "combat" false = "patrol" }
    combat { action = "attack" next = "check_enemy" }
  }
}
```

2. **房间引用** (`data/world/area.ucl`)：
```ucl
npcs = [{ id = "my_npc" brain = "guard" count = 1 respawn = 600 }]
```

### 7.5 代码规范与工具
```bash
# 格式化
mix format

# 静态分析
mix credo --strict
mix dialyzer

# 类型检查 (需 dialyxir)
mix dialyzer

# 运行测试
MIX_ENV=test mix test

# 生成文档
mix docs
```

**命名约定**：
- 模块：`Kantele.Character.Commands.XxxCommand` / `Kantele.Character.Events.XxxEvent`
- 文件：`lib/kantele/character/commands/xxx_command.ex`
- 测试：`test/kantele/character/commands/xxx_command_test.exs`
- UCL：`snake_case.ucl` (区域/房间/NPC/Brain)

### 7.6 常见坑与避坑指南
| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 跨节点 `:rpc.call` 失败 | 匿名函数/闭包无法序列化 | 只传递纯数据，远程端 `apply(Mod, fun, args)` |
| `Tags.escape` 导致颜色标签失效 | 所有命令默认转义 `{` `}` | `command_controller.ex` 中为 `general`/`waidi` 跳过 |
| 事件处理器不触发 | `interested?/1` 返回 `false` | 检查 `event.data.type` / `channel_name` 匹配 |
| 战斗 Tick 卡死 | `CombatEngine` 死循环/死锁 | 检查 `tick/1` 是否正确返回 `{:noreply, state}` |
| UCL 热重载不生效 | ETS 缓存未清理 | 调用 `Kantele.World.ZoneCache.reload()` |
| 跨节点 PubSub 不通 | Phoenix.PubSub 未组集群 | 确保 `RELEASE_DISTRIBUTION=name` + 相同 Cookie |
| 匿名函数在 `:rpc.call` 时报错 | Beam 无法序列化闭包 | 改用 `apply(Module, :function, args)` 形式 |
| WebSocket 颜色不显示 | `output_processors` 缺少 `Websocket` | 检查 `endpoint.ex` websocket 配置 |
| Telnet 颜色乱码 | `Tags.escape` 双重转义 | 确保仅在命令入口转义一次，输出管线不再转义 |

---

## 8. 近期重要变更记录

### 8.1 Bot 学习系统修复 (2026-09-14)
**问题**：Bot 反复发送 `learn ...` 命令，技能等级冻结不升级

**根因分析**：
1. **`do_tick` 作用域 Bug** (`lib/kantele/bot.ex:170`)：`case` 子句内 `state = ...` 绑定未逃逸，导致 `pending_learn` 每 Tick 丢失，失败检测永不触发
2. **经验门限拦截** (`config/dev.exs:68-70`)：`enable_exp_gate: true` + `combat_exp=3200` → 可学上限 ≈ 31 级，Bot `force=31` 恰卡上限，`sword/dodge/parry=60` 远超上限被 `learn_gate` 拒绝

**修复**：
- `lib/kantele/bot.ex`：`state = case action do ... end` 提升作用域
- 兜底机制改为持续型：`train_target` 空列表时返回 `get_fallback_train_cmd(cfg, st)` (qi 自适应 `exercise N`)
- 移除一次性 fallback 分支，改为持续自练

**验证**：日志从 `Received - "learn ..."` 变为 `Received - "exercise 50"`，`failed_cmds=3, train_fallback=true`

### 8.2 频道面板颜色标签渲染 (2026-09-14)
**问题**：Web 端 Channels 面板显示字面 `{color foreground="red"}文本{/color}`

**根因**：
- `Channel.Broadcast` 处理器直接透传 `event.data.text` (含原始标签)
- `Channels.jsx` 直接渲染字符串，未解析标签

**修复** (`assets/js/store.js`)：
```javascript
const parseColorTags = (text) => {
  // 解析 {color foreground="red"}...{/color} → React.createElement("span", {style: {color}})
  // 支持嵌套：{color green}{color yellow}hi{/color}{/color} → yellow 内层生效
};
```

**效果**：`{color foreground="green"}{color foreground="yellow"}hi{/color}{/color}` → "hi" 显示黄色

### 8.3 系统公告双重包裹导致标签泄漏 (2026-09-14)
**问题**：`{color foreground="red"}【天灾人祸】{/color}` 在系统公告中显示为字面文本

**根因**：
- Story 广播已含红色提示标签
- `ChannelView.render("system")` 再包裹一层黄色 → 嵌套同名 `color` 标签
- `Kalevala.Output.Tags` 碎片化解析时，跨片段的 `{` 重置导致外层 open 丢失，close 失配 → `matching_tags?` 失败 → `:error` → 原始文本直传

**修复**：`ChannelView.render("system")` 移除对 `text` 的二次包裹，保留原始 Story 色标

### 8.4 `general`/`waidi` 命令跳过 `Tags.escape` (2026-09-14)
**问题**：用户在 `general` 频道发送 `{color foreground="red"}hi{/color}` 显示为 `\hi\{/color\}`

**根因**：`CommandController.recv/2` 统一调用 `Tags.escape/1`，将 `{` `}` 转义为 `\{` `\}`

**修复** (`lib/kantele/character/controllers/command_controller.ex:26-31`)：
```elixir
is_channel = String.starts_with?(data, "general ") or String.starts_with?(data, "waidi ")
data = if is_channel do data else Tags.escape(data) end
```

**效果**：`general {color foreground="red"}hi{/color}` → 正确渲染红色 "hi"

---

*文档生成时间：2026-09-14*  
*项目版本：0.1.0 (基于 ExVenture + Kalevala)*  
*维护团队：wuxia_mud_ex 开发组*