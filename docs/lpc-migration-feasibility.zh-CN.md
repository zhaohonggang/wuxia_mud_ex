# LPC 迁移可行性分析：自动翻译 vs 人工分析 vs 无需迁移

> 基于 `C:\files\git\mud` 目录扫描结果，针对迁移到 Kantele (Elixir/ExVenture/Kalevala) 的可行性分级。
> 评估维度：结构化程度、业务逻辑复杂度、运行时依赖、目标框架映射度。

---

## 一、可编写翻译程序自动转换（结构化数据为主）

### 1. 世界区域数据 → `data/world/*.ucl`

| 源目录 | 文件数 | 可翻译内容 | 翻译策略 |
|---|---|---|---|
| `d/` (72区域) | ~8000 | 房间定义、出口连接、NPC 生成点、物品刷新、区域元数据 | **完全可自动化**：LPC `create()` 中的 `set("short")`、`set("long")`、`set("exits")`、`set("objects")` 等 `set()` 调用模式固定，正则/AST 提取即可生成 UCL room/zone/npc/item 块 |

**关键模式**：
```lpc
// LPC 房间典型结构
void create() {
    set("short", "柳溪镇广场");
    set("long", "这是柳溪镇的中心广场……");
    set("exits", ([ "north": __DIR__"guangchang_n", "south": __DIR__"shanlu" ]));
    set("objects", ([ __DIR__"npc/yepo": 1, __DIR__"npc/yezhu": 2 ]));
}
```
→ 直接映射为 UCL `room { id, name, desc, exits, npcs, items }`

**工具链建议**：Python + `lark` 解析器或 Tree-sitter LPC grammar，提取 `set()` 键值对、`mapping` 字面量、`__DIR__` 相对路径。

---

### 2. 物品基础属性 → `data/world/*.ucl` item meta

| 源目录 | 文件数 | 可翻译内容 | 翻译策略 |
|---|---|---|---|
| `clone/weapon/` | 45 | 武器基础属性：名称、伤害、技能类型、重量、价值、材质 | **完全可自动化**：`set("weapon_prop/damage", N)`、`set("skill_type", "sword")` 等固定键 |
| `clone/armor/`, `clone/cloth/` | 42+ | 护甲属性：防御、部位、重量、价值 | 同上 |
| `clone/book/` | 140 | 秘籍：可学技能、等级上限、消耗 | `set("book_skill", "liuxin-jian")` 等固定键 |
| `clone/medicine/`, `clone/food/`, `clone/herb/` | 30+ | 消耗品：回气/精/内、属性加成 | `set("cure_qi", N)`、`set("add_str", 1)` 等固定键 |

**工具链**：同世界数据，提取 `create()` 中所有 `set()` 调用。

---

### 3. NPC 基础模板 → `data/world/*.ucl` npc meta + `data/brains/*.ucl`

| 源目录 | 文件数 | 可翻译内容 | 翻译策略 |
|---|---|---|---|
| `clone/npc/` | 10 | 基础属性：名称、种族、性别、等级、基础属性、初始装备 | **可自动化**：`set("race", "human")`、`set("combat_exp", 10000)` 等 |
| `clone/fam/` | 129 | 门派 NPC：师父技能列表、教学配置、门派归属 | **大部分配置可自动化**，`teach_skills` 列表需人工核对映射 |

---

### 4. 帮助文档 → 可选导入

| 源目录 | 文件数 | 策略 |
|---|---|---|
| `help/` | 186 | 纯文本，可批量转 Markdown 作为游戏内帮助系统数据源 |

---

## 二、需 AI + 程序员分析源码迁移（含业务逻辑/复杂控制流）

### 1. 核心系统公式 → `lib/kantele/combat/engine.ex` 等

| 源文件 | 迁移目标 | 为什么需人工 |
|---|---|---|
| `feature/combat.c` | 战斗引擎公式 | 涉及随机数、多轮计算、buff 叠加、闪避/招架判定、内力消耗、招式选择算法——**非声明式，需语义理解并重写为 Elixir 函数式风格** |
| `feature/skill.c` | 技能系统核心 | `valid_learn`、`improve_skill`、`can_improve_skill`、`map_skill` 等核心逻辑，包含经验门槛 `lvl³/10`、潜能池 `potential-learned_points`、互斥检查 `valid_force` |
| `adm/daemons/combatd.c` | 战斗守护进程公式 | `skill_power`、`valid_power`、`do_attack`、`calculate_damage` 完整伤害链——**必须对照 LPC 逐行语义移植**，测试需回归对比 |
| `feature/attribute.c` | 属性成长/上限公式 | `query_max_qi`、`query_neili_limit`、`query_jingli_limit`、`improve_neili` 等天花板计算 |

