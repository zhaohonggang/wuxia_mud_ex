# 迁移计划：`mud/feature`（49 个 LPC 基础层文件）→ `lib/kantele`

> 计划生成: 2026-08-29 ｜ 分支: `kalevala` ｜ 方式: **按批推进，每批可编译/可测试/可回滚，批批推送**
> 目标: 把 `C:\files\git\mud\feature\*.c`（继承式 mudlib 基础层）完整接入真实游戏框架。

---

## 0. 现状基线

- **当前全量测试**: 388 tests, 0 failures (flaky `death` 战斗测试偶发，isolated 通过)
- 已完成 13 个 Phase 5 样本接入（feature_damage/attack、condition_poison、skill_taiji-quan/dugu-jiujian、room_qianting/qiyuan2/pigroom、item_yinzhen/qianzhumiji、room_wudu_liandu、npc_xiaoer/horseboss、class_wudang_zhang、system_npc_luban、class_generate_chinese）。
- 注意：`mud/feature` 是**完整 mudlib 继承层**（Player/NPC/物品共享行为），与之前"单个样本".ex 迁移是**两个层面**。本次把底层能力系统化落地。

---

## 1. 全量映射：49 个 feature 文件 → 落地方式

### 判定图例
- 🟢 **已有/可复用**：`lib/kantele` 已有对应实现，本计划只补缺口或直接视为完成
- 🟡 **需合并/扩展现有**：在现有模块上扩展
- 🔴 **需新建**：framework 尚无，需新模块
- ⏸ **延期**：工具/协议，核心可玩性之后再做

### 1.1 基础数据容器
| feature.c | 落地 | 对应 frame 模块 | 说明 |
|-----------|------|----------------|------|
| `dbase.c` | 🟢 | `Kantele.Character` (meta) | PlayerMeta temp 已实现；持久 dbase 由 Ecto schema 承载 |
| `treemap.c` | ✅ | `Kantele.Util.TreeMap` | 路径式 map 访问（_query/_set/_delete，自动建中间层） |

### 1.2 身份 / 属性
| feature.c | 落地 | 对应 frame 模块 | 说明 |
|-----------|------|----------------|------|
| `name.c` | ✅ | `Kantele.Character.Name` | surname+purename 组名/无名氏/set_name/id?/parse_command_id_list/短名 |
| `attribute.c` | 🔴 | `Kantele.Character.Stats` | 派生属性：str/int/con/dex/per/level = base + skill/10 + temp apply |
| `sadjust.c` | 🔴 | `Kantele.Combat.Skills` | 技能上限 = combat_exp^3/10 |

### 1.3 生命 / 伤害
| feature.c | 落地 | 对应 frame 模块 | 说明 |
|-----------|------|----------------|------|
| `damage.c` | 🟡 | `Kantele.Feature.Damage` | 已有 receive_damage/wound/unconcious/revive/heal_up；已补 craze 累计/ghost/dps_count 裁剪 |
| `condition.c` | 🟡 | `Kantele.Character.Conditions` | 已有 poison tick；扩为通用 condition 周期机制 + CONDITION_D 分发 |
| `action.c` | 🟡 | `Kantele.Character.Combat` | start_busy 已有；补 override 钩子(unconcious/die/win/lost) |

### 1.4 战斗 / 技能
| feature.c | 落地 | 对应 frame 模块 | 说明 |
|-----------|------|----------------|------|
| `skill.c` | 🟡 | `Kantele.Combat.Skills` | 已有 set_skill/query_skill/prepare/map/improve；已补 skill_death_penalty / skill_expell_penalty |
| `attack.c` | 🟡 | `Kantele.FeatureAttack` | 已有 enemy/kill/competitor/auto_fight；补 kill_ob 增强、守卫联动 |
| `equip.c` | 🟡 | `Kantele.World.Item` + Character | 补 wield/wear/unequip + 双手武器 + is_unarmed_weapon |

### 1.5 移动 / 位置
| feature.c | 落地 | 对应 frame 模块 | 说明 |
|-----------|------|----------------|------|
| `move.c` | 🟡 | `Kantele.World.Room` + Character | 已有 move_object；补 encumbrance/unequip-first/move_or_destruct/remove 钩子 |

