# LPC 迁移框架能力需求汇总与落地可行性分析

> 汇总自 `lpc_example/ex/*/FRAMEWORK_REQUIREMENTS.md`（共 17 份），并按跨领域能力归并、去重。
> 更新时间: 2026-08-28
>
> 本文档回答两件事：
> 1. **汇总**：17 个真实行为迁移（`.ex` 纯函数）要在真实游戏（`lib/kantele`，Kalevala 引擎）里跑起来，框架一共需要哪些能力。
> 2. **可行性分析**：对照 `lib/kantele` 现状，逐项评估"已有 / 部分有 / 无"，给出分阶段实现步骤与优先级。

---

## 0. 结论先行（Executive Summary）

- 所有迁移在 `.ex` 里都是**纯函数/纯数据**（决策树、公式、状态机、数据表），已通过全量 smoke test（559 断言 / 18 suite 全绿）。
- 因此**大部分逻辑可直接搬运**，框架要补的不是"算法"而是"副作用宿主"与"对象模型"：临时存储、心跳/定时器、房间广播、指令分发、玩家对象字段、物品实例注册、战斗钩子。
- **核心缺口分四类**（按影响面排序）：
  1. **Player 对象模型欠缺字段/接口**：temp 存储、`performs/gongxian/shen/learned_points/potential`、exert/dazuo/give_mount 等动作。影响几乎所有样本。
  2. **战斗引擎钩子（Skill/Item/Combat）**：`valid_damage` / `hit_ob` / `practice_skill` / `perform_action_file` / `skill_improved` / `receive_damage/wound` 回调钻取。影响 `daemon_combatd`、`skill_*`、`feature_attack/damage`、`condition_poison`。
  3. **房间级能力**：动态 exits、跨房间 sync、每房定时器、`valid_leave` 钩子、房间座位/玩家清单、`add_action` 指令分发、房间广播原语。影响 `room_*`、`inherit_room_pigroom`、`npc_xiaoer`。
  4. **全局服务**：物品唯一注册表、师门/关系查询、定时代理（schedule_callback）、巫师批核、房屋系统、公告频道。影响 `class_wudang_zhang`、`system_npc_luban`、`npc_*`。

- **可行性评估**：所有 17 项能力在 Elixir/Kalevala 架构下**均可行（无架构性阻碍）**——它们都是成熟的 MUD 服务端常备能力，且其中大部分是 Kalevala/ExVenture 生态的既有原语（`Kalevala.Verb`、Room Events、`Context`）。
- **估算工作量**：P0（Player 模型 + 战斗钩子 + 房间交互载体）约为主干；P1/P2（服务层：唯一物品、师门、房屋、定时）单独立项。总体的"打通框架 + 依次接入"是**数月级**工程，而非一次性重构。

---

## 1. 能力汇总（按跨领域域归并）

下表将 17 份 FRAMEWORK_REQUIREMENTS 的能力**去重归并**为 8 大域。`需求数` 为出现该能力的样本文件数；括号为代表性样本。

### 1.1 Player / Character 对象模型
| 能力 | 需求数 | 说明（代表样本） |
|------|-------|-----------------|
| `get_temp/2` `put_temp/3` `set_temp/3` `add_temp/3` `delete_temp/2` `query_temp/2` | 12 | 临时/会话存储：冷却、炼制进度、巫骑向导、attempt_hit、rent_paid、棋位、战斗标记（几乎全部） |
| `jing/qi/neili/max_* / eff_*` 读写 + `receive_damage/3` `receive_wound/4` `receive_heal/4` `receive_curing/4` | 9 | 生命/伤口/内力体系（feature_damage、condition_poison、skill_*） |
| `start_busy/2` `busy?/1` `interrupt_me/1` | 8 | 动作锁定（yinzhen、wudu_qianzhumiji、liandu、combatd） |
| `send_message/2` `say/2` | 7 | 面向玩家的消息（feature_attack、inherit_char_npc） |
| `add_potential/2` `potential/1` `potential_limit/1` `improve_potential/2` `learned_points` `spend_learned_points/2` | 5 | 潜能/已学点数（wudu_qianzhumiji、liandu、class_wudang_zhang） |
| `exert/2` `dazuo/2` | 4 | 运功/打坐（inherit_char_npc、combatd） |
| `is_player?/1` `is_npc?/1` `is_character/1` `is_wizard?/1` `is_guarder?/1` `is_idle?/1` `living?/1` `alive?/1` | 9 | 类型/状态判定（贯穿） |
| `give_mount/2` `give_item/2` `give_object/2` | 4 | 发奖/骑宠（horseboss、xiaoer） |
| `item_exists?/1` `has?/2` | 3 | 背包/ID 唯一（horseboss、liandu） |
| `name/1` `id/1` `get_env/2` `environment/1` `environment_id/1` `faction/1` `shen/1` | 9 | 属性读取 |
| 新字段：`performs` `can_perform` `gongxian` `learned_points` `potential_limit` `family`(增强) | 6 | 模型扩展（class_wudang_zhang） |
| `this_player/0` `entire_dbase/1` `get_state/1` `set_state/2` | 4 | 会话/状态访问（feature_attack） |

