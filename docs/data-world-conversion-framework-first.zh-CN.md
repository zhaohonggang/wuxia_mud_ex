# 哪些转换必须先补框架？—— 判据与决策矩阵

> 问题：`data/world` 里剩下的未转换内容，是不是**有些必须先补框架才能转**？
> 答案：**是，但只占一部分**。绝大多数可以现在就用数据脚本推进。
> 本文件给出**可操作的判据**，判据全部**实测**得出，不采信归档文档的说法。
> 建立日期：2026-10-16。配套：`docs/data-world-comments-continuation-plan.zh-CN.md`。

---

## 0. 直接回答

| 类别 | 占比 | 需要先补框架吗 |
|------|------|----------------|
| **A 类** 目标字段已在 loader 白名单 | 大头 | ❌ 不需要，纯数据脚本即可 |
| **B 类** loader 没有该字段，但 elias 能表达 | 中 | ⚠️ **「轻框架」**：加字段 + 定 schema（增量、零行为变化），然后就能转 |
| **C 类** 值本身表达不出来，或语义上需要运行时状态机 | 少数但集中 | ✅ **必须框架优先**，否则转了也没用 / 转不出来 |

**一句话**：**A 类先做完 → B 类一次定好 schema 批量加 → C 类一个子系统一个子系统做。**
**绝不要反过来先建框架** —— 框架的接口设计需要数据来验证，先建框架会空转。

---

## 1. 判据：三个问题

对每一个未转换项，依次问：

```
Q1  这个值能不能写进 UCL？（elias 能词法化吗）
    └─ 不能 →  【框架优先】必须先定 schema / 命名方案
Q2  loader 有没有对应的解析字段？
    └─ 没有 →  【轻框架】先加字段（只加，不改），再转数据
Q3  有没有消费端（谁读它）？
    └─ 没有 →  数据可以先转，但转了不生效 —— 这是「安全但无效」，
               不是「破坏」，所以不阻塞转换
```

**关键**：只有 **Q1 失败** 才是真正的「框架优先」。
Q2 失败只是「加个字段」，Q3 失败根本不影响转换能不能做。

---

## 2. 实测的 elias 硬边界（elias 0.2.8）

**判据必须实测，不能信归档文档。** 探针脚本：
`scripts/probe_elias_expressibility.exs`

```bash
docker exec -w /app wuxia_mud_dev-app-1 mix run --no-start scripts/probe_elias_expressibility.exs
```

### 2.1 ❌ 表达不出来（会硬报错）

| 构造 | 结果 | 应对 |
|------|------|------|
| key 以数字结尾（`hole_1`） | FAIL | 先定改名方案（`hole_a`）→ **框架优先** |
| key 含数字（`hole1`） | FAIL | 同上 |
| key 含连字符（`x-y`） | FAIL | 同上 |
| key 加引号（`"乾"`） | FAIL | 不要加引号 |
| **浮点数**（`1.5`） | FAIL | 先定表示法（字符串？放大整数？）→ **框架优先** |
| 单引号字符串（`'abc'`） | FAIL | 用双引号 |
| 列表尾随逗号（`["a","b",]`） | FAIL | 去掉 |
| **映射用逗号分隔**（`{a=1,b=2}` / `{a=1, b=2}`） | FAIL | 映射**只能用空白分隔**（`{a=1  b=2}`） |
| **列表里裸引用 + 逗号空格**（`[rooms.a.id, rooms.b.id]`） | FAIL | 写 `[rooms.a.id,rooms.b.id]`（**紧贴，无空格**） |
| **字符串内「逗号 + 空格 + 字母」**（`"present('ao bai', environment(me))"`） | FAIL | 去掉空格（现有数据已这么写） |

### 2.2 ✅ 能表达（放心用）

| 构造 | 结果 |
|------|------|
| **CJK key**（`乾 = rooms.bagua7.id`） | **OK 且保留**（见 §3 更正） |
| **嵌套 mapping**（`value = { kind = "smith"  pattern = "huwan" }`） | OK |
| **mapping 列表**（`actions = [ { verb = "turn"  handler = "M.F" } ]`） | OK |
| 深层嵌套 mapping | OK |
| 列表里的引号字符串 + `, ` | OK |
| 负数、空列表、`~` 哨兵、转义引号、CJK 值 | OK |

### 2.3 ⚠️ 会「静默变味」的坑