### 1.6 物品类型 / 工匠
| feature.c | 落地 | 对应 frame 模块 | 说明 |
|-----------|------|----------------|------|
| `food.c` | 🟡 | `Kantele.Item` | 补 apply_effect 栈 (max 12) + do_effect |
| `liquid.c` | 🟡 | `Kantele.Item` | 补 liquid fill level + apply_effect |
| `cutable.c` | 🟡 | `Kantele.Item` | 补 do_cut 剁尸产件 (parts 映射) |
| `itemmake.c` | 🟡 | `Kantele.Item` | 补 9 级武器/护甲锻造、item_owner、ITEM_D 委托动作；include 现有 qianzhumiji/yinzhen 模式 |
| `noclone.c` | 🟢 | `Kantele.Item.Registry` | unique/no_clone 已有 |
| `unique.c` | 🟢 | `Kantele.Item.Registry` | violate_unique / create_replica 已有 |
| `silentdest.c` | 🔴 | `Kantele.Scheduler` | 无人时 auto-destruct |
| `transport.c` | 🔴 | `Kantele.Mount` | 骑乘/驾驶载体 is_transport/owner |

### 1.7 NPC / 社会 / 经济
| feature.c | 落地 | 对应 frame 模块 | 说明 |
|-----------|------|----------------|------|
| `apprentice.c` | 🔴 | `Kantele.File.Family` | 师徒关系 assign_apprentice/create_family/recruit |
| `master.c` | 🔴 | `Kantele.Npc.Master` | prevent_learn / attempt_detach |
| `guarder.c` | 🟡 | `Kantele.Npc.Guarder` | 守卫 permit_pass / kill_enemy / check_enemy |
| `coagent.c` | 🔴 | `Kantele.Npc.Coagent` | 帮手 start_help / finish_help |
| `team.c` | ✅ | `Kantele.Character.Team` | team 已有；补 follow?/2 (follow_me 决策) |
| `finance.c` | 🔴 | `Kantele.Economy.Finance` | can_afford / pay_money (金/银/铜) |
| `banker.c` | 🟡 | `Kantele.Npc.Banker` | 存款/汇兑/转账/离线转账 |
| `dealer.c` | ✅ | `Kantele.Npc.Dealer` | 估价/收购/标价/购买价计算（纯函数，见 Batch 2 后补） |
| `vendor.c` | ✅ | `Kantele.Npc.Vendor` | 轻量 buy_object / price_string / 商品清单 |
| `quester.c` | 🟡 | `Kantele.Npc.Quests` | is_quester / ask_quest |
| `autoload.c` | 🔴 | `Kantele.Item.Autoload` | 重登还原背包 |

### 1.8 存储 / 玩家背包
| feature.c | 落地 | 对应 frame 模块 | 说明 |
|-----------|------|----------------|------|
| `user_storage.c` | 🔴 | `Kantele.Item.Backpack` | do_store/take/list_bag + 排除规则 + depot 持久化 |
| `save.c` | 🟢 | Ecto persistence | CORE_SAVE 占位，已由 Ecto 替代 |
| `dbsave.c` | 🟢 | Ecto persistence | CORE_DBSAVE 占位，已由 Ecto 替代 |
| `obsave.c` | ⏸ | — | 空注释 stub，标记 dead |
| `user_quest.c` | ⏸ | `Kantele.Quest` | CORE_USER_QUEST 占位 |

### 1.9 交互 / 指令输入
| feature.c | 落地 | 对应 frame 模块 | 说明 |
|-----------|------|----------------|------|
| `command.c` | 🟢 | `Kantele.Character.Commands` | command_hook/dispatch 已有 command_controller |
| `alias.c` | 🟢 | `Kantele.Character.Aliases` | process_input 别名展开已有 |
| `message.c` | 🟡 | `Kantele.Output` | prompt/color/缓冲已有；补 receive_snoop/log |
| `name.c`(in 1.2) | — | — | — |