### 1.2 Skill 技能系统
| 能力 | 需求数 | 说明 |
|------|-------|------|
| `get_level/2` | 11 | 等级查询（几乎所有） |
| `has?/2` | 5 | 是否掌握（yinzhen、wudu_qianzhumiji） |
| `improve/3` / `improve_skill/2` | 6 | 经验/技能成长 |
| `can_improve?/2` | 3 | 可提升门（liandu、poison） |
| `get_prepared/1` `get_mapped/2` `query_action/2` `get_skill/2` | 5 | 动作路由（taiji-quan、attack、inherit_char_npc） |
| perform 系统：`Player.has_perform?/2` `grant_perform/2` `Skill.perform_action_file/1` `can_perform?/2` | 5 | 绝技/特技解锁与路由（wudu_qianzhumiji、dugu-jiujian、class_wudang_zhang） |
| 行为钩子：`valid_damage` `hit_ob` `practice_skill` `skill_improved` `difficult_level` `valid_enable` `valid_learn` `valid_combine` `query_effect_parry` | 5 | 技能挂钩（combatd、skill_*） |
| 学习守门回调 `can_learn?/2` `on_learn/4` | 1 | wudang-jiuyang（class_wudang_zhang） |

### 1.3 Combat 战斗引擎
| 能力 | 需求数 | 说明 |
|------|-------|------|
| `do_attack/4`（hit/parry/dodge + 伤害管道） | 4 | 战斗核心（combatd、taiji-quan、attack） |
| `fight/2` `auto_fight/3` | 2 | 回合推进与自动战（feature_attack） |
| `announce/2` | 1 | 死亡/昏迷/复活公告（feature_damage） |
| `set_bhinfo/2` `damage_msg/2` `status_msg/1` | 2 | 战报/战斗信息（combatd、taiji-quan） |
| 玩家战斗状态：`is_killing/2` `is_fighting/1` `query_competitor/1` `set_competitor/2` `win/1` `lost/1` | 4 | 敌对/竞争（feature_attack、feature_damage） |
| 伤害公式/封顶/伤口（纯函数已落地，引擎接入） | 2 | valid_power/skill_power/do_damage（combatd） |
| PK 追踪：defeated_by/DPS/reward/killer_reward | 2 | feature_damage |

### 1.4 Room 房间级能力
| 能力 | 需求数 | 说明 |
|------|-------|------|
| 广播原语：`broadcast/3` `tell_room/2` `message_vision/1` `vision/2` | 8 | 房内/邻域消息 |
| `add_action/2` 指令分发（自定义动词） | 2 | 棋房 pigroom、房间动词 |
| 动态 exits + 跨房间 `sync_room/1` | 1 | qianting 大门开关同步 zoudao |
| 每房定时器 `set_timer/3` `cancel_timer/2` `call_out/2` | 2 | qianting 10s 关门、qiyuan2 清理 |
| `valid_leave/4` 移动拦截钩子 | 1 | qianting 权限门 |
| 房间座位/对弈状态 `%{black, white, game}` | 1 | qiyuan2 |
| 玩家清单 `present/1` `living/1` | 1 | qiyuan2 |
| 房间内物品 `move_object/2` `get_objects/1` | 2 | xiaoer 收尸/清场 |
| `no_fight?/1` | 1 | 禁战区（feature_attack） |

### 1.5 Item 物品系统
| 能力 | 需求数 | 说明 |
|------|-------|------|
| `is_currency?/1` `currency_amount/1` | 1 | 货币（xiaoer） |
| `is_corpse?/1` | 1 | 尸体（xiaoer） |
| `create/1` `get_skill_type/1` `get_actions/1` | 2 | 物品生成/兵刃属性（xiaoer、taiji-quan、attack） |
| `has?/2` `take/2` `destroy/1` | 2 | 消耗/检查（liandu） |
| 唯一物品注册表 `Item.Registry`（locate/transfer/destroy_unique） | 1 | 真武剑（class_wudang_zhang） |
| 装备恢复 `heal_qi` `add_eff_qi` | 1 | 针灸（yinzhen） |

