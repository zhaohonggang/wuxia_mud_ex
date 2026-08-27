# LPC 参照仓库目录全貌

> 仓库：`C:\files\git\mud`（FluffOS + LPC《炎黃群俠傳》，**只读参照，勿改**）
> 扫描时间：2026-08-26

---

## 核心游戏逻辑

| 目录 | 规模 | 作用 |
|---|---|---|
| **kungfu/** | ~2000+ 文件 | 武功系统核心：`class/` 470 门派类、`skill/` 1449 招式/技能、`condition/` 70 状态效果、`special/` 33 特殊武功 |
| **d/** | ~8000+ 文件 | **大世界地图**：72 个区域（北京/长安/成都/少林/武当/峨眉/明教/丐帮/古墓/桃花岛/侠客岛/雪山/血刀/星宿/神龙/白驼/大理/襄阳/扬州/苏州/杭州/泉州/福州/广州/昆明/兰州/西宁/拉萨/乌鲁木齐等），含房间/NPC/物品/任务 |
| **world/** | 10 文件 | 世界构建脚本：`area/` 区域索引、`builds/` 建筑模板 |
| **clone/** | ~1200+ 文件 | 可克隆对象实例：`weapon/` 兵器、`armor/cloth/` 防具、`book/` 秘籍、`medicine/food/herb/` 消耗品、`npc/` 基础 NPC 模板、`fam/` 门派 NPC、`shop/` 商店货物、`quest/questob/` 任务物品、`horse/` 坐骑、`poison/` 毒药、`tattoo/` 纹身等 |
| **inherit/** | ~90 文件 | 继承基类：`char/` 角色、`room/` 房间、`weapon/` 兵器、`armor/` 护甲、`item/` 物品、`skill/` 技能、`condition/` 状态、`medicine/misc/` 杂项 |
| **feature/** | 49 文件 | 核心特性模块：`combat.c` 战斗、`skill.c` 技能系统、`mapping.c` 映射、`team.c` 组队、`fight.c` 战斗流程、`save.c` 存档、`virtual.c` 虚拟对象等 |
| **std/** | 85 文件 | 标准命令/对象：移动、战斗、社交、物品操作、容器等基础命令 |
| **cmds/** | 356 文件 | 玩家/巫师/管理员命令分层：`usr/` 71 玩家基础、`skill/` 61 技能、`std/` 85 标准、`wiz/` 42 巫师、`arch/` 48 建筑、`adm/` 28 管理、`imm/` 6 仙人、`chat/` 11 聊天、`test/` 4 测试 |

---

## 系统/驱动层

| 目录 | 内容 |
|---|---|
| **adm/daemons/** | 161 个守护进程：`combatd.c` 战斗公式、`finger.c` 玩家查询、`chatd.c` 频道、`logind.c` 登录、`simul_efun.c` 模拟外部函数等 |
| **include/** | 35 个头文件：`combat.h`、`skill.h`、`armor.h`、`weapon.h`、`condition.h`、宏定义等 |
| **mudcore/** | FluffOS 驱动子模块：配置样例、changelog |
| **bin/** | 预编译二进制：`driver.exe`、`lpcc.exe`（编译器）、`lpcshell.exe`、`json2o.exe` |

---

## 内容/数据

| 目录 | 内容 |
|---|---|
| **data/** | 运行时数据：`.env/.env.example`、编译后的数据库对象（`.o`） |
| **doc/** | LPC 参考文档：`efuns/` 516 个外部函数说明、`applies/` 104 个 apply 接口、`lpc/` 语法文档 |
| **docs/** | 项目文档：`LPC_Language_FluffOS.md` 语言标准、`migration_to_wuxia_mud_ex_analysis.md` 迁移分析 |
| **help/** | 186 个帮助条目：属性、技能、门派、任务、地图等游戏内帮助 |
| **b/** | 3 个剧情线区域：屠龙/倚天/玉笔峰 |

---

## 运行/工具

| 目录 | 内容 |
|---|---|
| **log/** | 10 个日志文件/目录：`debug.log`、`error.log`、`catch_error/`、`dns_master/` |
| **dump/** | 转储目录 |
| **tools/** | `mssp_tester.py`、`websocket_client.py` |
| **ai_service/** | 可选 Python AI NPC 服务（5 文件） |
| **www/** | WebSocket 客户端入口 `index.html` |
| **backup/** | 备份目录 |
| **shadow/** | 3 个测试/阴影文件 |
| **u/** | 空目录（用户自定义区） |

---

## 迁移参考重点

| LPC 源 | Kantele 目标 | 用途 |
|---|---|---|
| `kungfu/skill/` | `lib/kantele/combat/skills/` | 技能/招式实现对照 |
| `d/` | `data/world/*.ucl` | 大世界数据（柳溪镇是 `d/minimal_world/` 子集） |
| `inherit/` | `lib/kantele/` 基类 | 角色/房间/物品/技能继承体系对照 |
| `feature/skill.c` `feature/combat.c` | 核心公式文档 | 战斗/技能/成长公式权威来源 |
| `cmds/usr/` `cmds/skill/` `cmds/std/` | 命令迁移清单 | 玩家可见命令对照 |
| `adm/daemons/combatd.c` | `lib/kantele/combat/engine.ex` | 战斗引擎公式权威来源 |
| `doc/efuns/` `doc/applies/` | `docs/LPC_Language_FluffOS.md` | 驱动 API 参考 |
