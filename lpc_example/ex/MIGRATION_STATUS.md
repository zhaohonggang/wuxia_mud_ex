# LPC Example 迁移现状与差距记录

> 生成时间: 2026-08-27
> 共 22 个样本目录，已完成 2 个真实迁移
>
> ⚠️ **重要约束**: 所有迁移仅限于 `C:\files\git\wuxia_mud_ex\lpc_example\ex` 目录内修改，**不实际接入游戏**。产物为纯数据 UCL + 纯函数 Elixir 模块，供开发参考与框架能力设计使用。

---

## 已完成真实迁移 (2/22)

| 目录 | 产物 | 状态 |
|------|------|------|
| `class_generate_chinese` | `class_generate_chinese.ex` + `name_generator.ex` + `sects.ex` + `.ucl` + `FRAMEWORK_REQUIREMENTS.md` | ✅ 真实迁移：完整姓名生成算法 + 39 门派原型 |
| `class_wudang_zhang` | `zhang_sanfeng.ucl` + `class_wudang_zhang.ex` + `zhenwu_jian.ucl` + `FRAMEWORK_REQUIREMENTS.md` | ✅ 真实迁移：13 问询处理器、5 关收徒、真武剑、九阳解锁、战斗 AI |

---

## 伪 REAL / 存根 (9/22) —— **有 UCL + .ex，但 .ex 只有骨架无实现**

### 1. item_yinzhen (银针)
- **LPC**: 7307 字节 / ~200 行
- **现有**: `item_yinzhen.ucl` (856B) + `yinzhen.ex` (1719B, 39 行)
- **缺失**: `do_heal` 完整判定链 (9 步检查)、成功率随机、治伤/刺伤分支、neili/jing 消耗、技能提升、60s 冷却
- **需移植函数**: `check_skill/1`, `check_handing/1`, `check_target/2`, `check_busy/1`, `check_force/2`, `check_vitals/2`, `check_cd/2`, `heal/2`, `fail_wound/2`
- **框架依赖**: `eff_qi` 双血条、start_busy、improve_skill、is_killing、receive_wound
- **计划**: 先补全纯函数实现，再写 FRAMEWORK_REQUIREMENTS.md

### 2. item_wudu_qianzhumiji (千蛛万毒手秘笈)
- **LPC**: 11387 字节 / ~324 行
- **现有**: `.ucl` (997B) + `qianzhumiji.ex` (985B, 24 行)
- **缺失**: 3 绝技解锁流程 (suck/zhugu/wan)、门槛检查 (skill 100/130/220, force 150/200/300, neili 1000/1500/3500)、潜能消耗、随机成功率 (5/150/200)、call_out 延迟授予、improve_skill
- **需移植函数**: `research/2`, `du/2`, `yanjiu/2`, `unlock_suck/1`, `unlock_zhugu/1`, `unlock_wan/1`
- **框架依赖**: InteractiveItem 持久化、can_perform 绝招解锁、skill 等级联动
- **计划**: 移植 3 条绝技解锁完整逻辑

### 3. npc_xiaoer (店小二)
- **LPC**: 11215 字节 / ~300 行
- **现有**: `npc_xiaoer.ucl` (810B) + `xiaoer.ex` (1136B, 23 行) —— 仅有 `exchange_cost/1` 查表
- **缺失**: `accept_object` (收金币 set rent_paid / 收尸体)、`greeting` 随机招呼、 `do_drop` 丢尸体被赶、 `do_exchange` 积分兑换 (state/jifen)、`heart_beat` 满座清场、valid_leave 拦截
- **需移植函数**: `accept_object/2`, `greeting/1`, `handle_drop/2`, `handle_exchange/2`, `heart_beat/1`, `valid_leave/2`
- **框架依赖**: NPC 通用钩子、玩家 jifen 字段、room 清单与 move、drop 拦截、receive_damage/unconcious
- **计划**: 最复杂 NPC，分阶段：先 accept_object + greeting，再 do_exchange + heart_beat

