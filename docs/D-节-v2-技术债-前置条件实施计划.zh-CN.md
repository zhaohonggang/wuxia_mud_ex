# D 节 v2 技术债 — 前置条件实施计划

> 基于 `docs/remaining-work-checklist.zh-CN.md` §D 与 LPC 源码 `/c/files/git/mud` 核查。
> 三个 Deferred 项均按「先建前置条件，再实装目标」分阶段推进。

---

## 一、总览：三个 Deferred 项与前置依赖

| D 节项 | LPC 原始实现 | Elixir 前置条件 | 阶段 |
|--------|-------------|----------------|------|
| **疾病/雪原封路** (Q2 v2) | `adm/daemons/natured.c` `event_noon/1` 季节性发病；`inherit/condition/illness.c` `dispel/3`；`d/guanwai/gwxuedi.h` `valid_leave/2` 冬季封路/寒冷伤害 | `Kantele.World.GameTime` (季节/时辰)、`Kantele.World.Weather` (季节/天气)、`Kantele.World.Room.snapshot/1` (房间人员)、`Kantele.Character.Conditions` (condition 通用机制) | Phase 1 |
| **真·clone 动态目标** (Q1-T3) | `cmds/wiz/clone.c` `new(file)` + `SECURITY_D->valid_grant`；`adm/daemons/securityd.c` grant/2 | `Kantele.Admin.Security` (授权注册表)、`WizArch.guard` + `Access.archwizp` (巫师门控) | Phase 2 ✅ 已完成 |
| **count>1 逐件交付** (Q1-T3 → T4) | `clone/quest/supply.c` `COUNT--` 逐件结算；`clone/quest/deliver.c` `AMOUNT -= amount`；`valid_leave` 入位门控 | Quest generator supply/deliver (`count` 字段)、`quest_event.ex` `turnin_request/2` 交付通路、`quest.ex` `task_meta` 持久化 | Phase 3 (T4) ✅ 已完成 |

---

## 二、Phase 1 — 季节/事件系统（建后可接 疾病 + 雪原封路）

### 1.1 前置条件（已就绪，无需新建）

- `Kantele.World.GameTime.season/0` / `hour/0` — 游戏季节与时辰（Q2-T1）。
- `Kantele.World.Weather.season/0` / `weather/0` / `light/0` / `step/2` — 季节天象推演（Q2-T2）。
- `Kantele.World.Room.snapshot/1` — `%{private: %{characters: characters}}` 房间人员快照（Q2-T0）。
- `Kantele.Character.Conditions.apply_condition/4` / `query_condition/2` / `clear_condition/2` / `update_condition/2` / `dispel/3` — 通用 condition 机制，已有 `drunk`/`poison`/`nishui`/`duyan` 范例。
- `Kantele.Character.Vitals.food/water` + `Feature.Damage.heal_up/1` — 饥饿口渴与心跳扣减（已落地，可复用心跳时机）。

### 1.2 需新建：五类疾病 condition daemon ✅ 已完成

对应 LPC `kungfu/condition/ill_kesou.c` / `ill_zhongshu.c` / `ill_shanghan.c` / `ill_dongshang.c` / `ill_fashao.c`，落盘到 `lib/kantele/illness.ex`（单模块承载家族，与 `Kantele.Drunk`/`Kantele.Poison` 同款模式），模块 `Kantele.Illness`：

| 模块 | LPC 对照 | `update_condition/1` | `do_effect/3` | `min_qi_needed/1` | `dispel_condition/2` |
|------|---------|---------------------|---------------|-------------------|----------------------|
| `Kantele.Illness` (ill_kesou) | 咳嗽 (春/秋) | duration 倒计时，到期 `:expire` | qi - 2*2，推送本人/房间文案 | 10（家族最严 20） | force + neili 消耗，×3/2 他人 |
| `Kantele.Illness` (ill_zhongshu) | 中暑 (夏) | 同上 | qi - 2*4，推送本人/房间文案 | 15（家族最严 20） | 同上 |
| `Kantele.Illness` (ill_shanghan) | 伤寒 (秋) | 同上 | qi - 2*6，推送本人/房间文案 | 20（家族最严 20） | 同上 |
| `Kantele.Illness` (ill_dongshang) | 冻伤 (冬) | 同上 | qi - 2*2，推送本人/房间文案 | 10（家族最严 20） | 同上 |
| `Kantele.Illness` (ill_fashao) | 发烧 (1/4 覆盖) | 同上 | qi - 2*2，推送本人/房间文案 | 10（家族最严 20） | 同上 |