| 构造 | 实际结果 | 含义 |
|------|----------|------|
| `true` | 解析成**字符串 `"true"`** | loader 侧要同时接受 `true`/`"true"`（已有先例，`loader.ex` L403） |
| `[rooms.a.id,rooms.b.id]` | 解析成**一个字符串** `"rooms.a.id,rooms.b.id"` | 靠 loader `pick_runtime_exit/1`（L1337）`String.split(item, ",")` 补救 |
| `direction = ~` | 解析成**字符串 `"~"`** | 这是**有意哨兵**，loader `to_veto_dir("~") -> "*"`（L414）。全库 101 处 |

> **推论**：想用「候选列表」机制，必须**沿用 `[a,b]` 紧贴无空格**这个约定 ——
> 这是现有数据已经在用的写法（`shaolin.ucl` 的 bamboo 房间）。

---

## 3. 更正：归档文档里有一条阻塞理由是错的

`docs/data-world-converted-ucl-comments.zh-CN.md` §2 说：

> 方向名非 ASCII（CJK）：elias 的 `Word` token 只认 ASCII
> → `skipped exit direction '乾': direction is not ASCII ...`（64 条）

**实测不成立。** `Elias.parse` 对 `乾 = rooms.c.id` 返回
`%{room_exits: %{r: %{room_id: "rooms.a.id", 乾: "rooms.c.id"}}}` —— **键被完整保留**。
而且 `data/world/shaolin.ucl` 里**本来就有**这 32 行 CJK 方向键（L106-113 等），
`room_exits "bagua0" { 乾 = rooms.bagua7.id  ... }`，并没有改成拼音。

**教训**：判断「能不能转」必须跑探针，不能读归档文档。
（其余几条阻塞理由 —— 数字 key、浮点、逗号空格 —— 实测**属实**。）

---

## 4. 三类划分

> **与续做计划的编号对照**（避免两份文档各说各话）：
>
> | 本文 | 续做计划 §1 | 三问 |
> |------|------------|------|
> | A 类 | **L1** | Q1 ✅ Q2 ✅ |
> | B 类 | **L2** | Q1 ✅ Q2 ❌ |
> | C 类 | **L3 / L3-前置** | Q1 ✅ Q3 ❌ → L3；**Q1 ❌ → L3-前置** |
>
> 执行顺序与批次以 `docs/data-world-comments-continuation-plan.zh-CN.md` 为准；
> 本文只负责「判据」与「该不该先补框架」。

### A 类 · 不需要补框架（纯数据脚本）

| 未转换内容 | 规模 | 目标字段（已存在） |
|-----------|-----:|-------------------|
| `base_weight` | 36 | `item.meta.weight` |
| `food_supply` | 185 | `item.meta.food` |
| `base_unit` / `base_value` | 72 / 69 | `item.meta.unit` / `.value` |
| `armor_prop` / `weapon_prop` 白名单内子键 | — | `item.meta.armor_prop` / `.weapon_prop` |
| `create()` 的 `if/else` 里标准 `set()` | 2619 行 | 走 key 通道（**不需要单独处理**） |
| `valid_leave` 剩余 bare 条件 | 410 | `exit_vetoes[].condition`（回源取 `notify_fail` 文案） |
| `init` / `greeting` 的 bare 条件 | 367 / 184 | `init.add_actions` / `greetings` |
| CJK 方向、候选列表、`~` 哨兵 | — | **已可表达，无需框架** |
| `chat_msg` → `chats` | 146 | 已有字段 |

### B 类 · 轻框架（加字段 + 定 schema，然后就能转）

**做法固定**：`struct` 加字段（默认 `nil`）→ `parse_*` 加 `Map.get` → 转数据 → 最后才接消费端。
**只加不改**，所以加字段这一步**零行为变化**，可以放心独立提交。

