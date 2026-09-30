# NPC 闲聊冷却门控（`Kantele.Brain.Conditions.ChatChance`）

> 对应 LPC 的 `chat_chance` / `chat_msg`（A10/N3）。
> 模块位置：`lib/kantele/character/actions/chat_action.ex`（与 `ChatAction` 同文件）。
> 默认冷却：**500 ms**。

---

## 1. 问题现象

NPC 闲聊把房间频道刷爆，日志里 `ChatAction` 队列不断增长：

```text
[info] Delaying Kantele.Character.ChatAction for 0ms with %{"lines" => ["巫士一声大喊: @@###$$!!! @@@! &*%%%%@!!!"]}
[info] Delaying Kantele.Character.ChatAction for 0ms with %{"lines" => ["巫士一声大喊: ..."]}
[info] Processing Kantele.Character.ChatAction, 47 left in the queue.
[info] Processing Kantele.Character.ChatAction, 46 left in the queue.
[info] Processing Kantele.Character.ChatAction, 29 left in the queue.
```

首次出现在 `mingjiao` 的 `miaorenbuluo`（苗人部落）房间。

> `@@###$$!!! @@@! &*%%%%@!!!` **不是乱码**——是 LPC 作者自己写的占位符
> （`mud/d/mingjiao/npc/miaozuwushi.c:25` 原文如此），转换器忠实保留。

---

## 2. 根因

**数据侧没有错**。`mud/d/mingjiao/miaorenbuluo.c:16-18` 原文：

```c
set("objects",([
    "/d/mingjiao/npc/miaozuwushi":4,
]));
```

即房间里有 **4 个巫士**；`mud/d/mingjiao/npc/miaozuwushi.c:23` 每个都有：

```c
set("chat_chance", 30);
set("chat_msg", ({ "巫士一声大喊: @@###$$!!! @@@! &*%%%%@!!! \n", }) );
```

问题出在 **Elixir 侧把 `chat_chance` 的求值时机搞错了**：

| 环节 | 位置 | 行为 |
|------|------|------|
| ① 挂载 | `lib/kantele/world/loader.ex:453` `chat_node/2` | 把闲聊节点挂在 NPC 行为树的**最前面**（无条件节点） |
| ② 求值 | `lib/kantele/character/controllers/spawn_controller.ex:45` | 对 NPC 收到的**每一个事件**都跑一遍 `Brain.run` |
| ③ 订阅 | `spawn_controller.ex:28` | NPC 订阅 `rooms:<room_id>` |
| ④ 发言 | `lib/kantele/character/actions/chat_action.ex` | `ChatAction` 把闲聊发到 **`rooms:<room_id>`** |

③ + ④ 构成关键一环：**发言者会收到自己刚发的消息**。于是

```
说话 → 收到自己的事件 → 掷骰 → 再说话 → …
```

成为一个自激反馈环。

### 为什么会指数发散

每条房间消息会被房间内 **N 个** NPC 各收到一次，各自独立掷骰，因此

```
繁殖率 = N × chance / 100
```

- 单个 NPC：`0.3 < 1` → 次临界，**不会**发散
- 4 个巫士：`4 × 0.3 = 1.2 > 1` → **超临界，指数发散**

这解释了为什么只有这个房间炸、其他区安静：**必须 N ≥ 4 才越过阈值**。

LPC 侧原本不是这样：`chat_chance` 是在 NPC 的 `call_out` **心跳**上评估的，不是每条消息。

---

## 3. 修复

### 3.1 新增条件 `Kantele.Brain.Conditions.ChatChance`

```elixir
%Kalevala.Brain.Condition{
  type: Kantele.Brain.Conditions.ChatChance,
  data: %{chance: 30, cooldown_ms: 500}
}
```

判定逻辑（两者都满足才放行）：

1. **时间冷却已过**——同一 NPC 两次闲聊至少间隔 `cooldown_ms`
2. **概率命中**——`:rand.uniform(100) <= chance`（与原 `Random` 同一套语义，`chance` 为 1-100 百分比）