`daemon/1`：五个 cnd 均返回 `{:ok, Kantele.Illness}`，未知 cnd 返回 `:error`。

`dispel_condition/2` 照搬 LPC `illness.c dispel/3`：
- `need_lvl = duration + 60`；他人驱散 × 3/2
- `need_neili = duration * 10`；他人驱散 × 3/2
- `force < need_lvl` → 失败「内功火候尚有欠缺」
- `neili < need_neili` → 失败「内力现在不足」
- 成功：扣 neili，返回驱散成功文案

`min_qi_needed/1`：返回家族最严阈值 20（伤寒），宿主 `Conditions.blocked_by_vitals` 按此门控「患病即难眠」。

测试：`test/kantele/condition_daemons_test.exs` 新增 `describe "Illness"` 块（18 例），覆盖 `daemon/1` / `family/0` / `min_qi_needed/1` / 五族 `update_condition` / 五族 `do_effect`（qi 扣减 + clamp 到 0 + 文案推送）/`dispel_condition`（自身/他人 ×3/2 门槛、成功/失败、ctx 缺失降级）/ `Conditions` 引擎集成（经注册表 daemon 递减后移除）。

### 1.3 需新建：正午发病事件 ✅ 已完成（对应 `natured.c event_noon/1`）

`lib/kantele/world/season_event.ex` 已实现（GenServer，`Scheduler.schedule_once` 链式）：

- 每游戏日正午（hour == 12），随机 `1/4` 触发发病（`random(4) == 0`）
- 依月份选疾病：3-5 月 `ill_kesou`，6-8 月 `ill_zhongshu`，9-11 月 `ill_shanghan`，12-2 月 `ill_dongshang`；`random(4) == 0` 时覆盖为 `ill_fashao`
- 只作用于 `outdoors` 房间内的 `player:*` 角色（room snapshot 判定 `env.outdoors`）
- CON 抗性：`con = con/2 + random(con)`；`ill_shanghan/dongshang` 加 `apply/warm` + `env.warm`；`ill_zhongshu` 减 `apply/warm` + `env.warm`；`con + ic < 25` 则发病（`ill_dongshang` ic=0，其余 ic=5）
- 发病时 `apply_condition(ill, 30 - con)` 经 `condition/apply` 事件落到角色自身进程

测试：`test/kantele/world/season_event_test.exs`（14 例），覆盖 `plan_noon/3`（3/4 空拦、5 个月份病种、fashao 覆盖、非玩家/非户外不发病、体质抗力边界、duration=30-con、多角色过滤）/`illness_for_month/1`（4 个月份映射）/`adjust_warm`（按病种加减 warm）。

### 1.4 需新建：雪原冬季封路与寒冷伤害 ✅ 已完成（对应 `gwxuedi.h valid_leave/2`）

`lib/kantele/world/snow_region.ex` 已实现（纯函数 + GenServer 守护进程）：

- `winter?/1`：12,1,2,3,4,5 为冬月
- `guanwai?/1`：room_id 以 `guanwai:` 开头
- `cold_damage/5`：`damage = 35 - (con_resist + warm)`，关外胡家 -25，夜间 ×1.5，深夜再 ×1.5，正午 ×0.5，`scale` 系数（出关 3 / 关内 1），clamp 到 0
- `cold_msg/1`：伤害文案阈值（>80/60/40/20/10/0）
- `dongshang_duration/2`：`damage > 10` 时 `existing + 5 + damage/3`，否则 0
- `cold_event_for/3`：非冬月或非关外返回 nil