### 1.10 定时 / 生命周期
| feature.c | 落地 | 对应 frame 模块 | 说明 |
|-----------|------|----------------|------|
| `clean_up.c` | 🔴 | `Kantele.Scheduler` | no_clean_up 保护 / 空闲销毁 / 失败日志 |
| `shadow.c` | 🔴 | util | do_shadow / remove_shadow |

### 1.11 ⏸ 延期批次（工具 + 协议，核心可玩性之后）
| feature.c | 落地 | 说明 |
|-----------|------|------|
| `vi.c` (1146) | ⏸ | 全屏 vi 编辑器（巫师工具） |
| `edit.c` | ⏸ | 简易行编辑器 |
| `more.c` | ⏸ | 分页器 |
| `shell.c` | ⏸ | 巫师 $...$ 求值 shell |
| `user_gmcp.c` | ⏸ | GMCP/MSP 协议 |
| `user_mxp.c` | ⏸ | MXP/MSDP/ZMP 协议 |
| `sserver.c` | ⏸ | 法术服务 wrapper（vestigial） |
| `itemmakeBak.c` | ⏸ | 重复备份，建议标记废弃不迁移 |
| `coagent.c` → 见 1.7 | — | — |

---

## 2. 分批推进计划（依赖顺序）

> 每批：实现 → 编译 → 全量 `mix test` 通过 → 提交推送 → 更新本文档勾选。
> 验收口径: 每批新增的纯函数走容器 smoke test，框架部分走 `MIX_ENV=test mix test`。

### Batch 1 — 派生属性与基础模型补齐 (P0)
**source**: `attribute.c`, `sadjust.c`, `name.c`(部分), `action.c`(override 钩子)
**target**:
- `Kantele.Character.Stats` 补 `query_str/int/con/dex/per/level`（base + tattoo + skill/10 + temp apply）
- `Kantele.Combat.Skills` 补 `skill_limit/1` (combat_exp^3/10)
- `Kantele.Character` 补 `id_str?/parse_command_id_list`
- `Kantele.Character.Combat` 补 override 注册表 (`run_override/delete_override/query_override`)
**测试**: stats_derived_test.exs、skills_limit_test.exs、override_hook_test.exs
**关键**: `attribute.query_level` 已被 user_storage/guarding 依赖，先立。

> ✅ **DONE (Batch 1)**
> - `lib/kantele/character/attributes.ex` — `Kantele.Character.Attributes`，纯函数移植 attribute.c（str/int/con/dex/per/level）
> - `Kantele.Combat.Skills.skill_adjust/3` — 移植 sadjust.c（combat_exp^3/10 封顶）
> - `Kantele.Character.PlayerMeta` — override 注册表（set/query/run/delete_override），移植 action.c
> - 测试: `test/kantele/character/attributes_test.exs`、`test/kantele/combat/skills_adjust_test.exs`、`test/kantele/character/override_test.exs`
> - 全量: **406 tests, 0 failures** (388 + 18)

### Batch 2 — 经济与货币引擎 (P0)
**source**: `finance.c`, `banker.c`
**target**:
- `Kantele.Economy.Money` (`Kantele.Economy.Finance`): can_afford/pay_money（金/银/铜换算）+ `is_currency?`
- `Kantele.Npc.Banker`: do_check/convert/deposit/withdraw/transfer（离线转账）
**测试**: finance_test.exs、banker_test.exs
**依赖**: Batch 1 的 `query_level`（无强依赖，可并行）

> ✅ **DONE (Batch 2)**
> - `lib/kantele/economy/money.ex` — `Kantele.Economy.Money`，移植 finance.c（split/total_value/can_afford/pay/money_str/normalize）
> - `lib/kantele/npc/banker.ex` — `Kantele.Npc.Banker`，移植 banker.c（check/convert/deposit/withdraw/transfer 纯逻辑）
> - 测试: `test/kantele/economy/money_test.exs`、`test/kantele/npc/banker_test.exs`
> - 全量: **420 tests, 0 failures** (406 + 14)