冷却状态存在 conn 的 session 里，key 为 `"npc_chat_at"`（`ChatChance.session_key/0`），值为
`System.monotonic_time(:millisecond)`。

### 3.2 `ChatAction` 在发布前写入时间戳

```elixir
conn = put_session(conn, Kantele.Brain.Conditions.ChatChance.session_key(),
                    System.monotonic_time(:millisecond))
```

**必须在 `publish_message` 之前**——发布后自己触发的下一次求值要立刻能看到时间戳，
否则第一次自触发仍然会通过冷却检查。空台词池（`lines == []`）不写时间戳。

### 3.3 `Kantele.Brain.Conditions.Random` 保持原样

`Random` 是通用概率条件，`data/brains/*.ucl` 里没有用到它做闲聊，**不做任何改动**，
避免波及其他行为树。只有 `loader.ex` 的 `chat_node/2` 改用 `ChatChance`。

---

## 4. 为什么时间冷却能治本

它把过程从**无界繁殖**变成**有界速率**：

```
上限 = 房间内 NPC 数 / cooldown_ms
```

无论房间事件多密集（有多少玩家说话、多少 NPC 移动），产出速率都有硬上限。
以 4 个巫士、`chance = 30`、冷却 500 ms 为例：

- 理论上限 `4 / 0.5s = 8` 条/秒
- 实际期望 `4 × 0.3 / 0.5s ≈ 2.4` 条/秒

> ⚠️ **500 ms 偏活跃**：这个房间的闲聊期望速率约 2.4 条/秒，虽然**不会指数发散**，
> 但仍可能显得吵。如果想更安静，把 `@default_cooldown_ms` 调大即可
> （3000 ms 时约 0.4 条/秒，接近 MudOS `random_move` 的 5 秒心跳）。
> 调整后 `chat_runtime_test.exs` 会自动跟随（测试引用 `default_cooldown_ms/0`，
> 不硬编码数值）。

---

## 5. 相关代码位置

| 文件 | 内容 |
|------|------|
| `lib/kantele/character/actions/chat_action.ex` | `ChatAction`、`Conditions.Random`（未改）、**新增 `Conditions.ChatChance`** |
| `lib/kantele/world/loader.ex:453` | `chat_node/2`——改用 `ChatChance` 并传入 `cooldown_ms` |
| `lib/kantele/character/controllers/spawn_controller.ex` | 每事件求值 + 订阅房间频道（**未改**，是问题的背景而非缺陷） |
| `test/kantele/world/chat_runtime_test.exs` | 12 个测试，见下 |

### 测试覆盖

`MIX_ENV=test mix test test/kantele/world/chat_runtime_test.exs` → **12 tests, 0 failures**

- `ChatAction`：随机挑一句广播 / 空池不发 / **写入冷却时间戳** / 空池不写时间戳
- `Conditions.Random`：chance=100 必中、chance=0 必不中（回归，原样保留）
- `Conditions.ChatChance`：无时间戳只看概率 / **冷却未到期必不中（即使 chance=100）** /
  冷却到期恢复 / chance=0 必不中
- `Loader 挂载`：金花的 chat 节点是 `ChatChance + ChatAction` /
  **全世界带 `ChatAction` 的 NPC 都不得回退到裸 `Random`**（含防呆断言，保证非空转）

---

## 6. 排查同类问题的通用方法

看到 `Delaying ...Action` 刷屏时，按这个顺序查：

1. **算繁殖率**：`房间内同配置 NPC 数 × chance/100`。`> 1` 就会指数发散。
2. **确认数据是否合理**——本例数据完全符合 LPC 原文，不是转换 bug。
3. **查求值时机**：动作是否挂在行为树**最前面**且**无事件过滤**？LPC 里靠 `call_out`
   心跳节流的逻辑，在 Elixir 侧必须有**时间或条件门控**等价物。
4. **查自反馈**：动作是否发回自己订阅的频道？