| 未转换内容 | 规模 | 要加的字段 |
|-----------|-----:|-----------|
| 装备文案 5 件套 `wield/unwield/wear/remove/unequip_msg` | 701 | `Item.Meta` 加 5 字段 |
| `chat_msg_combat` / `chat_chance_combat` | 132 / 129 | `NonPlayerMeta` 加 2 字段 |
| 容器 `max_liquid` | 74 | `Item.Meta` 加字段 |
| 打造 `can_make` / `not_make` / `power_point` / `item_origin` | 16 / 8 / 20 / 16 | `Item.Meta` 加字段 |
| `armor_prop/personality` / `armor_prop/armor_vs_force` / `armor_prop/warm` / `weapon_prop/personality` | 69 / 2 / 1 / 3 | 扩 `Combat.applies_keys()` 或单列字段 |
| 房间归属 `room_owner` / `room_name` / `room_position` / `room_owner_id` | 29 / 29 / 29 / 24 | `Room` 加 4 字段 |
| `switch(random())` 池 | 132 | schema 已有先例（`pick_runtime_exit`），需定 `pools` 字段 |

> **§4 更正（2026-10-16，实测）**：本节初稿把**房间 flag 类**误列为 B 类，实际是 **A 类（L1）** ——
> `Room` **已有** `flags` 字段（`room.ex` L34），loader 已解析（`parse_flags/1`，`loader.ex` L428），
> 消费端已存在（`World.room_flags/1`，`world.ex` L73；`snapshot/1` attrs，`room.ex` L238-240）。
> 因此下面这些 key 走 **已有 `flags` 通道**，**不要加字段**（已由 B1 落地，284 房间 / 56 区）：
>
> | key | 次数 | flag 名 | 消费端 |
> |-----|-----:|--------|--------|
> | `sleep_room` | 127 | `sleep_room` | ✅ `room.ex` L238（attrs） |
> | `no_sleep_room` | 90 | `no_sleep_room` | ✅ `room.ex` L239（attrs） |
> | `valid_startroom` | 68 | **`startroom`** | ✅ `home_command.ex` L54 / `recall_command.ex` L50 |
> | `no_steal` | 55 | `no_steal` | ⚠️ `room.ex` L1462 路径可疑（见风险 R6） |
> | `no_beg` | 39 | `no_beg` | ❌ 无（`beg_command.ex` 是桩）→ P3 |
>
> `female_only`(60) 同理属 A 类：`Item.Meta` 已有 `flag`（`item.ex` L262、`loader.ex` L1274）。
> `base_unit`(72) / `base_value`(69) → `Item.Meta` 已有 `unit`/`value`，亦属 A 类。
> 判据：**Q2 只看「字段在不在白名单」，不看「字段名是否与 key 同名」**。

### C 类 · 框架优先（不补框架就没法转 / 转了没意义）

| 未转换内容 | 规模 | 为什么必须框架优先 | 要补什么 |
|-----------|-----:|-------------------|----------|
| **逐对象动词 `do_*`** | 646 行 / 215 名 | UCL 没有「逐对象注册动词」的 schema；`Room.add_action/2` 只到房间级、只存 `dynamic_exits[:verbs]`、**没有 UCL 入口**，NPC/物品级完全不支持 | UCL `actions = [ {verb, handler} ]` + loader 读取 + 对象级优先的 dispatch |
| **动态出口**（`do_turn` 的 `set("exits/down", ...)`） | 含在 `do_*` 内 | 出口是加载期固化的，运行时增删需要有状态出口 | 出口运行时增删 API |
| **`do_effect`(90) / `invocation`(18)** | 108+ | 需要 buff/effect 子系统承载 | effect 框架 |
| **`check_dirs` / `check_out` / `ob->refuse`** | 18 条条件 | 现有 veto 是**纯判定**，这三个**带副作用**（扣精、扣内力、改计数） | 带副作用的 veto 通道（`ucl-comment-todo` §4 C 已登记） |
| **`look_*` / `ask_*` / `item_desc` 闭包**（`(: look_hua :)`） | 185 行 / 86 名 | 闭包无法进数据；需要 handler 注册表 | schema **已可表达**（`value = { kind=..., ... }` 实测 OK），缺的是运行时 handler 分发 |
| **门 / 容器** `close` / `close_passage` | 40 行 | 需要有状态的门 | 门状态机 |
| **学徒 / 门派** `recognize_apprentice` / `attempt_apprentice` | 52 行 / 2 名 | 需要门派系统承载 | 门派子系统 |
| **通信中继 / 载具** `relay_emote` / `relay_say` / `on_board` | 含在 459 内 | 需要跨房间通信 / 载具状态 | 中继子系统 |
| **一次性场景** 赌场（`city/bet`、`changan/duchang`）、`xiqu1..7`、棋房 | 459 行 / 246 名 | 各自是独立状态机 | 场景子系统，或**逐房写 Elixir 模块按 room id 绑定**（沿用棋房/拱猪先例） |

