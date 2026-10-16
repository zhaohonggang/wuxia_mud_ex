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
| **P0** | 清单化（5 个只读脚本） | 11095 条记录 | — | ✅ | （本轮新增，未提交） | 2026-10-16 |
| **P0.1** | 索引兜底收尾 + 基线表 | 32 条 | — | ⬜ | | |
| **P1** | 白名单内纯数据回填 | 4 个批次 | L1 | ⬜ | | |
| **P2** | 加字段 + 回填 | 7 个批次 | L2 | ⬜ | | |
| **P3** | 消费端接线 | 6 个字段 | L3 | ⬜ | | |
| **P4** | 条件分支补全（回源） | 410 条 / 60 区 | L1 | ⬜ | | |
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
| M6 | `set()` key 真丢失 distinct / occ | 202 / 3150 | `—` | ⬜ | `triage_lost_keys.py` |
| M7 | `valid_leave` 生效条数 | 133 / 166 | `—` | ⬜ | `world_reachability.py`（或 `recount_veto_status.exs`） |
| M8 | 可达性 | 4190 / 4409（95.0%） | `—` | ⬜ | `world_reachability.py` |
| M9 | 测试 | `mix test --seed 12345` 绿 | `—` | ⬜ | — |

**基线已实测确认**：M1–M6、M8 为本轮实跑值；M7 引用 `ucl-comment-todo.zh-CN.md` 的记录。

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
| P1a `plan_key_field_map.py` 生成映射表 | ⬜ | 输出 `tmp/key_field_map.json`；`decision` 枚举 `L1`/`L2`/`L3-framework`/`noop`/`manual` |
| P1a 人工过一遍 decision | ⬜ | **不许跳过**；判 `L3-framework` 的移交 P5 |
| P1b `backfill_l1_fields.py` 回填 | ⬜ | 只增不改 + 幂等 + dry-run 默认 |

| 批次 | key | 次数 | 目标 | 状态 | 提交 | 备注 |
|------|-----|-----:|------|:----:|------|------|
| **B1** | `base_weight` | 36 | `item.meta.weight` | ⬜ | | 建议第一个做（最小闭环） |
| **B2** | `armor_prop/*`、`weapon_prop/*` 白名单内子键 | — | `item.meta.armor_prop/weapon_prop` | ⬜ | | 仅 `applies_keys` 内的子键 |
| **B3** | `food_supply` / `base_unit` / `base_value` | 185 / 72 / 69 | `item.meta.food/unit/value` | ⬜ | | 与既有 food 回填对账 |
| **B4** | `max_force` / `force_factor` / `mana` / `max_mana` / `eff_qi` / `eff_jing` | 10/14/4/4/37/19 | `npc.vitals` 或 `npc.stats` | ⬜ | | **先查 `vitals` 结构再定** |

**P1 DoD**

- [ ] ⬜ dry-run → `--apply` → 二次 dry-run 显示「0 项」
- [ ] ⬜ `git diff --stat` 只有新增行
- [ ] ⬜ `validate_ucl.py` 通过
- [ ] ⬜ `mix test --seed 12345` 绿
- [ ] ⬜ `world_reachability.py` 不降

---

## 6. P2 · 加字段 + 回填（L2）

**先加字段（零行为变化，可独立提交）**

| 结构体 | 要加的字段 | 状态 |
|--------|-----------|:----:|
| `Item.Meta` | `wield_msg unwield_msg wear_msg remove_msg unequip_msg` | ⬜ |
| `Item.Meta` | `liquid max_liquid liquid_type` | ⬜ |
| `Item.Meta` | `can_make not_make power_point item_origin material_attrib material_name` | ⬜ |
| `Room` | `female_only no_beg no_map` | ⬜ |
| `Room` | `room_owner room_name room_position room_owner_id` | ⬜ |
| `NonPlayerMeta` | `chat_msg_combat chat_chance_combat` | ⬜ |
| `Combat.applies_keys()` | 是否纳入 `personality`（B10 前置） | ⬜ |

> **复核修正（2026-10-16）**：`sleep_room` / `no_sleep_room` / `no_steal` **不在此表** ——
> 消费端**已存在**（`room.ex` L223/L238 读 `data.flags` → `attrs["sleep_room"]`；`sleep_command.ex` L70）。
> 缺的是**数据**：全仓 `.ucl` 里 `"flags"` 出现 **0** 次，所以这两个 flag 恒为 `false`。
> → 它们归 **B7（L1 回填，写进已存在的 `flags` 通道）**，不需要动结构体。
> `female_only` / `no_beg` / `no_map` 在 `lib/` 里**无任何消费者**，才真正需要「加字段 + 接线」。