`lib/kantele/world/snow_region_event.ex` 已实现（`snow/cold` 事件处理器）：

- `cold/2`：渲染寒冷文案、`damage > 0` 时 `Damage.receive_damage("qi", damage)`，`damage > 10` 且 `qi < 50` 时挂 `ill_dongshang`（时长 `existing + 5 + damage/3`）

测试：`test/kantele/world/snow_region_test.exs`（22 例）+ `test/kantele/world/snow_region_event_test.exs`（8 例），覆盖 `winter?`/`guanwai?`/`cold_damage`（8 档）/`cold_msg`（7 档）/`dongshang_duration`/`cold_event_for` 以及 `cold/2`（扣气/落冻伤/qi 阈门控/damage 阈门控/持续时间累加/缺损数据降级/兜底条款）。

---

## 三、Phase 2 — 克隆/授权基础设施（建后可接 真·clone 动态目标）

### 2.1 前置条件（已就绪，无需新建）

- `Kantele.Admin.Security.grant/2` / `revoke/2` / `granted?/2` / `ensure!/0` — 公共 ETS 授权注册表（对应 LPC `securityd.c` grant/2）。
- `WizArch.guard` + `Access.archwizp` — 巫师门控（B2 已完成）。
- `Kantele.World.Item` / `Kantele.World.Items` — 物品定义与实例（已有 loader）。

### 2.2 需新建：运行时对象克隆（对应 `cmds/wiz/clone.c`）

新建 `lib/kantele/world/object_clone.ex`：

- `clone_by_path(file, amount \\ 1, actor)`：
  1. 校验 `file` 以 `.c` 结尾（缺失补 `.c`），`file_size` ≥ 0（Ex 侧对应 `Code.ensure_loaded?` / 模块存在性）
  2. `Security.granted?(actor, "clone")` 或巫师 `valid_grant(actor, "(wizard)")` → 否则拒绝
  3. `valid_read(file, actor, "clone")` → 文件读权限（Ex 侧对应模块白名单/路径允许列表）
  4. 非 admin 时站点特权：`gift` 仅允许 `/clone/special/*`、`/clone/gift/*`；`all` 放行；其余拒绝
  5. `Code.ensure_loaded(module)` 失败 → 载入错误回报
  6. `module.new()` / `module.start_link()` 实例化；`set_amount(amount)`；`log_file("static/clone", ...)` 形式记录操作日志
  7. `obj.move(actor)` 或 `obj.move(environment(actor))`；返回结果文案

### 2.3 需新建：巫师 clone 命令（对应 `cmds/wiz/clone.c` main/1）

新建 `lib/kantele/character/commands/clone_command.ex`：

- 路由 `clone <file> [amount]`（`optional(spaces + text(:rest))` 解析）
- 仅巫师：`Access.archwizp?/1` 守门，非巫师返回「你不能复制物品。」（LPC 默认拒绝）
- 参数缺失 → 「你想复制多少？」 / 「你要复制什麽对象？」
- 调用 `ObjectClone.clone_by_path/3`，渲染「只见$N伸手凌空一指，变出了$n。」并放入背包/房间

### 2.4 验收标准（已全部通过）

- `command_probe_test.exs` 白名单：`clone_command.ex` 回执不含占位标记。
- 非巫师执行 clone 被拒绝；无 `grant` 且非 `/clone/special\|/clone/gift` 路径被拒绝；模块不存在回报「载入失败」。
- 单测覆盖 `clone_by_path/3` 权限、金额、移动、日志四条。
- 全量 suite 0 新增失败（7569 tests / 27 failures，与 bcrypt 基线一致）。

