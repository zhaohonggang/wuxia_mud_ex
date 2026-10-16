# `data/world/*.comments.txt` 续做计划

> 配套：`docs/data-world-comments-txt-audit.zh-CN.md`（盘点与实测数字）。
> 本文件是**执行计划**，回答「接下来怎么做」。
> 建立日期：2026-10-16。
>
> **先读**：`docs/data-world-conversion-framework-first.zh-CN.md` ——
> 「哪些必须先补框架」的判据与决策矩阵。它决定了本计划 §1 三层模型里
> 每一项该走 L1 / L2 / L3，以及 C 类为什么必须排在后面。

---

## 0. 硬约束（七条原则，不可违反）

| # | 原则 | 具体含义 |
|---|------|----------|
| **P1** | **冻结转换器** | 不修改 `scripts/lpc_converter.py`、`lib/kantele/world/lpc_converter.ex`、`lib/mix/tasks/kantele.convert_lpc.ex` |
| **P2** | **不重跑转换器** | 任何脚本都**不得**调用 `convert_file` / `_generate_ucl` 去写 `data/world/*.ucl`。目录模式会**整体覆盖**该 zone，抹掉全部手工成果（见 `lpc-converter-usage.zh-CN.md` §二） |
| **P3** | **新增即独立** | 续做逻辑一律放在**新**脚本（`scripts/*.py`，一次性迁移/回填）和**新**模块（`lib/kantele/...`，运行时）里 |
| **P4** | **只增不改** | 数据脚本只「补缺失字段」，**绝不修改已有行**；必须幂等 —— 连跑两次，第二次 diff 必须为空 |
| **P5** | **写盘三步** | dry-run（默认）→ 备份 → 校验（`validate_ucl.py` + `mix test`）。三者缺一不可 |
| **P6** | **不删 sidecar** | `.comments.txt` 是唯一索引，删了就永久丢失。AGENTS.md「Never discard information」同样适用 |
| **P7** | **只加字段** | 涉及运行时字段时，`struct` 只**加**字段（默认 `nil`）、`parse_*` 只**加** `Map.get`；不改既有解析路径。**新字段在接线消费端之前不产生任何行为变化** |

---

## 1. 分诊：先过三问，再归入三层

每个未转换项**动手前**先过 `docs/data-world-conversion-framework-first.zh-CN.md` §1 的三问：

```text
Q1  这个值能不能写进 UCL？（elias 可词法化吗）
    └─ 不能 →  【框架优先】必须先定 schema / 命名方案，否则转了也是废数据
Q2  loader 有没有对应的解析字段？
    └─ 没有 →  【轻框架】先加字段（只加，不改），再转数据
Q3  有没有消费端（谁读它）？
    └─ 没有 →  可以先转，只是不生效 —— 不阻塞转换
```

> **Q1 必须实测**，跑 `scripts/probe_elias_expressibility.exs`，**不能读归档文档** ——
> 文档里至少一条阻塞理由（CJK 方向）已被证伪，见 §2.5。

过完三问，再归入三层：

| 层 | 对应三问 | 内容 | 风险 | 可立即做？ |
|----|----------|------|------|-----------|
| **L1 纯数据** | Q1 ✅ Q2 ✅ | 把丢失的值写回 `data/world/*.ucl`，目标字段**已在 loader 白名单** | 极低（只动数据，无消费者变化） | ✅ |
| **L2 数据 + 加字段** | Q1 ✅ Q2 ❌ | 先给 `struct` 加字段 + `parse_*` 加读取，再回填数据 | 低（数据可见，无行为变化） | ✅ |
| **L3 运行时子系统** | Q1 ✅ Q3 ❌ | 新模块 + 消费端接线（actions 通道、战斗回调、门/容器…） | 中～高（会改变游戏行为） | 需逐条验证 |
| **L3-前置 框架优先** | **Q1 ❌** | 值本身表达不出来，或语义上必须有状态机（动态出口、effect、带副作用的 veto） | — | ❌ **必须先补框架**，见 §3 P5（表中 `Q1` 列标 ⚠️ 的行） |

**推进顺序永远是 L1 → L2 → L3-前置以外 → L3-前置**。
先把「数据补齐」做干净，再谈「行为接入」；**绝不能反过来先建框架**（框架的接口设计需要真实数据来验证）。

---

## 2. 五个必须先知道的前置事实

这五点决定了计划为什么长这样。**不先接受这五点，计划一定会走偏。**

### 2.1 loader 是「白名单解析」，不是「原样透传」

