# `data/world/*.comments.txt` 续做进度跟踪

> **这是唯一记录「做到哪了」的文件。**
> 执行计划：`docs/data-world-comments-continuation-plan.zh-CN.md`
> 判据：`docs/data-world-conversion-framework-first.zh-CN.md`
> 盘点与基线来源：`docs/data-world-comments-txt-audit.zh-CN.md`
> 建立日期：2026-10-16。

---

## 0. 使用说明

### 状态图例

| 标记 | 含义 |
|:----:|------|
| ⬜ | 未开始 |
| 🟨 | 进行中 |
| ✅ | 已完成（DoD 全过） |
| ⏸️ | 暂停 / 阻塞（必须在 §14 写明原因） |
| ➖ | 明确免除（必须登记进 §11 抑制清单 + 理由） |

### 每完成一个批次，必须做四件事

1. 把批次行状态改成 ✅，填**提交号**与**完成日期**；
2. 更新 §2 基线表的「当前」列；
3. 在 §13 变更日志**追加**一行（只追加，不改历史行）；
4. 跑一遍 §15 的自检命令，全绿才算完成。

### 勾选框规则

- 勾选框只在**实际验证过**之后才勾（不是「写完了」就勾）。
- 勾完不许反勾 —— 若发现回退，在 §13 追加一行说明，并把状态改回 🟨。

---

## 1. 总体看板

| 阶段 | 内容 | 规模 | 层 | 状态 | 提交 | 完成日期 |
|------|------|-----:|:--:|:----:|------|----------|
| **P0** | 清单化（5 个只读脚本） | 11095 条记录 | — | ✅ | `059c07b8` | 2026-10-16 |
| **P0.1** | 索引兜底收尾 + 基线表 | 32 条 | — | ⬜ | | |
| **P1** | 白名单内纯数据回填 | 5 个批次 | L1 | ✅ | `cf0af449` | B1 ✅；B2/B3/B4 复核**改判**（L3-framework / L2 / manual）→ **L1 已清空** |
| **P2** | 加字段 + 回填 | 8 个批次 | L2 | ✅ | `2d9de14a` | **B5a ✅**（激活 `messages`）/ **B5b ✅**（46 块）/ **B3 ✅**（24 块）/ **B6 ✅**（122 块 / 29 区 / +239 行，提交 `72b86831`）/ **B7 代码 ✅**（Room 加 4 字段，提交 `48fa1b59`，**数据阻塞：源无真实值**）/ **B8 ✅**（96 块 / 30 区 / +96 行，提交 `a178e005`）/ **B9 ✅**（14 块 / 3 区 / +49 行，提交 `84dbaef2`）/ **B10 ✅**（B10a 126 块 / 22 区 / +389 行 `bcd168c0` + B10b 28 块 / 8 区 / +34 行 `2d9de14a`）→ **P2 批次全部完成** |
| **P3** | 消费端接线 | 6 个字段 | L3 | 🟨 | `524efcff` | **装备文案 5 件套 ✅**（`c5c3c325`）；**no_steal ✅**（`524efcff`，实际范围 skybook/no_fight/no_search 一并修复）；**female_only ✅**（P3-c，wield_command 灰度拦截）；余 no_beg / liquid+max_liquid / can_make / chat_msg_combat 待 P5 子系统（消费端未建） |
| **P4** | 条件分支补全（回源） | 410 条 / 60 区 | L1 | 🟨 | | **`valid_leave` 已完成 ✅**（11 条生效回填 / 6 区 / +68 行，M7 144→155；61 候选中 49 条转换器已有等价条目，余为 Trap 通道）；`create`(2619)/`init`/`greeting` 归 P1/P2/P5 未完 |
| **P5** | 运行时子系统 | 9 个子系统 | L3 / L3-前置 | ⬜ | | |
| **P6** | 防回归 | 2 个脚本 | — | 🟨 | | |

**P5 进度**：`0 / 9` 个子系统完成。

---

## 2. 基线（冻结）与当前值

> 基线**只能降不能升**。任一「当前」列超过基线即为回归，必须停下排查。
> 复现命令见 §15。

| # | 指标 | 基线 | 当前 | 状态 | 复现脚本 |
|---|------|-----:|-----:|:----:|----------|
| M1 | sidecar payload 行数 | 11247 | `—` | ⬜ | `analyze_comments_txt.py` |
| M2 | 条件分支行（其中无 body） | 8525（7096） | `—` | ⬜ | 同上 |
| M3 | `UNHANDLED FUNCTION` 条数 / 名数 | 2136 / 643 | `—` | ⬜ | 同上 |
| M4 | 分支归属函数数 | 442 | `—` | ⬜ | `build_unhandled_manifest.py` |
| M5 | 函数 body 未回源 | 32 | `—` | ⬜ | 同上 |
| M6 | `set()` key 真丢失 distinct / occ | 202 / 3150 | **200 / 3110** | ✅ | `triage_lost_keys.py` |
| M7 | `valid_leave` 生效条数 | 133 / 166 | **155 / 177** | ✅ | `recount_veto_status.exs`（P4 回填 11 条后实测） |
| M8 | 可达性 | 4190 / 4409（95.0%） | **4190 / 4409（95.0%）** | ✅ | `world_reachability.py` |
| M9 | 测试失败数 | 34（既有，12 个文件均不读 `data/world`） | **33**（无新增；`reload_command_test` 那条转好，属 recompile 环境相关） | ✅ | `mix test --seed 12345` |
| M10 | 已回填 `room.flags` 房间数 | 0 | **284** | ✅ | `backfill_l1_fields.py` |
| M11 | `validate_ucl.py` 通过 / 失败 | 67 / 10 | **67 / 10** | ✅ | `validate_ucl.py` |
| M12 | `Item.Meta.messages` 已装载物品数（转换器已输出、此前被丢弃） | 0 | **249**（wield 218 / unwield 155 / wear 22 / remove 13 / unequip 31；P3-a `c5c3c325` 已接消费端） | ✅ | `scripts/probe_item_messages.exs` + `scripts/probe_equip_messages_wiring.exs`（容器内） |
| M13 | 装备文案已回填条数（B5b 新增） | 0 | **66**（wear 22 / remove 13 / unequip 31，46 个 `items` 块 / 14 区） | ✅ | `backfill_item_messages.py` |
| M14 | `Item.Meta.female_only=true` 物品数（B3） | 0 | **24**（7 区） | ✅ | `scripts/probe_item_female_only.exs`（容器内） |
| M15 | `chat_msg_combat`/`chat_chance_combat` 载入 NPC 数（B6） | 0 | **254/256**（29 区，样本 老大娘 chance=50） | ✅ | `scripts/probe_npc_combat_chat.exs`（容器内） |
| M16 | `Item.Meta.*_prop` 已装载物品数（B10a/B10b；此前 .ucl 只有 liuxi 3 个手写块） | 0 | **133**（armor 117 / dodge 17 / personality 28 / defense 3 / unarmed_damage 4 / attack 1；含 liuxi 手写 3） | ✅ | `scripts/probe_item_props.exs`（容器内） |
| M17 | prop 子键白名单 `Combat.applies_keys()` 键数 | 7 | **11**（+personality/per/warm/armor_vs_force） | ✅ | `scripts/probe_item_props.exs`（容器内） |
| M18 | P4 回填 exit_vetoes 生效条数（回源 LPC `valid_leave` 的 `notify_fail`） | 0 | **11**（6 区：tulong 3 / shaolin 3 / jingzhou 2 / chengdu / gumu / hangzhou 各 1；+68 行） | ✅ | `scripts/probe_valid_leave_candidates.exs` + `backfill_exit_vetoes.py` |

**基线已实测确认**：M1–M8 为本轮实跑值；M7 的「133」是 `ucl-comment-todo.zh-CN.md` 的旧快照，P4 执行前实测为 144/166、回填后 155/177。

---

## 3. P0 · 清单化 ✅

| 脚本 | 作用 | 状态 | 备注 |
|------|------|:----:|------|
| `scripts/analyze_comments_txt.py` | sidecar 逐行分类 | ✅ | 输出 `tmp/comments_inventory.json` |
| `scripts/audit_ucl_key_loss.py` | `set()` key 原始对账 | ✅ | 输出 `tmp/ucl_key_loss.json` |
| `scripts/triage_lost_keys.py` | key 三分类 | ✅ | 输出 `tmp/lost_key_triage.json` |
| `scripts/build_unhandled_manifest.py` | 结构化清单 + 回源取 body | ✅ | 输出 `tmp/unhandled_manifest.json`（8.1 MB） |
| `scripts/probe_elias_expressibility.exs` | elias 表达力探针（容器内） | ✅ | 终端输出，elias 0.2.8 |

- [x] 五个脚本全部跑通，产出 5 个 `tmp/*.json`
- [x] 回源取 body：**2104 / 2136 = 98.5%**（2068 本文件 + 36 继承兜底）
- [x] 计数与独立分类脚本对账一致（8525 / 2136 / 135 / 132 / 38 / 34 / 27 / 5）
- [ ] ⬜ **提交**（当前 5 个脚本 + 3 份文档均为 untracked，尚未 commit）

---

## 4. P0.1 · 索引兜底收尾

- [ ] ⬜ 32 条未解析 `UNHANDLED FUNCTION` 加「命名变体」匹配（`ask_me1` ↔ `ask_me_1`）
- [ ] ⬜ 给每条记录补 `tier` 字段（Tier 0/1/2），让清单直接可排期
- [ ] ⬜ 产出 `docs/data-world-unhandled-baseline.zh-CN.md`（人类可读基线表）

---

## 5. P1 · 白名单内纯数据回填（L1）

**开工前**：跑**计划 §1** 的三问；Q1 必须用 `probe_elias_expressibility.exs` 实测。

| 步骤 | 状态 | 说明 |
|------|:----:|------|
| P1a `plan_key_field_map.py` 生成映射表 | ✅ | 输出 `tmp/key_field_map.json`（242 key）；`decision` 枚举 `L1`/`L2`/`L3-framework`/`noop`/`manual` |
| P1a 人工过一遍 decision | ✅ | 已复核；**发现并改判 3 项**（见下「P1a 复核结论」） |
| P1b `backfill_l1_fields.py` 回填 | ✅ | 只增不改 + 幂等 + dry-run 默认 + **写盘前备份** + **`validate_ucl` 自校验门禁**；**当前只实现 `room.flags` 目标** |

**P1a 复核结论（决定性的 3 处改判）**

1. **`base_weight` 不是 `weight` 的同义词 → 改判 L3-framework**。`set_weight(N)` 写私有 `weight` 变量
   （`mud/feature/move.c` L40），`set("base_weight", N)` 是独立属性，仅可堆叠物品读它
   （`cmds/std/hand.c` L37）。引擎无 `amount`/`base_weight` 字段。**计划原 B1 作废**。
2. **`female_only` 是物品属性 → 目标 `item.meta.flag`**（源为 `obj/qingpao.c` 等，item×45/npc×15），
   不是房间 flag。
3. **`parts` 目标不匹配**（源是物品，`NonPlayerMeta.parts` 是 NPC 字段）→ 退回 `manual`。

**P1a 复核结论 2（第二轮，逐条回源实测）—— B2/B3/B4 全部改判**