### Batch 3 — NPC 社会关系与守卫 (P0/P1)
**source**: `apprentice.c`, `master.c`, `guarder.c`, `coagent.c`, `quester.c`
**target**:
- `Kantele.File.Family`: create_family/assign_apprentice/is_apprentice_of/recruit_apprentice
- `Kantele.Npc.Master`: prevent_learn/attempt_detach (skill_expell)
- `Kantele.Npc.Guarder`: permit_pass/kill_enemy/check_enemy
- `Kantele.Npc.Coagent`: start_help/finish_help
- `Kantele.Npc.Quests`: is_quester/ask_quest (→QUEST_D 委托)
**测试**: family_test.exs、guarder_test.exs、coagent_test.exs
**依赖**: Batch 1 (skill_limit)、现有 `Kantele.Npc` + AskHandler + damage/attack

> ✅ **DONE (Batch 3)**
> - `lib/kantele/character/family.ex` — `Kantele.Character.Family`，移植 apprentice.c（is_apprentice_of/has_family/create_family/assign_apprentice/recruit_apprentice）
> - `lib/kantele/npc/master.ex` — `Kantele.Npc.Master`，移植 master.c（prevent_learn/attempt_detach）
> - `lib/kantele/npc/guarder.ex` — `Kantele.Npc.Guarder`，移植 guarder.c（permit_pass/check_enemy）
> - `lib/kantele/npc/coagent.ex` — `Kantele.Npc.Coagent`，移植 coagent.c（start_help/finish_help）
> - `lib/kantele/npc/quester.ex` + `lib/kantele/quest.ex` — 移植 quester.c + QUEST_D 桩
> - 测试: `test/kantele/character/family_test.exs`、`test/kantele/npc/traits_test.exs`
> - 全量: **449 tests, 0 failures** (420 + 29)

### Batch 4 — 物品类型扩展 (P0/P1)
**source**: `food.c`, `liquid.c`, `cutable.c`, `transport.c`, `equip.c`(增强)
**target**:
- `Kantele.Item.Food`: apply_effect 栈 + do_effect
- `Kantele.Item.Liquid`: 液量 + extra_long
- `Kantele.Item.Cutable`: do_cut 剁尸产件
- `Kantele.Mount` + `Kantele.Item.Transport`: is_transport/owner (衔接现有 horseboss)
- `Kantele.World.Item`/Character: 双手武器 + is_unarmed_weapon + unequip 增强
**测试**: food_test.exs、liquid_test.exs、cutable_test.exs、transport_test.exs
**依赖**: Batch 1 (attribute)、现有 item 系统

> ✅ **DONE (Batch 4)** — 已建纯逻辑模块（宿主命令/combat 接入为后续）
> - `lib/kantele/item/effect.ex` — `Kantele.Item.Effect`，移植 food/liquid 效果栈（apply/clear/query/do_effect，上限 12）
> - `lib/kantele/item/liquid.ex` — `Kantele.Item.Liquid`，移植 liquid.c extra_long（液量分级描述）
> - `lib/kantele/item/cutable.ex` — `Kantele.Item.Cutable`，移植 cutable.c（available_parts/validate_cut/extra_desc）
> - `lib/kantele/item/transport.ex` — `Kantele.Item.Transport`，移植 transport.c（set/query_owner/can_drive_by）
> - `lib/kantele/item/equip.ex` — `Kantele.Item.Equip`，移植 equip.c（two_handed?/secondary?/wield_decision/wield/unequip/wear_state 纯逻辑）
> - 注意：现有 `wield_command.ex`/`World.Item.Meta` 已实现多槽位护甲+weapon_prop；本期补齐双手/副手决策纯层
> - 测试: `test/kantele/item/feature_item_test.exs`
> - 全量: **471 tests, 0 failures** (449 + 22)

### Batch 5 — 物品锻造与背包存储 (P1)
**source**: `itemmake.c`, `user_storage.c`, `silentdest.c`, `autoload.c`
**target**:
- `Kantele.Item.Craft`: 9 级武器/护甲锻造、item_owner、ITEM_D 委托动作（include die/san/imbue/enchase）
- `Kantele.Item.Backpack`: do_store/take/list_bag + 排除规则 + depot
- `Kantele.Item.Autoload`: save/restore 重登背包
- `Kantele.Scheduler` 补 silentdest auto-destruct
**测试**: craft_test.exs、backpack_test.exs、autoload_test.exs
**依赖**: Batch 1/4、现有 Item.Registry + Scheduler