`data/world/*.ucl` 里写了字段**不等于**游戏读得到。loader 对每个结构体都是**固定字段列表**：

| 结构体 | 位置 | 白名单字段 |
|--------|------|-----------|
| `Kantele.World.Item.Meta` | `lib/kantele/world/item.ex` L248 | `damage skill_type armor value weight unit material food medicine book armor_type weapon_prop armor_prop flag storage_bag aliases no_sell no_put owner owner_id` |
| `Room` | `lib/kantele/world/loader.ex` `parse_room/4` L326 | `id key zone_id name description map_color map_icon x y z flags features item_desc exit_vetoes behavior behavior_config` |
| `NonPlayerMeta` | `lib/kantele/character.ex` L306 | `initial_events vitals zone_id stats combat_config combat goods inquiries teach apprentice turn_in loot quest coagents parts no_cut default_clone been_cut defeated_by greetings init aliases accept guarder engage carry` |

**推论**：白名单外的 key，光写进 `.ucl` 会被**静默丢弃**。这就是 L2 存在的理由。
**反例警示**：`armor_prop/personality`（69 次）写进 `armor_prop` 也会被丢 —— `sanitize_prop/1`
只放行 `Kantele.Character.Combat.applies_keys()`（`[:attack :defense :damage :unarmed_damage :dodge :parry :armor]`）。

### 2.2 sidecar 只记了 17% 的 body —— 必须回源

条件分支行 **8525 条中 7096 条（83.2%）只有条件、没有 action**。原因：转换器的
`_BRANCH_ACTION`（`lpc_converter.py` L94）只认 `command|say|tell_object|message_vision|write`，
`return notify_fail(...)` / `set(...)` / `me->set_temp(...)` 全都不记。

**结论**：sidecar 是索引，不是规格。**所有续做都要回 `C:\files\git\mud` 取真实 body。**
→ 已由 **P0** 解决：2104/2136（**98.5%**）函数 body 已自动回源。

### 2.3 部分「UNHANDLED FUNCTION」根本不在本文件里

2136 条里有 68 条在本文件中找不到定义 —— 转换器是在**继承链合并后**统计的，这些函数来自基类。
→ 已由 **P0** 的语料索引兜底 36 条（如 `beijing:matong#do_ride` → `mud/cmds/std/ride.c`）。
**剩下 32 条**（`ask_me1` vs `ask_me_1` 命名差异、宏生成等）留作 P0.1。

> **重要副产品**：`do_ride` 解析到 `mud/cmds/std/ride.c` —— 说明一部分「未转换函数」
> 其实是**全局命令**，Elixir 侧 `lib/kantele/character/commands/`（204 个模块）**已经有对应实现**。
> 这类应归 **Tier 0/1**（不需要逐对象实现），不是新功能。

### 2.4 数字基线（冻结，只能降不能升）

| 指标 | 基线 | 复现 |
|------|-----:|------|
| sidecar payload 行数 | 11247 | `scripts/analyze_comments_txt.py` |
| 条件分支行（其中无 body） | 8525（7096） | 同上 |
| `UNHANDLED FUNCTION` 条数 / 名数 | 2136 / 643 | 同上 |
| 分支归属函数数 | 442 | `scripts/build_unhandled_manifest.py` |
| 函数 body 已回源 | 2104 / 2136（98.5%） | 同上 |
| `set()` key 在 `.ucl` 无痕迹 | 202 distinct / 3150 occ | `scripts/triage_lost_keys.py` |
| 可达性 | **4190 / 4409（95.0%）** | `scripts/world_reachability.py` |
| 测试 | `mix test --seed 12345` 绿 | — |

> 可达性口径已实测：**4190/4409**。旧文档里的 `4190/4470` 是当时的世界规模，
> 分母已变（房间总数 4470 → 4409），引用时请以本表为准。

### 2.5 elias 有硬边界，而且判据必须实测

**有些值根本写不进 UCL** —— 这决定了哪些项是「框架优先」（§1 Q1）。
elias 0.2.8 实测（`scripts/probe_elias_expressibility.exs`）：

