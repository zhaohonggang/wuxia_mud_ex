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
| `set()` key 在 `.ucl` 无痕迹 | 200 distinct / 3110 occ（missing 桶）+ 37 / 1018（engine 桶） | `scripts/triage_lost_keys.py` |
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
   | **B1** | `sleep_room` / `no_sleep_room` / `no_steal` / `no_beg` / `valid_startroom` | 127/90/55/39/68 | `room.flags` | **已完成**（提交 `cf0af449`）：房间块无歧义；`flags` 已在 Room 白名单（`loader.ex` L428 `parse_flags/1`），消费端 `World.room_flags/1`（`world.ex` L73） |
   | ~~B2~~ | ~~`base_unit` / `base_value`~~ | ~~72/69~~ | ~~`item.meta.unit/value`~~ | **已改判 `L3-framework`**（见下「P1a 修正 2」）：`base_*` 是「单件」语义，与 `unit`/`value`（整叠）不同 |
   | ~~B3~~ | ~~`female_only`~~ | ~~60~~ | ~~`item.meta.flag`~~ | **已改判 `L2`**：`flag` 是武器类型位掩码，塞不得 → 需新字段 `item.meta.female_only` |
   | ~~B4~~ | ~~`coagents`~~ | ~~30~~ | ~~`npc.coagents`~~ | **已改判 `manual`**：源值是 mapping 列表，`parse_coagents` 会崩；两处消费端形状不一致 |
   | ~~B1'~~ | ~~`base_weight`~~ | ~~36~~ | ~~`item.meta.weight`~~ | **已改判 L3-framework**（见下「P1a 修正」） |
   | B5 | NPC 侧 `max_force` / `force_factor` / `mana` / `max_mana` / `eff_qi` / `eff_jing` | 10/14/4/4/37/19 | `npc.vitals` 或 `npc.stats` | **先查 `vitals` 结构再定**（P1a 判 `manual`） |

   > **L1 已清空**：B1 之后重跑分诊（`tmp/lost_key_triage.json` 12:29 版）只剩 `valid_startroom` 一个 L1 项，
   > 而它正是 B1 用 `FLAG_NAME` 改名写成了 `"startroom"`（消费端 `home_command.ex` L54 找的是 `"startroom"`）
   > —— 属**改名导致的假阳性**。因此**白名单内纯数据回填已全部做完**，下一步只能走 L2（加字段）。

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

   **P1a 修正 2（2026-10-16，逐条回源实测）—— 剩余三个「L1」全部改判**

   按 §3 P1 第 1 步「decision 必须人工过一遍再动手」，对 B2/B3/B4 逐条回源核对，**三条全部判错**：

   | 原判 | 实测结论 | 改判 | 硬证据 |
   |------|----------|------|--------|
   | `base_unit`→`unit`、`base_value`→`value`（L1） | **不是同义词**，是 `base_weight` 的同类陷阱 | **L3-framework** | `inherit/item/combined.c`：`set_amount()` 里 `set("value", amount * base_value)`；`short()` 用 `base_unit`；`setup()` 把 `unit` 默认成 `"些"`。`clone/money/coin.c` 同时写 `unit="些"`/`base_unit="文"`；`d/beijing/npc/obj/jinbiao.c` 同时写 `unit="些"`/`value=2000`/`base_unit="支"`/`base_value=4000`。**引擎无 `amount` 字段** → 表达不了堆叠 |
   | `female_only`→`item.meta.flag`（L1） | **`flag` 是武器类型位掩码**，不能当通用 flag 列表 | **L2**（需新字段） | `wield_command.ex` L101 `Map.get(item.meta, :flag, 1)`（默认 1 = `ONE_HANDED`）；`loader.ex` L1274 `flag: Map.get(meta, :flag) \|\| 1`；战斗按 `& TWO_HANDED` 取值。`female_only` 的真实消费端是 `cmds/std/wear.c` L75（穿戴限制），与武器位掩码无关 |
   | `coagents`→`npc.coagents`（L1） | **字段在，但形状不符** | **manual** | 源值恒为 mapping 列表 `({ ([ "startroom":…, "id":… ]) })`（30 处全是）；`loader.ex parse_coagents/1` 做 `Enum.map(&to_string/1)` → 对 map 调 `to_string` 会 `Protocol.UndefinedError` **崩加载**；且消费端不一致（`combat_event.ex` L435 迭代 id 字符串 / `guarder.ex` L73 过滤 `is_map`）→ 必须先定 schema |

   > **教训（已写进脚本）**：`plan_key_field_map.py` 新增两条硬规则，防止同类误判复发——
   > ① `base_*` 前缀一律 `L3-framework`（「单件」语义族，引擎无 `amount`）；
   > ② `KNOWN` 表里不再把任何 key 直接映射到 `item.meta.flag`（该字段专用于武器位掩码）。
   > 结果：分诊表 `tmp/key_field_map.json` 变为 **L1=1（假阳性）/ L2=21 / L3-framework=85 / noop=8 / manual=122**。

   **新发现（同一次回源核对的副产品）：`wield_msg`/`unwield_msg` 其实早就转好了，只是被 loader 丢弃**

   - 转换器 `lpc_converter.ex` L3253-3260 **已经**把这两个 key 输出成
     `messages = { wield = "…" unwield = "…" }`（占位符 `{npc}`/`{name}` 已归一化）。
   - 全库实测：**220 个 `messages` 块**（全部落在 `items` 块内），含 **218 条 `wield` + 155 条 `unwield`**。
   - 但 **loader 没有 `messages` 解析、`Item.Meta` 没有该字段** → 这 373 条文案被**静默丢弃**。
   - 「丢失 key 审计」把它们报成「丢失」，只是因为它在 `.ucl` 里搜的是字面 key `wield_msg`，
     而实际写的是 `messages.wield` —— 这是审计的一类**假阳性**（另一例见 B1 的 `valid_startroom`）。
   - **结论**：这是一笔「**零数据写入即可激活**」的 L2 收益，列为 **B5a**（见 §3 P2）。

   **D10 实测规模（B5b 期间测出）—— 不是 1 个文件，是 83 个块**

   D10 原文只举了 `danA_1.c` 一例。做 B5b 时按「源文件 → UCL 块」全量对账，实测：

   | | `items` 块（loader 会读 `messages`） | `characters` 块（loader 不读） |
   |---|---:|---:|
   | 命中块数 | **46** | **83** |
   | `wear`/`remove`/`unequip` 条数 | 22 / 13 / 31 | 63 / 56 / 20 |

   即 **68% 的目标落在 `characters` 块**，且**全部**来自 `npc/obj/*.c`（如
   `d/beijing/npc/obj/blade.c` `inherit BLADE` —— 明明是武器，却被输出成
   `characters "blade" { name/aliases/description }`，**整个 meta 都没有**：
   damage/value/unit/material/weapon_prop/messages 全丢）。

   - 转换器把「继承武器/护甲宏（BLADE/SWORD/STAFF/CLOTH…）」的文件误判成 NPC ——
     它的 item 判定只认字面量 `ITEM`/`OBJECT`。
   - **本批只写 `items` 块**（46 块）：`characters` 块里 loader 根本不读 `messages`，
     写进去是**无效数据**，故不写、只计数上报。
   - ⚠️ **修 D10 需要改已有行**（`characters "x" {` → `items "x" {`），与 **P4「只增不改」冲突**
     → 属**待决策项**（见进度文档 §14 R7）。且光改名不够：这些块的 meta **从未生成过**，
     还得从源补 meta（本计划 P1/P2 的 key 通道可覆盖）。

   > **⚠️ 对账方法本身踩过的坑（B3 期间修正，2026-10-16）**
   > 上面「83 / 46」用的是**错的归因**——把块归给它前面最近的 `# Generated from` 头。
   > 但转换器**并不给每个块都写这个头**：`characters "mangshe"` 跟在 `zhulou.c` 的头后面，
   > 真实源却是 `# LPC: clone/beast/mangshe.c`（该注释在块**内部**，depth ≥ 1，
   > 所以按 depth==0 扫前缀永远看不到它）。用错归因把 `mangshe`/`caihuashe`/… 这 12 条蛇
   > 全算成了「`zhulou.c`(物品) 被写成 characters」，虚高了 item 数。
   >
   > **正确口径**：块内首条 `# LPC: <path>` > 最近的 `# Generated from` 头；需**回溯**取块身。
   > 按此重算全库 `characters` 块：**npc 1108 / item 619 / 源缺失 623 / unknown 235**。
   > 已固化为 `scripts/audit_block_attribution.py`（`iter_blocks/1` 直接给出每块的
   > 块类型与真实源），后续对账一律用它，别再手写正则。

   **B5b 顺带实测的两条 elias 词法边界**（`scripts/probe_ucl_brackets.exs`）

   | 引号内的值含 | 结果 |
   |---|---|
   | `[` / `]`（如 `，[唰]的一声`） | ❌ `syntax error before: '['` → **必须换成 `(` `)`**（与 `(pen)` 同惯例） |
   | `,` + 空白（`，` 全角无碍） | ❌ `syntax error before: ','` |
   | `[0-9],`（数字紧邻逗号） | ❌ 同上报错 |
   | `,` + 非数字非空白（`把`、`and`） | ✅ |

   > 全库待写值里只有 **1 条**踩到（`kunlun:pao1` 的 `，[唰]的一声`），已按上表改成 `(唰)`。

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
   - `Item.Meta` 加：`wield_msg unwield_msg wear_msg remove_msg unequip_msg`、`max_liquid`（✅ 已加 `a178e005`）、`power_point can_make not_make item_origin`（✅ `84dbaef2`）；扩 `armor_prop` 子键（`personality`/`armor_vs_force`/`warm`）与 `weapon_prop` 子键（`personality`）→ **已改为扩 `Combat.applies_keys()`（✅ `2d9de14a`，见 D21：单列字段过不了 `sanitize_prop`）**；
   - `Room` 加：`room_owner room_name room_position room_owner_id`。（代码 ✅ `48fa1b59`，**数据 ⏸ 阻塞：源无真实值**）
   - `NonPlayerMeta` 加：`chat_msg_combat chat_chance_combat`。（✅ `72b86831`）
   - 每个字段**只加 `Map.get`**，不写任何默认逻辑 → 消费端未接 = 行为不变。