### 1.6 NPC / 交互
| 能力 | 需求数 | 说明 |
|------|-------|------|
| 可执行问询 `AskHandler`（check/execute + Effects） | 1 | 收徒/授技/给物（class_wudang_zhang） |
| 战斗 AI `chat_chance_combat`/`chat_msg_combat` + `Combat.AI.decide_action` | 2 | 张三丰等（class_wudang_zhang、inherit_char_npc） |
| 状态机向导（多步 temp） | 1 | 巫骑（horseboss） |
| 不可击倒钩子 `on_unconcious`（override: die/revive/ignore） | 1 | 张三丰（class_wudang_zhang） |
| 师门/关系查询 `Family.my_disciples` 等 | 1 | class_wudang_zhang |
| NPC 国籍/声望：`Alignment.title/1` `good?/evil?` | 1 | class_wudang_zhang |

### 1.7 时间 / 调度 / 全局服务
| 能力 | 需求数 | 说明 |
|------|-------|------|
| 心跳 `set_heart_beat/2` `heart_beat/0` + 定时 tick | 5 | 回复 heal_up、毒 tick、自动战、NPC 心跳清场 |
| 延迟回调 `schedule_callback/3` `call_out/2` | 2 | 炼制完成、复活、自动关门 |
| 房间复生/死亡 `DEATH_ROOM`/`start_death` `revive/3` `reincarnate/1` | 2 | feature_damage |
| 公告频道 `Channel.broadcast/3` | 1 | pigroom rumor |
| 巫师批核 `Wizard.form/1` | 1 | luban 房 |
| 房屋系统 `Npc.House`（create_room/create_key/demolish） | 1 | system_npc_luban |
| `DATA_DIR` 路径映射 + Persona `check_legal` | 1 | luban |

### 1.8 纯数据/纯函数（已落地，仅需宿主）
| 能力 | 需求数 | 说明 |
|------|-------|------|
| 围棋/五子棋引擎 | 1 | qiyuan2（纯函数已过测） |
| 拱猪牌局状态机 | 1 | pigroom（纯函数已过测） |
| 25 招太极拳表 / 24+3 独孤九剑招表 | 2 | skill_* |
| 毒引擎 mixed_poison/do_effect/dispel/公式 | 1 | condition_poison |
| 6 配方炼制 | 1 | wudu_liandu |
| 19 种坐骑物种表 / 8 兑换表 / 5 问询-收徒链 | 3 | horseboss/xiaoer/class_wudang_zhang |
| 姓名生成 + 39 门派 | 1 | class_generate_chinese |
| 伤害/威力公式（纯函数） | 1 | daemon_combatd |

---

## 2. 可行性分析（对照 `lib/kantele` 现状）

### 2.1 现状基线
`lib/kantele` 是一个 Kalevala 驱动的 MUD：有 `Kantele.World.Room`（Callbacks、Room Events 路由、Verb 系统）、`Kantele.Character.*`（commands/views/controllers）、`Kantele.Combat`（Skills 注册表 + `Character.Combat` 控制器/状态追踪）、`Kantele.Communication`（频道）。已接入的武学仅 2 个（`liuxin-jian`、`liuxi-neigong`），技能/物品/战斗仍处早期。

**重要**：LPC 迁移产物（`lpc_example/ex/*.ex`）为**纯函数模块**，与 `lib/kantele` **尚未打通**。接线工作 = 在各自领域引入副作用宿主，把纯函数接上去。

### 2.2 各域可行性分级