| ❌ 表达不出来（会硬报错） | ✅ 能表达 |
|---|---|
| key 以数字结尾（`hole_1`）/ 含数字（`hole1`）/ 含连字符（`x-y`）/ 加引号 | **CJK key**（`乾 = rooms.bagua7.id`） |
| **浮点数**（`1.5`） | 嵌套 mapping、mapping 列表（`actions = [ {verb, handler} ]`） |
| 单引号字符串、列表尾随逗号 | 负数、空列表、`~` 哨兵、CJK 值 |
| **映射用逗号分隔**（只能用空白分隔 `{a=1  b=2}`） | 列表里引号字符串 + `, ` |
| 列表裸引用带空格（必须 `[rooms.a.id,rooms.b.id]` **紧贴**） | — |
| 字符串内「逗号 + 空格 + **字母**」 | 字符串内「逗号 + 空格 + **数字**」是 OK 的 |

⚠️ **静默变味**：`true` → 字符串 `"true"`；`[a,b]` → **一个字符串**（靠 loader `pick_runtime_exit/1` 切分补救）；`direction = ~` → 字符串 `"~"`，是**有意哨兵**（`to_veto_dir("~") -> "*"`，全库 101 处）。

> **归档文档已有一处错误**：`data-world-converted-ucl-comments.zh-CN.md` §2 称
> 「CJK 方向 elias 只认 ASCII → 64 条 skipped」。实测**不成立** ——
> `shaolin.ucl` L106-113 本来就有 32 行 CJK 方向键且能解析。
> **凡是「能不能转」的问题，先跑探针，不要读归档文档。**

---

## 3. 阶段计划

### P0 · 清单化（✅ 已完成，本仓已落地）

**目的**：把纯文本 sidecar 变成可排期、可验收、可防回归的结构化清单，并**回源补回丢失的 body**。

已落地五个脚本（全部**只读**，不写 `data/world`，不 import 转换器）：

| 脚本 | 作用 | 输出 | 运行位置 |
|------|------|------|----------|
| `scripts/analyze_comments_txt.py` | sidecar 逐行分类盘点 | `tmp/comments_inventory.json` | 宿主机 |
| `scripts/audit_ucl_key_loss.py` | `set()` key 对 `.ucl` 原始对账 | `tmp/ucl_key_loss.json` | 宿主机 |
| `scripts/triage_lost_keys.py` | key 三分类（别名/引擎已有/真丢失） | `tmp/lost_key_triage.json` | 宿主机 |
| `scripts/build_unhandled_manifest.py` | **结构化清单 + 回源取 body** | `tmp/unhandled_manifest.json` | 宿主机 |
| `scripts/probe_elias_expressibility.exs` | **§1 Q1：elias 能表达什么** | 终端输出 | **容器内** |

`unhandled_manifest.json` 每条记录长这样：

```json
{
  "id": "beijing:aofu_shufang#function#do_turn",
  "kind": "function",
  "zone": "beijing", "object": "aofu_shufang",
  "source_path": "C:/files/git/mud/d/beijing/aofu_shufang.c",
  "name": "do_turn",
  "body_status": "recovered",
  "lpc_line": 61,
  "body": "do_turn(string arg)\n{\n        object me = this_player();\n ... }"
}
```

**验收**：条目数、函数名数、key 数写入 §2.4 基线表；数字可复现。

> ⚠️ **解析坑（已处理，但改脚本时别踩回去）**：sidecar 的段头是**倒序输出**的
> （`_generate_unhandled_comments` 末尾 `reversed(flat)`），
> `# ==== CONDITIONAL BRANCHES (fn) ====` 出现在它那几行条件**之后**。
> 正确做法是「先攒行、遇段头再归属」。

### P0.1 · 索引兜底收尾（可选，低优先）

- 32 条仍未解析的 `UNHANDLED FUNCTION`：加「命名变体」匹配（`ask_me1` ↔ `ask_me_1`）。
- 给每条记录补 `tier` 字段（见 P5 分诊表），让清单直接可排期。
- 产出 `docs/data-world-unhandled-baseline.zh-CN.md`（人类可读的基线表 + 抑制清单）。

### P1 · 白名单内纯数据回填（L1，**建议最先做**）

**目的**：把能映射到**已有** loader 字段的丢失值补回 `.ucl`。零运行时风险。

**步骤**

