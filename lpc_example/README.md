# LPC 源码示例集（lpc_example）

本目录从原 LPC 武侠 MUD（`C:\files\git\mud`）中挑选了一批**比较大、比较复杂的 `.c` 文件**副本，按**类型**分目录存放，作为把 LPC 世界数据迁移到 Kantele/ExVenture（Elixir）时的**分析参考样本**。

目的是透过这些代表性文件，总结每种类型的**结构规律、继承关系、常用 API、数据字段、消息/事件协议**，从而为批量迁移（d/h 期转换器/大世界搬运）建立映射规则。

> 注意：这里只是**副本**，仅用于静态阅读分析，不参与编译，也不可被游戏加载。每个文件的原始路径都写在文件名里（`类型_原路径段.c`），方便回源对照。

---

## 一、总体分类方法

LPC MUD 的 `.c` 文件虽然都叫"对象（object）"，但按**角色/职责**可归纳为几大类。判断方法主要看**继承的基类（`inherit` 声明，或 `create()` 里 `set("..."...)` 的字段）**与**所在目录**：

| 目录/规律 | 大致类型 |
|---|---|
| `d/<区域>/*.c`（区域根下的散文件） | 地方/房间（Room） |
| `d/<区域>/npc/*.c` | 人物/NPC |
| `d/<区域>/obj/*.c`、`clone/*` | 物品/道具/武器/坐骑 |
| `kungfu/skill/*.c` | 武功/技能（Skill） |
| `kungfu/class/*.c` | 门派宗师/传奇人物（Class NPC） |
| `inherit/*` | 基础继承类（供上面各类复用） |
| `feature/*` | 特性模块（战斗/移动/伤害等横切逻辑） |
| `adm/daemons/*.c` | 守护进程 Daemon（全局单例服务） |
| `adm/npc/*.c` | 系统级/后台 NPC |
| `*condition*` | 条件/状态（中毒、阵法等） |
| `*quest*` | 任务（Quest） |

---

## 二、目录结构与所选样本

```
lpc_example/
├── room/         地方·房间
├── npc/          普通地区 NPC（人）
├── class_npc/    门派宗师·传奇人物
├── skill/        武功·技能
├── item/         物品·道具对象
├── weapon/       武器（clone 模板）
├── mount/        坐骑（clone 模板）
├── daemon/       守护进程 Daemon
├── system_npc/   系统/后台 NPC
├── inherit/      基础继承类
├── feature/      特性模块
├── condition/    条件·状态
└── quest/        任务
```

---

## 三、按文件逐一说明

### 1. `room/` —— 地方/房间（Room）

房间是 MUD 世界的"节点"，玩家在其间移动。一组房间组成区域，区域再拼成大地图。

| 文件 | 原始路径 | 大小 | 为何选它 |
|---|---|---|---|
| `room_qiyuan2.c` | `d/city/qiyuan/qiyuan2.c` | 22 KB | **最复杂的房间之一**：奇缘主题，含随机事件/多分支/与玩家互动的内嵌逻辑，是"房间不只是坐标+出口"的典型——除 `long/exits` 外还带 `init`/触发函数 |
| `room_wudu_liandu.c` | `d/wudu/liandu.c` | 11 KB | 五毒"炼毒"房：房间+配方+产出/材料校验/冷却，演示房间附带"制作逻辑"的写法 |
| `room_qianting.c` | `d/room/qianting.c` | 6 KB | 通用"前厅"：**最简单最典型**的房间样板，`create()` 里 `set("short"/"long"/"exits")` + 物件/NPC `setup`。迁移时 90% 房间长这样 |

**关注点（迁移规律）：**
- `set("short", ...)` / `set("long", ...)` / `set("exits", ([方向: 目标路径]))` 是房间三件套 → 对应 Kantele 的 Room `name/short/long/exits`
- `set("objects", ([路径: 数量]))` + `setup()` 在房间内安置 NPC/物品
- `reset()`/`init()` 处理房间重置与玩家进入时的触发