> 第一轮只按「名字/同义」推断，第二轮按 §3 P1 第 1 步**回源读真实语义**，三条全部判错：

| 原判 | 改判 | 硬证据 |
|------|------|--------|
| `base_unit`→`unit`、`base_value`→`value`（L1） | **L3-framework** | `inherit/item/combined.c`：`set_amount()` 里 `set("value", amount * base_value)`；`short()` 用 `base_unit`；`setup()` 把 `unit` 默认 `"些"`。`clone/money/coin.c` 同写 `unit="些"`/`base_unit="文"`；`d/beijing/npc/obj/jinbiao.c` 同写 `unit="些"`/`value=2000`/`base_unit="支"`/`base_value=4000`。**引擎无 `amount`** |
| `female_only`→`item.meta.flag`（L1） | **L2**（新字段） | `flag` 是武器类型位掩码：`wield_command.ex` L101 默认 `1`=ONE_HANDED；`loader.ex` L1274 `\|\| 1`；战斗按 `& TWO_HANDED`。`female_only` 的真实消费端是 `cmds/std/wear.c` L75（穿戴限制） |
| `coagents`→`npc.coagents`（L1） | **manual** | 源值恒为 mapping 列表（30 处全含 `startroom`+`id`）；`loader.ex parse_coagents/1` 做 `Enum.map(&to_string/1)` → 对 map 崩；消费端不一致（`combat_event.ex` L435 要 id 字符串 / `guarder.ex` L73 要 map） |

- 分诊表 `tmp/key_field_map.json` 随之重算：**L1=1（假阳性）/ L2=21 / L3-framework=85 / noop=8 / manual=122**。
- **L1 已清空**：B1 之后重跑分诊只剩 `valid_startroom`，而它正是 B1 用 `FLAG_NAME` 改名写成 `"startroom"` → 假阳性。
- `plan_key_field_map.py` 加两条硬规则防复发：① `base_*` 前缀一律 `L3-framework`；② 不再把任何 key 直接映射到 `item.meta.flag`。

**新发现：`wield_msg`/`unwield_msg` 早已转好，只是被 loader 丢弃**

- 转换器 `lpc_converter.ex` L3253-3260 **已经**输出 `messages = { wield = "…" unwield = "…" }`（占位符已归一化）。
- 全库实测 **220 个 `messages` 块**（全在 `items` 块内），含 **218 `wield` + 155 `unwield`**。
- loader 无 `messages` 解析、`Item.Meta` 无该字段 → 373 条文案被静默丢弃。
- 审计把它报成「丢失」只因搜的是字面 key `wield_msg`（实际写的是 `messages.wield`）→ 审计**假阳性**第二例。
- → 列为 **B5a**：**零数据写入**即可激活。

> 同一 key 会落在不同对象类型上（`no_steal` = room×45/item×4/npc×6），
> 故 P1a 为每个 key 输出 `kinds` 源对象类型分布，target 按主导类型定。

| 批次 | key | 次数 | 目标 | 状态 | 提交 | 备注 |
|------|-----|-----:|------|:----:|------|------|
| **B1** | `sleep_room` / `no_sleep_room` / `no_steal` / `no_beg` / `valid_startroom` | 127/90/55/39/68 | `room.flags` | ✅ | `cf0af449` | 命中 **284 房间 / 56 区**；`valid_startroom` 的 flag 名是 **`startroom`** |
| ~~B2~~ | ~~`base_unit` / `base_value`~~ | ~~72/69~~ | ~~`item.meta.unit/value`~~ | ➖ | | **改判 L3-framework**（见「复核结论 2」）：`base_*` 是「单件」语义，引擎无 `amount` |
| **B3** | `female_only` | 60 | `item.meta.female_only`（**新字段**） | ⬜ | | **改判 L2**：`flag` 是武器位掩码，不能复用 |
| ~~B4~~ | ~~`coagents`~~ | ~~30~~ | ~~`npc.coagents`~~ | ➖ | | **改判 manual**：源值是 mapping 列表，`parse_coagents` 会崩；消费端形状不一致 |
| B5 | `max_force` / `force_factor` / `mana` / `max_mana` / `eff_qi` / `eff_jing` | 10/14/4/4/37/19 | `npc.vitals` 或 `npc.stats` | ⬜ | | **先查 `vitals` 结构再定**（P1a 判 `manual`） |
| ~~B1'~~ | ~~`base_weight`~~ | ~~36~~ | ~~`item.meta.weight`~~ | ➖ | | **作废**：改判 L3-framework（堆叠物品单件重量） |

**B1 验收记录（2026-10-16，最终）**

- dry-run：284 待补 → `--apply` → 二次 dry-run：`filled=0, already=284`（**幂等 ✓**）
- `git diff --numstat`：**56 文件 / +921 行 / -0 行**（只增不改 ✓）
- `validate_ucl.py`：**67 通过 / 10 失败**，与基线**完全一致**；且对 56 个改动文件**逐文件对照 HEAD**，
  `新增失败 = NONE` ✓
  > ⚠️ 全库本就有 10 个区不通过（`baituo clone_lib huashan kissa-jarvi lepakko-luola
  > lingxiao liuxi shaolin wudu xiangyang`），DoD 因此读作「**不新增失败**」而非「全绿」。
- 备份：`tmp/backup-20261016-122602/`（56 个文件，**写盘之前**复制；已抽验为改前态）
- ⚠️ **列表分隔符必须是逗号（踩过的坑）**：首版脚本照手写先例写成「多行、无逗号」，
  elias 报 `syntax error before: '"'`，56 个区语法非法 → **整批回滚重做**。
  手写先例 `city.ucl` 的 `flags` 只有 **1 项**（无需分隔符），所以看不出这个坑。
  实测：`scripts/probe_elias_expressibility.exs`。正确写法：多行带逗号，或单行 `["a", "b"]`。
  已给脚本加 **`validate_ucl` 自校验门禁**（新增失败即拒绝写盘）。
- ⚠️ 消费端现状（写数据 ≠ 生效）：
  - `sleep_room` / `no_sleep_room` → ✅ `room.ex` L238-239（attrs）
  - `valid_startroom` → ✅ `home_command.ex` L54 / `recall_command.ex` L50 找 flag `"startroom"`
  - `no_steal` → ⚠️ `room.ex` L1462 读 `context.data.no_steal`，但 `context.data` 就是 `%Room{}`，
    而 `Room` 无 `:no_steal` 字段（实测 `Map.has_key?` = false）→ 该分支会抛 `KeyError`。见风险 R6
  - `no_beg` → ❌ 无消费端（`beg_command.ex` 是「乞讨系统暂未开放」桩）→ P3

**P1 DoD**

- [x] dry-run → `--apply` → 二次 dry-run 显示「0 项」
- [x] `git diff --stat` 只有新增行
- [x] `validate_ucl.py` 不新增失败
- [x] `mix test --seed 12345` **不新增失败**（实测 **3435 tests, 34 failures**；34 个失败分布在 12 个测试文件，
  **没有一个读 `data/world`**；其中 `recall_command_test` / `home_command_test` 已用「限定路径 `git stash` 回干净树」
  对照验证为**既有失败**。属既有问题，与本批无关）
- [x] `world_reachability.py` 不降（实测 **4190/4409 = 95.0%**，与基线一致）

---

## 6. P2 · 加字段 + 回填（L2）

**先加字段（零行为变化，可独立提交）**

| 结构体 | 要加的字段 | 状态 |
|--------|-----------|:----:|
| `Item.Meta` | `messages`（**激活已存在**的 `wield`/`unwield`，B5a；`messages` 在物品块顶层） | ✅ |
| `Item.Meta` | `wear_msg remove_msg unequip_msg`（B5b；`wield`/`unwield` 已在 `messages` 内，不重复加） | ⬜ |
| `Item.Meta` | `female_only`（B3；**不能塞 `flag`** —— `flag` 是武器位掩码） | ✅ `199e2b74` |
| `Item.Meta` | `max_liquid`（B8；容器容量，96 块 / 30 区 / +96 行） | ✅ `a178e005` |
| `Item.Meta` | `liquid liquid_type`（容器类型，B8 关联字段） | ⬜ |
| `Item.Meta` | `can_make not_make power_point item_origin material_attrib material_name` | ⬜ |
| `Room` | `room_owner room_name room_position room_owner_id` | ✅ 代码 `48fa1b59`；**数据 ⏸ 阻塞（源无真实值）** |
| `NonPlayerMeta` | `chat_msg_combat chat_chance_combat` | ✅ `72b86831` |
| `Combat.applies_keys()` | 4 键（personality（B10b）：per warm armor_vs_force；R2 已决策 = 扩白名单，不让 sanitize_prop 丢弃） | ✅ `2d9de14a` |

> **复核修正 2（2026-10-16）**：`female_only` **从 `Room` 行移到 `Item.Meta` 行** ——
> 源对象是 `obj/qingpao.c` 等**物品**（item×45/npc×15），消费端 `cmds/std/wear.c` L75 也是物品穿戴。
> 原表把它列在 `Room` 下是错的。`base_unit`/`base_value` **不进本表**（已改判 L3-framework，见 §5 复核结论 2）。

**B5a 验收记录（2026-10-16）**

- 改动**只在 `lib/`，零数据写入**：`Item.Meta` 加 `:messages`（`item.ex`）；`loader.ex parse_item/4`
  加一行 `item_meta = %{item_meta | messages: Map.get(item_data, :messages)}`（P7：只加字段 + `Map.get`）。
- 容器探针 `scripts/probe_item_messages.exs`：`items total 1588 / with messages 219`，
  其中 **218 `wield` + 155 `unwield`** —— 与 `.ucl` 里实测的 220 块 / 218+155 条**一致**
  （差 1 块属未加载的排除区）。示例：`mingjiao:chanzhang` → `%{wield: "{npc}抽出一根{name}…", unwield: …}`。
- `mix compile`：仅既有 warning，无新增。
- `mix test --seed 12345`：**3435 tests, 34 failures** —— 与基线**完全一致**（34 个既有失败不新增）。
- 无消费端 → **线上行为零变化**；`Meta.Trim` 只 `Map.take([:damage, :armor])` → 新字段不进 web 载荷，**无需 `Jason.Encoder`**。

**B5b 验收记录（2026-10-16）**

- **实际是 L1，不是 L2**：B5a 已建好 `messages` 通道（`Item.Meta.messages` + loader 读取），
  所以 B5b 只需把 `wear`/`remove`/`unequip` 三个键写进同一个 map —— **零代码改动、纯数据**。
- 新脚本 `scripts/backfill_item_messages.py`（沿用 B1 的安全模式：dry-run 默认 / **写盘前备份** /
  `is_insertion_only` 断言 / `validate_ucl` 自校验门禁）。
- 值归一化**逐条对齐转换器**：`extract_strings_from_macro_wrapped` → `process_lpc_escapes` →
  `$N`→`{npc}`/`$n`→`{name}` → `sanitize_ucl_sval`。非字面量（closure `(: do_wear :)`、含变量）**跳过并计数**（1 条 closure）。