1. **P1a 生成映射表**（新脚本 `scripts/plan_key_field_map.py`，**已建**）
   对 `tmp/lost_key_triage.json` 的 `missing` + `engine` 两桶（共 242 个 key）逐个过 §1 的三问：
   （`missing` = 全库无字段痕迹；`engine` = lib/ 里出现过该名字，通常字段已存在 → 多属 L1。
   两桶都要过，因为 P1/P2 的批次表同时引用它们。）
   - **Q1** 这个 key 的名字/值 elias 能表达吗？（含数字/连字符的 key、浮点值 → ❌）
     —— 判定必须跑 `scripts/probe_elias_expressibility.exs`，**不采信归档文档**；
   - **Q2** 是否等于某个 struct 字段名（`Item.Meta` / `Room` / `NonPlayerMeta`）？
   - **Q2** 是否与已有字段同义（`armor_prop/personality` → `armor_prop`、`base_weight` → `weight`）？
   - **Q3** 是否属于某个已知的 LPC 子系统（`liquid` → 容器、`chat_msg_combat` → NPC 闲聊）？

   输出 `tmp/key_field_map.json`：
   `{key, occ, target: "item.meta.X"|"room.X"|"npc.X"|null, decision: "L1"|"L2"|"L3-framework"|"noop"|"manual", reason}`。
   **decision 必须人工过一遍再动手**；判成 `L3-framework` 的项移交 §3 P5，**不要**在 P1/P2 里硬转。

2. **P1b 分批回填**（新脚本 `scripts/backfill_l1_fields.py`）
   - 从 LPC 源取 `set("key", value)` 的**真实值**（含 `clonep()` / `else` 分支区分）；
   - 注入到对应 `.ucl` 块的 `meta = { ... }`（或房间/NPC 块）；
   - **只加不存在的键**，已存在的键**跳过并计数**（P4 幂等）；
   - 默认 dry-run，`--apply` 才写盘；写盘前把目标文件复制到 `tmp/backup-<时间戳>/`。
   - 方法沿用既有先例 `scripts/item_meta_backfill.py`（`c7c5fd9`，685 物品）。

3. **优先批次**（按收益/风险）——**已由 P1a 实测重排**，见 `tmp/key_field_map.json`：

   | 批次 | key | 次数 | 目标 | 说明 |
   |------|-----|-----:|------|------|
   | **B1** | `sleep_room` / `no_sleep_room` / `no_steal` / `no_beg` / `valid_startroom` | 127/90/55/39/68 | `room.flags` | **最先做**（已实施）：房间块无歧义；`flags` 已在 Room 白名单（`loader.ex` L428 `parse_flags/1`），消费端 `World.room_flags/1`（`world.ex` L73） |
   | **B2** | `base_unit` / `base_value` | 72/69 | `item.meta.unit/value` | 同义（白名单含 unit/value）；**注意 `npc/` 路径下的物品被输出成 `characters` 块**（见下） |
   | **B3** | `female_only` | 60 | `item.meta.flag` | **物品**属性（不是房间）；白名单含 `flag` |
   | **B4** | `coagents` | 30 | `npc.coagents` | NonPlayerMeta 白名单已含 `coagents` |
   | ~~B1'~~ | ~~`base_weight`~~ | ~~36~~ | ~~`item.meta.weight`~~ | **已改判 L3-framework**（见下「P1a 修正」） |
   | B5 | NPC 侧 `max_force` / `force_factor` / `mana` / `max_mana` / `eff_qi` / `eff_jing` | 10/14/4/4/37/19 | `npc.vitals` 或 `npc.stats` | **先查 `vitals` 结构再定**（P1a 判 `manual`） |

   **B1 实施记录（2026-10-16，提交 `cf0af449`）**：284 房间 / 56 区，`+921` 行 `-0` 行；幂等、校验 67/10 不退化、可达性 4190/4409 不变、`mix test` 34 个既有失败不新增。
   - `valid_startroom` → flag 名 **`"startroom"`**（消费端 `home_command.ex` L54 / `recall_command.ex` L50 找的是 `"startroom"`，不是 `valid_startroom`）。
   - ⚠️ **列表分隔符必须是逗号**：elias 对「两个换行分隔、无逗号」的列表元素报 `syntax error before: '"'`。
     手写先例 `city.ucl` 的 `flags` **只有 1 项**（无需分隔符）因而看不出这个坑 —— 首版脚本按它写了无逗号多行格式，整批 56 区语法非法，已回滚重做。
     实测见 `scripts/probe_elias_expressibility.exs`；正确写法是 `"a",\n"b"`（逗号）或单行 `["a", "b"]`。
   - ⚠️ **`no_beg` 无消费端**（`beg_command.ex` 是「乞讨系统暂未开放」桩）；
     **`no_steal` 消费端可疑** —— `room.ex` L1462 读 `context.data.no_steal`，但 `context.data` 就是 `%Room{}` 结构体，
     而 `Room` **没有** `:no_steal` 字段（实测 `Map.has_key?` = false）→ 该分支会抛 `KeyError`。二者均登记 P3/风险 R6。

   **P1a 修正（2026-10-16，实测）**

   - **`base_weight` 不是 `weight` 的同义词**：`set_weight(N)` 写的是私有 `weight` 变量（`mud/feature/move.c` L40），
     而 `set("base_weight", N)` 是**独立**属性，只有可堆叠物品才读它
     （`cmds/std/hand.c` L37：`query_amount() ? query("base_weight") : query_weight()`）。
     引擎既无 `amount` 也无 `base_weight` 字段 → 属**框架优先**，不能塞进 `weight`。
   - **`female_only` 是物品属性，不是房间属性**：源文件是 `d/baituo/obj/qingpao.c` 等 obj 物品
     （item×45 / npc×15），所以目标是 `item.meta.flag` 而不是 `room.flags`。
   - **同一 key 会落在不同对象类型上**：`no_steal` = room×45/item×4/npc×6，`base_unit` = item×63/npc×11。
     P1a 因此为每个 key 输出**源对象类型分布**（`kinds` 字段），target 按主导类型定。
   - ⚠️ **转换器把 `npc/` 路径下的物品输出成 `characters` 块**（实例：`d/beijing/npc/dan/danA_1.c` 是
     可堆叠的「养精丹」`COMBINED_ITEM`，却生成 `characters "danA_1" { ... }`）。
     `item_meta_backfill.py` 只处理 `items` 块 → 这批物品**从未被回填过**。
     做 B2 时必须同时处理 `characters` 块里的物品，否则会漏。