---

### 2. `npc/` —— 普通地区 NPC（人）

NPC 是房间里的角色（商人、守卫、师父……）。规模比宗师小，但带"行为"（买卖、对话、攻击）。

| 文件 | 原始路径 | 大小 | 为何选它 |
|---|---|---|---|
| `npc_horseboss.c` | `d/city/npc/horseboss.c` | 13 KB | 马场老板：**商人型 NPC**，演示 `init` 对话 + 买卖坐骑 + 招揽互动的复合行为 |
| `npc_xiaoer.c` | `d/city/npc/xiaoer.c` | 11 KB | 店小二：**最常见的小店 NPC**，`init` 提供菜单/收钱/给物的交易闭环 |

**关注点（迁移规律）：**
- 继承 `inherit NPC;` / `inherit F_DEALER;`（商人）等
- `init()` 里用 `add_action("...", "...")` 注册玩家可触发的动词 → 对应 Kantele 的房间内交互/合并命令
- `set("combat_exp"...)`、`set_temp("..."...)` 设定数值；`random_move`/`会逃跑`等行为 flag

---

### 3. `class_npc/` —— 门派宗师/传奇人物（Class NPC）

宗师是"移动的武功库"：通常带全套职业技能、拜师/出师流程、门派内功、专属战斗 AI，往往还挂钩任务。

| 文件 | 原始路径 | 大小 | 为何选它 |
|---|---|---|---|
| `class_generate_chinese.c` | `kungfu/class/generate/chinese.c` | 67 KB | **全项目 sizeof 前几的巨型文件**：通用"中式宗师"生成器，一次覆盖武学/拜师/收徒/出师/教功夫等大量通用逻辑 |
| `class_wudang_zhang.c` | `kungfu/class/wudang/zhang.c` | 40 KB | 张三丰：具体门派宗师范本（武当），比生成器更"写死"、更贴近真实一个宗师长什么样 |

**关注点（迁移规律）：**
- `inherit F_MASTER;`（师父）+ 门派 id + `skill()` 技能表 + `teach/ask` 交互
- 是**最高复杂度的人形对象**：技能清单 + 拜师限制 + 专属心法，迁移时要映射到 Kantele 的 `Character + Skills + quest`

---

### 4. `skill/` —— 武功/技能（Skill）

技能是整个游戏的成长核心，有海量同构文件（1448 个），规律性最强，最适合"数据驱动"迁移。

| 文件 | 原始路径 | 大小 | 为何选它 |
|---|---|---|---|
| `skill_dugu-jiujian.c` | `kungfu/skill/dugu-jiujian.c` | 25 KB | 独孤九剑：**顶级内功/剑法复合**技能，`valid_learn`/`valid_enable`/`type`/`exert` 全覆盖 |
| `skill_taiji-quan.c` | `kungfu/skill/taiji-quan.c` | 15 KB | 太极拳：中等复杂度常见范式，适合看"普通技能怎么定义" |

**关注点（迁移规律）：**
- 顶层 `inherit SKILL;`（技能基类）
- `valid_learn`（能否学）/`valid_enable`（能否装备为当前武功）/`type`（内功/空手/兵刃）/`actions`（招式与伤害系数）/`exert`（运功）/`valid_force`（内功兼容）
- 同构极强 → 非常适合拆成**配置表**而非手写 Elixir 模块

---

### 5. `item/` —— 物品/道具对象（Item/Obj）

物品是背包里、房间里、商人卖的道具。继承物品基类，靠 `meta` 描述属性。

| 文件 | 原始路径 | 大小 | 为何选它 |
|---|---|---|---|
| `item_wudu_qianzhumiji.c` | `d/wudu/obj/qianzhumiji.c` | 11 KB | 千蛛秘籍：**书/秘籍类**物品（可 `study`/读），演示"物品=数据+技能入口" |
| `item_shaolin_map.c` | `d/shaolin/obj/map.c` | 8 KB | 少林地图：带 `init` 展示/查询的**功能物品** |
| `item_yinzhen.c` | `d/beijing/obj/yinzhen.c` | 7 KB | 银针：细器类道具，演示 `set("unit"/"weight"/"long")` 等元数据 |