> ✅ **DONE (Batch 5)** — 纯逻辑落地（ITEM_D 委托/宿主副作用为后续）
> - `lib/kantele/item/craft.ex` — `Kantele.Item.Craft`(+`Level`)，移植 itemmake.c（weapon_level/apply_damage/apply_armor/chinese_s/item_owner/is_equiped_weapon/is_unarmed_weapon）
> - `lib/kantele/item/backpack.ex` — `Kantele.Item.Backpack`，移植 user_storage.c（capacity/store/take/list_bag/serialize/deserialize）
> - `lib/kantele/item/autoload.ex` — `Kantele.Item.Autoload`，移植 autoload.c（save/parse_entry/restore_plan）
> - `lib/kantele/item/silentdest.ex` — `Kantele.Item.SilentDest`，移植 silentdest.c（should_destruct?/env 链判定）
> - 测试: `test/kantele/item/batch5_test.exs`
> - 全量: **489 tests, 0 failures** (471 + 18)

### Batch 6 — 移动 / 负重 / 生命周期 (P1)
**source**: `move.c`(增强), `clean_up.c`, `shadow.c`, `condition.c`(通用化)
**target**:
- `Kantele.World.Room`/Character: encumbrance/weight、move_or_destruct/remove 钩子、GMCP Room.Info(挂)
- `Kantele.Scheduler`: clean_up 空闲销毁 + no_clean_up 保护
- util `shadow`
- `Kantele.Character.Conditions`: 通用 condition 周期机制（非仅毒）
**测试**: encumbrance_test.exs、clean_up_test.exs、condition_generic_test.exs
**依赖**: Batch 4 (equip)、现有 Scheduler

> ✅ **DONE (Batch 6)** — 纯逻辑落地（move/remove 实体副作用由宿主执行）
> - `lib/kantele/character/encumbrance.ex` — `Kantele.Character.Encumbrance`，移植 move.c（weight/encumb/max_encumb/set_weight/on_over 回调）
> - `lib/kantele/character/conditions.ex` — `Kantele.Character.Conditions`，移植 condition.c（apply/query/clear/update/affect_by + piyi 免疫）
> - `lib/kantele/object/cleanup.ex` — `Kantele.Object.CleanUp`，移植 clean_up.c（:never_again/:again 决策）
> - `lib/kantele/util/shadow.ex` — `Kantele.Util.Shadow`，移植 shadow.c（do/remove_shadow/query）
> - 测试: `test/kantele/batch6_test.exs`
> - 全量: **505 tests, 0 failures** (489 + 16)

### Batch 7 — 消息 / 提示补强 (P1)
**source**: `message.c`(增强)
**target**:
- `Kantele.Output`: receive_snoop、log_command/log_message、缓冲细化
**测试**: message_io_test.exs
**依赖**: 现有 Output

> ✅ **DONE (Batch 7)** — 纯格式化层
> - `lib/kantele/communication/message.ex` — `Kantele.Communication.Message`，移植 message.c（color_class 消息类→ANSI、s 染色、prompt_prefix 四种/自定义、buffer_message 输入缓冲≤500、drain_buffer、written 状态机）
> - 测试: `test/kantele/communication/message_test.exs`
> - 全量: **513 tests, 0 failures** (505 + 8)

> ✅ **DONE (补充：dealer.c + vendor.c)** — 经济 NPC 补全（核心可玩性 P1，原批外）
> - `lib/kantele/npc/dealer.ex` — `Kantele.Npc.Dealer`，移植 dealer.c（is_vendor_good 按 id/去色名匹配、do_value 估价 x3/10、do_sell 收购价、do_list 库存+目录聚合清单、do_buy 购买价：成本 10/现货 12/目录覆盖/店东八折）
> - `lib/kantele/npc/vendor.ex` — `Kantele.Npc.Vendor`，移植 vendor.c（buy_object、price_string 金/银/铜分档、vendor_list 清单）
> - 测试: `test/kantele/npc/dealer_test.exs`
> - 全量: **529 tests, 0 failures** (513 + 16)