**验收**：`python scripts/validate_ucl.py data/world/<zone>.ucl` 通过；
`git diff --stat` 只有**新增行**（无删除/修改）；`mix test --seed 12345` 绿；
二次运行 dry-run 报「0 待补」。

### P2 · 加字段 + 回填（L2）

**目的**：白名单外的 key，先让 loader **能装下**，再回填数据。此时仍无行为变化。

**步骤**

1. **只加字段**（P7）——**下表已由 P1a 实测收敛为 20 个 key（1282 occ）**，
   早期草稿里的 `sleep_room`/`no_sleep_room`/`no_steal`/`no_beg`/`female_only`/`no_map`
   已被改判（前四个走已有 `room.flags` → **B1/L1**；`female_only` → **B3/L1**；`no_map` → noop），
   **不要再为它们加字段**：
   - `Item.Meta` 加：`wield_msg unwield_msg wear_msg remove_msg unequip_msg`、`max_liquid`、
     `power_point can_make not_make item_origin`；扩 `armor_prop` 子键（`personality`/`armor_vs_force`/`warm`）与 `weapon_prop` 子键（`personality`）；
   - `Room` 加：`room_owner room_name room_position room_owner_id`；
   - `NonPlayerMeta` 加：`chat_msg_combat chat_chance_combat`。
   - 每个字段**只加 `Map.get`**，不写任何默认逻辑 → 消费端未接 = 行为不变。
2. **回填数据**（复用 P1b 脚本，换映射表）。
3. **补 `Jason.Encoder`**（若新字段会进 `Meta.Trim` 发给 web 客户端）——
   见 `ucl-comment-todo.zh-CN.md` §9.2 第 3 条：**裁剪副本必须能 JSON 编码**，否则 websocket 进程崩溃。

**验收**：字段在 `.ucl` 中可见；`mix test` 绿；**线上行为零变化**（无消费者）。

**P2 批次（按次数，来源 `tmp/key_field_map.json` 的 20 个 L2 key）**：

| 批次 | key | 次数 | 目标 |
|------|-----|-----:|------|
| B5 | `wield_msg` / `unwield_msg` / `wear_msg` / `remove_msg` / `unequip_msg` | 295/217/89/63/37 | `Item.Meta` 装备文案（**最高收益**） |
| B6 | `chat_msg_combat` / `chat_chance_combat` | 132/129 | `NonPlayerMeta` |
| B7 | `room_owner` / `room_name` / `room_position` / `room_owner_id` | 29/29/29/24 | `Room` 房间归属 |
| B8 | `max_liquid` | 74 | `Item.Meta` 容器容量 |
| B9 | `can_make` / `not_make` / `power_point` / `item_origin` | 16/8/20/16 | `Item.Meta` 打造系统 |
| B10 | `armor_prop/personality`、`armor_prop/armor_vs_force`、`armor_prop/warm`、`weapon_prop/personality` | 69/2/1/3 | 扩 `Combat.applies_keys()` 或单列字段 |

