# 快速上手指南

> 10 分钟跑通本地开发环境，理解核心架构，写第一个测试。

---

## 1. 环境准备

```bash
# 检查版本
elixir --version    # 1.11+
erl -version        # 23+
psql --version      # 12+
node --version      # 12+

# 克隆项目
git clone https://github.com/your-org/wuxia_mud_ex.git
cd wuxia_mud_ex
```

---

## 2. 启动步骤

```bash
# 1. 安装依赖
mix deps.get

# 2. 前端资源 (仅首次)
cd assets && npm install && npm run deploy && cd ..

# 3. 数据库
mix ecto.setup

# 4. 启动
mix phx.server
```

**验证:** `telnet localhost 4000` → 进入角色创建。

---

## 3. 跑通测试

```bash
# 全量 (约 50s)
MIX_ENV=test mix test

# 指定 seed 复现
MIX_ENV=test mix test --seed 731933

# 单模块
MIX_ENV=test mix test test/kantele/world/mirror_daemon_test.exs

# 目录
MIX_ENV=test mix test test/kantele/quest/
```

**预期:** 2334 tests, 0 failures (seeds 731933/788424)

---

## 4. 目录速览

```
lib/
├── kantele/
│   ├── character/
│   │   ├── commands/          # 玩家命令
│   │   ├── events/            # 事件处理 (NpcAskEvent, QuestEvent, ...)
│   │   └── ...                # 属性/战斗/背包/技能
│   ├── world/
│   │   ├── loader.ex          # UCL 解析入口
│   │   ├── kickoff.ex         # 世界启动/兜底
│   │   ├── mirror_daemon.ex   # 宝镜任务
│   │   ├── story.ex           # 剧情叙事
│   │   ├── invasion.ex        # 入侵事件
│   │   ├── weather.ex         # 天气
│   │   └── game_time.ex       # 游戏时间
│   ├── quest/                 # 任务核心
│   │   ├── quest.ex           # 状态机
│   │   ├── reward.ex          # 奖励计算
│   │   └── generator/         # 开放任务生成器
│   └── npc/                   # NPC 模板
data/world/
├── liuxi.ucl          # 主区域
├── signature.ucl      # 隐世之境
└── nature/weather.ucl # 天气表
test/
├── kantele/
│   ├── quest/         # 任务测试
│   ├── world/         # 世界/守护进程测试
│   └── character/     # 命令/事件测试
```

---

## 5. 常用开发操作

### 添加新 NPC (数据驱动)
1. `data/world/liuxi.ucl` 中添加 `characters "npc_key" { ... }`
2. 定义 `quest` / `turn_in` / `inquiries` / `goods`
3. `room_characters` 挂载到房间
4. `MIX_ENV=test mix test test/kantele/world/loader_test.exs`

### 添加新任务步骤
1. `liuxi.ucl` 新增 `quest = { file = "_0_tutorial_xxx", chain = [...] }`
2. 对应 NPC 配置 `turn_in` 物品 + 奖励
3. 确保物品有获取来源 (商店/掉落)
5. 跑 `tutorial_step_wiring_test.exs`

### 添加新命令
1. `lib/kantele/character/commands/xxx_command.ex`
2. `use Kalevala.Character.Command`
3. 实现 `run/2` + `bare/2`
4. `lib/kantele/character/commands.ex` 注册 `parse("verb", ...)`
6. 写 `test/kantele/character/xxx_command_test.exs`

### 修改 UCL 后验证
```bash
# 语法检查
docker exec wuxia_mud_dev-app-1 /bin/sh -c 'cd /app && MIX_ENV=test mix run -e "Kantele.World.Loader.load()"'

# 或跑 loader 相关测试
MIX_ENV=test mix test test/kantele/world/loader_test.exs
```

---

## 6. 调试技巧

### 交互式调试
```bash
# 启动 iex 会话
iex -S mix phx.server

# 运行时查看世界
Kantele.World.Loader.load() |> Map.keys()
Kantele.World.ZoneCache.get("liuxi") |> elem(1) |> Map.get(:characters) |> Map.keys()
```

### 日志查看
```bash
# 运行时日志
tail -f log/dev.log

# 测试日志
MIX_ENV=test mix test 2>&1 | grep -A 5 "mirror_daemon"
```

### 热重载
```bash
# 代码修改后自动编译 (Phoenix 默认)
# 或手动
mix compile
```

---

## 7. 常见坑

| 现象 | 原因 | 解决 |
|------|------|------|
| UCL 解析报 `syntax error before: '";"'` | 字符串内含 `;` | 去掉分号或用中文逗号 |
| 数组解析失败 | 多元素缺逗号 | 所有元素间加 `,` |
| `Enum.find_value` 报 FunctionClauseError | 匹配结构不匹配 | 检查 map 字段名/是否为空 |
| `Process.exit` 不生效 | 目标进程已死/不可达 | 先 `Process.alive?(pid)` 判断 |
| 测试冲突 `test:sword` | 多测试并发写同一 item id | 用私有前缀 `mytest:sword` |
| `:timer.send_interval` 不取消 | 旧版本 bug | 用 `schedule_once` 链式 |

---

## 8. 提交前自检

```bash
# 1. 格式化
mix format

# 2. 编译无警告
mix compile --warnings-as-errors

# 3. 目标 seed 全绿
MIX_ENV=test mix test --seed 731933
MIX_ENV=test mix test --seed 788424

# 4. 推送
git push origin kalevala
```

---

## 9. 有用链接

- [MIGRATION_PLAN.md](lpc_example/ex/MIGRATION_PLAN.md) — 完整进度
- [API_REFERENCE.md](docs/API_REFERENCE.md) — 核心模块 API
- [Kalevala 官方文档](https://kalevala.dev)
- [Elixir 1.11 文档](https://hexdocs.pm/elixir/1.11/)

---

> 遇到问题先搜 `MIGRATION_PLAN.md` 和现有测试，大部分实现已有参考。