- 实测：**46 个 `items` 块 / 14 区 / +126 行 / −0 行**；`wear` 22 / `remove` 13 / `unequip` 31 = **66 条**。
- 幂等：二次 dry-run `filled=0, already=46` ✅；备份 `tmp/backup-20261016-151807/`（14 文件，**写盘之前**，抽验为改前态 ✅）。
- **校验不新增失败** ✅：14 区逐个与 `HEAD` 对比「完整 issue 集合（行号归一化）」→ `NEW=NONE`。
  （`baituo`/`huashan`/`shaolin`/`wudu` 本来就各带 1 个 Chars 问题，属既有。）
- 探针 `probe_item_messages.exs`：带 `messages` 的物品 **219 → 249**。
- ⚠️ **68% 的目标落在 `characters` 块（83 块），本批不写** —— loader 不读 `characters` 的 `messages`，
  写了是无效数据。属 **D10 待决策**（见 §14 R7）。

**B3 验收记录（2026-10-16）**

- **先做代码、再写数据**：`Item.Meta` 加 `{:female_only, false}`（默认 `false`，布尔语义）；
  `parse_item_meta/1` 加 `female_only: to_bool(Map.get(meta, :female_only))`
  —— 与 `no_sell`/`no_put`/`owner` 同路（都在 `meta` 块内、由 `parse_item_meta` 读）。
- 新脚本 `scripts/backfill_item_female_only.py`，写成**两阶段**：先把所有区的改动算完并过门禁
  （`insertion-only` 断言 + `validate_ucl` 完整 issue 集合比对、行号归一化），
  **全过**才备份、才写盘。避免「后半区失败、树已被改一半」。
- 实测：**24 个 `items` 块 / 7 区 / +24 行 / −0 行**；全库 74 处 `female_only` 取值恒为 `1`，
  与 `no_sell = 1` 的既有惯例一致（`to_bool/1` 收 `true/"true"/1/"1"`）。
- 幂等 ✅（二次 dry-run `blocks_written=0, blocks_skipped=24`）；
  备份 `tmp/backup-20261016-180527/`（7 文件，**写盘之前**，`female_only` 计数 0 vs 线上 10 ✅）。
- 校验不新增失败 ✅：7 区逐个与 `HEAD` 对比归一化 issue 集合 → `NEW=NONE`。
- 探针 `scripts/probe_item_female_only.exs`：**24 物品命中**
  （`taohua:shudai` 束发金带 / `quanzhou:flower_shoe` 绣花鞋 / `fuzhou:junfu` 军妇 … 语义吻合）；
  且 **`flag` 位掩码未被污染**（24 件的 `flag` 全是 `1`，无一进 `& TWO_HANDED` 分支）✅
  —— 这正是没把 `female_only` 塞进 `flag` 的验证点。
- 与 B5b 同因，**56 个 `characters` 块未写**（loader 不读）→ D10/R7。

> **对账方法修正（2026-10-16，B3 期间）**：B5b 的「83 / 46」用的是**错误的块归因** ——
> 把块归给前面最近的 `# Generated from` 头，但转换器**不给每个块都写头**，
> 且真实源 `# LPC: <path>` 注释在块**内部**（depth ≥ 1）。错归因把 `mangshe` 等 12 条蛇
> 全算成「`zhulou.c`(物品) 被写成 characters」，虚高 item 数。
> **正确口径**：块内首条 `# LPC:` > 最近的 `# Generated from`，需回溯块身取。
> 按此重算全库 `characters` 块 = **npc 1108 / item 619 / 源缺失 623 / unknown 235**。
> 已固化为 `scripts/audit_block_attribution.py`。

> **复核修正（2026-10-16）**：`sleep_room` / `no_sleep_room` / `no_steal` **不在此表** ——
> 消费端**已存在**（`room.ex` L223/L238 读 `data.flags` → `attrs["sleep_room"]`；`sleep_command.ex` L70）。
> 缺的是**数据**：全仓 `.ucl` 里 `"flags"` 出现 **0** 次，所以这两个 flag 恒为 `false`。
> → 它们归 **B7（L1 回填，写进已存在的 `flags` 通道）**，不需要动结构体。
> `female_only` / `no_beg` / `no_map` 在 `lib/` 里**无任何消费者**，才真正需要「加字段 + 接线」。

**再回填数据**

| 批次 | key | 次数 | 归属 | 状态 | 提交 |
|------|-----|-----:|------|:----:|------|
| **B5a** | （无 key）激活**已存在**的 `messages = { wield, unwield }` | 220 块 / 218+155 条 | 装备文案（**零数据写入，最高性价比，先做**） | ✅ | `0676bd08` |
| **B5b** | `wear_msg`/`remove_msg`/`unequip_msg` | 89/63/37 | 装备文案 → `messages = { wear, remove, unequip }`（`wield`/`unwield` 已由 B5a 覆盖） | ✅ | `e8c88c32` |
| **B3** | `female_only` | 60 | 物品穿戴限制（需 `Item.Meta.female_only` 新字段） | ✅ | `199e2b74` | `Item.Meta` 加 `{:female_only, false}` + `parse_item_meta` 读 `meta.female_only`；回填 **24 个 `items` 块 / 7 区 / +24 行**；全库 74 处取值恒为 `1` |
| **B6** | `chat_msg_combat` / `chat_chance_combat` | 132 / 129 | NPC 战斗喊话 | ✅ | `72b86831` |
| ~~B7~~ | ~~`sleep_room`/`no_sleep_room`/`no_steal`（→ `flags`）~~ | ~~127/90/55~~ | **已由 B1 完成**（`cf0af449`） | ✅ | `cf0af449` |
| **B7** | `room_owner`/`room_name`/`room_position`/`room_owner_id` | 29/29/29/24 | 房间归属 | ⏸ 数据阻塞 | 代码 `48fa1b59`；源 .c 全为 `//**` 注释模板占位符，无激活 set()，无真实值可回填 |
| **B8** | `max_liquid` | 74（实测 96 块） | 容器容量 | ✅ | `a178e005` | `Item.Meta` 加 `{:max_liquid, nil}` + `parse_item_meta` 读 `meta.max_liquid`；回填 **96 个 `items` 块 / 30 区 / +96 行**；全库 82 处源文件取值 |
| **B9** | `can_make`/`not_make`/`power_point`/`item_origin` | 16/8/20/16 | 打造系统 | ✅ | `84dbaef2` | `Item.Meta` 加 `{:can_make, nil}`/`{:not_make, nil}`/`{:power_point, nil}`/`{:item_origin, nil}` + `parse_item_meta` 读取；新增 `scripts/backfill_item_craft_keys.py` + `scripts/probe_item_craft_keys.exs`；回填 **14 个 `items` 块 / 3 区 / +49 行**；源文件 can_make=35/不_make=10/power_point=51/item_origin=35；探针 OK（can_make 14/不_make 7/power_point 14/item_origin 14，类型全部正确） |
| **B10** | `armor_prop/personality` / `weapon_prop/personality` / `per` / `warm` / `armor_vs_force` + 白名单内子键（B10a 新发现） | 96 源文件（non-wl）+ 532 源文件（wl） | prop 子键斜杠式 **全库 663 处从未被转换**（转换器只认整体式）→ 拆两批：**B10a** 白名单内 armor/dodge/defense/attack/unarmed_damage（数据即生效）、**B10b** 扩 `applies_keys` + personality 回填 | ✅ | `bcd168c0` + `2d9de14a` | B10a：**22 区 / 126 块 / +389 行**（137 子键；260 characters 块跳过）；B10b：`@applies_keys` +4 键 + **8 区 / 28 块 / +34 行**（personality；per/warm/armor_vs_force 的 items 目标 0，全在 characters 块 = D10 受害）。技能键 finger/hand/strike/cuff/claw/unarmed（20 源文件）**不写**（Fighter.skills 通道 v0 不支持，写了也被 sanitize_prop 丢） |
| ~~B11~~ | ~~`base_unit`/`base_value`~~ | ~~72/69~~ | **已改判 L3-framework**，退出本表 | ➖ | |

> `default_long`(28) / `for_family`(35) / `jiaji`(21) / `hellzhen`(18) 等仍判 `manual`，不在上表。

- [ ] ⬜ 若新字段进 `Meta.Trim`，已补 `Jason.Encoder`（否则 websocket 进程崩溃）
- [ ] ⬜ `mix test` 绿且**线上行为零变化**（无消费者）

---

## 7. P3 · 消费端接线（L3，逐字段）

| 字段 | 消费端 | 风险 | 灰度 | 状态 | 提交 |
|------|--------|:----:|:----:|:----:|------|
| 装备文案 5 件套 | `wield/wear/remove_command.ex` | 低 | 不需要 | ✅ | `c5c3c325` | **新增 vision 广播原语**（`VisionEvent`/`VisionView` + 路由 + web handler，LPC `message_vision` 语义：`{npc}` 对自己→「你」、对他人→行动者名）；wield/unwield/wear/remove 接线（`unwield`/`remove` 回退 `unequip` 键）；**数据零写入**，激活 249 物品 439 条文案；swap 路径保持默认文案 |
| `female_only` | `wield`/`wear` 命令前置判定 | 中 | **需要**（新拦截） | ✅ | `a52ece2b` | 在 `with_item` 加性别门控：`item.meta.female_only==true` 且 `meta.env["gender"]=="男性"` → 拒绝「只有女性才能穿戴。」；性别未知 fail-open（宁漏不误拦）；激活 B3 回填的 24 件 female_only 物品 |
| `no_beg` | 乞讨命令前置判定 | 中 | **需要**（新拦截） | ⬜ | | `beg_command.ex` 是「乞讨系统暂未开放」桩，无真实消费端 → 等 P5 乞讨系统 |
| `liquid` / `max_liquid` | 倒/喝命令 | 中 | **需要**（新拦截） | ⬜ | | `max_liquid` 数据已回填（B8），但倒/喝命令未接线 → 等 P5 容器/酒水系统 |
| `can_make` / `not_make` / `power_point` / `item_origin` | 打造命令 | 中 | **需要**（新拦截） | ⬜ | | 数据已回填（B9），但打造系统未建 → 等 P5 打造子系统 |
| `chat_msg_combat` / `chat_chance_combat` | NPC 战斗闲聊 | 低 | **需要**（新消费端） | ⬜ | | 数据已回填（B6），但 NPC 战斗闲聊未接线 → 等 P5 NPC AI 聊天子系统 |
| `no_steal` | **修 bug**：`room.ex` L1458-1462 改用 `World.room_flags(room_id)`（现写法会抛 `KeyError`，见 R6） | 低 | 不需要 | ✅ | `524efcff` | **实际范围比计划大**：不止 no_steal——`skybook`/`no_fight`/`no_search` 四个直读全崩（steal 三个 cond 全踩 + search 每搜必崩）；新增 `Room.has_flag?/2` 统一 flags 成员判定；顺手修 search 的 `put_in` Access 二次 bug。真实数据 45 个 no_steal 房恢复拒绝 |
| `sleep_room` / `no_sleep_room` | `sleep_command.ex` | 低 | 不需要 | ⬜ | |
| `liquid` / `max_liquid` | 倒 / 喝命令 | 中 | 需要 | ⬜ | |
| `can_make` / `not_make` / `power_point` | 打造命令 | 中 | 需要 | ⬜ | |
| `chat_msg_combat` | NPC 战斗心跳 | 低 | 不需要 | ⬜ | |

- [ ] ⬜ 每个字段一条集成测试
- [ ] ⬜ 行为变更走**灰度开关 + 默认关**