**明确免除（登记抑制清单，不实现）**：`no_clean_up`（1805，生命周期）、`no_map`/`no_shown`/`no_user`/`no_magic`（显示开关）、`max_room`。
**判 `manual`、待人工定夺（不在上表）**：`default_long`(28)、`for_family`(35)、`jiaji`(21)、`hellzhen`(18)、`no_get_from`(14)、`liquid_type`(3) 等。

### P3 · 消费端接线（L3，逐字段）

每个新字段接一个消费端，**一次一个、逐条提交**：

| 字段 | 消费端 | 风险 |
|------|--------|------|
| 装备文案 5 件套 | `wield/wear/remove_command.ex` 输出替换硬编码文案 | 低 |
| `female_only` / `no_steal` / `no_beg` | 移动/偷窃/乞讨命令的前置判定 | 中（**新拦截**，需灰度） |
| `sleep_room` / `no_sleep_room` | `sleep_command.ex` | 低 |
| `liquid` / `max_liquid` | 倒/喝命令 | 中 |
| `can_make` / `not_make` / `power_point` | 打造命令 | 中 |
| `chat_msg_combat` | NPC 战斗心跳 | 低 |

**验收**：每个字段一条集成测试；行为变更走**灰度开关 + 默认关**。

### P4 · 条件分支补全（数据层，回源）

**目的**：把 7096 条「只有条件、没有 body」的分支，按归属函数分诊补全。

| 归属函数 | 行数 | 处置 |
|----------|-----:|------|
| `create` | 2619 | **回源补 `set()` key**（走 P1/P2 的 key 通道），不单独做 |
| `valid_leave` | 472 | 剩余 410 条 bare 条件 → 回源取 `notify_fail` 文案 → 补进 `exit_vetoes`（与既有 183 条同法） |
| `init` / `greeting` | 367 / 184 | 回源补 action（`add_action`、台词池） |
| `do_*` 等 | 其余 | 归 P5 |

**验收**：`exit_vetoes` 生效条数从 133 上升；`world_reachability.py` 不降。

### P5 · 运行时子系统（L3 / L3-前置）

**开工前每个子系统都要先过 §1 Q1**：它的 UCL schema **实测可表达**吗？
表达不出来的（浮点、含数字的 key、动态出口）必须先定 schema 再转数据，否则转出来是废数据。
判定方法：`scripts/probe_elias_expressibility.exs`。

按「复用度 × 条数」排序推进，**每次一个子系统、独立提交**。

| 顺序 | 子系统 | 代表函数 | 规模 | 做法 | Q1 |
|-----:|--------|----------|-----:|------|:--:|
| 1 | **逐对象 `add_action` 通道** | `do_move/climb/jump/open/push/enter/get/eat/think/serve/...` | 646 行 / 215 名 | `Room.add_action/2` 已有雏形但只有房间级、无 UCL 入口。定义 UCL `actions = [ { verb, handler } ]`，loader 读入后注册到房间/NPC/物品；`Kalevala.Verb` 路由时**对象级优先**。**这一层覆盖最大面积** | ✅ 已实测可表达 |
| 2 | 战斗回调 | `accept_fight/kill/hit/ansuan`、`unconcious`、`die`、`owner_is_killed` | 259 行 / 12 名 | **方案 A：在新脚本里重新抽取 `engage`**（读同一批 LPC 源，只增不改地合并进 `.ucl`）。**不要加宽转换器的抽取规则** —— 那违反 P1。见框架文档 §5 决策点 1 | ✅ |
| 3 | 动态出口 | `do_turn` 的 `set("exits/down", ...)` | 含在 `do_*` 内 | **框架优先**：出口现在是**加载期固化**的，运行时增删需要先加 API（`Room.dynamic_exits` 已有雏形，缺增删入口） | ⚠️ 需定 schema |
| 4 | look / inquiry | `look_*`、`ask_*`、`item_desc` 闭包 `(: look_hua :)` | 185 行 / 86 名 | schema **已可表达**（`value = { kind = "smith"  pattern = "huwan" }` 实测 OK），缺的是运行时 handler 注册表 + 分发。与 `ucl-comment-todo` §6 E（`xiangyang` 铁匠 6 条）合并做 | ✅ |
| 5 | effect / invocation | `do_effect`(90)、`invocation`(18) | 108 行 / 2 名 | **框架优先**：需要 buff/effect 子系统承载 | ⚠️ 需定 schema |
| 6 | 门 / 容器 | `close`、`close_passage`、`do_open/knock/break` | 40 行 | **框架优先**：需要有状态的门 | ✅ |
| 7 | 学徒 / 门派 | `recognize_apprentice`、`attempt_apprentice` | 52 行 / 2 名 | 名数少、行数多，单点收益高 | ✅ |
| 8 | 通信中继 / 载具 | `relay_emote`、`relay_say`、`on_board` | 含在 459 内 | 需要跨房间通信 / 载具状态 | ✅ |
| 9 | 一次性场景 | 赌场（`city/bet`、`changan/duchang`）、`xiqu1..7`、棋房、`look_gaoshi`、`begin/working/halt_working` | 459 行 / 246 名 | **逐房写 Elixir 模块按 room id 绑定**（沿用棋房/拱猪先例），不硬塞数据。出现**第 3 个**同形状场景才提炼子系统。见框架文档 §5 决策点 2 | ✅ |