**再回填数据**

| 批次 | key | 次数 | 归属 | 状态 | 提交 |
|------|-----|-----:|------|:----:|------|
| **B5** | `wield_msg`/`unwield_msg`/`wear_msg`/`remove_msg`/`unequip_msg` | 295/217/89/63/37 | 装备文案（**最高收益**） | ⬜ | |
| **B6** | `chat_msg_combat` / `chat_chance_combat` | 132 / 129 | NPC 战斗喊话 | ⬜ | |
| **B7** | `sleep_room`/`no_sleep_room`/`no_steal`（→ `flags`）/`female_only`/`no_beg` | 127/90/55/60/39 | 前三个走 **L1**（已有 `flags` 通道）；`female_only`/`no_beg` 依赖上表加字段 | ⬜ | |
| **B8** | `max_liquid`/`liquid`/`base_unit`/`base_value` | 74/74/72/69 | 容器 / 酒水 | ⬜ | |
| **B9** | `can_make`/`not_make`/`power_point`/`item_origin` | 16/8/20/16 | 打造系统 | ⬜ | |
| **B10** | `armor_prop/personality` / `weapon_prop/personality` | 69 / 3 | 需扩 `applies_keys` 或单列字段 | ⬜ | |
| **B11** | `default_long`/`for_family`/`jiaji`/`hellzhen`/`room_*` | 28/35/21/18/111 | 杂项 | ⬜ | | `valid_startroom`(68) 已判 noop → 见 §11；`room_*` 取 4 个规范键 |

- [ ] ⬜ 若新字段进 `Meta.Trim`，已补 `Jason.Encoder`（否则 websocket 进程崩溃）
- [ ] ⬜ `mix test` 绿且**线上行为零变化**（无消费者）

---

## 7. P3 · 消费端接线（L3，逐字段）

| 字段 | 消费端 | 风险 | 灰度 | 状态 | 提交 |
|------|--------|:----:|:----:|:----:|------|
| 装备文案 5 件套 | `wield/wear/remove_command.ex` | 低 | 不需要 | ⬜ | |
| `female_only` / `no_beg` | 移动 / 乞讨命令前置判定 | 中 | **需要**（新拦截） | ⬜ | |
| `sleep_room` / `no_sleep_room` | `sleep_command.ex` | 低 | 不需要 | ⬜ | |
| `liquid` / `max_liquid` | 倒 / 喝命令 | 中 | 需要 | ⬜ | |
| `can_make` / `not_make` / `power_point` | 打造命令 | 中 | 需要 | ⬜ | |
| `chat_msg_combat` | NPC 战斗心跳 | 低 | 不需要 | ⬜ | |

- [ ] ⬜ 每个字段一条集成测试
- [ ] ⬜ 行为变更走**灰度开关 + 默认关**

> **复核修正（2026-10-16）**：`no_steal` 已有生效消费端（`room.ex` L1462 `context.data.no_steal` → 「这里禁止行窃」），
> 属 **L1 回填**（B7），不需要新写拦截，已从本表移出。
> ⚠️ 待确认：`context.data` 的来源（是否直接来自 `.ucl` 原始 map）—— 决定 `no_steal` 到底能不能纯数据落地。

---

## 8. P4 · 条件分支补全（数据层，回源）

| 归属函数 | 行数 | 处置 | 状态 |
|----------|-----:|------|:----:|
| `create` | 2619 | 走 P1/P2 的 key 通道，不单独做 | ⬜ |
| `valid_leave` | 410（bare） | 回源取 `notify_fail` 文案 → 补进 `exit_vetoes` | ⬜ |
| `init` / `greeting` | 367 / 184 | 回源补 action（`add_action`、台词池） | ⬜ |

**`valid_leave` 逐区清单（410 条 / 60 区，去掉 test 靶场）**

