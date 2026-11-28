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

| # | 缺口 | 说明 | 优先级 |
|---|------|------|--------|
| A | unimplemented 占位符（171 个） | clone_lib.ucl 71、beijing.ucl 38、death.ucl 15 等 | P1 |
| B | lpc-port-gaps §十五 8 NPC 闭包 | 莫邪24、干将5、苗人凤5、商剑鸣2、桑三娘1、青阳子2、平四3 | P1 |
| C | carry 引用未解引用（147 个） | NPC 出生空手 | P2 |
| D | Items.get!/1（88 处） | 缺物品定义时崩溃 Foreman | P2 |
| E | attitude 接线到运行时 | 未接进 room.ex | P2 |
| F | 重复/冗余 NPC 数据 | 762/3437 处 room_characters 引用 clone_lib 独有角色 | P3 |

## 4. 验收标准
- `python scripts/validate_ucl.py data/world/clone_lib.ucl` 通过
- `mix compile` 通过
- 地藏王 NPC 可通过定向测试验证基础属性和问询分支

---
*本计划按宪章「lpc 有 ex 无」主动报告 + 建立移植计划的要求编写，严禁简化。*