> **另外两个已在别处登记的框架优先项**（不在本表内，属既有待办）：
> `check_dirs` / `check_out` / `ob->refuse` 18 条条件需要**带副作用的 veto 通道**
> （`ucl-comment-todo.zh-CN.md` §4 C），`xiangyang` 铁匠 inquiry 6 条（同文档 §6 E）。

**Tier 0 免除**（不写代码，登记抑制清单 + 理由）：
`setup`(37) `reset`(34) `create` `init` `long`(19) `name`(11) `is_container`(17) `is_chat_room`(11) `query_autoload`(13)；
以及 P0 解析出的**全局命令**（如 `do_ride` → `cmds/std/ride.c`，Elixir 已有 `ride_command.ex`）。
⚠️ 例外：`long` / `name` 若依赖 `query()` 动态生成 → 归 P5 第 3 项。

### P6 · 防回归（贯穿始终）

1. **基线断言**：新脚本 `scripts/assert_unhandled_baseline.py` —— 读 `tmp/*.json`，
   断言 §2.4 的每个数字 **≤ 基线**，超出即退出码非 0。可挂 pre-commit。
2. **抑制清单**：`scripts/unhandled_suppressions.json`，每条 `{id|key, tier:"noop", reason:"..."}`。
   原则照抄 `ucl-comment-implementation-plan` §3.1：**不允许留成待办黑洞**。
3. **可达性**：`python scripts/world_reachability.py` 不降（实测 4190/4409）。
4. **测试**：`MIX_ENV=test mix test --seed 12345`（文档基线）/ `--seed 731933`（AGENTS.md CI 种子）。
5. **幂等自检**：所有回填脚本连跑两次，第二次必须 0 改动。

---

## 4. 脚本清单

| 脚本 | 阶段 | 读 | 写 | 运行位置 | 幂等 | 状态 |
|------|------|----|----|----------|:----:|------|
| `analyze_comments_txt.py` | P0 | `.comments.txt` | `tmp/` | 宿主机 | ✅ | **已建** |
| `audit_ucl_key_loss.py` | P0 | `.c` + `.ucl` | `tmp/` | 宿主机 | ✅ | **已建** |
| `triage_lost_keys.py` | P0 | `.c` + `.ucl` + `lib/` | `tmp/` | 宿主机 | ✅ | **已建** |
| `build_unhandled_manifest.py` | P0 | `.comments.txt` + `.c` | `tmp/` | 宿主机 | ✅ | **已建** |
| `probe_elias_expressibility.exs` | **§1 Q1 / P5 前置** | —（只解析字符串） | — | **容器内** | ✅ | **已建** |
| `plan_key_field_map.py` | P1a | `tmp/lost_key_triage.json` + `.c` 语料 | `tmp/` | 宿主机 | ✅ | **已建** |
| `backfill_l1_fields.py` | P1b | `.c` + `.ucl` | `.ucl` | 宿主机 | 必须 | ✅ **已建**（含写盘前备份 + `validate_ucl` 自校验门禁） |
| `assert_unhandled_baseline.py` | P6 | `tmp/*.json` | — | 宿主机 | ✅ | 待建 |

**所有脚本的公共约定**
- Python 脚本只在**宿主机**跑（容器内无 Python，见 `lpc-converter-usage.zh-CN.md` §二）；
  `.exs` 探针**只能在容器内**跑（宿主机没有 Elixir）。
- 默认 **dry-run**；写盘必须显式 `--apply`。
- 写盘前把受影响文件复制到 `tmp/backup-<时间戳>/`。
- 不 import `lpc_converter` 的写路径；需要编码转换时自带 `decode()`（GBK/UTF-8 自适应）。

---

## 5. 安全与回滚协议

