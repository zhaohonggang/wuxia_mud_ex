# hell-地藏王 NPC 移植计划

## 1. 背景

LPC `mud/d/death/npc/dizangwang.c`（地藏王）在 ex 中完全缺失：
- `clone_lib.ucl` 中没有 `characters "hell_dizang"` 定义
- `death.ucl` 中只有地藏王殿房间描述和条件门控，没有该 NPC 的出生/教学数据

缺失会导致死区（/d/death）的 NPC 无法交互，死亡/还阳/转世流程断裂。

## 2. 需要移植的内容（基于 LPC 源码）

### 2.1 基础属性
| 字段 | LPC 值 | ex UCL 对应 |
|------|--------|-------------|
| name | 地藏王 | name = "地藏王" |
| aliases | ("dizang",) | aliases = ["hell_dizang", "dizang"] |
| long | 他容貌威严，不可一世... | description |
| gender | 男性 | gender = "男性" |
| age | 99 | age = 99 |
| attitude | peaceful | combat.attitude = "peaceful" |
| shen_type | 0 | combat.shen_type = 0 |
| per | 18 | combat.per = 18 |
| str/int/con/dex | 31/39/34/36 | combat.str/int/con/dex |
| max_qi/max_jing | 49999/29999 | combat.max_qi/max_jing |
| neili/max_neili | 49999/49999 | combat.max_neili |
| jiali | 400 | combat.jiali |
| combat_exp | 50000000 | combat.combat_exp |
| skills | unarmed/finger/parry/dodge/force/sword/count/kuihua-mogong/martial-cognize/literate | skills 映射 |
| skill maps | parry/force/dodge/finger/sword → kuihua-mogong | (技能映射由引擎处理) |
| prepare_skill | finger/kuihua-mogong | (技能准备由引擎处理) |
| family | 冥府地藏王殿前 / 1 / 幽冥之主 | family = %{name="冥府地藏王殿前", generation=1, master="幽冥之主"} |
| title | 幽冥之主 | title = "幽冥之主" |

### 2.2 装备
- `/clone/cloth/cloth.c`（布衣）穿戴
- `/clone/misc/spin`（判官笔）持握

ex 中需要在 clone_lib.ucl 的 items 中预先定义，或在 NPC 的 carry/inventory 中引用。

### 2.3 问询（inquiry）
| 关键字 | LPC 处理函数 | 行为 |
|--------|-------------|------|
| 麒麟靴 | ask_xue() | 需 hell_quest/锁阳丹；检查靴子持有者；成功则给予 |
| 转世 | ask_zhuan() | 需 HellZhenPass；检查 SkyPass；否则战斗 |

### 2.4 收徒（attempt_apprentice）
- 未出生 → "你快投胎去..." → 拒绝
- 已出生 → "滚！给我一边儿去！" → 拒绝
- 地藏王不收徒，应设 `apprentice.deny_all = true`

### 2.5 战斗行为
- accept_kill/accept_hit/accept_object 都返回 0（不接受）
- fight_ob/win/lost/ob_die：转世战斗流程
- 受击/被杀时的消息

### 2.6 accept_object（精元丹）
- 物品 id == "jingyuan dan"
- 需 SkyPass && DiZangPass
- 成功后：摧毁精元丹，玩家移动到六道轮回各场景，广播谣言

## 3. 待处理的其他缺口（按优先级，后续批次）

> 详细执行顺序、计数校正与“先检查再做”规则见 **`docs/移植缺口统一执行计划.zh-CN.md`**。本表只保留大类摘要。

| # | 缺口 | 说明 | 优先级 |
|---|------|------|--------|
| A | unimplemented 占位符（183 个） | clone_lib.ucl 68、beijing.ucl 22、death.ucl 15 等；旧记 171/184 已校正 | P1 |
| B | lpc-port-gaps §十五 8 NPC 硬闭包 | 莫邪24、干将5、苗人凤5、商剑鸣2、桑三娘1、青阳子2、平四3；另 1 NPC 为 LPC 自身缺陷不追 | P1 |
| C | carry 引用未解引用（147 个） | NPC 出生空手 | P2 |
| D | Items.get!/1（88 处） | 缺物品定义时崩溃 Foreman | P2 |
| E | attitude 接线到运行时 | 未接进 room.ex | P2 |
| F | 重复/冗余 NPC 数据 | 762/3437 处 room_characters 引用 clone_lib 独有角色 | P3 |
| G | TaskList 172 个 pending 候选 GAP | 含状态滞后/重复项；按门派分批先检查再关单或实现 | P1–P2 |