**已完成（2026-11-11）：**
- `lib/kantele/world/object_clone.ex` — 完整 `clone_by_path/3` 7 步流程，支持 `zone:id` 物品/NPC 查找、`/clone/*.c` Elixir 模块加载回退，写 `static/clone/clone.log`。
- `lib/kantele/character/commands/clone_command.ex` — arch-only 门控 + `rest` 参数解析 + 背包放入 + 房间广播「只见$N伸手凌空一指，变出了$n。」
- `lib/kantele/character/commands.ex` — CloneCommand 路由改为 `optional(empty() |> spaces() |> text(:rest))`。
- 测试：`object_clone_test.exs` 16 例 + `clone_command_test.exs` 10 例 + `wizard_guard_test.exs` 更新 3 例，全部通过。

---

## 四、Phase 3 — count>1 逐件交付（T4，依赖 Phase 1-2）

### 3.1 前置条件

- Quest generator `Supply`/`Deliver` 模板已有 `count: 1` 字段（Q1-T3 v1），需改为可配置数量。
- `quest_event.ex` `turnin_request/2` 已有背包物品校验与 `complete/4` 结算（A11/N6）。
- `quest.ex` `task_meta/1` 已持久化 `target_room`；`entry_position_ok?/3` 已对 search/explore 生效。

### 3.2 需新建/改造：逐件计数交付

对应 LPC：
- `supply.c`：`COUNT = 3 + random(6)`；`npc_accept_object` 中 `COUNT--`；`COUNT < 1` 时 `do_finish` 结算；每件给报酬 `MONEY_D->pay_player`。
- `deliver.c`：`AMOUNT` 初始设定；`npc_accept_object` 中 `AMOUNT -= ob->query_amount()`；`AMOUNT < 1` 时 `do_finish`；每件按数量比例奖励 `exp/pot/score *= amount`。
- 入位门控：`base_name(environment(me)) != me->query("startroom")` → NPC 茫然不接（`supply.c`）。

#### 3.2.1 Generator 改造
- `Supply.generate/1`：`count = 3 + rand_between(0, 5)`（LPC `3 + random(6)`），`count` 写入 spec。
- `Deliver.generate/1`：`amount` 可配置（默认 5-10，对应 LPC deliver 心跳生成 up to 10 tasks, amount 5-10），写入 spec。

#### 3.2.2 QuestEvent 改造（`turnin_request/2`）
- 交付前读 `Quest.get_todo(state, quest_id)` 的 `meta.count`（剩余需交付数量，缺省 1）。
- 背包匹配物品后，**逐件扣减**：每交付 1 件，`count - 1`；`count` 存回 todo meta（或专用 `delivered` 计数）。
- `count` 归 0 → 走 `complete/4` 结算并标记任务已解；`count > 0` → 提示「还需要 X 件才够」（LPC `do_notice`）并保持在办。
- 入位校验：`supply` 类型任务若 `meta.start_room`（NPC 初始房间）与玩家当前房间不符 → 拒绝并提示茫然（LPC `base_name(environment(me)) != me->query("startroom")`）。

#### 3.2.3 奖励按件比例
- 每件交付的 exp/pot/score/coins 按 `ob->query_amount()` 比例放大（LPC `deliver.c` `exp *= ob->query_amount()` 等）。

### 3.3 验收标准
- supply 任务 `count=3`：交付 1 件后提示「还需要 2 件才够」，任务仍在办；交齐 3 件后结算。
- deliver 任务 `amount=5`：交付 2 件后 `AMOUNT=3`，继续；交齐后 `do_finish` 结算。
- 非 start_room 交付 supply 被拒。
- `command_probe` 无误报；全量测试 0 新增失败。

---

## 五、Phase 4 — W3 对象引擎（对应 6 个引擎绑定 W3 arch 命令）

### 5.1 前置条件（已就绪，无需新建）

- `WizArch.guard/3` + `Access.wizardp/1` — 巫师门控（B2/E5 已完成）。
- `Kantele.World.ObjectClone.clone_by_path/3` — 运行时对象实例化（Phase 2 已完成）。
- `Kalevala.Character.Command.Router` DSL — 路由注册，带 `optional(empty() |> spaces() |> text(:rest))`。
- `daemon 惯例`：GenServer 持公共 ETS，`ensure!/0` 补建表，直接 `:ets.insert`，`read_state/0` 缺失返缺省。