```text
1. git status 干净（否则先提交/暂存）           ← 回滚靠 git
2. python scripts/<backfill>.py                ← dry-run，看 diff 预览
3. python scripts/<backfill>.py --apply        ← 写盘 + 自动备份到 tmp/backup-*/
4. python scripts/validate_ucl.py data/world/<zone>.ucl
5. git diff --stat                             ← 必须只有新增行
6. MIX_ENV=test mix test --seed 12345          ← 绿
7. 提交（按区/按批次，不用一个 commit 混多个批次）
```

**回滚**：`git checkout -- data/world/<zone>.ucl`（或从 `tmp/backup-*/` 还原）。

**绝不**：`rm data/world/*.comments.txt`、手改 `data/world/*.ucl` 而不留脚本、
用脚本整体重写 `.ucl`（P2/P4 违反）。

---

## 6. 完成定义（DoD）

一个批次算完成，必须同时满足：

- [ ] **§1 三问已过**：Q1 跑过 `probe_elias_expressibility.exs`（判「框架优先」的项已移交 P5，没在本批次硬转）
- [ ] dry-run 显示「待补 N 项」，`--apply` 后二次 dry-run 显示「0 项」（幂等）
- [ ] `git diff --stat` 只有新增行，无删除/修改
- [ ] `validate_ucl.py` 通过
- [ ] `mix test --seed 12345` 绿
- [ ] `world_reachability.py` 不降
- [ ] 该批次的 key/函数从 `tmp/` 清单里移入抑制清单或标记完成
- [ ] `scripts/assert_unhandled_baseline.py` 通过
- [ ] 文档更新：§2.4 基线表 + 批次记录

---

## 7. 明确不做的事

| 不做 | 原因 |
|------|------|
| 重跑转换器重新生成 `.ucl` | P2 原则；会整体覆盖 |
| 修改 `lpc_converter.py` 的抽取规则 | P1 原则；宁可脚本侧补齐。**战斗回调（P5 第 2 项）曾经写成「加宽抽取规则」，那是错的，已改为新脚本重抽** |
| **先建框架再转数据** | 框架接口需要真实数据验证；反过来会做出错误抽象，再为迁就它扭曲数据。顺序永远是 L1 → L2 → L3 |
| **凭归档文档判断「能不能表达」** | 已证伪至少一条（CJK 方向）。必须跑 `probe_elias_expressibility.exs` |
| **在数据里硬塞 §1 Q1 失败的项** | 浮点、含数字/连字符的 key 转了也解析不了，只会污染 `.ucl` |
| 删除或重写 `.comments.txt` | P6；唯一索引 |
| 把 sidecar 当规格直接翻译 | 83.2% 无 body，必须回源 |
| 用 `key` 定位房间 | 全库 432 个 key 重名（`majiu` 22 区）→ **必须用 `id`** |
| 一次性把所有 L3 子系统一起接 | 行为变更需逐条灰度验证 |
| 给 `no_clean_up` 等生命周期 key 建字段 | 引擎已覆盖，属噪音 |

---

## 附录 A. 当前可立即执行的命令

```bash
# P0 已落地，先跑一遍拿到全部基线（只读，不写 data/world）—— 宿主机
python scripts/analyze_comments_txt.py data/world
python scripts/audit_ucl_key_loss.py
python scripts/triage_lost_keys.py
python scripts/build_unhandled_manifest.py      # 首次约 30s，之后有缓存约 4s

# §1 Q1 探针 —— 容器内（宿主机没有 Elixir）；只解析字符串，不碰 data/world
docker exec -w /app wuxia_mud_dev-app-1 mix run --no-start scripts/probe_elias_expressibility.exs
```

产出：`tmp/comments_inventory.json`、`tmp/ucl_key_loss.json`、
`tmp/lost_key_triage.json`、`tmp/unhandled_manifest.json`、`tmp/lpc_function_index.json`。

> Git Bash 下 `docker exec -w /app` 会被 MSYS 改写路径，报 `Cwd must be an absolute path`。
> 加 `MSYS_NO_PATHCONV=1` 前缀即可。

## 附录 B. 建议的第一个提交

**P1a + P1b-B1**（最小闭环，用来验证整套协议）：

1. 写 `scripts/plan_key_field_map.py`，产出映射表；
2. 只做 `base_weight` → `item.meta.weight`（36 次，同义、低风险）；
3. 跑完 §5 七步协议，提交。

这一步跑通后，P2 的批量回填就只是「换映射表 + 重复协议」。