| 域 | 可行性 | 理由 |
|----|--------|------|
| Player 临时存储 temp | ★★★ 低难度 | 已有 `Player`/`Character` 持久层；temp 可入会话（`Context`/ETS 或 Player 进程字典），不落库。 |
| Player 字段扩展（performs/gongxian/shen/learned_points/potential） | ★★★ 低难度 | Ecto schema 加列即可；`shen`/`family` 已有基础。 |
| 属性/资源读写（jing/qi/neili/eff_*） | ★★★ 低难度 | `Kantele.Character.Stats` 已存在，补 eff_*/伤口/上限即可。 |
| Skill 注册表扩展 | ★★★ 低难度 | 已有 `Kantele.Combat.Skills` 注册表；新增 18+ 技能模块 + 招表即可。 |
| Skill 行为钩子（valid_damage/hit_ob/practice_skill/perform_action_file） | ★★☆ 中难度 | `Combat` 引擎需在伤害/练习管道钻回调；现 `Skills.DefaultActions` 已有雏形，需标准化回调协议。 |
| Combat 引擎（do_attack/fight/announce/set_bhinfo） | ★★☆ 中难度 | `Character.Combat.*` 已有控制器骨架；需把 `daemon_combatd` 公式与 feature_attack/damage 状态机并入。 |
| Room 广播/指令分发/动态 exits/sync/定时器/valid_leave | ★★☆ 中难度 | `Room.Events` + `Kalevala.Verb` 可承载；动态 exits 需在 Room schema 增加 `dynamic_exits` + 状态重写；跨房 sync 与每房定时器为新增原语。 |
| Item 注册表/唯一物品 | ★★☆ 中难度 | 新增 `Kantele.Item.Registry`（GenServer/ETS）；物品实例已有 `Items`/`item_instances` 表。 |
| NPC 问询/收徒/多步向导 | ★★☆ 中难度 | 新增 `AskHandler` 行为 + Effects 执行器；框架 `NPC` 尚属雏形。 |
| 全局调度（心跳/延迟回调/复活/公告） | ★★☆ 中难度 | Kalevala 有 `set_timer`/`call_out` 类原语可用；需统一封装。 |
| 师门关系/房屋系统/巫师批核 | ★☆☆ 高难度 | 全新服务层 + 数据模型（family graph、house tables、wizpanel）。 |

**综合评价**：无任何一项存在**架构性不可行**。全部能力均属于 MUD 服务端常规能力，且在 Elixir/Kalevala 生态有成熟范式。瓶颈在**工程量**而非**可行性**。

---

## 3. 建议实现步骤（分阶段）

采用"**先立对象模型与副作用宿主 → 再接战斗 → 再补服务层**"的依赖顺序，保证每阶段可编译、可测试、可回滚。

### Phase 1 — Player 模型与通用副作用宿主（P0，约 40% 工作量）
**目标**：让"纯函数"能落到真实玩家对象上。
1. **temp 存储**：在 `Character` 添加会话级 temp（ETS/进程字典，不落库）：`get_temp/put_temp/set_temp/add_temp/delete_temp/query_temp`。
2. **字段扩展**：`playable_characters` 加 `performs(map)`、`gongxian(int)`、`shen(int)`、`learned_points(int)`、`potential(potential_limit)`；`Stats` 补 `eff_jing/eff_qi/max_*` 上限与 `receive_damage/4`、`receive_wound/5`、`receive_heal/4`、`receive_curing/4`、`start_busy`、`add_potential`、`improve_potential`、`send_message`。
3. **动作接口**：`give_item`、`give_mount`、`exert`、`dazuo`、`item_exists?`、`is_*?` 判定。
4. **对齐**：为 12 个依赖 temp/资源读写的样本逐一接上（yinzhen / wudu_qianzhumiji / liandu / horseboss / xiaoer / attack）。
5. **验收**：每个样本用容器 smoke_test 在"真实 Player 上下文"重跑通过。

### Phase 2 — 战斗引擎与 Skill 钩子（P0/P1，约 30%）
**目标**：让公式与状态机接入真实战斗。
1. 把 `daemon_combatd` 公式并入 `Kantele.Combat.Engine.do_attack`（hit/parry/dodge/伤害/封顶/伤口）。
2. 标准化 `Kantele.Combat.Skill` 行为：`valid_enable` `valid_learn` `valid_combine` `query_action` `valid_damage` `hit_ob` `practice_skill` `perform_action_file` `skill_improved` `difficult_level` `query_effect_parry`。
3. 新增 18+ 技能模块（taiji-quan、dugu-jiujian、wudang 系等），复用 `.ex` 招表。
4. 接入 `Combat.announce`、`set_bhinfo`、`fight/2`、`auto_fight/3`、`is_killing`、competitor、`feature_attack` 状态机、`feature_damage` 的昏迷/死亡/复活/心跳回复（heal_up）。
5. **验收**：一个新技能（如 taiji-quan）+ 一场真实对战日志正确。

### Phase 3 — Room 交互载体与 NPC 互动（P1，约 20%）
**目标**：让房间动作与 NPC 问询可玩。
1. Room：`add_action` 动词分发、`tell_room/message_vision/broadcast`、`dynamic_exits` + `sync_room`、`set_timer/cancel_timer`、`valid_leave` 钩子、座位/玩家清单、`no_fight?`、`move_object/get_objects`。
2. 接入 `room_qianting`（动态门）、`room_qiyuan2`（棋座）、`inherit_room_pigroom`（拱猪）、`npc_xiaoer`、`skill_*` 的 perform 路由。
3. NPC：`AskHandler` 行为 + Effects 执行器（set_perform/add_gongxian/improve_skill/give_item/recruit/message）、`Combat.AI.decide_action`、`on_unconcious` 钩子、多阶段绝技、`Family` 师门查询、`Alignment`。
4. 接入 `class_wudang_zhang`、`inherit_char_npc`、`condition_poison`（毒 tick 挂到心跳）。
5. **验收**：玩家可在棋苑下棋、在拱猪房开局、与张三丰完成"问鹤嘴劲→收徒→学真武剑"完整链。

