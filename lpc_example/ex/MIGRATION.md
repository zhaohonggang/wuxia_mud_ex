# LPC 样本迁移影响一览

> 本目录按“每个 `.c` 文件一个子目录”组织，目录名即 `.c` 文件名。
> 每个子目录里放该 `.c` 迁移到 Kalevala 的**目标产物**：
> 若能落到一个文件，就用 `.c` 文件名做文件名；
> 若涉及多个文件（数据 + 行为），则全部放在该子目录下。
> 迁移**未接入游戏、未测试**，标注为“需底层”的项即落地之前要做的框架改动。

## 三分档速查

| 判定 | 含义 | 样本 |
|---|---|---|
| **A 单文件直落** | 纯数据/纯服务，一个文件即可，不动框架 | weapon_changjian, mount_ziliuma, item_shaolin_map, class_generate_chinese, quest_song-yupai(数据), 各房间静态 |
| **B 单模块+数据** | 主体单文件可落，仅个别回调需确认 | skill_taiji-quan, skill_dugu-jiujian（招式表+选招可落） |
| **C 需改底层** | 行为部分超出框架现有能力，要先扩框架 | combatd, damage, attack, poison, npc/, inherit/, system_npc/, class_npc/, 互动房间/物品 |

## 逐项

### A — 单文件（共依赖最轻）
| 目录(即.c) | 文件 | 说明 |
|---|---|---|
| `weapon_changjian/` | `weapon_changjian.ucl` | 纯数据武器，`Item.Meta` 直落 |
| `mount_ziliuma/` | `mount_ziliuma.ucl` | 野兽 NPC；`ridable` 字段需 loader 解析(小改) |
| `item_shaolin_map/` | `item_shaolin_map.ucl` | 纯数据(大 ASCII long 省略) |
| `quest_song-yupai/` | `quest_song-yupai.ucl` | 用既有 turn_in 机制(收物发奖) |

### 更正是 C 档的样本（初判被低估）
| 目录 | 文件 | 原判 | 改判原因 |
|---|---|---|---|
| `class_generate_chinese/` | `class_generate_chinese.ex`, `name_generator.ex`, `sects.ex` | ~~A 单文件~~ | 实为**随机中国武侠 NPC 生成基类**：委托 `include/npc/chinese.c` daemon 取名 + 内嵌 39 个门派原型。= 多文件(姓名数据 + 39 门派 + 基类) |

### B — 技能主体单模块（个别回调待底层）
| 目录 | 文件 | B可落 | C需底层 |
|---|---|---|---|
| `skill_taiji-quan/` | `skill_taiji-quan.ex` | @actions 招式表 + pick_action + valid_learn + practice_cost | valid_combine / valid_damage / query_effect_parry / hit_ob |
| `skill_dugu-jiujian/` | `skill_dugu-jiujian.ex` | @actions 招式表 + pick_action | “无招”双表切换, valid_damage, hit_ob, skill_improved, difficult_level, valid_enable 依赖等级 |

### C — 需改底层（文件数 = 该.c 的目标产物）
| 目录(即.c) | 文件 | 需底层能力 |
|---|---|---|
| `daemon_combatd/` | `daemon_combatd.ex` | 就是战斗引擎，并入 Kantele.Combat.Engine |
| `feature_damage/` | `feature_damage.ex` | Vitals 加 eff_qi/eff_jing 双血条 |
| `feature_attack/` | `feature_attack.ex` | is_killing / kill_ob / start_busy |
| `condition_poison/` | `condition_poison.ex` | Buff 扩展为周期 tick 的 Condition |
| `inherit_char_npc/` | `inherit_char_npc.ex` | NPC 基类钩子(chat_chance/add_action/heart_beat/is_killing/unconcious) |
| `inherit_room_pigroom/` | `inherit_room_pigroom.ex` | 房间 reset/心跳/自定义动词/动态 exit |
| `system_npc_luban/` | `system_npc_luban.ex` | 新增 Kantele.Crafting 服务层 |
| `class_wudang_zhang/` | `class_wudang_zhang.ucl/.ex` | 带逻辑 ask、收徒条件、accept_object(现有 inquiries 只支持静态字符串) |
| `npc_xiaoer/` | `npc_xiaoer.ucl`, `xiaoer.ex` | accept_object / greeting / drop 拦截 / 积分兑换 / 心跳清场 |
| `npc_horseboss/` | `npc_horseboss.ucl`, `horseboss.ex` | input_to 多步向导 + 随机坐骑生成 |
| `room_qianting/` | `room_qianting.ucl`, `qianting.ex` | room_verbs(push/close) + 动态 exit + 定时自动关 + valid_leave 拦截 |
| `room_wudu_liandu/` | `room_wudu_liandu.ucl`, `poison_workshop.ex` | room_verbs + 炼毒进度持久化 |
| `room_qiyuan2/` | `room_qiyuan2.ucl`, `qiyuan.ex` | room_heart_beat + 随机事件 |
| `item_wudu_qianzhumiji/` | `item_wudu_qianzhumiji.ucl`, `qianzhumiji.ex` | InteractiveItem 持久化研读进度 + 技能解锁联动 |
| `item_yinzhen/` | `item_yinzhen.ucl`, `yinzhen.ex` | eff_qi 双血条 + start_busy + improve_skill + is_killing |

## 归纳：落地下一步要扩的框架能力（按依赖排序）

1. **战斗引擎扩展**：`valid_combine`、`valid_damage`、`hit_ob`、`query_effect_parry`、`skill_improved`（skills 全都碰到）
2. **Vitals 双血条** `eff_qi/eff_jing`（damage/poison/yinzhen/quest 全部依赖）
3. **Condition 周期机制**（poison）
4. **Room/NPC 交互钩子**：`add_action`、`heart_beat`、`reset`、动态 exit、`accept_object`、带逻辑 ask、`input_to`（互动房间 + 行为性 NPC + 张三丰）
5. **击杀/仇恨与硬直**：`is_killing`、`kill_ob`、`start_busy`（attack / yinzhen / xiaoer）
6. **服务层**：Crafting（鲁班）