### 4. npc_horseboss (马车老板/坐骑向导)
- **LPC**: 13333 字节 / ~400 行
- **现有**: `npc_horseboss.ucl` (815B) + `horseboss.ex` (870B, 19 行) —— 仅骨架
- **缺失**: 完整多阶段向导 (choose -> 选种 -> 性别 -> ID -> 名字 -> 描述 -> 生成)、20 种坐骑类型表、随机属性生成器、坐骑实例化写文件 (`VERSION_D->append_sn`)、whistle 召唤绑定、金钱检查 (100 gold)、training 技能门槛 (30 级)
- **需移植函数**: `do_choose/1`, `get_subtype/2`, `get_gender/2`, `get_id/2`, `get_name/2`, `get_desc/2`, `build_pet/1`, `check_legal_id/1`, `check_legal_name/2`, `random_pet_stats/1`
- **框架依赖**: input_to 多步输入机制、随机坐骑生成器、物品实例持久化、玩家背包/骑乘系统、金钱系统
- **计划**: 核心是状态机 + 生成器，先做纯函数版状态机，再补生成器

### 5. room_qianting (大门状态机)
- **LPC**: 6371 字节 / ~180 行
- **现有**: `room_qianting.ucl` (1268B) + `qianting.ex` (1377B, 31 行) —— 骨架
- **缺失**: 动态 exit 管理 (gate 开关控制 north/zoudao.south)、10s 自动关门 timer、valid_leave 权限检查 (老家人/主人/许可者)、gate 状态持久化、推门/关门消息广播
- **需移植函数**: `push/1`, `close/1`, `auto_close/1`, `valid_leave/2`, `add_north_exit/1`, `remove_north_exit/1`, `check_permission/1`
- **框架依赖**: Room 动态 exit、call_out/定时器、valid_leave 钩子、room 状态持久化
- **计划**: 最小自包含，先做完整状态机纯函数

### 6. weapon_changjian (长剑) —— **纯 UCL，无 .ex**
- **LPC**: 678 字节 / ~20 行
- **现有**: `weapon_changjian.ucl` (868B)
- **缺失**: 行为模块 (可选：wield/unwield 消息、damage_type 覆盖、特殊 hit_ob)
- **需新建**: `weapon_changjian.ex` (若需特殊行为)
- **框架依赖**: 标准武器即可，若无特殊行为可不建 .ex
- **计划**: 验证 UCL 完整性，决定是否需要 .ex

### 7. mount_ziliuma (紫驴马) —— **纯 UCL，无 .ex**
- **LPC**: 849 字节 / ~25 行
- **现有**: `mount_ziliuma.ucl` (1383B)
- **缺失**: ridable 加载器适配、wield/unwield 消息
- **需新建**: `mount_ziliuma.ex` (若需特殊骑乘逻辑)
- **框架依赖**: ridable 字段解析、mount 系统
- **计划**: 验证 UCL，补 ridable loader 说明

### 8. item_shaolin_map (少林地图) —— **纯 UCL，无 .ex**
- **LPC**: 8217 字节 / ~200 行 (大量 ASCII 长字符串)
- **现有**: `item_shaolin_map.ucl` (759B) —— 长字符串已省略
- **缺失**: read_map 行为 (若原文有 do_read)、使用次数限制
- **需新建**: `item_shaolin_map.ex` (如有交互)
- **框架依赖**: 物品使用钩子、长文本存储
- **计划**: 读原文确认是否有交互逻辑，无则仅补全 UCL 长文本

### 9. quest_song-yupai (宋玉佩任务物品) —— **纯 UCL，无 .ex**
- **LPC**: 4647 字节 / ~120 行
- **现有**: `quest_song-yupai.ucl` (1384B)
- **缺失**: turn_in 任务流程行为模块 (收物给奖、状态检查)
- **需新建**: `quest_song-yupai.ex` (复用现有 turn_in 框架)
- **框架依赖**: Quest 系统、turn_in 机制
- **计划**: 复用框架 turn_in，补行为模块

---

## 完全未迁移 / 框架核心逻辑 (11/22) —— **需全量算法移植**