### C 类里的特例 · 半框架

| 内容 | 说明 |
|------|------|
| **战斗回调** `accept_fight/kill/hit/ansuan`（259 行 / 12 名） | 转换器**已有** `ast.engage` schema（`%{fight: %{accept:, msg:, retaliate:, spawn:}}`），只是抽取规则窄。**加宽抽取规则 = 改转换器** → 与 P1 原则冲突。**决策点见 §5** |

---

## 5. 两个必须拍板的决策点

### 决策点 1 · 战斗回调：要不要为它破例改转换器？

- **方案 A（守 P1）**：在**新脚本**里重新实现 engage 抽取（读同一批 LPC 源，输出到 `data/world`）。
  转换器不动。代价：抽取逻辑有第二份实现，将来可能漂移。
- **方案 B（破例）**：给 `lpc_converter.py` 加宽 `engage` 抽取规则，重跑**相关区**。
  代价：违反 P2（目录模式整体覆盖），必须逐区重跑 + 人工对账。
- **推荐 A**。259 行 / 12 个函数名的规模，不值得为它破例。而且新脚本可以**只增不改**地
  把结果合并进 `.ucl`，比整体重跑安全得多。

### 决策点 2 · 一次性场景（459 行 / 246 名）：子系统还是逐房模块？

- 这些场景（赌场掷骰、`xiqu1..7`、棋房）**互不共用**逻辑，做成通用子系统会过度设计。
- **推荐**：逐房写 Elixir 模块 + 按 room id 绑定（棋房/拱猪已有先例）。
  只有当**第三个**场景出现相同形状时，才提炼成子系统。

---

## 6. 推荐顺序（含理由）

| 阶段 | 内容 | 为什么在这个位置 |
|------|------|------------------|
| **1** | **A 类全部做完** | 纯数据、零运行时风险；先把「数据面」补齐，后面的框架才有真实输入 |
| **2** | **B 类：一次性把所有要加的字段加完** | 加字段零行为变化；一次加完只跑一轮测试，比零散加省事 |
| **3** | **B 类：批量回填数据** | 换映射表 + 重复 §5 协议 |
| **4** | **C 类第 1 项：`actions` 通道** | **单个收益最大的框架** —— 一次覆盖 646 行 / 215 个函数名；且是通用机制，不是一次性 |
| **5** | C 类其余子系统，按「复用度 × 条数」 | 每个独立提交、独立灰度 |
| **6** | 一次性场景（逐房模块） | 最后做，因为互不共用、可随时插入 |

**为什么 `actions` 通道排第一**：
它同时满足三个条件 —— ① 覆盖面积最大（215 个函数名）；② 是**通用机制**（房间/NPC/物品都能用）；
③ 它的 UCL schema **实测可表达**（`actions = [ { verb = "turn"  handler = "M.F" } ]` 通过探针）。
换句话说，它是 C 类里**唯一一个「框架能一次做完、不用返工」**的项。

---

## 7. 方法提醒

1. **判据必须实测**。归档文档里至少一条阻塞理由（CJK 方向）是错的（§3）。
   任何「能不能表达」的问题，先跑 `scripts/probe_elias_expressibility.exs`。
2. **不要先建框架再转数据**。框架的接口设计需要真实数据来验证；
   先建框架会做出错误抽象，然后为了迁就它去扭曲数据。
3. **加字段永远只加不改**（`struct` 加默认 `nil` 字段 + `parse_*` 加 `Map.get`），
   这样「补框架」和「转数据」可以解耦成两个独立提交。
4. **新字段进 `Meta.Trim` 前必须能 JSON 编码** —— 裁剪副本要发给 web 客户端，
   漏了 `Jason.Encoder` 会让 websocket 进程崩溃（`ucl-comment-todo.zh-CN.md` §9.2 第 3 条）。
5. **定位对象用 `id` 不用 `key`**（全库 432 个 key 重名）。

---

## 附录 · 复现

```bash
# elias 表达力探针（容器内，只读）
docker exec -w /app wuxia_mud_dev-app-1 mix run --no-start scripts/probe_elias_expressibility.exs

# 未转换清单 + 回源取 body（宿主机，只读）
python scripts/build_unhandled_manifest.py
python scripts/triage_lost_keys.py
```