### 5.2 需新建：W3 对象引擎核心 + 3 个 MVP 命令

新建 `docs/B2-W3-对象引擎实施计划.zh-CN.md`（详细设计），核心内容：

| 模块 | 职责 | 状态 |
|------|------|------|
| `Kantele.World.W3ObjectEngine` | GenServer + 公共 ETS `w3_objects`，对象注册/查询/销毁/列表 + 受控系统操作 `schedule_system/3` | ✅ 已完成 |
| `Kantele.Character.CallCommand` | `call <对象> <函数> [参数...]`，对象函数调用 | ✅ 已完成 |
| `Kantele.Character.RebootCommand` | `reboot [延迟秒]`，应用层受控重启（dry-run 默认） | ✅ 已完成 |
| `Kantele.Character.ShutdownCommand` | `shutdown [延迟秒]`，应用层受控停机（dry-run 默认） | ✅ 已完成 |
| `Kantele.Character.PossessCommand` | 附身（依赖角色进程迁移） | 后续，保留 not_modeled |
| `Kantele.Character.RestoreCommand` | 存档恢复（依赖持久化层） | 后续，保留 not_modeled |
| `Kantele.Character.BuildCommand` | 建造房间/对象（依赖房间编辑器） | 后续，保留 not_modeled |

路由：全部在 `lib/kantele/character/commands.ex` 新增 module 块，使用 `optional(empty() |> spaces() |> text(:rest))`（已在 E5 完成）。

### 5.3 验收标准

- `call`：巫师调用已注册对象函数返回结果；对象/函数不存在返回明确错误；非巫师被拒绝。
- `reboot`/`shutdown`：巫师触发返回确认文案；非巫师被拒绝；不崩溃。
- `possess`/`restore`：巫师触发返回真实行为回执（附身记录 / 跨进程存档恢复事件）；`build`：巫师触发返回 `not_modeled` 回执（用户确认不做）。
- `command_probe_test.exs` 白名单 `%{}`，0 误报。
- 全量 `mix test --seed 831693`：0 新增失败（27 bcrypt 基线）。

**已完成（2026-11-11）：**
- `lib/kantele/world/w3_object_engine.ex` — GenServer + 公共命名 ETS `w3_objects`，`register/4`/`lookup/1`/`unregister/1`/`list/0`/`read_state/0`，以及受控系统操作 `schedule_system/3`（默认 dry-run，仅当 `config :ex_venture, Kantele.World.W3ObjectEngine, allow_system_actions: true` 时经 `Process.send_after` 投递到 GenServer 执行 `Application.stop/start`）与 `cancel_system/0`；遵循 daemon 惯例（`ensure!/0` 补建表、直接 `:ets.insert`）。
- `lib/kantele/character/commands/wiz_arch.ex` — 新增 `system_action/4` 共享 helper（解析延迟秒、调度、确认文案）。
- `lib/kantele/character/commands/call_command.ex` — `call <对象> <函数> [参数...]`：先查 W3ObjectEngine，未命中按引用名/路径解析为 Elixir 模块或经 `ObjectClone.clone_by_path/3` 验证存在；`Module.apply` 调用，结果/错误/属主权限分级回执。
- `lib/kantele/character/commands/reboot_command.ex` / `shutdown_command.ex` — 经 `WizArch.system_action/4` 调度，dry-run 确认文案。
- `possess`/`restore`：本阶段真化（port-appropriate，不照搬 LPC）：`Possession`（公共 ETS，附身关系记录 + 标记式广播）、`ObjectRestore`（`Records.load` 存档信息）+ 跨进程 `character/restore` 事件经 `RestoreEvent` 重载；`build` 已定案不做（用户确认，代码保留 `not_modeled` 清晰回执，永不再实现，`@moduledoc` 注明预留 `Builder`）。
- 测试：`w3_object_engine_test.exs`（13 例：ensure 幂等 / 注册查询 / 销毁 / 列表 / read_state / schedule_system dry-run）+ `wiz_arch_test.exs`（将 call/reboot/shutdown 移出 `@deferred`，新增真实行为测试，37 例全绿）+ `command_probe_test.exs`（白名单 `%{}` 0 误报）。
- 全量 `mix test --seed 831693`：0 新增失败（27 bcrypt 基线）。