2. **回填数据**（复用 P1b 脚本，换映射表）。
3. **补 `Jason.Encoder`**（若新字段会进 `Meta.Trim` 发给 web 客户端）——
   见 `ucl-comment-todo.zh-CN.md` §9.2 第 3 条：**裁剪副本必须能 JSON 编码**，否则 websocket 进程崩溃。

**验收**：字段在 `.ucl` 中可见；`mix test` 绿；**线上行为零变化**（无消费者）。

**P2 批次（按次数，来源 `tmp/key_field_map.json` 的 21 个 L2 key）**：

| 批次 | key | 次数 | 目标 |
|------|-----|-----:|------|
| **B5a** | （无 key）激活**已存在**的 `messages = { wield, unwield }` | 220 块 / 218+155 条 | `Item.Meta` 加 `messages` 字段 + loader 读取（**零数据写入，最高性价比**）—— **已完成 `0676bd08`**（219 物品命中） |
| B5b | `wear_msg` / `remove_msg` / `unequip_msg` | 89/63/37 | `messages = { wear, remove, unequip }`（`wield`/`unwield` 已在 B5a 覆盖，不重复转）—— **已完成**：因 B5a 已建好 `messages` 通道，本批实际是 **L1 纯数据**，无需再加字段 |
| B3 | `female_only` | 60 | `Item.Meta` **新字段** `female_only`（**不能塞 `flag`**，见「P1a 修正 2」）—— **已完成**：`Item.Meta` 加 `{:female_only, false}` + `parse_item_meta` 读 `meta.female_only`（`to_bool`）；回填 **24 个 `items` 块 / 7 区 / +24 行**，探针实测 24 物品命中 |
| B6 | `chat_msg_combat` / `chat_chance_combat` | 132/129 | `NonPlayerMeta` —— **已完成 `72b86831`**：`NonPlayerMeta` 加 `{:chat_msg_combat, []}` / `{:chat_chance_combat, 0}`；`loader.ex parse_character/4` 读取 + `parse_chat_msg_combat/1`；回填 **122 个 `characters` 块 / 29 区 / +239 行**，容器内探针 `probe_npc_combat_chat.exs` 实测 loader 载入字段（254/256 命中，样本 老大娘 chance=50） |
| B7 | `room_owner` / `room_name` / `room_position` / `room_owner_id` | 29/29/29/24 | `Room` 房间归属 —— **代码 ✅ `48fa1b59`**（Room 结构体加 4 字段 + `parse_room/4` Map.get；4409 个房间字段均为 nil）；**数据 ⏸ 阻塞**：源 .c 中 4 个 key 全在 `//**` 注释块为模板占位符，无激活 set()，无真实值可回填 |
| B8 | `max_liquid` | 74（实测 96 块） | `Item.Meta` 容器容量 —— **已完成 `a178e005`**：`Item.Meta` 加 `{:max_liquid, nil}`；`loader.ex parse_item_meta/1` 读 `meta.max_liquid`；回填 **96 个 `items` 块 / 30 区 / +96 行**，容器内探针 `probe_item_max_liquid.exs` 实测 loader 载入字段（96 命中，样本 葫芦 max_liquid=10） |
| B9 | `can_make` / `not_make` / `power_point` / `item_origin` | 16/8/20/16 | `Item.Meta` 打造系统 —— **已完成 `84dbaef2`**：`Item.Meta` 加 `{:can_make, nil}`/`{:not_make, nil}`/`{:power_point, nil}`/`{:item_origin, nil}` + `parse_item_meta/1` 读取；新增 `scripts/backfill_item_craft_keys.py` + `scripts/probe_item_craft_keys.exs`；回填 **14 个 `items` 块 / 3 区 / +49 行**，源文件 can_make=35/不_make=10/power_point=51/item_origin=35；容器内探针 OK（can_make 14/不_make 7/power_point 14/item_origin 14，类型全部正确） |
| B10 | `armor_prop/personality`、`armor_prop/armor_vs_force`、`armor_prop/warm`、`weapon_prop/personality` | 69/2/1/3 | **已完成（D21 拆两批）**：勘查（`scripts/survey_b10_props.py`）发现**全库 663 处斜杠式 `set("armor_prop/<sub>", N)` 从未被转换**（转换器只认整体式，`lpc_converter.ex` L3327-3328）—— 白名单内 armor/dodge/defense/attack/unarmed_damage（532 源文件）同样缺失。**B10a `bcd168c0`**：白名单内 137 子键 → **126 个 items 块 / 22 区 / +389 行**，经既有链路生效（`Equip.wear_state` 同 LPC `feature/equip.c` L38-47）；**B10b `2d9de14a`**：`Combat.applies_keys()` +personality/per/warm/armor_vs_force（惰性携带、无战斗行为变化）+ personality 回填 **28 块 / 8 区 / +34 行**（per/warm/armor_vs_force 的 items 目标 0 = D10 受害）。技能键 finger/hand/strike/cuff/claw/unarmed 判 manual（Fighter.skills 通道 v0 未建模） |
| B11 | `valid_leave` bare 条件（P4 的 data 部分） | 410 | **已完成（D22）**：回源 LPC `valid_leave` 的 `notify_fail` 判条件，61 候选中 **49 条转换器已有等价条目**、**11 条回填**（6 区：tulong/shaolin 各 3、jingzhou 2、chengdu/gumu/hangzhou 各 1，+68 行），1 条被遮蔽；余走 Trap 通道（见 §P4）。M7 生效 **144→155**；可达性不变；`mix test` 无新增失败 |