## 4. 验收标准（已达成）
- `python scripts/validate_ucl.py data/world/death.ucl` 通过 ✅
- `mix compile` 通过（无警告） ✅
- `mix test test/kantele/world/death_chain_test.exs`：14 tests, 0 failures ✅
- 提交 `1f35cabe` 已推送到远程 `kalevala` ✅

## 5. 后续缺口计划（按优先级，从前到后）

> 本表的逐项展开以 **`docs/移植缺口统一执行计划.zh-CN.md`** 为准。执行指针当前为 UG-03 / A-5-c（`reward` 组）；A-4 庄允城 `init()`（第 58 批）、A-5-a QUEST_D 历练问询（第 59 批）与 A-5-b `job` 问询（第 60 批）均已实现并登记待全量回归。

| # | 缺口 | 说明 | 状态 |
|---|------|------|------|
| A | unimplemented 占位符（复核后 182 个，当前剩 153） | clone_lib.ucl 67、beijing.ucl 22、death.ucl 15 等 | P1 · 进行中 |
| B | lpc-port-gaps §十五 8 NPC 硬闭包 | 莫邪24、干将5、苗人凤5、商剑鸣2、桑三娘1、青阳子2、平四3 | P1 · 待开始 |
| C | carry 引用未解引用（147 个） | NPC 出生空手 | P2 · 待开始 |
| D | Items.get!/1（88 处） | 缺物品定义时崩溃 Foreman | P2 · 待开始 |
| E | attitude 接线到运行时 | 未接进 room.ex | P2 · 待开始 |
| F | 重复/冗余 NPC 数据 | 762/3437 处 room_characters 引用 clone_lib 独有角色 | P3 · 待开始 |
| G | TaskList 172 个 pending 候选 GAP | 先检查 stale，再按门派分批实现 | P1–P2 · 待检查 |

### 5.1 缺口 A 分片进度（2026-11-28）

| 分片 | 内容 | 批次 | 状态 |
|---|---|---|---|
| A-1 | `city_ping` 平一指 `ask_job()`（配药/工作/job）| 第 55 批 | ✅ 已实现 + 端到端 `AskCommand` 验证，待全量回归授权 |
| A-2 | `city_smith` 中原铁匠 `ask_back()`（血海无边）+ 打工链推广到 city/suzhou 打铁铺 | 第 56 批 | ✅ 已实现 + 定向验证，待全量回归授权 |
| A-3 | 北京 8 NPC `ask_weiwang()`（威望/江湖威望，16 个占位符） | 第 57 批 | ✅ 已实现 + 定向验证，待全量回归授权；庄允城 `init()` 威望 +10 另立 Task #1245 |
| A-4 | 庄允城 `init()` 威望 +10 / 入场求救文案（Task #1245） | 第 58 批 | ✅ 已实现 + 定向验证，待全量回归授权 |
| A-5-a | 6 NPC / 18 个 QUEST_D 历练占位（#744/#747/#892/#927） | 第 59 批 | ✅ 已实现 + 定向验证，待全量回归授权 |
| A-5-b | 平一指 / 书童 / 厨娘共 11 个 `job` 占位 | 第 60 批 | ✅ 已实现 + 定向验证，待全量回归授权 |
| A-5 | 剩余 153 个 `unimplemented` 占位符 | 后续批次 | ⏳ 按统一计划 §4.2 分组推进（下一片 A-5-c `reward`） |

每片均按「先读 LPC 原函数 → 只补 ex 缺口 → 定向测试 → 登记 `docs/待全量回归清单.zh-CN.md`」执行；全量回归按 AGENTS.md §0.4 等待用户明确指示。

---
*本计划按宪章「lpc 有 ex 无」主动报告 + 建立移植计划的要求编写，严禁简化。*