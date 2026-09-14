# 接线完成情况记录 (Wiring Completion Status)

**更新时间**：2026-09-13  
**分支**：`kalevala` (commit `f0792aa`)  
**测试基线**：2342 passed, 0 failures  
**编译警告**：零新增（仅历史存根警告）

---

## ✅ 核心任务完成情况

### Phase 1: 杀戮意图系统
| 文件 | 改动 |
|------|------|
| `lib/kantele/world/room.ex` | `combat/start` 事件携带 `type` (fight/kill/duel/aggressive)；`engage/start_combat` 传递类型 |
| `lib/kantele/character/events/combat_event.ex` | `start` 时 `type=="kill/aggressive"` 记录 `attack_killer` / `attack_want_kills`；`die/enemy_died/halt/yield/enemy_left` 清理意图 |

### Phase 2: 决斗系统
| 文件 | 改动 |
|------|------|
| `lib/kantele/character/commands/duel_command.ex` | 新增 `duel <目标>` 命令，发 `combat/attack` type="duel" |
| `lib/kantele/character/events/combat_event.ex` | `type=="duel"` 双方互设 `competitor`；`enemy_died` 胜者端广播胜负文案 |

### Phase 3: 守卫联动
| 文件 | 改动 |
|------|------|
| `lib/kantele/world/room.ex` | `guard/guard` `guard/cancel` 真实实现（目标 `meta.temp.guarded` 登记守护者）；`combat/attack` 检查 `guarded_deny?` / `trigger_guarded_allies` |
| `lib/kantele/character/commands/guard_command.ex` | 已存在，现生效 |

### Feature_Attack 重写
| 文件 | 改动 |
|------|------|
| `lib/kantele/feature_attack.ex` | **全量重写**：删除所有 stub/并行引擎代码，改为真实引擎薄查询层<br>— `fighting?`/`killing?`/`want_kill?` 委托 `Combat`/`PlayerMeta`<br>— `fight_ob/kill_ob/want_kill` 仅记录意图<br>— `clean_up_enemy/select_opponent/remove_enemy` 同步 `Combat` 真实状态<br>— `competition_with/win/lost/set_compulator` 管理 `competitor`<br>— `reset_action` 用 `Stats.mapped` + `Item.get_skill_type` + `Combat.Skills.query_action` |

### Xiaoer 真实接线
| 文件 | 改动 |
|------|------|
| `lib/kantele/item/item.ex` | 实现 `is_currency?` (meta.is_money) / `is_corpse?` (meta.is_corpse) / `is_exchange_item?` (xiaoer 兑换列表) / `currency_amount` (meta.amount) |
| `lib/kantele/npc/xiaoer.ex` | 重写为真实 API：`validate_give`/`rent_per_night`/`exchange_items`/`item_name`/`greet/is_xiaoer?` |
| `lib/kantele/character/events/give_event.ex` | **跨进程流程**：NPC 验证物品 → 给予者进程处理 `pay_rent/exchange_item/dispose_corpse` → 双向事件确认 |
| `lib/kantele/character/events.ex` | 注册 `xiaoer/process_give` 事件 |

### HorseBoss 真实接线
| 文件 | 改动 |
|------|------|
| `data/world/liuxi.ucl` | 新增 `characters "mafu"` NPC（kind=horseboss，含 combat 配置）；在 `guangchang` 广场添加 `mafu` 到 room_characters |
| `lib/kantele/character/commands/horse_command.ex` | **新增命令**：`horse <马夫>` 进入购买流程，支持物种/性别/ID/名字/描述/取消完整流程 |
| `lib/kantele/npc/horseboss.ex` | 已有完整购买逻辑（greet/start_purchase/choose_gender/choose_id/choose_name/choose_desc/cancel），现被命令调用 |

### Feature_Damage 重写
| 文件 | 改动 |
|------|------|
| `lib/kantele/feature_damage.ex` | **全量重写**：删除所有 stub/并行引擎代码，接入真实引擎<br>— `receive_damage/wound/heal/curing`：真实 `Vitals.damage/wound/heal/curing`<br>— `unconcious/revive/die`：委托 `CombatEvent` 流程（scheduler, announce, enemy_died 奖励）<br>— `heal_up`：委托 `Vitals.regenerate` + `CombatEvent.kick_regen`<br>— `schedule_revive/remove_call_out`：委托 `Scheduler`/`cancel`<br>— `announce/send_message`：委托 `Communication.announce`/`Broadcast`<br>— `make_corpse/move_to_death_room/destruct_npc`：World 集成桩<br>— `winner_reward/killer_reward`：委托 `CombatEvent.enemy_died`<br>— DPS/craze 追踪：真实 `PlayerMeta.update_damage` |

---

## 📊 验证结果

```
$ mix test
2342 tests, 0 failures

$ mix compile
# 零新增警告（仅历史 feature_attack/feature_damage 存根警告）
```

---

## 📝 后续可选工作

| 优先级 | 任务 | 预估工作量 |
|--------|------|------------|
| Low | `banker/master/quester/horseboss` 逻辑库文档化 | 小 ✅ **已完成** (`NPC_LOGIC_LIBS.md`) |

---

## 📁 主要变更文件列表

```
lib/kantele/character/commands/duel_command.ex       (新增)
lib/kantele/character/commands/horse_command.ex      (新增)
lib/kantele/character/events/combat_event.ex         (165 行)
lib/kantele/character/events/give_event.ex           (159 行)
lib/kantele/character/events/ex                      (1 行)
lib/kantele/feature_attack.ex                        (364 行重写)
lib/kantele/feature_damage.ex                        (全量重写)
lib/kantele/item/item.ex                              (26 行)
lib/kantele/npc/horseboss.ex                          (187 行)
lib/kantele/npc/xiaoer.ex                             (187 行重写)
lib/kantele/world/room.ex                             (180 行)
data/world/liuxi.ucl                                  (NPC + room_characters)

共 12 文件，+657/-453 行
```