> **B5a 做法**（P7 只加字段）：`Item.Meta` 加 `:messages`（默认 `nil`）；`loader.ex parse_item/4`
> 加一行 `messages: Map.get(item_data, :messages)`（`messages` 在物品块**顶层**，与 `name` 同级，
> 不在 `meta` 块内）。**无消费端 → 行为零变化**；`Meta.Trim` 只 `Map.take([:damage, :armor])`，
> 新字段不进 web 载荷，**不需要 `Jason.Encoder`**。

**明确免除（登记抑制清单，不实现）**：`no_clean_up`（1805，生命周期）、`no_map`/`no_shown`/`no_user`/`no_magic`（显示开关）、`max_room`。
**判 `manual`、待人工定夺（不在上表）**：`default_long`(28)、`for_family`(35)、`jiaji`(21)、`hellzhen`(18)、`no_get_from`(14)、`liquid_type`(3) 等。

### P3 · 消费端接线（L3，逐字段）

每个新字段接一个消费端，**一次一个、逐条提交**：

| 字段 | 消费端 | 风险 | 状态 |
|------|--------|------|------|
| 装备文案 5 件套 | `wield/wear/remove_command.ex` 输出替换硬编码文案 | 低 | ✅ `c5c3c325`（2026-10-17） |
| `female_only` | `wield`/`wear` 命令前置判定（`with_item` 性别门控） | 中（**新拦截**，需灰度） | ✅（P3-c，a52ece2b） |
| `no_steal` | 偷窃命令前置判定 | 中（**新拦截**） | ✅ `524efcff`（P3-b，实际范围扩为 steal 三 flag + search no_search 共 4 处 KeyError 修复） |
| `no_beg` | 乞讨命令前置判定 | 中（**新拦截**） | ⬜（`beg_command.ex` 是「暂未开放」桩，无真实消费端 → 等 P5 乞讨系统） |
| `sleep_room` / `no_sleep_room` | `sleep_command.ex`（`room.attrs["sleep_room"]`） | 低 | ✅（consumer 已存在，`room.ex` L266-267 把 flags→attrs；B1 数据即生效，无需接线） |
| `liquid` / `max_liquid` | 倒/喝命令 | 中 | ⬜（`max_liquid` 数据已回填 B8，但倒/喝命令未接线 → 等 P5 容器/酒水系统） |
| `can_make` / `not_make` / `power_point` / `item_origin` | 打造命令 | 中 | ⬜（数据已回填 B9，但打造系统未建 → 等 P5 打造子系统） |
| `chat_msg_combat` / `chat_chance_combat` | NPC 战斗心跳 | 低 | ⬜（数据已回填 B6，但 NPC 战斗闲聊未接线 → 等 P5 NPC AI 聊天子系统） |