| 区 | 条数 | 状态 | 区 | 条数 | 状态 |
|----|-----:|:----:|----|-----:|:----:|
| shaolin | 71 | ⬜ | chengdu | 7 | ⬜ |
| city | 23 | ⬜ | huanghe | 7 | ⬜ |
| xiyu | 21 | ⬜ | wuguan | 7 | ⬜ |
| beijing | 19 | ⬜ | xueshan | 7 | ⬜ |
| mingjiao | 17 | ⬜ | lingzhou | 6 | ⬜ |
| death | 15 | ⬜ | 其余 **42 区** | 各 1–6（共 140） | ⬜ |
| huashan | 15 | ⬜ | | | |
| tulong | 11 | ⬜ | | | |
| jingzhou | 10 | ⬜ | | | |
| heimuya / wudang | 9 / 9 | ⬜ | | | |
| guanwai / wudu | 8 / 8 | ⬜ | | | |

- [ ] ⬜ `exit_vetoes` 生效条数从 **133** 上升（M7）
- [ ] ⬜ `world_reachability.py` 不降

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
| `valid_startroom`（68） | noop | 出生点校验，非运行时数据 | 2026-10-16 |
| `no_map` / `no_shown` / `no_user` / `no_magic` | noop | 显示开关 | 2026-10-16 |
| `max_room` | noop | 容量提示，无消费端 | 2026-10-16 |
| `death:heisenlin` / `heimuya:insert` / `huashan:tsr_room_dugu-jiujian` | manual | generic 文件，需人工判断是否接入世界 | 2026-10-16 |

---

## 12. 决策记录

| # | 决策点 | 结论 | 日期 | 依据 |
|---|--------|------|------|------|
| D1 | 战斗回调：改转换器还是新脚本重抽？ | **方案 A：新脚本重抽**（守 P1/P2） | 2026-10-16 | 框架文档 §5 决策点 1 |
| D2 | 一次性场景：子系统还是逐房模块？ | **逐房 Elixir 模块按 room id 绑定**；第 3 个同形状场景才提炼子系统 | 2026-10-16 | 框架文档 §5 决策点 2 |
| D3 | 是否信归档文档的阻塞理由？ | **不信，必须跑探针**（CJK 方向一条已证伪） | 2026-10-16 | 框架文档 §3 |
| D4 | `sleep_room`/`no_sleep_room`/`no_steal` 加字段还是回填？ | **回填**：消费端已存在（`room.ex` 读 `flags`），只是 `.ucl` 里 `flags` 全缺 | 2026-10-16 | 本轮复核：`grep '"flags"' data/world/*.ucl` = **0** |
| D5 | `food_supply` 是否算丢失？ | **不算**：是 `food` 的别名，`item_meta_backfill.py` 已处理；B3 只需**对账** | 2026-10-16 | `triage_lost_keys.py` ALIAS 表 |
| D6 | `valid_startroom` 是否要做？ | **不做（noop）**：`lib/` 无消费者；B11 已移出 | 2026-10-16 | §11 抑制清单 |

---

## 13. 变更日志（append-only）

| 日期 | 批次 | 提交 | 改动 | 数字变化 |
|------|------|------|------|----------|
| 2026-10-16 | P0 | （未提交） | 新增 5 个只读脚本 + 3 份文档；建立基线 M1–M9 | 建立基线，无数据改动 |
| 2026-10-16 | 复核 | （未提交） | 修正 9 处失效 `§` 引用；P5.1 `gumu` 15→14；Tier 0 计数改为「去 test 区」口径（129）；`valid_startroom` 移出 B11；§6 Room 字段表移出 `sleep_room`/`no_sleep_room`/`no_steal`（改判 L1）；§7 移出 `no_steal`（已有消费端） | 无数据改动，仅文档口径 |

---

## 14. 阻塞 / 风险

| # | 事项 | 影响 | 状态 | 处理 |
|---|------|------|:----:|------|
| R1 | 5 个新脚本 + 3 份文档尚未 commit | 回滚基线缺失 | ⬜ | 先提交 P0 |
| R2 | `armor_prop/personality` 被 `sanitize_prop` 丢弃 | B10 无法纯数据落地 | ⬜ | 需决定扩 `applies_keys` 或单列字段 |
| R3 | 战斗回调方案 A 会有第二份 `engage` 抽取实现 | 与转换器漂移风险 | ⬜ | 加对账脚本，或明确记录在文档 |
| R4 | `Meta.Trim` 新字段必须能 JSON 编码 | websocket 进程崩溃 | ⬜ | 加字段时同步补 `Jason.Encoder` |
| R5 | `context.data.no_steal` 的取数路径未确认 | 决定 `no_steal` 是 L1（纯数据）还是 L3（要接线） | ⬜ | 追 `context.data` 赋值点后再定 B7 归属 |

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