| 目录 | LPC 大小 | 核心逻辑 | 难度 | 优先级 |
|------|---------|---------|------|--------|
| `inherit_char_npc` | 529 行 | NPC 基类全行为 (accept_fight/hit/kill/ansuan/touxi/ask/object/need_accede, heal_self, chat, return_home, scan, check_family) | 高 | P1 |
| `inherit_room_pigroom` | 675 行 | 完整拱猪牌游戏 (52 张牌、叫牌、出牌、吃牌、算分、自动打) | 高 | P2 |
| `feature_damage` | 637 行 | 伤害核心 (receive_damage/wound/heal/curing, unconcious/revive/die, heal_up, 食物水分) | 高 | P1 |
| `feature_attack` | 537 行 | 战斗/攻击核心 (enemy/killer/want_kill, fight_ob/kill_ob, action 系统, auto_fight) | 高 | P1 |
| `condition_poison` | 419 行 | 毒条件引擎 (mixed_poison, do_effect, dispel, jing/qi_damage, update_condition) | 高 | P1 |
| `daemon_combatd` | 2295 行 | 战斗引擎全量 (damage_msg, skill_power AP/DP/PP, do_attack 完整解析, fight 心跳, killer_reward) | 极高 | P3 |
| `system_npc_luban` | 2000+ 行 | 玩家建房系统 (合同/表单/私有房间状态机、向导生成房间文件、钥匙管理、巫师审批) | 高 | P2 |
| `room_wudu_liandu` | 279 行 | 五毒炼毒房 (6 配方、材料检查、定时回调、成功率、经验奖励) | 中 | P1 |
| `room_qiyuan2` | 702 行 | 围棋/五子棋引擎 (棋盘状态、坐标系、手谈规则、提子/劫/禁入、悔棋) | 高 | P2 |
| `skill_dugu-jiujian` | 657 行 | 独孤九剑技能 (22 招式 + 3 无招、valid_damage/parry/ob、破气/总破式进阶) | 高 | P1 |
| `skill_taiji-quan` | 426 行 | 太极拳技能 (25 招式、极意动态属性、valid_combine、hit_ob 冲力蓄力) | 高 | P1 |

---

## 总体迁移计划

### Phase 1: 补全「伪 REAL」9 个 (预计 5-8 轮)
| 顺序 | 目录 | 预计轮次 | 备注 |
|------|------|---------|------|
| 1 | `room_qianting` | 1 | 最小自包含，状态机纯函数 |
| 2 | `item_yinzhen` | 1 | 单一 do_heal 流程 |
| 3 | `item_wudu_qianzhumiji` | 1 | 3 绝技解锁逻辑清晰 |
| 4 | `npc_horseboss` | 2 | 状态机 + 生成器分离 |
| 5 | `npc_xiaoer` | 2-3 | 最复杂 NPC，分阶段 |
| 6 | `weapon_changjian` | 0.5 | 验证 UCL，可选 .ex |
| 7 | `mount_ziliuma` | 0.5 | 验证 UCL，ridable 说明 |
| 8 | `item_shaolin_map` | 0.5 | 确认无交互则仅补 UCL |
| 9 | `quest_song-yupai` | 0.5 | 复用 turn_in 框架 |

### Phase 2: 框架核心逻辑 11 个 (预计 15-25 轮)
| 批次 | 目录 | 依赖关系 | 备注 |
|------|------|---------|------|
| 2A | `feature_damage`, `feature_attack`, `condition_poison` | 相互依赖，战斗三基石 | 先定数据结构与 Effect 类型 |
| 2B | `inherit_char_npc` | 依赖 2A | NPC 基类行为挂载到 2A 能力上 |
| 2C | `skill_dugu-jiujian`, `skill_taiji-quan` | 依赖 2A | 技能钩子挂载到 CombatEngine |
| 2D | `room_wudu_liandu`, `room_qiyuan2` | 依赖 2A/2B | 房间交互/游戏逻辑 |
| 2E | `system_npc_luban`, `inherit_room_pigroom` | 独立系统 | 建房/牌类，可并行 |
| 2F | `daemon_combatd` | 全部依赖 | 最后整合，或拆分为多模块 |

---

## 迁移标准 (Definition of Done)

每个目录完成需满足：
1. ✅ 原 `.c` 完整读取并理解
2. ✅ `.ucl` 数据完整对应原文件字段
3. ✅ `.ex` 含**所有**原 LPC 函数对应的纯函数实现 (无占位)
4. ✅ `elixirc *.ex` 在容器 (Elixir 1.11) 通过编译
5. ✅ `FRAMEWORK_REQUIREMENTS.md` 列出该样本需的框架能力扩展
6. ✅ 关键算法有单元测试用例 (可选但推荐)

---

## 文件命名约定

```
<sample_dir>/
├── <sample>.c          # 原 LPC (只读对照)
├── <sample>.ucl        # 数据模板 (必有)
├── <sample>.ex         # 行为模块 (纯函数，必有)
├── <related>.ucl       # 关联物品/NPC/房间数据
└── FRAMEWORK_REQUIREMENTS.md  # 框架需求文档
```

---

## 下一步行动

**开始 Phase 1 第 1 个：`room_qianting`** —— 将大门状态机 (push/close/auto_close/valid_leave/动态 exit) 完整移植为纯函数，补全 FRAMEWORK_REQUIREMENTS.md。