**装备文案 5 件套已完成（P3-a，`c5c3c325`）**：新起 `VisionEvent`/`VisionView`
落地 LPC `message_vision` 语义（`rooms:` 频道 + 事件类型 `"vision"`；`{npc}`
对行动者渲染「你」、对旁观者渲染姓名，`{name}` 由命令侧预替换）。接线只覆盖
「单物品动作」：wield（主手/副手）/wear/unwield/remove；`unwield`/`remove`
回退 `unequip` 键（源里两个键同义）；**swap 路径保持默认文案**（双物品复合
动作，LPC 无对应文本）。无自定义文案的路径渲染路径完全不变 → 行为变更只发生
在 249 个带文案物品上。零数据写入。

**验收**：每个字段一条集成测试；行为变更走**灰度开关 + 默认关**。

### P4 · 条件分支补全（数据层，回源）

**目的**：把 7096 条「只有条件、没有 body」的分支，按归属函数分诊补全。

| 归属函数 | 行数 | 处置 |
|----------|-----:|------|
| `create` | 2619 | **回源补 `set()` key**（走 P1/P2 的 key 通道），不单独做 |
| `valid_leave` | 472 | 剩余 410 条 bare 条件 → 回源取 `notify_fail` 文案 → 补进 `exit_vetoes`（与既有 183 条同法） |
| `init` / `greeting` | 367 / 184 | 回源补 action（`add_action`、台词池） |
| `do_*` 等 | 其余 | 归 P5 |