**AI 辅助点**：代码翻译（LPC→Elixir 语法）、边界条件枚举、测试用例生成。
**程序员决策点**：架构映射（如 LPC 全局变量→Elixir GenServer 状态）、性能优化、Elixir 惯用语重构。

---

### 2. 技能/招式实现 → `lib/kantele/combat/skills/*.ex`

| 源目录 | 规模 | 为什么需人工 |
|---|---|---|
| `kungfu/skill/` | 1449 文件 | 每个招式/技能是独立 `.c`，包含 `query_action()` 返回动作映射、`valid_enable()`、`valid_learn()`、`practice_cost()`、`exert_list()`、`perform_list()` 等回调——**需逐个语义映射为 Kantele Skill behaviour 实现**，招式伤害公式、特殊效果（吸内、封穴、连击）需人工还原 |
| `kungfu/class/` | 470 文件 | 门派类定义门派技能列表、师父教学逻辑、门派特有招式组合——**需建立门派配置数据结构**，而非逐行翻译 |

**策略**：先建「技能元数据提取器」自动导出技能 ID、类型、enable 用法、招式列表、perform 列表；再由人工/半自动填充 Elixir 实现模板。

---

### 3. 任务系统 → `lib/kantele/character/tasks/` + UCL quest 定义

| 源目录 | 规模 | 为什么需人工 |
|---|---|---|
| `d/*/quest*.c`、`clone/questob/` | 数百 | 任务流程含状态机、NPC 对话分支、物品交付条件、时间限制、分支奖励——**强业务逻辑，需理解剧情设计后重写为 UCL 任务定义 + 通用任务引擎** |
| `clone/questob/` | 48 | 任务专用物品，含触发脚本 |

---

### 4. 复杂命令 → `lib/kantele/character/commands/*.ex`

| 源目录 | 命令示例 | 为什么需人工 |
|---|---|---|
| `cmds/skill/` | `learn.c` `practice.c` `exert.c` `perform.c` `enable.c` `study.c` `respirate.c` `closed.c` | 含多步校验链（潜能/精力/经验/互斥/师徒关系/房间限制/忙碌状态）、事件发送/接收（`skills/learn` → `skills/teach` → `skills/learn-result`）、动态消息生成——**需映射为 Kantele Command + SkillsEvent 流程** |
| `cmds/std/` | `fight.c` `kill.c` `halt.c` `flee.c` `give.c` `follow.c` `team.c` `ride.c` | 战斗状态机、组队逻辑、坐骑系统、跟随移动——**需对接 Combat/Room/Channel 子系统** |
| `cmds/usr/` | `hp.c` `finger.c` `recall.c` `wimpy.c` `alias.c` `save.c` `suicide.c` | 玩家状态查询、自动逃跑阈值、别名系统、手动存档、角色删除确认流程 |

---

### 5. 状态/条件系统 → `lib/kantele/character/conditions/`

| 源目录 | 规模 | 说明 |
|---|---|---|
| `kungfu/condition/` | 70 | 中毒、封穴、眩晕、加速、护体等状态效果，含 `condition_type`、间歇伤害、持续时间、免疫/解除条件——**需设计通用 Condition 框架并逐个实现** |
| `inherit/condition/` | 3 | 基类定义 |

---

### 6. 守护进程/全局服务 → Kantele GenServer/Service

| 源文件 | 功能 | 迁移策略 |
|---|---|---|
| `adm/daemons/chatd.c` | 频道广播、历史记录 | 映射为 `Kantele.Chat` GenServer + Channel 机制（已部分有） |
| `adm/daemons/finger.c` | 玩家查询服务 | 映射为 `FingerService` |
| `adm/daemons/logind.c` | 登录验证、多重登录限制 | 映射为认证流程 |
| `adm/daemons/simul_efun.c` | 模拟外部函数库 | 部分常用函数迁为工具模块，部分废弃（Elixir 标准库替代） |

---

### 7. 虚拟对象/动态生成 → 世界生成器

| 源文件 | 功能 |
|---|---|
| `feature/virtual.c` | 虚拟房间/物品生成（如迷宫、随机地牢） |
| `feature/mapping.c` | 坐标地图渲染、寻路 |

---

## 三、不可能或不需要迁移