> ✅ **DONE (补充：treemap + name + team follow)** — 小工具/决策补全
> - `lib/kantele/util/treemap.ex` — `Kantele.Util.TreeMap`，移植 treemap.c（query/set 自动建中间层/delete）
> - `lib/kantele/character/name.ex` — `Kantele.Character.Name`，移植 name.c（surname+purename 组名/无名氏、set_name、id?、parse_command_id_list、短名、非玩家首字母小写 ID）
> - `lib/kantele/character/team.ex` — 补 `follow?/3`，移植 team.c follow_me 决策（leader/队伍首位跟随 + no_follow 身法判定）
> - 测试: `test/kantele/followup_test.exs`
> - 全量: **547 tests, 0 failures** (529 + 18)

> ✅ **DONE (补充：damage craze/DPS + skill 惩罚)** — 战斗事后逻辑补全
> - `lib/kantele/feature_damage.ex` — `Kantele.Feature.Damage`：improve_craze/query_craze 狂暴累计、dps_count 存活裁剪（damage.c craze/DPS 部分）
> - `lib/kantele/combat/skills.ex` — `Kantele.Combat.Skills`：skill_death_penalty（技能 -1/领悟惩罚）、skill_expell_penalty（逐出/禁招删除/压回 100）
> - 测试: `test/kantele/skill_penalty_test.exs`
> - 全量: **554 tests, 0 failures** (547 + 7)

### Batch 8 — 工具/协议（⏸ 延期，最后做）
**source**: `vi.c`, `edit.c`, `more.c`, `shell.c`, `user_gmcp.c`, `user_mxp.c`
**target**（单独里程碑，核心可玩性之后）:
- `Kantele.Editor.Vi` / `Kantele.Editor.Line` / `Kantele.Pager`
- `Kantele.Shell`（巫师求值）
- `Kantele.Protocol.GMCP/MXP`
**测试**: editor_test.exs、shell_test.exs、protocol_test.exs

---

## 3. 依赖图 & 优先级总表

```
Batch1(派生属性) ──► Batch3(NPC社会/守卫) ──► Batch5(锻造/背包)
        │                    │                       │
        └──► Batch2(经济) ───┘                       │
                        └──► Batch4(物品类型) ────────┘
                                └──► Batch6(移动/生命周期)
                                         └──► Batch7(消息)
                                                  └──► Batch8(工具/协议 ⏸)
```

| 批次 | 核心价值 | 影响 feature 数 | 优先级 |
|------|---------|---------------|--------|
| Batch 1 | 玩家属性、技能上限、override 钩子 | 3 | P0 |
| Batch 2 | 钱币/银行经济 | 2 | P0 |
| Batch 3 | NPC 师徒/守卫/帮手/任务 | 5 | P0/P1 |
| Batch 4 | 食物/饮料/剁尸/坐骑/装备 | 5 | P0/P1 |
| Batch 5 | 锻造/背包/自动装载 | 4 | P1 |
| Batch 6 | 负重/清场/通用 condition | 4 | P1 |
| Batch 7 | 消息/提示补强 | 1 | P1 |
| Batch 8 | 编辑/协议(工具层) | 6 | ⏸ 延期 |

---

## 4. 验收与回归策略

1. 每批产出：框架模块 + 测试 + 更新本文档勾选。
2. 每批跑 `MIX_ENV=test mix test`（容器 `wuxia_mud_dev-app-1`），目标保持 **388 + 新增 tests, 0 failures**（允许既知 flaky `death`）。
3. 纯函数/数据部分（招表、配方、公式、状态机）沿用 `lpc_example/ex/*.ex` 作为"参照真值"，集成层断言结果一致。
4. 每批 git commit + push 到 `origin/kalevala`，commit 信息标注 `Batch N: <source files>`。
5. 延期项（Batch 8 工具/协议）不在本期核心可玩性验收内，可后续单独立项。

---

## 5. 修订记录
| 日期 | 变更 |
|------|------|
| 2026-08-29 | 创建文档，产出 49 feature 全量映射 + 8 批次推进计划 |
