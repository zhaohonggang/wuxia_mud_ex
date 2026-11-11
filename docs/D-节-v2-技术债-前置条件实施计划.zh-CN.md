# D 节 v2 技术债 — 前置条件实施计划

> 基于 `docs/remaining-work-checklist.zh-CN.md` §D 与 LPC 源码 `/c/files/git/mud` 核查。
> 三个 Deferred 项均按「先建前置条件，再实装目标」分阶段推进。

---

## 一、总览：三个 Deferred 项与前置依赖

| D 节项 | LPC 原始实现 | Elixir 前置条件 | 阶段 |
|--------|-------------|----------------|------|
| **疾病/雪原封路** (Q2 v2) | `adm/daemons/natured.c` `event_noon/1` 季节性发病；`inherit/condition/illness.c` `dispel/3`；`d/guanwai/gwxuedi.h` `valid_leave/2` 冬季封路/寒冷伤害 | `Kantele.World.GameTime` (季节/时辰)、`Kantele.World.Weather` (季节/天气)、`Kantele.World.Room.snapshot/1` (房间人员)、`Kantele.Character.Conditions` (condition 通用机制) | Phase 1 |
| **真·clone 动态目标** (Q1-T3) | `cmds/wiz/clone.c` `new(file)` + `SECURITY_D->valid_grant`；`adm/daemons/securityd.c` grant/2 | `Kantele.Admin.Security` (授权注册表)、`WizArch.guard` + `Access.archwizp` (巫师门控) | Phase 2 |
| **count>1 逐件交付** (Q1-T3 → T4) | `clone/quest/supply.c` `COUNT--` 逐件结算；`clone/quest/deliver.c` `AMOUNT -= amount`；`valid_leave` 入位门控 | Quest generator supply/deliver (`count` 字段)、`quest_event.ex` `turnin_request/2` 交付通路、`quest.ex` `task_meta` 持久化 | Phase 3 (T4) |

---

## 二、Phase 1 — 季节/事件系统（建后可接 疾病 + 雪原封路）

### 1.1 前置条件（已就绪，无需新建）

- `Kantele.World.GameTime.season/0` / `hour/0` — 游戏季节与时辰（Q2-T1）。
- `Kantele.World.Weather.season/0` / `weather/0` / `light/0` / `step/2` — 季节天象推演（Q2-T2）。
- `Kantele.World.Room.snapshot/1` — `%{private: %{characters: characters}}` 房间人员快照（Q2-T0）。
- `Kantele.Character.Conditions.apply_condition/4` / `query_condition/2` / `clear_condition/2` / `update_condition/2` / `dispel/3` — 通用 condition 机制，已有 `drunk`/`poison`/`nishui`/`duyan` 范例。
- `Kantele.Character.Vitals.food/water` + `Feature.Damage.heal_up/1` — 饥饿口渴与心跳扣减（已落地，可复用心跳时机）。

### 1.2 需新建：五类疾病 condition daemon

对应 LPC `kungfu/condition/ill_kesou.c` / `ill_zhongshu.c` / `ill_shanghan.c` / `ill_dongshang.c` / `ill_fashao.c`，各自落盘到 `lib/kantele/condition/`（与 `attrition.ex` 并列）：

| 模块 | LPC 对照 | `update_condition/1` | `do_effect/3` | `min_qi_needed/1` | `min_jing_needed/1` | `dispel_condition/2` |
|------|---------|---------------------|---------------|-------------------|---------------------|----------------------|
| `Illness.Kesou` | 咳嗽 (春/秋) | duration 倒计时，到期 `:expire` | qi/jing 轻伤 | 10 | 10 | force + neili 消耗 |
| `Illness.Zhongshu` | 中暑 (夏) | 同上 | qi/jing 伤 | 15 | 15 | 同上 |
| `Illness.Shanghan` | 伤寒 (秋) | 同上 | qi/jing 重伤 | 20 | 20 | 同上 |
| `Illness.Dongshang` | 冻伤 (冬) | 同上 | qi/jing 伤，无 `ic` 时不扣 vitals | 10 | 10 | 同上 |
| `Illness.Fashao` | 发烧 (1/4 覆盖) | 同上 | qi/jing 伤 | 10 | 10 | 同上 |

`dispel_condition/2` 照搬 LPC `illness.c dispel/3`：
- `need_lvl = duration + 60`；他人驱散 × 3/2
- `need_neili = duration * 10`；他人驱散 × 3/2
- `me.query_skill("force") < need_lvl` → 失败
- `me.neili < need_neili` → 失败
- 成功：`me.add("neili", -need_neili)`，目标 `clear_condition`