**`valid_leave` 状态：✅ 已完成（2026-10-16，D22）**。410 条 bare 的回源结论：
**61 条候选里 49 条转换器早已写过等价条目**（cond+msg+方向三同），
**11 条真缺口已回填**（6 区 / +68 行，全部过容器八项真门），1 条被既有
等价条目遮蔽（city:qiyuan1）。余 91+66 条走 **Trap 通道**：elias 词法不
支持多参调用 `present('x', environment(me))`（48）、白名单外函数
check_dirs/check_out/member_array/sscanf/random（19）、上游局部裸变量
（17）、`b/` 镜像树无对应房间（5）、动态拼接文案无法静态落库（66 文件）。
验收：**生效条数 144→155**（M7；实测基线非文档旧值 133）、
`world_reachability.py` 前后逐字节一致。

**验收**：`exit_vetoes` 生效条数从 133 上升；`world_reachability.py` 不降。

### P5 · 运行时子系统（L3 / L3-前置）

**开工前每个子系统都要先过 §1 Q1**：它的 UCL schema **实测可表达**吗？
表达不出来的（浮点、含数字的 key、动态出口）必须先定 schema 再转数据，否则转出来是废数据。
判定方法：`scripts/probe_elias_expressibility.exs`。

按「复用度 × 条数」排序推进，**每次一个子系统、独立提交**。