---

## 六、排序建议与里程碑

```
Phase 1 (季节/事件系统) ✅ 全部完成
  ├─ 1.1 前置条件 (GameTime/Weather/Room.snapshot/Conditions/Vitals) — 已就绪
  ├─ 1.2 条件 daemon ×5 (Kantele.Illness) ✅ 已完成（测试 18 例全绿）
  ├─ 1.3 正午发病事件 (season_event.ex) ✅ 已完成（测试 14 例全绿）
  └─ 1.4 雪原冬季封路/寒冷伤害 (snow_region.ex + snow_region_event.ex) ✅ 已完成（测试 30 例全绿）
      → 验收后：疾病 + 雪原封路 可真化

Phase 2 (克隆/授权基础设施) ✅ 已完成
  ├─ 2.1 运行时对象克隆 (object_clone.ex) — 已完成
  └─ 2.2 巫师 clone 命令 (clone_command.ex) — 已完成
      → 验收后：真·clone 动态目标 可真化 ✅ 已真化

Phase 3 / T4 (count>1 逐件交付) ✅ 已完成
  ├─ 3.1 generator count 字段 (Supply count=3..8, Deliver count=5..10, start_room)
  ├─ 3.2 turnin_request 逐件扣减 + 入位门控 (meta.count 累计，count=0→complete，count>0→提示「还需要 X 件」)
  └─ 3.3 按件比例奖励 (scale_rewards_by_count，v>0 缩为0 补 1)
      → 验收后：count>1 逐件交付 ✅ 可真化（7601 tests / 27 failures，与 bcrypt 基线一致，0 回归）

Phase 4 (W3 对象引擎) ✅ 已完成（2026-11-11 MVP + possess/restore 真化）
  ├─ W3ObjectEngine 核心 (GenServer + 公共 ETS w3_objects，注册/查询/销毁/列表 + 受控 schedule_system)
  ├─ call 命令 (对象函数调用，经 ObjectClone 落点)
  ├─ reboot / shutdown 命令 (应用层受控，dry-run 默认)
  ├─ possess 命令 ✅ 真化（标记式附身：BeastTaming 解析同房间活物 + Possession ETS 记录 + 房间广播）
  ├─ restore 命令 ✅ 真化（ObjectRestore.info 校验存档 + 向目标 pid 投递 character/restore 事件经 RestoreEvent 重载）
  └─ build 命令 ⏳ not_modeled（用户确认不做，预留 Kantele.World.Builder）
      → 验收后：6 个引擎绑定命令中 call/reboot/shutdown/possess/restore 已真化（全量 0 新增失败，27 bcrypt 基线）；仅 build 保留 not_modeled
```

建议优先开工 **Phase 1**：前置条件（GameTime/Weather/Room.snapshot/Conditions）全部已就绪，代码量中等，且可直接复用现有 `Scheduler.schedule_once` 链式与 `Kantele.Character.Conditions` 机制，风险最低。Phase 2 涉及运行时模块加载与巫师权限，需谨慎设计沙箱；Phase 3 标记为 T4，可在 Phase 1-2 验收后再立项。

---

> 说明：本计划仅做规划与查阅，开工任意项前先在 `docs/remaining-work-checklist.zh-CN.md` §D 更新"状态"列，每批验收以 `MIX_ENV=test mix test --seed 831693` 全绿为准。按仓库约定，无用户明确指令不执行 `git commit/push`。