### 1.3 需新建：正午发病事件（对应 `natured.c event_noon/1`）

新建 `lib/kantele/world/season_event.ex`（GenServer，`Scheduler.schedule_once` 链式，与 Weather 同周期）：

- 每游戏日正午（hour == 12），随机 `1/4` 触发发病（`random(4) == 0`）
- 依月份选疾病：3-5 月 `ill_kesou`，6-8 月 `ill_zhongshu`，9-11 月 `ill_shanghan`，12-2 月 `ill_dongshang`；`random(4) == 0` 时覆盖为 `ill_fashao`
- 只作用于 `outdoors` 房间内的 `living` 角色（room snapshot 判定 `env.outdoors`，字符型 `living`）
- CON 抗性：`con = con/2 + random(con)`；`ill_shanghan/dongshang` 加 `apply/warm` + `env.warm`；`ill_zhongshu` 减 `apply/warm` + `env.warm`；`con + ic < 25` 则发病（`ill_dongshang` ic=0，其余 ic=5）
- 发病时 `apply_condition(state, ill, %{duration: 30 - con})` 并向角色发送 LPC 风文案（咳嗽/中暑/伤寒/冻伤/发烧）

### 1.4 需新建：雪原冬季封路与寒冷伤害（对应 `gwxuedi.h valid_leave/2`）

- 在房间离开校验链（`move_event.ex` 或 `Room.exit_veto/2`）中，冬季月份（12,1,2,3,4,5）对 `interactive` 角色执行 `do_cold/3`：
  - `damage = 35 - (con/2 + random(con) + apply/warm + room.warm)`
  - 关外胡家 born 减 25；小时 ≤6 或 ≥18 伤害 ×1.5；≤4 或 ≥22 再 ×1.5；11-13 时 ×0.5
  - `damage < 0` 归 0；`scale` 参数（`valid_leave` 传 3，`cold_effect` 定时传 1）
  - `qi < 50 且 damage > 10` 时挂 `ill_dongshang` 5 + damage/3 轮
- 新建 `lib/kantele/world/snow_region.ex` 供房间 inherit/调用（LPC `gwxuedi.h` 的 Ex 等价）

### 1.5 验收标准
- `mix compile` 0 警告；`season_event` 单测覆盖：冬季户外角色正午发病概率、CON 抗性边界、dispel 消耗 neili、夏季不发冻伤。
- `room_test` 新增雪原房间冬季离开扣伤、非冬季不扣伤。

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

### 2.4 验收标准
- `command_probe_test.exs` 白名单：`clone_command.ex` 回执不含占位标记。
- 非巫师执行 clone 被拒绝；无 `grant` 且非 `/clone/special\|/clone/gift` 路径被拒绝；模块不存在回报「载入失败」。
- 单测覆盖 `clone_by_path/3` 权限、金额、移动、日志四条。

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

## 五、排序建议与里程碑

```
Phase 1 (季节/事件系统)
  ├─ 1.1 条件 daemon ×5 (Illness.*)
  ├─ 1.2 正午发病事件 (season_event.ex)
  └─ 1.3 雪原冬季封路/寒冷伤害 (snow_region.ex)
      → 验收后：疾病 + 雪原封路 可真化

Phase 2 (克隆/授权基础设施)
  ├─ 2.1 运行时对象克隆 (object_clone.ex)
  └─ 2.2 巫师 clone 命令 (clone_command.ex)
      → 验收后：真·clone 动态目标 可真化

Phase 3 / T4 (count>1 逐件交付)
  ├─ 3.1 generator count 字段
  ├─ 3.2 turnin_request 逐件扣减 + 入位门控
  └─ 3.3 按件比例奖励
      → 验收后：count>1 逐件交付 可真化
```

建议优先开工 **Phase 1**：前置条件（GameTime/Weather/Room.snapshot/Conditions）全部已就绪，代码量中等，且可直接复用现有 `Scheduler.schedule_once` 链式与 `Kantele.Character.Conditions` 机制，风险最低。Phase 2 涉及运行时模块加载与巫师权限，需谨慎设计沙箱；Phase 3 标记为 T4，可在 Phase 1-2 验收后再立项。

---

> 说明：本计划仅做规划与查阅，开工任意项前先在 `docs/remaining-work-checklist.zh-CN.md` §D 更新"状态"列，每批验收以 `MIX_ENV=test mix test --seed 831693` 全绿为准。按仓库约定，无用户明确指令不执行 `git commit/push`。