> **复核修正（2026-10-16）**：`no_steal` 的既有消费端 `room.ex` L1462 `context.data.no_steal` **是坏的** ——
> `context.data` 就是 `%Room{}` 结构体（`vendor/kalevala/.../room.ex` L79-85），而 `Room` 没有 `:no_steal` 字段
> （容器实测 `Map.has_key?` = false）→ 该 cond 抛 `KeyError`。数据已按 L1 回填（B1），
> **接线工作因此变成「修 bug」**：改用 `Kantele.World.room_flags(room_id)`。见 R6。
> `no_beg` 确认无消费端（`beg_command.ex` 是桩）→ 需新写拦截。

---

## 8. P4 · 条件分支补全（数据层，回源）

| 归属函数 | 行数 | 处置 | 状态 |
|----------|-----:|------|:----:|
| `create` | 2619 | 走 P1/P2 的 key 通道，不单独做 | ⬜ |
| `valid_leave` | 410（bare） | 回源取 `notify_fail` 文案 → 补进 `exit_vetoes` | ✅ |
| `init` / `greeting` | 367 / 184 | 回源补 action（`add_action`、台词池） | ⬜ |

**`valid_leave` 回源结果（2026-10-16 完成，D22）**

LPC 侧 384 个文件有 `valid_leave`；解析器可静态提取 150 条 `notify_fail`
判条件，过完数据层门槛后 61 条候选：**49 条转换器早已写过等价条目**
（同 cond+msg+方向，去重命中），12 条新；再过容器真门（parse /
enforceable / supported / direction_scoped / 方向存在 / 别名有定义 /
不撞车）→ **11 条生效、1 条被既有等价条目遮蔽**（city:qiyuan1，
既有条目两个操作数顺序不同、语义相同）。

| 区 | 新回填条数 | 房间 |
|----|-----:|------|
| tulong | 3 | daobian / was_damen / was_dayuan |
| shaolin | 3 | bagua3 / guangchang5 / wuchang3 |
| jingzhou | 2 | huayuan / shikuang1 |
| chengdu / gumu / hangzhou | 各 1 | wuguan / shandong / tiejiangpu |

合计 **+68 行 / 6 区**。其余落选原因（Trap 通道，非缺陷）：elias 词法
不接受多参调用 `present('x', environment(me))`（48）、白名单外函数
check_dirs/check_out/member_array/sscanf/random（19）、上游局部裸变量
如 `skill`/`myfam`（17）、`b/` 镜像树无对应房间（5）；另有 66 个文件
的 notify_fail 是动态拼接文案（`RANK_D->query_respect(me)` 等），无法静态落库。

**踩过的坑（都留了注释）**：① `&&` 后直接粘 `ob = present(...)` ——
补括号成 `(ob = present('x',this_object()))`；② 裸 `present('x')` 单参
会在求值器 `eval_args` 解构时 MatchError —— 按 LPC 语义补
`,this_object()`（注意逗号后不能有空格，elias 不接受 `, x`）；
③ elias 不接受 `}` 与 `,` 之间的空行 —— 逗号必须紧跟在上一条目 `}` 后；
④ 转换器会把 `dir=='a'||dir=='b'` 的条件截成单个方向（chengdu/wuguan
只留 up）—— 去重必须方向感知，同 cond+msg 不同方向的候选是真缺口。

**`valid_leave` 逐区清单（410 条 / 60 区，去掉 test 靶场）**

| 区 | 条数 | 状态 | 区 | 条数 | 状态 |
|----|-----:|:----:|----|-----:|:----:|
| shaolin | 71 | ✅ 3 条已回填，余 Trap | chengdu | 7 | ✅ 1 条已回填，余 Trap |
| city | 23 | ✅ 1 条有效（1 条被遮蔽） | huanghe | 7 | Trap（kedian 全家动态文案） |
| xiyu | 21 | Trap（wall* 全靠 sscanf） | wuguan | 7 | Trap |
| beijing | 19 | Trap | xueshan | 7 | Trap |
| mingjiao | 17 | Trap | lingzhou | 6 | Trap |
| death | 15 | Trap | 其余 **42 区** | 各 1–6（共 140） | Trap / 已存在 |
| huashan | 15 | Trap | | | |
| tulong | 11 | ✅ 3 条已回填，余 Trap | | | |
| jingzhou | 10 | ✅ 2 条已回填，余 Trap | | | |
| heimuya / wudang | 9 / 9 | Trap | | | |
| guanwai / wudu | 8 / 8 | Trap | | | |

- [x] ✅ `exit_vetoes` 生效条数从 **144** 上升到 **155**（M7；+11 全部通过运行时真门。文档旧值 133 是更早数据状态的快照，执行前实测为 144）
- [x] ✅ `world_reachability.py` 不降（4190/4409，前后逐字节一致）

---

## 9. P5 · 运行时子系统（L3 / L3-前置）

> **开工前每个子系统先过计划 §1 的 Q1**（`probe_elias_expressibility.exs`）。
> `Q1` 列标 ⚠️ 的是**框架优先** —— 必须先定 schema 再转数据。

| # | 子系统 | 规模 | Q1 | 状态 | 提交 | 备注 |
|--:|--------|-----:|:--:|:----:|------|------|
| 1 | **逐对象 `add_action` 通道** | 646 行 / 215 名 / 63 区 | ✅ | ⬜ | | **收益最大**；UCL `actions = [ {verb, handler} ]` |
| 2 | 战斗回调 | 259 行 / 12 名 / 37 区 | ✅ | ⬜ | | **方案 A：新脚本重抽 `engage`**，不改转换器 |
| 3 | 动态出口 | 含在 `do_*` 内 | ⚠️ | ⬜ | | 需先加运行时增删出口 API |
| 4 | look / inquiry | 185 行 / 86 名 | ✅ | ⬜ | | 与铁匠 inquiry 6 条合并做 |
| 5 | effect / invocation | 108 行 / 2 名 | ⚠️ | ⬜ | | 需 buff/effect 子系统 |
| 6 | 门 / 容器 | 40 行 | ✅ | ⬜ | | 需要有状态的门 |
| 7 | 学徒 / 门派 | 52 行 / 2 名 | ✅ | ⬜ | | 名数少、行数多 |
| 8 | 通信中继 / 载具 | 含在 459 内 | ✅ | ⬜ | | `relay_emote`/`on_board` |
| 9 | 一次性场景 | 459 行 / 246 名 | ✅ | ⬜ | | **逐房模块按 room id 绑定** |

> **规模口径**：本表一律按**函数名**计（`kind=function`、去掉 `test` 区），**不是**条件分支行数 ——
> 与 `data-world-comments-txt-audit.zh-CN.md` §2.4 同口径，可由 `tmp/unhandled_manifest.json` 直接复算。
> 别把本表的 646 与 §8 P4 的 410 混为一谈：前者是「有多少个 `do_*` 函数定义」，后者是「有多少条裸条件分支」。

**P5.1 逐区清单（646 条 / 63 区，`do_*` 去掉 `do_effect`）**

| 区 | 条数 | 状态 | 区 | 条数 | 状态 |
|----|-----:|:----:|----|-----:|:----:|
| city | 65 | ⬜ | wudu | 20 | ⬜ |
| huashan | 58 | ⬜ | shenfeng | 19 | ⬜ |
| hengyang | 34 | ⬜ | mingjiao | 18 | ⬜ |
| death | 31 | ⬜ | jueqing | 16 | ⬜ |
| shaolin | 22 | ⬜ | jingzhou / lingxiao / gumu | 15 / 15 / 14 | ⬜ |
| tulong / xiakedao | 22 each | ⬜ | 其余 **48 区** | 各 1–12（共 255） | ⬜ |
| beijing | 20 | ⬜ | | | |

**Tier 0 免除**（登记进 §11 抑制清单，不写代码）：

按**函数名**计（与上表同口径，去掉 `test` 区）：
`setup`(37) `reset`(34) `long`(19) `is_container`(16) `query_autoload`(13) `is_chat_room`(10) —— 共 **129** 个函数定义（对应审计表 §2.4「生命周期/无操作」桶）。

- `create` / `init` **不在此列**：它们不以 `UNHANDLED FUNCTION` 形式出现，只作为条件分支的归属函数（见 §8 P4）。
- 以及 P0 解析出的**全局命令**（如 `do_ride` → `cmds/std/ride.c`，Elixir 已有 `ride_command.ex`）。
- ⚠️ 例外：`long` 若依赖 `query()` 动态生成 → 归 P5 第 4 项。

---

## 10. P6 · 防回归

| 项 | 状态 | 说明 |
|----|:----:|------|
| `scripts/assert_unhandled_baseline.py` | ⬜ | 读 `tmp/*.json`，断言 §2 每个数字 ≤ 基线 |
| `scripts/unhandled_suppressions.json` | ⬜ | 抑制清单（§11） |
| 可达性不降 | 🟨 | 每次批次后跑 |
| `mix test --seed 12345` 绿 | 🟨 | 每次批次后跑 |
| 幂等自检（连跑两次 0 改动） | ⬜ | 所有回填脚本 |

---

## 11. 抑制清单（append-only）

> 原则：**不允许留成待办黑洞**。每条必须写理由。

| id / key | tier | 理由 | 登记日期 |
|----------|:----:|------|----------|
| `no_clean_up`（1805） | noop | 房间重置提示，引擎生命周期已覆盖 | 2026-10-16 |
| ~~`valid_startroom`（68）~~ | ~~noop~~ | ~~出生点校验，非运行时数据~~ → **已推翻（D11）**：消费者是 `flags` 里的 `"startroom"`，已并入 B1 落地 | 2026-10-16 |
| `no_map` / `no_shown` / `no_user` / `no_magic` | noop | 显示开关 | 2026-10-16 |
| `max_room` | noop | 容量提示，无消费端 | 2026-10-16 |
| `death:heisenlin` / `heimuya:insert` / `huashan:tsr_room_dugu-jiujian` | manual | generic 文件，需人工判断是否接入世界 | 2026-10-16 |
| `coagents`（30） | manual | 字段在但**形状不符**：源值是 mapping 列表（`startroom`+`id`），`parse_coagents/1` 做 `to_string/1` 会崩；两处消费端形状不一致 → 需先定 schema（D16） | 2026-10-16 |
| `base_unit`（72）/ `base_value`（69） | L3-framework | 「单件」语义（堆叠物品），与 `unit`/`value`（整叠）不同；引擎无 `amount` → 框架优先（D14） | 2026-10-16 |

---

## 12. 决策记录