### Phase 4 — 全局服务层（P2/P3，约 10%）
**目标**：补齐跨场景服务，可选但需上线前完成。
1. `Kantele.Item.Registry`（唯一物品可持续登记/追溯/转移）→ 真武剑、任务物品。
2. `Kantele.House` 房屋服务 + 巫师批核面板 → system_npc_luban。
3. 定时/调度统一封装（复活、炼制完成、自动关门、NPC 心跳清场、公告频道）。
4. 坐骑系统（`Kantele.Mount`）→ horseboss whistle。

### Phase 5 — 整合与回归（贯穿）
- 把所有接入纳入统一 smoke/集成测试；保留现有 `lpc_example/ex` 纯函数套件作为"参照真值"，集成层断言其结果一致。
- 全量跑 `elixir test_runner.exs` + 主工程 `mix test`。

---

## 4. 优先级总表（按影响样本数 × 复杂度）

| 优先级 | 能力 | 影响样本 | 复杂度 |
|--------|------|----------|--------|
| P0 | Player temp 存储 | 12 | 低 |
| P0 | 属性/资源/伤口读写 | 9 | 低 |
| P0 | 战斗 do_attack + 伤害公式 | 4 | 中 |
| P0 | Skill 注册表 + 行为钩子 | 5 | 中 |
| P0 | 玩家字段扩展(performs/gongxian/shen/learned_points) | 6 | 低 |
| P1 | Room 广播/动态 exits/定时/valid_leave/add_action | 8 | 中 |
| P1 | 物品唯一注册表 | 1 | 中 |
| P1 | 可执行问询 AskHandler | 1 | 高 |
| P1 | 战斗 AI 执行 | 2 | 中 |
| P2 | 师门/关系查询 | 1 | 中 |
| P2 | 铁布衫心跳 heal_up/毒 tick/调度 | 5 | 中 |
| P2 | 房屋系统 + 巫师批核 | 1 | 高 |
| P3 | 坐骑系统 / 公告频道 / 不可击倒钩子 / 多阶段绝技 | 3 | 中低 |

> 排序依据：`§1` 各域"需求数" + 现有 `lib/kantele` 已有程度。P0 为打通主干，P1/P2 为可玩性，P3 为世界丰富度。

---

## 5. 附录：各样本 → 主接入点映射

| 样本 | 主要缺口域 | 建议接入位置 |
|------|-----------|--------------|
| daemon_combatd | Combat 引擎公式 | `Kantele.Combat.Engine` |
| feature_damage | 昏迷/死亡/复活/心跳 | `Kantele.Character.Combat.*` + 心跳 |
| feature_attack | 敌对/自动战状态机 | `Kantele.Character.Combat` mixin |
| condition_poison | 毒 tick + dispel | `Kantele.Character.Conditions` + 心跳 |
| skill_taiji-quan / skill_dugu-jiujian | Skill 钩子 + 招表 | `Kantele.Combat.Skills.*` |
| item_yinzhen | 针灸动作 + 冷却 | `Kantele.Item` verb + Player temp |
| item_wudu_qianzhumiji | 绝技解锁链 | `Kantele.Skill.Perform` + Player.performs |
| room_qianting | 动态门 + sync + 定时器 | `Kantele.World.Room` |
| room_qiyuan2 / inherit_room_pigroom | 多玩家座位 + 指令分发 | `Kantele.World.Room` + `Kalevala.Verb` |
| room_wudu_liandu | 炼制调度 + 配方 | `Kantele.World.Room` + schedule_callback |
| npc_xiaoer | 收尸/兑换/心跳清场 | `Kantele.NPC` + Room |
| npc_horseboss | 坐骑向导 | `Kantele.Mount` + Player temp |
| class_wudang_zhang | 问询/收徒/唯一物品/师门/战斗AI | `Kantele.NPC.AskHandler` + `Item.Registry` + `Family` |
| system_npc_luban | 房屋 + 巫师批核 | `Kantele.House` |
| class_generate_chinese | 姓名/门派（纯数据） | 直接并入配置 `Kantele.Characters` |

---

*本文档是 `lpc_example/ex` 各子目录 FRAMEWORK_REQUIREMENTS.md 的汇总裁决入口；实现时以各子目录文档的细节为准。*