| 目录/文件 | 理由 |
|---|---|
| **`mudcore/`** | FluffOS 驱动核心（C 代码），Kantele 跑在 BEAM 上，驱动层完全不同 |
| **`bin/` `binaries/`** | 预编译驱动二进制，无关游戏逻辑 |
| **`include/*.h`** | C 头文件/宏定义，Elixir 无对应概念；常量迁为 Elixir 模块属性 |
| **`doc/efuns/` `doc/applies/` `doc/lpc/`** | 驱动 API 文档，仅供参考，不迁移 |
| **`backup/` `dump/` `log/` `shadow/` `u/`** | 运行时产物/临时/备份/空目录 |
| **`data/*.o`** | 编译后的数据库对象二进制，源码在别处 |
| **`b/`** | 剧情线区域（屠龙/倚天/玉笔峰），属于 `d/` 大世界子集，按区域数据统一迁移即可 |
| **`adm/etc/` `adm/npc/` `adm/single/` `adm/single/`** | 管理员工具/一次性脚本/测试 NPC，非核心玩法 |
| **`cmds/adm/` `cmds/arch/` `cmds/wiz/` `cmds/imm/` `cmds/chat/` `cmds/test/`** | 管理员/建筑/巫师/测试命令，**不面向玩家**，Kantele 管理后台另行设计（或复用 ExVenture Admin） |
| **`inherit/Socket.c` `inherit/insect.c` `inherit/worm.c`** | 底层网络/测试继承类，BEAM 原生支持 |
| **`tools/`** | 外部测试工具，不迁移 |
| **`ai_service/`** | 可选 Python 服务，独立部署，不翻译 |
| **`www/index.html`** | 旧 WebSocket 客户端入口，Kantele 另行前端 |

---

## 四、迁移优先级与建议路线图

| 阶段 | 内容 | 方式 | 预估工作量 |
|---|---|---|---|
| **Phase 0** | 世界数据提取器（`d/` → UCL） | 编译器/脚本 | 2-3 周 |
| **Phase 1** | 物品/NPC 基础属性提取器（`clone/` → UCL meta） | 同套工具 | 1 周 |
| **Phase 2** | 核心公式手工迁移（combat/skill/attribute） | 程序员+AI 结对 | 4-6 周 |
| **Phase 3** | 技能/招式半自动迁移（提取元数据→模板填充） | 提取器+人工审核 | 6-8 周 |
| **Phase 4** | 命令系统迁移（优先玩家核心命令） | 程序员逐个实现 | 4-6 周 |
| **Phase 5** | 任务/条件/守护进程/高级系统 | 分模块攻克 | 长期迭代 |

---

## 五、工具链原型建议

```python
# 伪代码：LPC create() 提取器核心逻辑
import re
from dataclasses import dataclass

@dataclass
class RoomDef:
    id: str
    name: str
    desc: str
    exits: dict[str, str]
    npcs: list[tuple[str, int]]  # (npc_path, count)
    items: list[tuple[str, int]]

def parse_lpc_room(filepath: str) -> RoomDef:
    content = read_file(filepath)
    # 1. 提取 set("key", value) 调用
    sets = re.findall(r'set\("(\w+)"\s*,\s*([^)]+)\)', content)
    # 2. 解析 mapping 字面量：([ "key": "value" ])
    # 3. 处理 __DIR__ 相对路径
    # 4. 归一化为 RoomDef
    ...
```

**关键技术点**：
- LPC 语法子集解析：`set()`、`mapping`、`array`、`__DIR__`、`inherit`、`::create()` 调用链
- 处理 `#include`、宏展开、条件编译
- 增量式：先跑通 `d/minimal_world/` 再推全量

---

## 六、决策矩阵速查

| 文件类型 | 自动翻译 | AI辅助翻译 | 人工重写 | 放弃 |
|---|---|---|---|---|
| `d/*.c` 房间/区域 | ✅ | | | |
| `clone/*` 物品/NPC 基础属性 | ✅ | | | |
| `help/*` | ✅ (文本转换) | | | |
| `feature/combat.c` `skill.c` `attribute.c` | | ✅ | ✅ | |
| `adm/daemons/combatd.c` | | ✅ | ✅ | |
| `kungfu/skill/*.c` | | ✅ (元数据提取) | ✅ (实现填充) | |
| `kungfu/class/*.c` | | | ✅ (配置化) | |
| `cmds/usr/*.c` `cmds/skill/*.c` `cmds/std/*.c` | | ✅ (框架生成) | ✅ (逻辑实现) | |
| `cmds/adm/arch/wiz/imm/chat/test/*.c` | | | | ✅ |
| `inherit/*.c` | | | 部分映射为基类 | 大部分 ✅ |
| `mudcore/` `bin/` `include/` `data/*.o` `log/` `dump/` `backup/` `shadow/` `u/` `tools/` `www/` `ai_service/` | | | | ✅ |
