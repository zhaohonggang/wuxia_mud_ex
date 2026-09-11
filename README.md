# 武侠 MUD 服务端 — Wuxia MUD Server

基于 **Kalevala** 框架的 Elixir 武侠 MUD 服务端，实现了完整的任务系统、战斗系统、NPC 交互、天气/昼夜、剧情叙事、入侵事件、宝镜任务等核心玩法。

> **注意**：本分支是在原版 [ExVenture](https://github.com/oestrich/ex_venture) 基础上，结合 [Kalevala](https://github.com/oestrich/kalevala) 框架重写，并针对武侠题材深度定制的版本。

---

## 🚀 快速开始

### 依赖环境
- **PostgreSQL** 12+
- **Elixir** 1.11+ (当前测试版本)
- **Erlang/OTP** 23+
- **Node.js** 12+ (前端资源编译)

### 安装与运行

```bash
# 1. 安装后端依赖
mix deps.get

# 2. 安装前端依赖并编译
cd assets && npm install && npm run deploy && cd ..

# 3. 初始化数据库
mix ecto.setup

# 4. 启动服务
mix phx.server
```

服务启动后可通过 telnet 连接：
```bash
telnet localhost 4000
```

---

## 📦 核心系统架构

### 1. Kalevala 框架核心
- **GenServer 监督树** —— 区域、房间、角色、物品、频道均为独立进程
- **事件总线** (`Kalevala.Event`) —— 解耦模块间通信，支持同步/异步分发
- **配置驱动** — UCL 格式数据文件 (`data/world/*.ucl`) 定义区域、房间、NPC、物品、任务

### 2. 任务系统 (`lib/kantele/quest.ex`, `lib/kantele/character/events/quest_event.ex`)
- **通用 todo/solved 模型** — `set_todo`/`set_solved`/`del_todo`
- **链式前置** (`chain`) — `chain_open?` 校验前置任务已完成
- **互斥任务** (`mutex`) — 同组任务不可并行
- **类型**：`kill` (击杀)、`item` (送物)、`deliver/supply/search/explore` (开放任务)
- **奖励计算** (`lib/kantele/quest/reward.ex`) — exp/pot/score/weiwang/gongxian/coins + 里程碑

### 3. NPC 与交互系统
- **NpcAskEvent** (`lib/kantele/character/events/npc_shop_event.ex`) — 问答/任务发布/物品交付
- **NpcScriptEvent** (`lib/kantele/character/events/npc_script_event.ex`) — 数据驱动脚本效果 (给物品/传授技能/入门派)
- **动态脚本化问询** — UCL 中 `inquiries` 支持 map 格式 (`reply`/`give`/`learn_skill`/`family`/`gongxian`)
- **特色 NPC** — 干将/莫邪/青阳子/南贤/裁判等纯数据定义 (`data/world/signature.ucl`)

### 4. 战斗系统 (`lib/kantele/character/combat/`, `lib/kantele/character/events/combat_event.ex`)
- **属性/技能/Buff** 体系 — 气/精/内力/攻防/轻功/招架
- **招式/技能映射** (`mapped`) — 技能 ID → 招式 ID
- **击杀/死亡钩子** — `CombatEvent.die` 触发经验/掉落/任务进度

### 5. 天气/昼夜系统 (`lib/kantele/world/game_time.ex`, `lib/kantele/world/weather.ex`)
- **GameTime** — 现实 1s = 游戏 12s，季节/时辰自动推进
- **Weather** — 12 套相表 (四季 × {晴/雨/风})，户外房间 `look` 自动注入描述
- **广播** — 时段切换/换季自动 `waidi` 频道公告

### 6. 剧情叙事 (`lib/kantele/world/story.ex`, `lib/kantele/world/story/*.ex`)
- **StoryDaemon** — 定时随机选故事，逐行全服播报 (`general` 频道)
- **14 内置故事** — 四仙丹/两卷书/玄铁令/幻阴指/三分剑/四天灾/摆擂
- **赠礼机制** — 在线玩家随机掉落仙丹/书籍到房间地面

### 7. 入侵事件 (`lib/kantele/world/invasion.ex`)
- **Invasion GenServer** — 周期触发，每波 24 只外族 NPC (3 国族 × 5 级)
- **自动穿戴** — NPC 背包自带装备，SpawnController 延迟 1s 装备
- **waidi 频道** — 全服广播入侵开始/击杀/全歼/撤退，支持 `waidi on/off`

### 8. 宝镜任务 / MirrorDaemon (`lib/kantele/world/mirror_daemon.ex`)
- **周期分发** — 180s 间隔，30 个 TaskCarrier NPC 随机散落 liuxi 区
- **50ms 批量生成** — `spawn_tasks` 队列 + `Process.send_after(50ms)` 逐个生成
- **子虚道人** — 固定驻守 `liuxi:zixu_guan`，给乾坤宝镜/传送心魔幻境
- **carrier 清理** — 玩家上交自动 `Process.exit(:shutdown)`，死亡监控 `:DOWN` 消息标记

### 9. 高价值命令 (`lib/kantele/character/commands/`)
- `ask` — NPC 问询 (支持脚本化)
- `hide` — 隐藏兵器 (需 `can_summon` 登记 + 精力≥100)
- `summon` — 召唤物品 (需登记 + 精力≥200，实际给予物品实例)
- `rideto` — 骑乘传送 (64 预设地点，需骑马+非战斗+非负重)
- `can_summon` 登记 — 王铁匠 `登记召唤` 询问，解析关键词提取物品名写入属性

---

## 🗂️ 数据驱动开发指南

### UCL 数据文件结构 (`data/world/`)
```
data/world/
├── liuxi.ucl          # 柳溪镇主区域 (房间/NPC/物品/任务/天气表)
├── signature.ucl      # 隐世之境 (特色NPC/新手链收官)
└── nature/weather.ucl # 天气相表 (四季×3天气×8时段)
```

### 常用定义示例

**区域与房间**
```ucl
zones "liuxi" { name = "柳溪镇 Liuxi" }

rooms "guangchang" {
  name = "镇广场"
  description = "青石板铺就的广场..."
  x = 0 y = 1 z = 0
  flags = ["outdoors"]
}

room_exits "guangchang" {
  room_id = rooms.guangchang.id
  west = rooms.lianwuchang.id
  east = rooms.tiepupu.id
}
```

**NPC 定义 (含 quest/turn_in/goods/inquiries)**
```ucl
characters "wangtiefu" {
  name = "王铁匠"
  description = "张记铁铺的老师傅..."

  goods = [{ id = items.tiekuai.id }]

  inquiries = {
    打铁 = "后生愿意学打铁？..."
    登记召唤 = {
      reply = "想让兵器听你呼唤？..."
      register_summon = true
    }
  }

  quest = {
    file = "_0_tutorial_datie"
    chain = []
    repeatable = false
    type = "chain"
    limit = 1800
    master_name = "周不通"
    master_id = "liuxi:butong"
  }

  turn_in = {
    quest = "_0_tutorial_datie"
    item = items.tiekuai.id
    prompt = "王铁匠掂了掂铁块..."
    rewards = { exp = 100 potential = 20 score = 5 coins = 50 }
  }
}
```

**物品定义**
```ucl
items "tiekuai" {
  name = "铁块 Iron Lump"
  description = "一块黑沉沉的生铁疙瘩..."
  verbs = ["get", "drop"]
  meta = { value = 10 weight = 20 unit = "块" material = "iron" }
}
```

---

## 🧪 测试指南

### 运行测试
```bash
# 全量测试 (默认 seed)
MIX_ENV=test mix test

# 指定 seed (复现 flaky)
MIX_ENV=test mix test --seed 731933

# 单文件测试
MIX_ENV=test mix test test/kantele/world/mirror_daemon_test.exs

# 目录测试
MIX_ENV=test mix test test/kantele/quest/
```

### 关键测试文件
| 文件 | 覆盖内容 |
|------|----------|
| `test/kantele/quest/chain_walk_test.exs` | 任务链前置/逐步解锁/不可重接 |
| `test/kantele/world/signature_npc_test.exs` | signature 区加载/NPC落位/脚本问询 |
| `test/kantele/quest/tutorial_step_wiring_test.exs` | 新手链6步发放方/物品来源/全链通关 |
| `test/kantele/world/mirror_daemon_test.exs` | MirrorDaemon 轮次/载体生成/上交收轮 |
| `test/kantele/world/kickoff_test.exs` | 世界加载兜底/解析层/编排层失败恢复 |

### 容器化测试 (CI 推荐)
```bash
docker cp data/world/liuxi.ucl wuxia_mud_dev-app-1:/app/data/world/liuxi.ucl
docker exec wuxia_mud_dev-app-1 /bin/sh -c 'cd /app && MIX_ENV=test mix test --seed 731933'
```

---

## ⚙️ 开发规范与约定

### GenServer 模式
- 所有长驻进程使用 `Behaviour` 定义契约 (`prompt`/`init_state`/`start_round`/`stop_round`/`status`)
- **schedule_once 链式定时** — 避免 `Process.send_interval` 取消 bug
- **safe_run / safely** — 统一异常捕获，防止进程崩溃

### UCL 语法注意
- **数组元素需逗号分隔** — 单元素也建议加尾随逗号
- **字符串内禁用 `;`** — Elias 解析器会将其视为 token 分隔符
- **对象引用** — `{ id = items.xxx.id }` 由 loader 解析为 `"zone:xxx"` 字符串

### 物品 ID 规则
- 格式：`zone:key` (如 `liuxi:changjian`, `signature:jinggang`)
- task 物品：`liuxi:task/xxx`
- 怪物掉落/商店货品：统一在 `zone` 坐标下定义

### 推送规范
- **仅在明确指示时推送** (`git push origin kalevala`)
- 提交信息格式：`<模块>: <简述>` (如 `MirrorDaemon: 50ms batched spawn + carrier cleanup`)

---

## 🐳 部署指南

### Docker 生产部署
```bash
docker-compose pull
docker-compose build
docker-compose up -d postgres
docker-compose run --rm app eval "ExVenture.ReleaseTasks.Migrate.run()"
docker-compose up -d app
```

### 环境变量
```env
DATABASE_URL=ecto://user:pass@postgres:5432/wuxia_mud
SECRET_KEY_BASE=...
PHX_HOST=your.domain.com
```

---

## 📚 相关文档
- [MIGRATION_PLAN.md](lpc_example/ex/MIGRATION_PLAN.md) — 完整迁移计划与进度 (Q1-Q6 全部完成)
- [Kalevala 文档](https://kalevala.dev) — 底层框架参考
- [Elixir 1.11 参考](https://hexdocs.pm/elixir/1.11/) — 语言版本特性

---

## 🤝 贡献指南
1. Fork & 新建分支
2. 编写代码 + 对应测试 (`*_test.exs`)
3. 本地 `MIX_ENV=test mix test --seed 731933` 全绿
4. PR 描述包含：变更动机、测试覆盖、已知限制

---

## 📄 License
MIT License — see [LICENSE](LICENSE) for details.