| # | 决策点 | 结论 | 日期 | 依据 |
|---|--------|------|------|------|
| D1 | 战斗回调：改转换器还是新脚本重抽？ | **方案 A：新脚本重抽**（守 P1/P2） | 2026-10-16 | 框架文档 §5 决策点 1 |
| D2 | 一次性场景：子系统还是逐房模块？ | **逐房 Elixir 模块按 room id 绑定**；第 3 个同形状场景才提炼子系统 | 2026-10-16 | 框架文档 §5 决策点 2 |
| D3 | 是否信归档文档的阻塞理由？ | **不信，必须跑探针**（CJK 方向一条已证伪） | 2026-10-16 | 框架文档 §3 |
| D4 | `sleep_room`/`no_sleep_room`/`no_steal` 加字段还是回填？ | **回填**：消费端已存在（`room.ex` 读 `flags`），只是 `.ucl` 里 `flags` 全缺 | 2026-10-16 | 本轮复核：`grep '"flags"' data/world/*.ucl` = **0** |
| D5 | `food_supply` 是否算丢失？ | **不算**：是 `food` 的别名，`item_meta_backfill.py` 已处理；B3 只需**对账** | 2026-10-16 | `triage_lost_keys.py` ALIAS 表 |
| D6 | `valid_startroom` 是否要做？ | ~~**不做（noop）**：`lib/` 无消费者~~ → **已推翻（见 D11）**：消费者存在，是 `flags` 里的 `"startroom"` | 2026-10-16 | ~~§11 抑制清单~~ |
| D7 | `base_weight` 是否等于 `weight`？ | **否** → 改判 L3-framework。`set_weight()` 写私有 `weight` 变量；`base_weight` 是独立属性，仅可堆叠物品读（`hand.c` L37） | 2026-10-16 | P1a 复核；`feature/move.c` L40 |
| D8 | `female_only` 是房间还是物品属性？ | **物品** → `item.meta.flag`（源为 `obj/qingpao.c` 等） | 2026-10-16 | P1a `kinds` 分布 |
| D9 | `validate_ucl.py` 的 DoD 怎么算？ | **不新增失败**（全库本就有 10 个区不通过，属既有问题） | 2026-10-16 | 实测基线 67/10 |
| D10 | `npc/` 下的物品为何没有 meta？ | 转换器把它们输出成 `characters` 块，而 `item_meta_backfill.py` 只处理 `items` 块 → 从未回填。B2 起须一并处理 | 2026-10-16 | `d/beijing/npc/dan/danA_1.c` → `characters "danA_1"` |
| D11 | `valid_startroom` 到底是不是 noop？ | **不是**。消费者是 `flags` 里的 **`"startroom"`**（`home_command.ex` L54 / `recall_command.ex` L50 都 `Enum.find(..., "startroom" in room.flags)`）。**推翻 D6**，改判 L1，已并入 B1 | 2026-10-16 | `grep -rn 'startroom' lib/` |
| D12 | 房间 flag 类要不要给 `Room` 加字段？ | **不加**。`Room.flags` 字段已存在（`room.ex` L34）、loader 已解析（`parse_flags/1`）、消费端已存在（`World.room_flags/1`）。**框架文档 §4 B 类该行已更正为 A 类** | 2026-10-16 | `Room.__struct__()` 含 `:flags`（容器实测） |
| D13 | UCL 列表元素之间用什么分隔？ | **必须逗号**。elias 对「两个换行分隔、无逗号」的元素报 `syntax error before: '"'`。1 项时无需分隔符（这是手写先例看不出坑的原因） | 2026-10-16 | `scripts/probe_elias_expressibility.exs` |
| D14 | `base_unit`/`base_value` 是否等于 `unit`/`value`？ | **否** → 改判 L3-framework。`base_*` 是「单件」语义（`combined.c`：`set("value", amount*base_value)`、`short()` 用 `base_unit`），`unit`/`value` 是「整叠」；引擎无 `amount` 字段 | 2026-10-16 | `inherit/item/combined.c` L15-45；`clone/money/coin.c`；`d/beijing/npc/obj/jinbiao.c` |
| D15 | `female_only` 能塞 `item.meta.flag` 吗？ | **不能**（**推翻 D8 的目标**）→ 改判 L2，需新字段 `item.meta.female_only`。`flag` 是武器类型位掩码（`wield_command.ex` L101 默认 1=ONE_HANDED；`loader.ex` L1274 `\|\| 1`） | 2026-10-16 | `wield_command.ex` L101；`cmds/std/wear.c` L75 |
| D16 | `coagents` 是纯数据 L1 吗？ | **否** → `manual`。源值是 mapping 列表（`startroom`+`id`），`parse_coagents/1` 做 `to_string/1` 会崩；两处消费端形状不一致（`combat_event.ex` 要 id 串 / `guarder.ex` 要 map） | 2026-10-16 | `loader.ex` L1055-1062；`combat_event.ex` L435；`guarder.ex` L73 |
| D17 | 「丢失 key 审计」的结果可直接信吗？ | **不可全信** —— 存在**假阳性**：key 可能已被转换器**改名/改形**输出。已知两例：`wield_msg`→`messages.wield`（220 块）、`valid_startroom`→flag `"startroom"` | 2026-10-16 | `lpc_converter.ex` L3253；`tmp/lost_key_triage.json` |
| D18 | `wield_msg`/`unwield_msg` 需要回填数据吗？ | **不需要** —— 转换器**早已输出** `messages = { wield, unwield }`，只缺 loader 读取。列为 **B5a**：零数据写入激活 373 条文案 | 2026-10-16 | 全库实测 220 块 / 218+155 条 |
| D19 | 引号内的 `[` / `]` 怎么处理？ | **换成 `(` / `)`**（elias 实测拒绝 `[`：`syntax error before: '['`；`(` 可解析，全库既有的 `(pen)` 即此惯例）。同时确认 `,`+空白 与 `[0-9],` 也不可入串 | 2026-10-16 | `scripts/probe_ucl_brackets.exs` |
| D20 | B5b 要不要写 `characters` 块？ | **不写**。`characters` 块里 loader 不读 `messages` → 写了是无效数据。只写 `items` 块（46/129），其余 83 块登记为 **D10 待决策**（R7） | 2026-10-16 | 全量「源文件→UCL 块」对账 |
| D21 | B10 的 prop 子键：扩 `applies_keys` 还是单列字段？范围是否含白名单内子键？ | **扩白名单**（R2 决策）：单列字段过不了 `sanitize_prop`，白名单是唯一装载通道。范围**含白名单内子键** —— 勘查（`scripts/survey_b10_props.py`）发现**旧审计的假设错误**：全库 663 处斜杠式 `set("armor_prop/<sub>")` 从未被转换（转换器只认整体式，`lpc_converter.ex` L3327-3328），白名单内 armor/dodge 等同样缺失。拆 B10a（白名单内数据，经既有链路生效）→ B10b（+4 键白名单 + personality 数据）。技能键（finger/hand/strike/cuff/claw/unarmed）判 manual：Fighter.skills 通道引擎 v0 未建模，写了会被丢弃 | 2026-10-16 | `tmp/b10_survey.json`；`feature/equip.c` L38-47；`Combat.effective_applies` 泛型 `Map.get` 读取 |
| D22 | P4 只回填「通过容器真门」的候选，还是全部 410 条 bare？ | **只回填真门通过的 11 条**（`probe_valid_leave_candidates.exs` 八项检查）。三问分诊：elias 词法不支持多参调用/裸变量/取反不了的复杂守卫/动态拼接文案的，归 Trap 通道（91 条跳过有据）。**去重方向感知**：转换器会把 `dir=='a'||dir=='b'` 截成单方向，同 cond+msg 不同方向 = 真缺口（chengdu/wuguan 补 down）。既有「无条件裸条目」（转换器丢守卫产物，condition=nil 运行时本就跳过）**不删不改**，新条目才是生效的那条 | 2026-10-16 | `tmp/p4_candidates.json` 61 候选；`tmp/p4_verdict.json` 11 effective / 1 遮蔽 |
| D23 | R6 修复范围：只修 no_steal，还是把同类直读一起修？ | **一起修**。四个直读（steal 的 skybook/no_fight/no_steal + search 的 no_search）同为「Room 无此字段」KeyError，单独修 no_steal 会留下 search 每搜必崩的半死状态；且新增 `Room.has_flag?/2` 后同类问题有唯一正路。数据侧：no_steal 45 房 / no_fight 17 房即刻生效，skybook/no_search 数据为 0 → 判定保留但休眠（与 LPC 语义对齐，等数据） | 2026-10-17 | `probe_no_steal_flag.exs` 实跑；`room_event_flag_test.exs` 7 测试 |
| D24 | P5-1 `add_action` 怎么启动？范围怎么切？ | **先勘查、按对象类型切、先 pilot 后用处最大的**。勘查（`scripts/survey_add_action.py`）：1568 调用/793 文件；room 60/22、npc 578/237、item 143/118、other 787/416。关键发现：**NPC 的 add_actions 已被冻结转换器写进 UCL（52 文件，`add_actions = ["list","buy"]`），loader `parse_enter_init` 也已读入 `NonPlayerMeta.init.add_actions`，但（1）转换器 `lpc_converter.ex` L1286-1289 只存 **handler、丢了玩家输入的 verb**（UCL 里是 handler 名如 "list"，真正的 verb "do_list" 已丢失）→ schema 需 verb→handler 对账；（2）NPC add_actions 加载后**无人分发**；（3）`room.ex` 有 `resolve_verb/4` 骨架但期望 `%{verb=>{module,fun,args}}` map，与 UCL 扁平 list 格式不匹配；（4）item 完全缺 UCL 入口。结论：P5-1 = 定义 verb→handler schema + 对象级分发路由（房间/物品补 UCL 入口）+ 复用/桥接既有 shop 事件。先 pilot 高体量子集（shop list/buy 292 调用，已有 `npc_shop_event.ex` 承载），再扩 | 2026-10-17 | `tmp/survey_add_action.json`；`lpc_converter.ex` L1286-1289；`room.ex` L311-340 |

---

## 13. 变更日志（append-only）

