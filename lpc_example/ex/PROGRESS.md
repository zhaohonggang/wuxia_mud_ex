# Kantele Framework Landing Progress

> Last updated: 2026-08-28 (commit `b761663` on `kalevala`)

## Baseline
- **Full test suite**: 372 tests, 0 failures
- All increments verified with `MIX_ENV=test mix test` in container

---

## Phase 1 — Player 模型与通用副作用宿主 (P0)
| 任务 | 状态 | 涉及文件 |
|------|------|----------|
| 1-1: PlayerMeta temp 存储 (`get_temp/put_temp/delete_temp/add_temp`) | ✅ | `lib/kantele/character.ex`, `test/kantele/character/player_meta_temp_test.exs` |
| 1-2: Vitals `heal/curing`、Combat `start_busy/interrupt`、Stats `potential/add_potential/potential_limit/improve_potential` | ✅ | `lib/kantele/character.ex`, `lib/kantele/character/combat.ex`, `test/kantele/character/vitals_test.exs`, `test/kantele/character/combat_test.exs`, `test/kantele/character/stats_potential_test.exs` |

**验收**：基线 352 → 369 tests, 0 failures

---

## Phase 2 — 战斗引擎与 Skill 钩子 (P0/P1)
| 任务 | 状态 | 涉及文件 |
|------|------|----------|
| 2-1: Skill 行为钩子协议（`valid_damage` `hit_ob` `practice_check` `skill_improved` `query_effect_parry/dodge` `perform_action_file`）、动态 Skills 注册表、Engine `valid_damage` 钻取 | ✅ | `lib/kantele/combat/skill.ex`, `lib/kantele/combat/skills.ex`, `lib/kantele/combat/engine.ex`, `test/kantele/combat/skill_hooks_test.exs` |
| 2-2: Engine `hit_ob` 钻取、`skill_improved` 在 learn 管道触发、`fight/auto_fight/announce/set_bhinfo` 桩 | ✅ | `lib/kantele/combat/engine.ex`, `lib/kantele/character/events/skills_event.ex`, `test/kantele/combat/skill_hooks_test.exs` |

**验收**：372 tests, 0 failures

---

## Phase 3 — Room 交互载体与 NPC 互动 (P1)
| 任务 | 状态 | 涉及文件 |
|------|------|----------|
| 3-1: Room 广播原语（`tell_room/message_vision/broadcast`）、定时器（`set_timer/cancel_timer`）、动态出口、valid_leave、present/living/get_objects/move_object | ✅ | `lib/kantele/world/room.ex` |
| 3-2: NPC AskHandler 行为 + 张三丰实现 + CombatAI + on_unconcious 钩子 | ✅ | `lib/kantele/npc/npc.ex`, `lib/kantele/npc/zhang_sanfeng.ex` |
| 3-3: Room `add_action` 动词分发 + `sync_room` 跨房 + 座位/玩家清单 + move_object | ✅ | `lib/kantele/world/room.ex` |

**验收**：372 tests, 0 failures

---

## Phase 4 — 全局服务层 (P2/P3)
| 任务 | 状态 | 涉及文件 |
|------|------|----------|
| 4-1: Item Registry（唯一物品 `locate/transfer/destroy_unique` + Ecto 持久化） | ✅ | `lib/kantele/item/registry.ex`, `lib/kantele/item/unique_item.ex` |
| 4-2: House System（建房申请/巫师批核/拆除/钥匙/巫师面板） | ✅ | `lib/kantele/house/house.ex`, `lib/kantele/house/house_schema.ex` |
| 4-3: Scheduler（统一 `call_out/set_heart_beat/复活/炼制/关门/NPC清场/广播`） | ✅ | `lib/kantele/scheduler.ex` |

**验收**：372 tests, 0 failures

---

## 样本接入（Framework Landing）
| 样本 | 状态 | 涉及文件 |
|------|------|----------|
| **feature_damage** — 受击/治疗/昏迷/死亡/复活/心跳回复/DPS/容量 | ✅ | `lib/kantele/character.ex` (damage state), `lib/kantele/feature_damage.ex` |
| **feature_attack** — 仇恨/想杀/敌人/竞争者/动作/心跳攻击/自动战斗/守卫联动 | ✅ | `lib/kantele/character.ex` (attack state), `lib/kantele/feature_attack.ex` |

**当前全量**：**372 tests, 0 failures**

---

## 待接入样本（按依赖顺序建议）

1. **condition_poison** — 毒引擎 + tick 挂 Scheduler
2. **skill_taiji-quan / skill_dugu-jiujian** — 新技能模块 + hook 验证
3. **room_qianting / room_qiyuan2 / inherit_room_pigroom** — Room 交互验证
4. **item_yinzhen / item_wudu_qianzhumiji** — 物品动词 + temp 存储 + busy/potential
5. **room_wudu_liandu** — 炼制调度 + 配方
6. **npc_xiaoer / npc_horseboss** — NPC 行为 + 坐骑向导
7. **class_wudang_zhang** — AskHandler 全链（问鹤嘴劲→收徒→授真武剑）
8. **system_npc_luban** — House + 巫师批核
9. **class_generate_chinese** — 纯配置并入

---

## 快速恢复命令

```bash
cd /app && MIX_ENV=test mix test   # 应输出 372 tests, 0 failures
```

---

## Git 历史关键节点

| Commit | 描述 |
|--------|------|
| `b761663` | feature_attack integration |
| `04e3658` | feature_damage integration |
| `b7a5f63` | Phase 3-3 + Phase 4: Room add_action/sync_room/seats + NPC AskHandler/ZhangSanfeng + Item Registry + House System + Scheduler |
| `b659637` | Phase 3-1/3-2: Room broadcast/timers/dynamic_exits + NPC AskHandler/ZhangSanfeng |
| `30a5963` | Phase 2-2: Engine hit_ob + skill_improved + fight/auto_fight/announce stubs |
| `4e5e630` | Phase 2-1: Skill hook protocol + dynamic registry + valid_damage wiring |
| `3edc83e` | Phase 1: Player temp storage + Vitals heal/curing + Combat busy + Stats potential |
| `6e46e1d` | Consolidated FRAMEWORK_REQUIREMENTS + tier-2 smoke tests |
| `d474db2` | Tier-2 smoke tests (feature_attack, npc_xiaoer, npc_horseboss, room_wudu_liandu, class_wudang_zhang) |

---

*文件创建于 2026-08-28，随对话进度更新。*