**关注点（迁移规律）：**
- 继承物品基类 + `set("name"/"long"/"unit"/"weight"/"value")`
- 对 Kantele 的映射重点是 `item_name`/描述/`meta`（重量、品类、可读性等）
- 检查是否带 `init`（可交互）——有即需额外逻辑而非纯数据

---

### 6. `weapon/` —— 武器（clone 模板）

`clone/weapon/` 是典型的"模板克隆"：一份定义被大量复制实例化。文件**小而规整**，是物品里最有规律的一类。

| 文件 | 原始路径 | 大小 | 为何选它 |
|---|---|---|---|
| `weapon_changjian.c` | `clone/weapon/changjian.c` | 0.7 KB | 长剑：标准武器 clone，`set("weapon_prop", ...)` + `hit_func`，是"一件武器怎么写"的最小完整样本 |

**关注点（迁移规律）：**
- `set("weapon_prop", ([damage:.., type:..]))` 武器属性
- 少量文件定义全类型（剑/刀/枪/杖……），迁移 = 参数化模板

---

### 7. `mount/` —— 坐骑（clone 模板）

| 文件 | 原始路径 | 大小 | 为何选它 |
|---|---|---|---|
| `mount_ziliuma.c` | `clone/horse/ziliuma.c` | 0.8 KB | 紫骝马：坐骑模板样本（对应 Kantele Batch 6 的 `ride/unride` 物品） |

**关注点（迁移规律）：**
- `set("ridable", 1)` 之类标记 + 移动/负重字段 → 与已实现的 `ride` 命令的 `"ridable"`/`"type"=>"mount"` 判定对应

---

### 8. `daemon/` —— 守护进程 Daemon（全局单例服务）

Daemon 是"活的单例服务"：所有对象都可 `…D->函数()` 调用它。代表系统级逻辑，不直接是"世界数据"。

| 文件 | 原始路径 | 大小 | 为何选它 |
|---|---|---|---|
| `daemon_combatd.c` | `adm/daemons/combatd.c` | 79 KB | **全项目最大的战斗守护进程**：伤害结算/命中/武器判定，是战斗规则的"总装订本" |

**关注点（迁移规律）：**
- 这类**不是世界数据**而是系统服务 → 对应 Kantele 的模块/服务（如 `CombatEvent`、`Vitals`），不参与 d 目录搬运，但要阅读理解战斗数值如何算出来
- 提取其中**数值公式与规则**，落到 Elixir 常量/函数

---

### 9. `system_npc/` —— 系统/后台 NPC

| 文件 | 原始路径 | 大小 | 为何选它 |
|---|---|---|---|
| `system_npc_luban.c` | `adm/npc/luban.c` | 100 KB | **全项目最大的 .c 文件**：鲁班——集制造/打造/修复/坐骑/器械于一身的巨型系统 NPC，几乎所有"制作/升级"逻辑都在这 |

**关注点（迁移规律）：**
- 系统级服务型 NPC：跨越"人 + 制作系统 + 装备强化"多种职责
- 阅读它 = 读懂整个"打造/升级"供应链，迁移时拆成多个 Elixir 服务/命令

---

### 10. `inherit/` —— 基础继承类（Base Class）

基础类是"父对象"，普通房间/NPC/物品都 `inherit` 它们。看懂基类才看得懂实例。

| 文件 | 原始路径 | 大小 | 为何选它 |
|---|---|---|---|
| `inherit_char_npc.c` | `inherit/char/npc.c` | 15 KB | **NPC 基类**：所有非玩家生物的父类，字段（combat_exp/气血等）+ 生存/死亡/对话/AI 骨架 |
| `inherit_room_pigroom.c` | `inherit/room/pigroom.c` | 21 KB | **复杂房间基类**（赌/竞技场类），演示房间还能挂游戏规则 |