| 日期 | 批次 | 提交 | 改动 | 数字变化 |
|------|------|------|------|----------|
| 2026-10-16 | P0 | （未提交） | 新增 5 个只读脚本 + 3 份文档；建立基线 M1–M9 | 建立基线，无数据改动 |
| 2026-10-16 | 复核 | （未提交） | 修正 9 处失效 `§` 引用；P5.1 `gumu` 15→14；Tier 0 计数改为「去 test 区」口径（129）；`valid_startroom` 移出 B11；§6 Room 字段表移出 `sleep_room`/`no_sleep_room`/`no_steal`（改判 L1）；§7 移出 `no_steal`（已有消费端） | 无数据改动，仅文档口径 |
| 2026-10-16 | P1a | `cf0af449` | 新增 `scripts/plan_key_field_map.py`（242 key 三问分诊）；`tmp/key_field_map.json`；改判 `base_weight`→L3-framework、`female_only`→`item.meta.flag`、`parts`→manual | L1=9 / L2=20 / L3-fw=83 / noop=8 / manual=122 |
| 2026-10-16 | P1b + **B1**（首版，**已回滚**） | 未提交 | 新增 `scripts/backfill_l1_fields.py`；回填 `sleep_room`/`no_sleep_room`/`no_steal`/`no_beg` → `room.flags` | 55 区 / +242 行 / -0 行；M6 202→200、M10 0→242 |
| 2026-10-16 | **回滚 + B1 重做** | `cf0af449` | 首版脚本**备份在写盘之后**（等于没备份）+ **列表缺逗号**导致 56 区语法非法 → `git checkout -- data/world` 回滚、删除无效备份；修脚本（备份前置 + 逗号 + `validate_ucl` 自校验门禁）；补入 `valid_startroom` → flag `"startroom"` 重做 | **56 区 / +921 行 / -0 行**；M10 242→**284** |
| 2026-10-16 | 文档更正 | `cf0af449` | 框架文档 §4 B 类：房间 flag 行更正为 **A 类**（`flags` 字段已存在）；计划 P2 批次表按 20 个 L2 key 收敛；计划 B1 行并入 `valid_startroom` | 无数据改动 |
| 2026-10-16 | **B3（female_only）** | `199e2b74` | `Item.Meta` 加 `{:female_only, false}`；`parse_item_meta` 读 `meta.female_only`；新脚本 `scripts/backfill_item_female_only.py`（**两阶段：算完+门禁全过才备份写入**）；新探针 `probe_item_female_only.exs`；**新增 `scripts/audit_block_attribution.py` 修正块归因口径** | **7 区 / 24 块 / +24 行 / −0 行**；M14 0→**24**；幂等 ✓；校验 NEW=NONE；测试失败集合与基线**完全一致**（NEW=NONE） |
| 2026-10-16 | **P1a 复核 2（B2/B3/B4 改判）** | `0676bd08` | 回源实测推翻 3 条原判：`base_unit`/`base_value`→L3-framework、`female_only`→L2（新字段）、`coagents`→manual；`plan_key_field_map.py` 加 `base_*` 硬规则 + 禁映射 `flag`；重算 `tmp/key_field_map.json`；新增发现 `messages` 早已转好（B5a）；计划 + 进度文档同步更正 | 分诊表 L1 9→**1**（假阳性）/ L2 20→**21** / L3-fw 83→**85** / manual 122→**123**；**L1 清空** |
| 2026-10-16 | **B5a（激活 messages）** | `0676bd08` | `Item.Meta` 加 `:messages`；`loader.ex parse_item` 读取物品块顶层 `messages`；新增只读探针 `scripts/probe_item_messages.exs` | 代码改动，**零数据写入**；M12 0→**219**（218 wield / 155 unwield）；测试 3435/34 不新增 |
| 2026-10-16 | **B5b（wear/remove/unequip）** | `e8c88c32` | 新增 `scripts/backfill_item_messages.py`；回填 46 个 `items` 块的 `messages.wear/remove/unequip`；新增 `scripts/probe_ucl_brackets.exs`（elias 引号内 `[`/`,` 边界）；门禁升级为「完整 issue 集合 + 行号归一化」比对 | **14 区 / +126 行 / −0 行**；M12 219→**249**、M13 0→**66**；幂等 ✓；校验 NEW=NONE |
| 2026-10-16 | **B6（chat_msg_combat/chat_chance_combat）** | `72b86831` | `lib/kantele/character.ex` NonPlayerMeta 加两字段；`lib/kantele/world/loader.ex` `parse_character/4` 读取 + 新增 `parse_chat_msg_combat/1`；新增 `scripts/backfill_npc_combat_chat.py`（dry-run 默认、两阶段、insertion-only、`validate_ucl` 门禁、幂等、双引号列表）+ `scripts/probe_npc_combat_chat.exs` | **29 区 / 122 块 / +239 行 / −0 行**；M15 0→**254/256**；per-zone 与 HEAD 对比 NEW=NONE；幂等 ✓；容器内探针 OK（loader 载入 NonPlayerMeta 字段，样本 老大娘 chance=50） |
| 2026-10-16 | **B7（room_owner/room_name/room_position/room_owner_id，代码侧）** | `48fa1b59` | `lib/kantele/world/room.ex` Room 结构体加 4 字段（默认 nil）；`lib/kantele/world/loader.ex` `parse_room/4` 加 Map.get 读取；新增 `scripts/probe_room_owner.exs` | **3 文件 / +60 行 / −2 行**；4409 个房间字段均为 nil（无源数据）；**数据回填阻塞：源 .c 4 个 key 全在 `//**` 注释块为模板占位符，无激活 set()，也无 sidecar/其他真实值来源** |
| 2026-10-16 | **B8（max_liquid 容器容量）** | `a178e005` | `lib/kantele/world/item.ex` Item.Meta 加 `{:max_liquid, nil}`；`lib/kantele/world/loader.ex` `parse_item_meta/1` 读 `meta.max_liquid`；新增 `scripts/backfill_item_max_liquid.py`（dry-run 默认、两阶段、insertion-only、`validate_ucl` 门禁、幂等、8 空缩进写入 meta 块内）+ `scripts/probe_item_max_liquid.exs` | **30 区 / 96 块 / +96 行 / −0 行**；源 .c 82 处取值；per-zone 与 HEAD 对比 NEW=NONE；幂等 ✓；容器内探针 OK（96 物品命中，样本 葫芦 max_liquid=10） |
| 2026-10-16 | **B9（can_make/not_make/power_point/item_origin 打造系统）** | `84dbaef2` | `lib/kantele/world/item.ex` Item.Meta 加 4 字段（默认 nil）；`lib/kantele/world/loader.ex` `parse_item_meta/1` 加 4 Map.get 读取；新增 `scripts/backfill_item_craft_keys.py`（dry-run 默认、两阶段、insertion-only、`validate_ucl` 门禁、幂等、8 空缩进写入 meta 块内）+ `scripts/probe_item_craft_keys.exs` | **3 区 / 14 块 / +49 行 / −0 行**；源文件 can_make=35/不_make=10/power_point=51/item_origin=35；per-zone 与 HEAD 对比 NEW=NONE；幂等 ✓；容器内探针 OK（can_make 14/不_make 7/power_point 14/item_origin 14，样本 补天石 can_make=["all"] power_point=100 item_origin=1） |
| 2026-10-16 | **B10a（prop 斜杠子键·白名单内，计划外新发现）** | `bcd168c0` | 勘查脚本 `scripts/survey_b10_props.py` 发现**转换器只认整体式 `set("armor_prop", ([...]))`（`lpc_converter.ex` L3327-3328），而全库 663 处均为斜杠路径式 `set("armor_prop/armor", 1)` → prop 子键从未被转换**（旧审计假设白名单子键已转，不成立）。新增 `scripts/backfill_item_props.py`（`--subsets` 分子键类、缩进自适应、已有 map 并吞模式）+ `scripts/probe_item_props.exs`；白名单内 armor/dodge/defense/attack/unarmed_damage 137 子键写入 126 个 `items` 块 | **22 区 / +389 行 / −0 行**；per-zone 与 HEAD 对比 NEW=NONE；幂等 ✓；探针 OK（130 物品带 prop，白名单外键 []，round-trip 干净）；`mix test` 3435/34 不新增。**行为说明**：这批经既有消费链路生效（`Equip.wear_state` 语义同 LPC `feature/equip.c` L38-47 穿戴累加），等价于恢复原始 LPC 战斗数值 |
| 2026-10-16 | **B10b（扩 applies_keys + personality 回填，R2 决策落地）** | `2d9de14a` | `lib/kantele/character/combat.ex` `@applies_keys` 7→11 键（+personality/per/warm/armor_vs_force，P7 只加不改；公式 `Map.get(applies, key, 0)` 惰性读取 → 无战斗行为变化；Combat 不在 `Meta.Trim` 保留清单 → 无 web 载荷影响）；`backfill_item_props.py --subsets non_whitelisted` 写入 personality（25 块并入 B10a 既有 map、3 块新建 map） | **8 区 / 28 块 / +34 行 / −0 行**；per-zone 与 HEAD（B10a 后）对比 new_issues=0；幂等 ✓；探针 OK（133 物品带 prop、personality 28）；`mix test` 3435/**33**（33 = 原 34 基线去掉 recompile 后转好的 `reload_command_test`，失败清单与文档 12 文件基线一致、无新增）。per/warm/armor_vs_force 的 items 块目标 0（源全在 characters 块，D10/R7 受害） |
| 2026-10-16 | **P4-valid_leave（exit_vetoes 回源回填，计划内）** | `c219937d` | 三脚本链：`scripts/survey_valid_leave.py`（LPC `valid_leave` 解析器：嵌套 if 守卫合取、放行守卫取反累积、颜色宏包裹的 notify_fail、裸 `present()` 补 `this_object()` 参数、`&&ob=` 补括号）→ `scripts/probe_valid_leave_candidates.exs`（容器内八项真门）→ `scripts/backfill_exit_vetoes.py`（dry-run→备份→insertion-only 子序列断言+`validate_ucl` 问题集对比→写盘，幂等）。**只增不改**：新条目插在既有 `valid_leave` 列表内（逗号紧跟上一 `}`）或房间块尾部新建列表 | **6 区 / +68 行 / −0 行**（tulong 3 / shaolin 3 / jingzhou 2 / chengdu / gumu / hangzhou 各 1）；61 候选中 49 条转换器已有等价条目（方向感知去重）、11 条生效回填、1 条被既有等价条目遮蔽（city:qiyuan1）；91 条跳过均登记原因（elias 多参 48 / 白名单外函数 19 / 裸变量 17 / b/ 镜像无房间 5 / 动态文案另计 66 文件）；幂等 ✓（二次 dry-run 11 跳过 0 写）；`recount_veto_status.exs` M7 **144→155**；`audit_veto_effectiveness.exs` 11 条全部 live；`world_reachability.py` 前后逐字节一致（4190/4409） |
| 2026-10-17 | **P3-a（装备文案 5 件套消费端接线，计划内）** | `c5c3c325` | 新增 LPC `message_vision` 语义原语：`lib/kantele/character/events/vision_event.ex`（新事件类型 `"vision"`，`interested?` = type + `rooms:` 前缀门控）+ `lib/kantele/character/views/vision_view.ex`（echo/listen 分流：`{npc}` 对自己→「你」、对他人→行动者姓名；`{name}` 发布方预替换）+ `events.ex` 路由注册 + `assets/js/store.js` `Room.Vision` handler（与 `Room.Say` 同形的 display 分发）。`wield_command.ex` 接线：wield（主手/副手）→`:wield`、wear→`:wear`、unwield→`:unwield` 回退 `:unequip`、remove→`:remove` 回退 `:unequip`（源里两键同义，blade.c 只设 unequip_msg）；卸下路径按 combat 快照全名从背包精确回查物品定义；swap 路径保持默认文案；无自定义文案的路径渲染路径完全不变。新增 `scripts/probe_equip_messages_wiring.exs`（真实数据全链路） | **零数据写入**（纯消费端，8 文件 +533/−12）；激活 249 物品 / 439 条文案；新增 11 测试（vision_event 6 + equipment 5）；全量 **3446/34** 与基线一致（34 既有失败不新增）；probe OK（样本 mingjiao:langyabang：actor/room 双视角渲染正确，interested? 门控 speech=false） |
| 2026-10-17 | **P3-b（R6 flag 直读 KeyError 修复，计划内延伸）** | `524efcff` | 发现 `room.ex` 消费端 **4 处 flag 直读全部 KeyError 崩溃**：`StealRequestEvent.call` 直读 `context.data.skybook/no_fight/no_steal`、`SearchRequestEvent.call` 直读 `context.data.no_search`（`%Room{}` 仅有 `:flags` 字符串列表、无这些字段，每偷/每搜必崩），且 search 第二层 `put_in([:attributes,...])` 踩 `%Kalevala.Character{}` 的 `Access` 未实现（第二层崩溃）。修复：新增 `Room.has_flag?/2`（flags 字符串列表成员判定，复用 L1 已写 flag 数据，含 nil/非列表/非字符串防御）；steal 三 arm 改用 `"flag" in flags`、search 改用 `has_flag?(context.data,"no_search")` 并用 `Map.merge` 更新 requester attributes（qi/jing 各 −30）。`no_steal` 数据早已写入（B1 重做 `cf0af449`）但此前因崩溃从未生效——本次修复后恢复拒绝语义。新增 `scripts/probe_no_steal_flag.exs`（真实数据全链路，内含 `defmodule Probe`） | **3 文件 / +~50 行**（纯消费端，零数据写入）；4409 房中 no_steal 45 / no_fight 17 / no_search 0 —— **45 个 no_steal + 17 个 no_fight 房间的拒绝语义恢复**（数据休眠期结束）；新增 7 测试（room_event_flag 7：steal no_steal/no_fight 拒绝、未标记→对象不在这里、无关 flag 穿透；search no_search 拒绝、未标记→qi/jing 扣到 70；`has_flag?` 语义含 nil/非列表/非字符串防御）；全量 **3453/34**（34 既有失败不新增）；probe OK（真实 no_steal 房 →「这里禁止行窃。」；未标记房 →「你想行窃的对象不在这里。」；search 未标记房 qi/jing 扣到 70） |
| 2026-10-17 | **P3-c（female_only 穿戴限制接线，计划内）** | `a52ece2b` | `Item.Meta.female_only` 数据早在 B3（`199e2b74`）回填 24 件，但 `lib/` 一直无消费者。在 `wield_command.ex` 的 `with_item`（wield/wear 共用的物品解析入口）加性别门控：`female_only_conflict?/2` = 物品 `female_only==true` 且 `character_gender/1 == "男性"` → 拒绝「只有女性才能穿戴。」。性别取自运行态 `meta.env["gender"]`（`Records.apply_to_character` 把 DB `gender` 写进 env），`env` 仅 PlayerMeta 有 → 用 `Map.get(meta, :env, %{})` 取避免 NPC 上 struct 取未定义键 KeyError；gender 未知（nil）按 LPC `nil == "男性"` 恒假 → 放行（fail-open，宁漏不误拦）。`equip_weapon`/`equip_armor` 共用一处门控，零数据写入 | **2 文件 / +~25 行**（纯消费端，零数据写入）；激活 B3 的 24 件 female_only 物品；新增 4 测试（equipment_test：男性拒绝 / 女性可穿 / 非 female_only 男性不误拦 / 性别未知 fail-open）；全量 **3457/34**（34 既有失败不新增，+4 新测试）；子集 `equipment_test.exs` 18/0 |
| 2026-10-17 | **P5-1 勘查（add_action 通道，计划内前置）** | （只读脚本） | 新脚本 `scripts/survey_add_action.py`：扫描 LPC 源语料 `add_action("verb","handler")` 调用，按对象类型分诊（room/npc/item/other）。结果：1568 调用/793 文件（room 60/22、npc 578/237、item 143/118、other 787/416）；338 verb / 379 handler；Tier0（已有 Elixir 命令）390 调用，需新建 1178 调用。关键发现：NPC add_actions 已被冻结转换器写进 UCL（52 文件）且 loader 已读入，但转换器 `lpc_converter.ex` L1286-1289 只存 handler 丢了 verb、加载后无人分发；`room.ex` `resolve_verb/4` 骨架格式（map）与 UCL 扁平 list 不匹配；item 完全缺 UCL 入口。见决策 **D24** | **1 脚本 / +~230 行**（纯只读，落 `tmp/survey_add_action.json`）；为 P5-1 定义 verb→handler schema + 对象级分发路由 + 房间/物品 UCL 入口提供数据基线 |
| 2026-10-17 | **P5-1a（add_action 基础：Room actions 字段 + loader，P7 只加字段）** | `9d185a57` | `Room` 结构体新增 `actions` 字段（默认 `%{}`）+ `loader.parse_room` 读入 UCL `actions = { verb = "handler" }`（verb→handler map，键归一化字符串）；`parse_room_actions/1` 对 nil/非 map 防御回退 `%{}`。**纯 P7 只加字段、零行为变化**（消费端 = 对象级 verb 分发路由，见 P5-1b）。新增 `test/kantele/world/room_actions_test.exs`（4 测试：map 读入 / 默认 %{} / 异常值回退 / 结构体默认）。**backfill（从 .c 回源 verb）与分发路由未做** | **3 文件 / +~20 行**（lib 2 + test 1）；子集 `room_actions_test.exs` 4/0；激活 0 数据（schema 先行，数据回填归 P5-1a2） |
| 2026-10-17 | **P5-1a2（房间 actions 回填：从 .c 回源 verb→handler）** | `315f87dd` | 冻结转换器只存 handler 丢了 verb；本轮核对 `lpc_converter.ex` L1286-1289（`Regex.scan` 返回 `[full, group1, group2]`，`Enum.map(fn [_, _func, verb] -> verb end)` 取的是 **group2 = 玩家输入 verb**，故 D24 把两组角色写反、但「丢了 handler」结论正确）。新脚本 `survey_room_actions_backfill.py`（从 UCL 房间块反查权威 `.c→UCL room id` 映射，绕过非统一路径 `d/dali/chahua1.c` vs `d/room/caihong/houyuan.c`）+ `backfill_room_actions.py`（dry-run→备份→validate 门禁【排除不可靠的 Syntax 检查——其解析器不支持任何嵌套 map，features/messages/armor_prop 亦触发假阳性】→写盘；插入性子序列断言 + 幂等 + P4 只增不改）。回填 **304 房间 / 532 verb→handler / 1140 行 / 59 区文件，0 删除**；2 个动态 verb 房间跳过。全量 `mix test` 验证 elias 解析无误（失败集不变） | **59 文件 / +1140 行 / −0 行**；子集 `room_actions_test.exs` 4/0；激活 0 行为（消费端 = 对象级 verb 分发路由，归 P5-1b） |
| 2026-10-17 | **P5-1b-1（对象级 verb 解析层：resolution + handler 注册表）** | `b9c6286f` | 死代码 `resolve_verb/4` 从 `dynamic_exits[:verbs]` 读 `{module,fun,args}` 元组、`apply` 直接执行，且格式与 UCL `actions`（verb→handler 字符串）不匹配、无调用方。本轮：① 新增 `Room.resolve_action/2`（读 `Room.actions` 字段，verb 大小写敏感查找，返回 `{:ok, handler}` \| `{:error, :no_such_action}`）；② `resolve_verb/4` 改为委托 `resolve_action`（保留签名兼容，返回 `{:ok, handler}` \| `{:error, :no_such_verb}`，消除旧的错误数据来源）；③ 新增 `Kantele.World.RoomActionHandlers` 注册表（`lookup/1` → `{:ok, {module, function}}` \| `{:unimplemented, name}`；初始 `@registry` 为空，handler 名待 P5-1b-3 逐个移植；未注册优雅降级不崩溃）。**纯 P7 只加逻辑、零行为变化**（新函数/模块当前无调用方；真正的「房间 verb 优先于全局命令」接线归 P5-1b-2）。新增 `test/kantele/world/room_resolve_action_test.exs`（7 测试）+ `test/kantele/world/room_action_handlers_test.exs`（3 测试），子集 10/0 | **4 文件 / +~90 行**（lib 2 + test 2）；子集 10/0；激活 0 行为（接线 + handler 实现归 P5-1b-2/3） |
| 2026-10-17 | **P5-1b-2（对象级 verb 分发接线：dormant-safe 路由接入）** | `76345f7f` | 命令分发是 `Kantele.Character.Commands`（用 `Kalevala.Character.Command.Router` 宏，编译期把 verb 绑定到命令模块），入口 `Commands.call(conn, data)`，**无运行时对象级 verb 钩子**。本轮：① 新增 `Kantele.World.RoomAction`（handler 行为契约：`@callback run(conn, params)`）+ `Kantele.World.RoomActionDispatcher`（`extract_verb` 取首词 / `resolve` 纯决策 / `dispatch` 应用 handler；`lookup_fun` 可注入便于单测）；② 在 `command_controller.ex recv/2` 的 `Commands.call` **之前**插入分发器：命中且已注册 → 执行 handler（拦截全局命令），否则 `:not_handled` 放行全局命令；prompt 逻辑在两条分支对称保留。③ **安全性（P7）**：当前 `RoomActionHandlers.@registry` 为空 → 所有 verb 走 `:not_handled`，对全局命令**零行为影响**；P5-1b-3 每注册一个 handler 对应房间动作才被激活。优先级=房间 verb 优先于同名全局命令（LPC 语义），重名 verb（look/say/get/open/close 等核心命令）在 handler 未完整移植前**不应注册**，以免玩家失功能。**仍为纯 P7 只加接线、零行为变化**（dormant）。新增 `test/kantele/world/room_action_dispatcher_test.exs`（10 测试：动词提取/CJK/空白、resolve 命中-未移植-无房间、dispatch 正向-dormant-无 verb），子集 10/0 | **3 文件 / +~90 行**（lib 2 + test 1，controller 修改接线）；子集 10/0；激活 0 行为（dormant，待 P5-1b-3 注册 handler） |
| 2026-10-17 | **P5-1b-2 运行期修正（修复分发在运行期 inert 的潜伏 bug）** | `c545ef3a` | 单测用手建 `%Room{}` 蒙混过关，运行期才发现：引擎从不把房间塞进 `conn.private.room`（恒为 nil），既有的 `get_room` 只回退到 `conn.private.room` → 永远 nil；且 `Kantele.World.Room.snapshot/1` 返回精简 map **不含 `actions`**、`resolve_action` 又按 `%Room{}` 结构体匹配 → 即便有房间也匹配不上。结果：原接线在运行期**永远返回 `:not_handled`**，verb 从未被识别（handler 即便注册也永不被触发）。修正：① 新增 `Room.actions_by_id/1`（`:global.whereis_name` + `:sys.get_state` 取房间进程 `state.data.actions`，进程不在 → `%{}` 安全降级）；② `RoomActionDispatcher.get_room_actions/1` 优先走 `actions_by_id`（单测仍可手建结构体走快速路径）；③ `build_params` 改传 `room_id`（handler 改房间用）而非整结构体，且所有 `conn.character` 访问改为 `Map.get` 防 KeyError。运行期现在能正确识别房间 verb（仍因空注册表 dormant，但识别链路已通）。补充测试：`Room.actions_by_id` 缺失/非字符串 → `%{}`；`conn` 无 `:character` 不崩。子集 17/0（dispatcher 13 + room_actions 4） | **2 文件 / +~25 行**（lib 2）；子集 17/0；激活 0 行为（dormant，识别链路通，待 P5-1b-3 房间级 handler 注册） |
| 2026-10-17 | **P5-1b-3 样板（房间级 handler 注册表 + huashan:lianhua do_tiao 端到端打通）** | `cb0900f9` | 回源证实 handler 是**房间级、非共享**（同名 do_move/do_climb 各房间独立），故把 `RoomActionHandlers.lookup/1` 改为**房间级 `lookup(room_id, handler_name)`**，`@registry` 现为 `room_id -> (handler -> {mod,fun})`；`RoomActionDispatcher.resolve` 把 `conn.character.room_id` 注入 lookup，dispatch 优先走真实注册表，其余房间/handler 仍 `:not_handled` 放行全局命令（P7 零影响）。首例移植 `d/huashan/lianhua.c` 的 `do_tiao`（动词 `tiao` **在全局命令表无注册**、纯 `write` 文本、零副作用）→ 新模块 `Kantele.World.RoomActions.Huashan.Lianhua.Tiao`（推文本进 `conn.output`，仅本人可见），并注册。新增 E2E 用例经**真实注册表 + 真实 handler** 验证 dispatch 在运行期真触发、文本输出到玩家，且同名 handler 按房间区分（`baituo:neishi` 的 `do_move` 未移植→不触发）。选样板 verb 一律避开与全局命令重名者（look/say/get/open/close/eat/drink/fight…），优先 `clap`/`knock`/`reach`/`swim`/`pull`/`tiao` 这类非全局 verb，避免覆盖真实玩法 | **5 文件 / +153/−51**（lib 2 改 + 新 handler 模块 1 + test 2 改）；子集 20/0；全量 **3488/34**（失败集与基线 34 完全一致，无新增回归）；激活 1 房间 1 动作（huashan:lianhua 的 tiao），其余 303 房间 dormant |
| 2026-10-17 | **P5-1b-3 样板 #2（message_vision 广播 helper + emei:shierpan3 do_clap）** | `c3bc18ff` | 新增 `Kantele.World.RoomActions.Helpers`：`broadcast_vision/3` = LPC `message_vision(msg, this_player())` 等价（`Conn.publish_message` 到 `rooms:<room_id>` 频道、`type: "vision"`，`$N` 替换为行动者名字，由 `Kantele.Character.VisionEvent` 按 `from_pid` 分流 echo/listen 渲染，P3-a 已建）；`render_to_player/2` = LPC `write(msg)` 等价（只推 `conn.output`）。移植 `d/emei/shierpan3.c` 的 `do_clap`（`message_vision` 广播、无参无状态）为 `Kantele.World.RoomActions.Emei.Shierpan3.Clap` 并注册（动词 `clap` 不在全局命令表，仅本房间拦截）；`Tiao` 改用 `render_to_player` 复用 helper。新增 `room_actions_helpers_test.exs`（3：write/广播/`$N` 回退）+ clap E2E（真实 `Conn`/`Character`/`Private` 结构体，断言 `private.channel_changes` 含 `rooms:emei:shierpan3` 的 vision publish） | **7 文件 / +169/−6**（lib 3 + test 3 + 注册表 1）；子集 24/0；全量 **3492/34**（失败集与基线 34 完全一致，无新增回归）；激活累计 2 房间 2 动作（tiao 玩家私发 + clap 房间广播），其余 302 房间 dormant |
| 2026-10-17 | **P5-1b-3 批量机制（数据驱动 MessageOnly + knock/reach）** | `71faab9c` | 长尾里大量 `do_*` 只输出文字、无状态变更。新增 `Kantele.World.RoomActions.MessageOnly`：按 `{room_id, verb}` 查 `@messages` 表执行，支持 `{:player, text}`（LPC `write`）/`{:vision, text}`（LPC `message_vision`）/`{:vision_args, %{arg=>text}}`（按 arg 分支，未匹配不输出）。移植 `hangzhou:liuzhuang` 的 `do_knock`（广播）与 `huanggong:inwell` 的 `do_reach`（按 arg 分支：木桶/长绳）到该表并注册；动词均非全局命令。需要真实逻辑（改 exits/查属性/战斗）的 handler 仍单独写模块（Tiao/Clap，未来 Move）。新增 `room_actions_message_only_test.exs`（6：knock/reach mutong/reach string/未知 arg 不广播/未配置不崩/entries） | **4 文件 / +157/−5**（lib 2 + test 2）；子集 30/0；全量 **3498/34**（失败集与基线 34 完全一致，无新增回归）；激活累计 4 房间 4 动作，其余 300 房间 dormant |
| 2026-10-17 | **P5-1b-3 样板 #3（运行时出口增删 API + baituo:neishi do_move 开/关密道）** | `251cf545` | 先摸清出口模型：`room.exits` 是 `%Kalevala.World.Exit{}` **列表**（loader `%{room \| exits: [exit \| room.exits]}`），移动回调 `Callbacks.exits/1` 与 `snapshot/1` 都直接读它；而 `all_exits/1`/`set_dynamic_exit/3` 用 `Map.merge`（对列表会崩）是**未接线死代码**。故采用**只加不改**方案：`Room` 新增纯函数 `put_exit/remove_exit/has_exit?`（在 `exits` 列表上增删/查）+ 运行期 `set_exit/delete_exit/has_exit_by_id?`（`:sys.replace_state` 改房间进程 `state.data.exits`；进程不在 → `:error`/`false` 安全降级）。`exits/1`/`snapshot` 原样读 `room.exits` → 增删后 look/移动立即生效；无调用方时零行为变化（P7）。移植 `d/baituo/neishi.c` 的 `do_move`：`arg!="pen"`/`born_family!="欧阳世家"` 各给本人提示；无 `down` 出口 → `set_exit` 开密道 + 广播，已有 → `delete_exit` 封洞 + 广播。动词 `move` 非全局命令。新增 `room_dynamic_exit_test`（6）+ Move handler 测试（3）+ dispatcher move E2E | **7 文件 / +341/−5**（lib 3 + test 3 + 注册表 1）；子集 40/0；全量 **3508/34**（失败集与基线 34 完全一致，无新增回归）；激活累计 5 房间 5 动作（含首个状态变更样板），其余 299 房间 dormant |
| 2026-10-17 | **P5-1b-3 批量（房间动作覆盖全局命令，7 个纯消息处理器）** | `963667b7` | 「纯消息长尾」几乎已抽干（非全局 verb 的纯消息 handler 仅剩 3 个，均已移植），剩下的 9 个无条件纯消息 handler 全部挂在**全局 verb** 上（drink/eat/give/drop/suicide）。核查 LPC 源：这些 `do_*` 是**各房间独立函数体**，`add_action` 注册后即接管该房间内的同名全局命令，属于**完整移植**（不是残缺覆盖，不会让玩家失功能）。本轮移植 2 房间 7 动作到 `MessageOnly` 数据表并注册：`chengdu:guangchang`（drink/eat，广场禁止吃喝）、`register:prison`（eat/drink/suicide/give/drop，冥府牢房禁止）。`RoomActionHandlers.@registry` 首次出现**单房间多 handler** 形态。新增测试：handlers lookup/2 覆盖 7 房间 + `registered_rooms/0` 集合同步、MessageOnly 文案断言（chengdu drink / prison drop）、dispatcher E2E（chengdu:guangchang 拦截 drink；`some:other` 不拦截） | **5 文件 / +74/−3**（lib 2 + test 3）；子集 44/0；全量 **3512/34**（失败集与基线 34 完全一致，无新增回归）；激活累计 7 房间 12 动作，其余 297 房间 dormant |

---

## 14. 阻塞 / 风险

| # | 事项 | 影响 | 状态 | 处理 |
|---|------|------|:----:|------|
| R1 | 5 个新脚本 + 3 份文档尚未 commit | 回滚基线缺失 | ⬜ | 先提交 P0 |
| R2 | `armor_prop/personality` 被 `sanitize_prop` 丢弃 | B10 无法纯数据落地 | ✅ 已决策 | **决策 = 扩 `Combat.applies_keys()` 白名单**（B10b `2d9de14a`）：让 loader 装得下是唯一通道；新键经 `Map.get(applies, key, 0)` 惰性携带、公式不读 → 无战斗行为变化。同时发现**白名单内子键（532 源文件）也从未被转换**（斜杠式）→ B10a 先数据回填 |
| R3 | 战斗回调方案 A 会有第二份 `engage` 抽取实现 | 与转换器漂移风险 | ⬜ | 加对账脚本，或明确记录在文档 |
| R4 | `Meta.Trim` 新字段必须能 JSON 编码 | websocket 进程崩溃 | ⬜ | 加字段时同步补 `Jason.Encoder` |
| R5 | `context.data.no_steal` 的取数路径未确认 | 决定 `no_steal` 是 L1（纯数据）还是 L3（要接线） | ✅ 已查清 | **已确认**：`context.data` 就是 `%Room{}`（`vendor/kalevala/.../room.ex` L79-85 `state.data = room`；`Context.new` 取 `state.data`），所以 `no_steal` 走 L1（数据已写），消费端见 R6 |
| R6 | **`room.ex` L1458-1462 的 cond 会抛 `KeyError`（既有缺陷）** | 偷窃在房间内必然崩溃；`no_steal` 数据写了也不生效 | ✅ 已修 `524efcff` | `context.data.skybook` / `.no_fight` / `.no_steal` 三个字段 `Room` 都没有（实测 `Map.has_key?` = false）。**实际范围比登记时更大**：search 的 `context.data.no_search` 同样直读必崩（每搜必崩，`%%Kalevala.Character{}` 上的 `put_in` 还踩 Access 未实现，第二层）。修复：新增 `Room.has_flag?/2`（flags 字符串成员判定，L1 数据原样生效——45 个 no_steal / 17 个 no_fight 房恢复拒绝），skybook/no_search 数据为 0 保留判定休眠 |
| R7 | **D10：83 个 `characters` 块其实是物品（整个 meta 缺失）** | 68% 的装备文案目标 + 这些物品的 damage/value/unit/material/weapon_prop 全部无法装载 | ⬜ **待决策** | 修法＝把 `characters "x" {` 改成 `items "x" {` —— **改已有行，与 P4「只增不改」冲突**；且这些块的 meta **从未生成过**，改名后仍需回填 meta。需用户拍板是否开 P4 例外（可做成独立、可回滚的脚本 + 逐块对账） |
| R8 | **B7 数据回填阻塞：源无真实值** | Room 4 字段已加（代码 `48fa1b59`），但无数据可写 | ⏸ 阻塞 | 源 .c 中 `room_owner`/`room_name`/`room_position`/`room_owner_id` 全在 `//**` 注释块里为 `ROOM_OWNER` 等模板占位符，**无激活的 set() 调用**；sidecar `room.comments.txt` 仅 1 处条件判断提及 `room_owner_id`，无值；UCL 现无相关字段。待出现真实数据源或消费端后再回填。字段本身默认 nil，不产生行为变化 |

---

## 15. 自检命令

```bash
# ---- 基线重算（宿主机，只读）----
python scripts/analyze_comments_txt.py data/world
python scripts/audit_ucl_key_loss.py
python scripts/triage_lost_keys.py
python scripts/build_unhandled_manifest.py

# ---- elias 表达力（容器内，只读）----
MSYS_NO_PATHCONV=1 docker exec -w /app wuxia_mud_dev-app-1 \
  mix run --no-start scripts/probe_elias_expressibility.exs

# ---- 每个批次完成后 ----
python scripts/validate_ucl.py data/world/<zone>.ucl
python scripts/world_reachability.py
git diff --stat                                   # 必须只有新增行
MSYS_NO_PATHCONV=1 docker exec -w /app -e MIX_ENV=test wuxia_mud_dev-app-1 \
  mix test --seed 12345
```

> Git Bash 下 `docker exec -w /app` 会被 MSYS 改写路径 → 必须加 `MSYS_NO_PATHCONV=1`。