| 顺序 | 子系统 | 代表函数 | 规模 | 做法 | Q1 |
|-----:|--------|----------|-----:|------|:--:|
| 1 | **逐对象 `add_action` 通道** | `do_move/climb/jump/open/push/enter/get/eat/think/serve/...`（实际 1568 调用/793 文件，详见 D24） | 1568 调用 / 379 handler | **P5-1a 基础（9d185a57）+ P5-1a2 回填已完成（2026-10-17，315f87dd）**：Room 新增 `actions` 字段 + loader 读入（P7 只加字段），回填脚本从 UCL 房间块反查权威 `.c→UCL room id` 映射，把 304 房间 / 532 verb→handler 写进 `actions`（1140 行 / 59 区 / 0 删除，P4 只增不改）。**P5-1b-1 解析层（b9c6286f）+ P5-1b-2 接线（dormant-safe，2026-10-17，76345f7f）已完成**：`Room.resolve_action/2` + `resolve_verb/4`（委托）+ `RoomActionHandlers` 注册表 + `RoomAction`（handler 行为契约）+ `RoomActionDispatcher`（`extract_verb`/`resolve`/`dispatch`，`lookup_fun` 可注入）+ 在 `command_controller.ex recv/2` 的 `Commands.call` **之前**插入分发（命中且已注册→执行 handler 拦截全局命令，否则 `:not_handled` 放行）。**当前 `@registry` 为空 → 全 dormant、对全局命令零影响**；P5-1b-3 每注册一个 handler 对应房间动作才激活（房间 verb 优先于同名全局命令，重名核心命令 look/say/get/open/close 等 handler 未完整移植前不应注册）。**P5-1b-2 运行期修正（2026-10-17，c545ef3a）**：发现引擎不把房间塞进 `conn.private.room`（恒为 nil）、且 `Room.snapshot` 精简 map 不含 `actions`、`resolve_action` 又按 `%Room{}` 结构体匹配 —— 原接线在运行期会**永远 inert**（单测用手建结构体蒙混过关）。已补 `Room.actions_by_id/1`（查房间进程 `state.data` 取 `actions`）并修正 `RoomActionDispatcher.get_room_actions` 优先走它，使运行期能真正读到房间 verb（仍因空注册表 dormant，但 verb 已能被正确识别）。NPC add_actions 已被冻结转换器写进 UCL（52 文件）但**只存 handler 丢了 verb**、加载后无人分发；item 完全缺 UCL 入口。**P5-1b-3 样板已打通（2026-10-17）**：注册表改为**房间级 `lookup(room_id, handler)`**（同名 handler 按房间区分，`RoomActionHandlers.@registry` 现在是 `room_id -> (handler -> {mod,fun})`）。首例 `huashan:lianhua` 的 `do_tiao`（动词 "tiao" **在全局命令表无注册**、纯 `write` 文本、零副作用）移植为 `Kantele.World.RoomActions.Huashan.Lianhua.Tiao` 并注册；单测经**真实注册表 + 真实 handler** 端到端验证 dispatch 在运行期真触发、文本输出到玩家，且同名 handler 按房间区分（`baituo:neishi` 的 `do_move` 未移植→不触发）。**样板 #2（`c3bc18ff`）**：新增 `Kantele.World.RoomActions.Helpers`——`broadcast_vision/3`（LPC `message_vision` 等价：`publish_message` 到 `rooms:<room_id>`、`type: "vision"`、`$N`→行动者名，由 `VisionEvent` 渲染）+ `render_to_player/2`（LPC `write` 等价）；移植 `emei:shierpan3` 的 `do_clap`（房间广播）为 `Kantele.World.RoomActions.Emei.Shierpan3.Clap` 并注册，clap E2E 断言 `private.channel_changes` 含 vision publish。两样板动词均非全局命令，激活零玩法影响。**待做**：① **P5-1b-3 批量移植（长尾，本质=移植房间交互逻辑本身）**—— 回源 LPC 确认 handler 是房间级、非共享（`do_move`/`do_climb` 等同名 handler 在每个房间 `.c` 是各自独立的函数体，53 个 `do_move`/35 个 `do_climb` 各不相干）；逐个把房间独有 `do_*` 移植为 `use Kantele.World.RoomAction` 的模块并注册。**选样板/批量时一律避开与全局命令重名且未完整实现的 verb**（look/say/get/open/close/eat/drink/fight 等），优先挑 `clap`/`knock`/`reach`/`swim`/`pull`/`tiao` 这类非全局 verb，避免覆盖真实玩法（P7 安全）；含状态变更（`set("exits/down",...)`）或 `message_vision` 广播的 handler 需补 LPC→Elixir 世界模型桥接（查 family / 改 exits / 房间广播）；② 接线扩展到 NPC/物品 `actions` + shop list/buy 桥接 `npc_shop_event`；③ item 通道 UCL 入口；④ NPC verb 回源 | ✅ 已实测可表达 |
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
| `backfill_item_messages.py` | B5b | `.c` + `.ucl` | `.ucl` | 宿主机 | 必须 | ✅ **已建**（装备文案 → `messages = { wear, remove, unequip }`；门禁为「完整 issue 集合 + 行号归一化」比对） |
| `probe_item_messages.exs` | B5a/B5b 验收 | —（加载世界） | — | **容器内** | ✅ | ✅ **已建**（统计 `Item.Meta.messages` 各键装载数） |
| `backfill_item_female_only.py` | B3 | `.c` + `.ucl` | `.ucl` | 宿主机 | 必须 | ✅ **已建**（`meta.female_only`；两阶段：先算+门禁全过再备份写入） |
| `probe_item_female_only.exs` | B3 验收 | —（加载世界） | — | **容器内** | ✅ | ✅ **已建**（24 物品命中 + `flag` 位掩码未被污染） |
| `audit_block_attribution.py` | D10/R7 对账 | `.ucl` | — | 宿主机 | ✅ | ✅ **已建**（修正后的块归因；`iter_blocks/1` 输出每块的块类型与真实源路径） |
| `probe_ucl_brackets.exs` | elias 边界 | —（只解析字符串） | — | **容器内** | ✅ | ✅ **已建**（引号内 `[`/`,` 的可词法性） |
| `probe_room_owner.exs` | B7 验收 | —（加载世界） | — | **容器内** | ✅ | ✅ **已建**（B7；4409 房间字段均 nil，loader 读取正常；数据阻塞：源无真实值） |
| `backfill_npc_combat_chat.py` | B6 | `.c` + `.ucl` | `.ucl` | 宿主机 | 必须 | ✅ **已建**（B6 回填 `chat_msg_combat/chat_chance_combat`；dry-run 默认、两阶段、insertion-only、`validate_ucl` 门禁、幂等、双引号列表） |
| `probe_npc_combat_chat.exs` | B6 验收 | —（加载世界） | — | **容器内** | ✅ | ✅ **已建**（探针；实测 loader 载入 NonPlayerMeta.chat_msg_combat/chat_chance_combat，254/256 命中） |
| `backfill_item_max_liquid.py` | B8 | `.c` + `.ucl` | `.ucl` | 宿主机 | 必须 | ✅ **已建**（B8 回填 `max_liquid`；dry-run 默认、两阶段、insertion-only、`validate_ucl` 门禁、幂等、8 空缩进写入 meta 块内） |
| `probe_item_max_liquid.exs` | B8 验收 | —（加载世界） | — | **容器内** | ✅ | ✅ **已建**（探针；实测 loader 载入 Item.Meta.max_liquid，96 命中，样本 葫芦=10） |
| `backfill_item_craft_keys.py` | B9 | `.c` + `.ucl` | `.ucl` | 宿主机 | 必须 | ✅ **已建**（B9 回填 `can_make/not_make/power_point/item_origin`；dry-run 默认、两阶段、insertion-only、`validate_ucl` 门禁、幂等、8 空缩进写入 meta 块内） |
| `probe_item_craft_keys.exs` | B9 验收 | —（加载世界） | — | **容器内** | ✅ | ✅ **已建**（探针；实测 loader 载入 4 字段，can_make 14/不_make 7/power_point 14/item_origin 14） |
| `survey_b10_props.py` | B10 勘查 | `.c` + `.ucl` | `tmp/b10_survey.json` | 宿主机 | ✅ | ✅ **已建**（prop 斜杠子键三分：whitelisted/non_whitelisted/skill_manual + items/characters 块归属；证实 663 处从未被转换） |
| `backfill_item_props.py` | B10a/B10b | `.c` + `.ucl` | `.ucl` | 宿主机 | 必须 | ✅ **已建**（`--subsets whitelisted\|non_whitelisted\|both`；缩进自适应、既有 prop map 并入模式、dry-run 默认、两阶段、insertion-only、`validate_ucl` 门禁、幂等） |
| `probe_item_props.exs` | B10 验收 | —（加载世界） | — | **容器内** | ✅ | ✅ **已建**（探针；133 物品带 prop、personality 28、白名单外键 []、round-trip 干净） |
| `survey_valid_leave.py` | P4 勘查 | `.c` + `.ucl` | `tmp/p4_candidates.json` | 宿主机 | ✅ | ✅ **已建（P4 已完成）**（LPC `valid_leave` 解析器：嵌套 if 合取、放行守卫取反累积/复杂即作废、颜色宏 notify_fail、裸 `present()` 补 `this_object()`、裸变量与多参调用 elias 敌意检测、方向感知去重；61 候选 = 49 已有 + 12 新） |
| `probe_valid_leave_candidates.exs` | P4 分类 | —（加载世界） | `tmp/p4_verdict.json` | **容器内** | ✅ | ✅ **已建（P4 已完成）**（八项真门：parse/enforceable/supported/dir-scoped-or-all_dirs/房间找到/方向存在/别名有定义/不被既有生效条目遮蔽；产物 11 effective / 1 blocked） |
| `backfill_exit_vetoes.py` | P4 回填 | `tmp/p4_verdict.json` + `.ucl` | `.ucl` | 宿主机 | 必须 | ✅ **已建（P4 已完成）**（dry-run 默认、先 dry-run 定计划→`validate_ucl` 基线→备份→写盘→插入性子序列断言+问题集对比；逗号紧跟上一 `}`；幂等；**6 区 / +68 行**） |
| `assert_unhandled_baseline.py` | P6 | `tmp/*.json` | — | 宿主机 | ✅ | 待建 |
| `survey_add_action.py` | **P5-1 勘查** | `.c` 语料 + `lib/.../commands/` | `tmp/survey_add_action.json` | 宿主机 | ✅ | ✅ **已建（D24）**（扫描 `add_action("verb","handler")` 调用；按对象类型 room/npc/item/other 分诊；标注 Tier0 已有命令 vs 需新建；1568 调用/793 文件；发现 NPC add_actions 已被转换器写进 UCL 但只存 handler 丢了 verb、且未接分发） |

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