**关注点（迁移规律）：**
- 基类定义了实例可用的全部 `set` 字段与函数 → 是建"字段映射表"的最佳来源
- `inherit/char/npc.c` ≈ Kantele 的 `NonPlayer` / `Character` 抽象

---

### 11. `feature/` —— 特性模块（Feature）

Feature 是"横向能力"：被继承后给对象注入某类逻辑，是 LPC 的 Mixin 概念。

| 文件 | 原始路径 | 大小 | 为何选它 |
|---|---|---|---|
| `feature_damage.c` | `feature/damage.c` | 15 KB | 伤害特性：`receive_damage/wound` 等，战斗落点 |
| `feature_attack.c` | `feature/attack.c` | 13 KB | 攻击特性：`attack()`/`hit_ob()`/敌人管理 |

**关注点（迁移规律）：**
- 对应 Kantele 的 `Vitals`/`Combat`/`CombatEvent` 等模块
- 迁移重点是**落盘/伤害/死亡/敌人列表**这些定义与公式

---

### 12. `condition/` —— 条件/状态（Condition）

状态是"挂在对象上、随时间生效"的效果（中毒、内息、阵法）。

| 文件 | 原始路径 | 大小 | 为何选它 |
|---|---|---|---|
| `condition_poison.c` | `inherit/condition/poison.c` | 14 KB | 中毒状态：计时 + 每 tick 扣血 + 解除条件，条件类最典型 |

**关注点（迁移规律）：**
- DIOS 状态机（tick 触发 `update_condition`）→ 对应 Kantele 的定时/状态事件
- 迁移关键是"持续时间 + 每周期副作用 + 解除逻辑"的数据化

---

### 13. `quest/` —— 任务（Quest）

| 文件 | 原始路径 | 大小 | 为何选它 |
|---|---|---|---|
| `quest_song-yupai.c` | `d/minimal_world/quest/song-yupai.c` | 4.6 KB | 送玉佩：完整闭环小任务（取物 → 交物 → 领赏），演示任务触发/中间态/完成条件 |

**关注点（迁移规律）：**
- 任务普遍依赖 `questd/ultra_questd` 守护进程 + NPC 对话 `ask` 分支
- 迁移时要拆成"任务模板 + 步骤状态 + 奖励"配置，并接上对话系统

---

## 四、迁移规律初步总结（供后续 d/h 转换器参考）

1. **按同构文件建"配置表"，不手写模块** —— 最典型：`skill/`（1448 份）、`clone/weapon`（每件 0.7KB）。这类应收敛为数据（UCL/JSON），用统一加载器生成 Kantele 对象。
2. **`inherit` 基类是映射第一来源** —— 各实例的字段/函数都来自 `inherit/char/npc.c`、物品/房间基类等；先读基类建"字段表"，再套到实例。
3. **房间 = 结构三件套**（short/long/exits）+ 可选 objects/触发；**NPC/物品 = 数据 + 可选 init 交互**。判断"纯数据 or 带逻辑"看有没有 `init`/`setup`/`hit_func` 等函数。
4. **Daemon / system_npc / feature / class 属"系统逻辑"**，不参与 d 目录世界搬运，但要单独提炼数值公式与规则落到 Elixir 服务。
5. **任务/条件/阵法依赖跨对象协议**（questd、condition 状态机、NPC `ask`），迁移需同时处理消息/事件侧，而不只是单个对象。

---

## 五、如何用这套样本

- 阅读某类型前，先开 `inherit/` 那条基类找"字段/函数词典"；
- 再对比同类型 2 份样本（1 大 1 小）找共性 vs 特例；
- 最后用共性推出该类型的"迁移模板"，特例作为边界情况补进转换器。
