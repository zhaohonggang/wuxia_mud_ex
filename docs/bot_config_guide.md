# Kantele Bot 配置教程 (UCL 格式)

本文档说明如何编写 `data/bots/*.ucl` 来定义不同行为的自动化机器人。

---

## 1. 文件结构

```ucl
bots {
  my_bot_key {          # 内部唯一 key，也用作停止/启动命令的参数
    # 所有字段均可选，均有默认值
  }
}
```

- 文件放在 `data/bots/` 目录下，扩展名 `.ucl`
- 启动时自动加载该目录下所有 `.ucl` 文件
- `bots { ... }` 顶层表下可写多个 bot，key 互不重复

---

## 2. 完整字段参考表

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enabled` | bool | `true` | 世界启动时是否自动启动该 bot |
| `account` | string | key 值 | 登录账号名 |
| `password` | string | `""` | 登录密码（当前版本不校验，可任意） |
| `name` | string | key 值 | 角色名（唯一，重名会登录失败） |
| `who` | bool | `true` | 是否出现在 `who` 列表 |
| `tick_ms` | int | `800` | 决策循环间隔（毫秒） |
| `march` | string[] | `[]` | 巡逻路线（出口名数组，如 `["west","north"]`） |
| `hunt` | string[] | `[]` | 打猎目标 NPC 名单（同房间即 `kill`） |
| `hunt_rooms` | string[] | `[]` | 允许打猎的房间引用（空 = 任意非禁斗房间） |
| `train` | string[] | `[]` | 练功/学艺指令序列（轮询执行） |
| `train_rooms` | string[] | `[]` | 练功/学艺允许的房间（空 = 任意房间） |
| `heal_qi` | float | `0.5` | 气血比例 < 此值 → `halt` 回血 |
| `flee_qi` | float | `0.35` | 气血比例 < 此值 → `逃跑` |
| `train_jing` | float | `0.5` | 精力比例 ≥ 此值才执行 `train` |
| `train_potential` | int | `10` | 可用潜能 ≥ 此值才执行 `train` |
| `hunt_potential_threshold` | int | `0` | 可用潜能 < 此值才去打猎（0 = 无限制，默认退回 `train_potential`） |
| `save_every` | int | `60` | 每 N 拍主动存档 |
| `relog` | bool | `true` | foreman 意外退出是否自动重登 |

> **注意**：UCL 里浮点数建议加引号（如 `"0.5"`），避免解析器把 `0.5` 当成字符串报错。

---

## 3. 行为逻辑概览

每 `tick_ms` 毫秒执行一次决策（优先级从高到低）：

1. **战斗中**：
   - 气血 < `flee_qi` → `逃跑`
   - 气血 < `heal_qi` → `halt`
   - 否则继续输出

2. **精力过低**（精力/最大精力 < 0.2）→ 待机

3. **练功/学艺**（满足全部条件）：
   - 可用潜能 ≥ `train_potential`
   - 精力比例 ≥ `train_jing`
   - 若配置了 `train_rooms` 且不在其中 → 先用 BFS 寻路过去
   - 执行 `train` 数组下一条指令（循环）

3. **打猎**（潜能不足时）：
   - 可用潜能 < `hunt_potential_threshold`（或默认 `train_potential`）
   - 在 `hunt_rooms` 内（或未配置则任意非禁斗房）
   - 冷却 ≥ 2.5 秒
   - 同房间有 `hunt` 列表里的 NPC → `kill <目标>`

4. **巡逻/导航**：
   - 有目标房间且不在其中 → BFS 寻路走第一步
   - 无目标房间 → 按 `march` 轮询；`march` 为空 → 随机出口

---

## 4. 常见场景示例

### 4.1 纯打猎挂机（无练功）
```ucl
bots {
  farmer {
    enabled = true
    account = "bot1"
    password = "123"
    name = "bot_farmer"
    hunt = ["yecu", "lang"]
    hunt_rooms = ["liuxi:guangchang", "liuxi:shanlu"]
    heal_qi = "0.6"
    flee_qi = "0.4"
    tick_ms = 1000
  }
}
```

### 4.2 拜师学艺 + 打猎赚潜能（当前 `bot_auto` 模式）
```ucl
bots {
  student {
    enabled = true
    account = "bot2"
    password = "123"
    name = "bot_student"
    hunt = ["yecu"]
    hunt_rooms = ["liuxi:guangchang"]
    train = ["learn sword 师父名 x10", "learn force 师父名 x5"]
    train_rooms = ["liuxi:lianwuchang"]
    train_potential = 50
    hunt_potential_threshold = 30
    train_jing = "0.5"
    heal_qi = "0.5"
    flee_qi = "0.35"
  }
}
```
> 注意：`learn` 目标 NPC 必须在 `train_rooms` 房间内，且该 NPC 的 `teach_skills.max` 未达上限，否则会被拒绝。

### 4.3 纯自练（打坐/吐纳，无师父上限）
```ucl
bots {
  meditator {
    enabled = true
    account = "bot3"
    password = "123"
    name = "bot_meditator"
    train = ["exercise", "respirate"]
    train_rooms = ["liuxi:lianwuchang"]
    train_potential = 50
    train_jing = "0.5"
    hunt = []  # 不打猎
  }
}
```

### 4.4 研读秘籍自学（需背包有书）
```ucl
bots {
  scholar {
    enabled = true
    account = "bot4"
    password = "123"
    name = "bot_scholar"
    train = ["study 基础剑法 5", "study 基础内功 5"]
    train_rooms = ["liuxi:shufang"]
    train_potential = 30
    train_jing = "0.6"
  }
}
```

### 4.4 混合：低潜能去打猎，高潜能去研读
```ucl
bots {
  hybrid {
    enabled = true
    hunt = ["yecu"]
    hunt_rooms = ["liuxi:guangchang"]
    train = ["study 基础剑法 10"]
    train_rooms = ["liuxi:shufang"]
    train_potential = 50
    hunt_potential_threshold = 20  # 潜能 <20 去打猪，≥50 去读书
    train_jing = "0.5"
  }
}
```

---

## 5. 常见坑 & 调试技巧

| 现象 | 原因 | 解决 |
|------|------|------|
| `learn` 指令发了但技能不涨 | 师父 `teach_skills.max` 已达上限，或不在 `train_rooms` | 换更高级师父 / 改用 `exercise`/`study` |
| bot 卡在房间不动 | `train_rooms`/`hunt_rooms` 写错房间引用，或 BFS 找不到路 | 检查房间引用拼写（区分大小写），确认 zone 连通 |
| 潜能一直不降 | `train` 指令不消耗潜能（`exercise`/`respirate` 不耗潜能） | 用 `learn`/`study`/`research` |
| bot 反复在两房间来回跑 | `train_rooms` 和 `hunt_rooms` 互斥且潜能在阈值边缘震荡 | 拉大 `hunt_potential_threshold` 与 `train_potential` 差距 |
| 浮点数报错 | UCL 里裸写 `0.5` 被当成字符串 | 加引号：`"0.5"` |

---

## 6. 运行时控制（不改文件）

```bash
# 查看状态
mix run scripts/bots.exs status

# 启动/停止单个 bot（key 为 ucl 里的 key）
mix run scripts/bots.exs start grinder
mix run scripts/bots.exs stop grinder
```

> 容器内执行需先连到节点：
> ```bash
> docker exec wuxia_mud_dev-app-1 elixir --sname ctl --cookie PPYUAFBQGIXTSHJUKWEZ -r scripts/bots.exs status
> ```

---

## 7. 新增 bot 步骤清单

1. 在 `data/bots/` 新建 `mybot.ucl`（或追加到现有文件）
2. 填好 `enabled = true` 及所需字段
3. 重启 app 容器，或运行 `start <key>` 热启动
4. 用 `detail <bot名>` 观察实时技能/潜能/位置
5. 根据日志微调阈值/房间/指令

---

## 8. 进阶：自定义行为

如需完全不同的逻辑（组队、跑商、任务链等），可：
1. 在 `lib/kantele/bot.ex` 里新增 `decide/3` 分支
2. 或另写一个 `MyCustomBot` 模块 `use GenServer`，按相同 `Foreman` 通道发指令
3. 在 `Kantele.Bot.Supervisor` 里 `DynamicSupervisor.start_child` 启动

配置文件只管“数据驱动”的参数；复杂流程写在代码里更易维护。