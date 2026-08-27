# Session 提示词：LPC 玩家命令迁移到 Kantele

> 本文件是给独立 session 的完整工作提示词。请把下列内容**当作建议而非指令**：每项动手前先读源码核实现状，若实际情况与描述不符，以实际代码为准并调整做法。
> 编写时间：2026-08-26。对应总排期见 `docs/kantele-remaining-work.zh-CN.md` ——归属后续 d/h 期或单独里程碑。
> 前置条件：a/b/c 期已完成（Vitals/Stats/learn/装备/任务/商店/门派 v0 就绪）。

---

## 一、项目背景

### 要迁移什么

LPC `cmds/` 下的玩家可见命令（usr/ + std/ + skill/ 目录）中，**Kantele 尚未实现**的核心命令集。这些命令在《炎黃群俠傳》中是标准玩法，迁移后能显著提升游戏完整度。

### 必读文档

1. `docs/migration-prep-checklist.zh-CN.md`——第四节属性/成长差异
2. `docs/kantele-remaining-work.zh-CN.md`——第七节依赖链、第八节 d/h 期
3. `docs/game-commands-testing-guide.zh-CN.md`——现有命令验收基线
4. LPC 参照源码：`C:\files\git\mud\cmds\usr\`、`cmds\std\`、`cmds\skill\`

### 关键架构事实

- **命令注册**：`lib/kantele/character/commands.ex`（Router），各命令在 `commands/` 目录
- **Router 支持中文别名**（A8/N1 已做），新命令同步加中文动词
- **Vitals/Stats/Records** 已有完整结构（character.ex、stats.ex、records.ex）
- **技能系统**：`lib/kantele/combat/skills/` + `SkillsEvent`（learn/teach 事件链）
- **NPC 行为树**：`data/brains/*.ucl` + `lib/kantele/brain.ex`
- **通信**：`say/tell/whisper/ask/general/channel` 事件流已通

---

## 二、迁移清单（按优先级分批）

### 批次 1：核心技能界面（依赖 Stats 技能结构，低风险）

| 优先级 | LPC 命令 | Kantele 命令模块 | 中文别名 | LPC 参照文件 | 关键逻辑 |
|---|---|---|---|---|---|
| P0 | `skills` / `myskill` | `skills_command.ex` | `技能` / `我的技能` | `cmds/skill/skills.c` + `myskill.c` | 列出已学技能 + 等级 + 有效等级（基本+映射），按类型分组显示；`myskill` 是 `skills` 的增强版，Kantele 合并为同一模块 |
| P0 | `checkskill` | `checkskill_command.ex` | `查技能` | `cmds/skill/checkskill.c` | 查单项技能详情：等级、有效等级、进度条、可学招式、enable 状态 |
| P1 | `prepare` | `prepare_command.ex` | `备招` | `cmds/skill/prepare.c` | 组合拳术：`prepare finger strike` 将指法+掌法组合（最多2种）；`prepare ?` 列出可组合种类；`prepare none` 取消；仅限拳术类（finger/hand/cuff/claw/strike/unarmed） |

**验收**：`技能` 显示完整分类表；`查技能 基本剑法` 显示等级/有效/进度/招式；`备招 sword liu` 后 `info` 显示映射生效。

---

### 批次 2：精力养成闭环（依赖 Vitals jing、Stats potential，中风险）

| 优先级 | LPC 命令 | Kantele 命令模块 | 中文别名 | LPC 参照文件 | 关键逻辑 |
|---|---|---|---|---|---|
| P0 | `respirate` / `tuna` | `respirate_command.ex` | `吐纳` / `炼精` | `cmds/skill/respirate.c` | 耗精炼精力上限：参数为耗精量（正整数）、qi≥70%、非战斗、非 no_fight；每轮将 force/10 的精转化为 max_jing，直到精尽或参数耗完；Kantele 可加参数≥10 下限（参照 dazuo） |
| P1 | `jingzuo` | `jingzuo_command.ex` | `静坐` | `cmds/skill/jingzuo.c` | 峨嵋派专属（Kantele 可改为通用或保留门派限制）；需大乘般若功≥40；静坐 45-90 秒后获得 combat_exp + potential；消耗 jing；有冷却时间（120秒） |
| P2 | `closed` | `closed_command.ex` | `闭关` | `cmds/skill/closed.c` | 大宗师玩法：需 ultrap、潜能≥10000、qi/jing≥90%、sleep_room+no_fight 房间；周期消耗潜能增技能等级；实现可简化为占位+配置开关 |

**依赖**：b 期已有 `exercise/dazuo`（打坐）框架，直接复用 busy 循环 + Vitals.damage(:jing) + 瓶颈判定逻辑。

**验收**：`吐纳 30` 能把 max_jing 从默认推到瓶颈；`静坐` 同理；`闭关` 占位命令不报错、有配置开关默认关。

---

### 批次 3：秘籍自学（依赖 Item Meta book 字段、learn 校验链，中风险）

| 优先级 | LPC 命令 | Kantele 命令模块 | 中文别名 | LPC 参照文件 | 关键逻辑 |
|---|---|---|---|---|---|
| P1 | `study` / `yanjiu` | `study_command.ex` | `研习` / `读书` | `cmds/skill/study.c` | 背包有秘籍（item.meta.book = %{skill, max_level, cost_jing...}）→ 耗精+潜能自学，无需师父；受 exp_gate/valid_force 同效 |

**依赖**：a4 D1 已扩展 Item Meta book 五元组；b 期 learn 校验链（learned_points/jing_cost/exp_gate/valid_force）复用。

**验收**：背包放《柳心剑法秘籍》→ `研习 秘籍` → learned_points/jing 扣费、技能等级升、exp_gate 生效。

---

### 批次 4：战斗/移动辅助（依赖 Combat/Room 事件，低风险）

| 优先级 | LPC 命令 | Kantele 命令模块 | 中文别名 | LPC 参照文件 | 关键逻辑 |
|---|---|---|---|---|---|
| P1 | `flee` | `flee_command.ex` | `逃跑` | `cmds/std/go.c` / combat | 战斗中尝试脱离：随机出口、受 wimpy/负重/dex 影响；失败 busy 1-2 轮 |
| P1 | `wimpy` | `wimpy_command.ex` | `逃跑设置` / `自动逃跑` | `cmds/usr/wimpy.c` | 设置气血百分比阈值（0-80），低于阈值自动 flee；`wimpy 0` 关闭；无参数显示当前设置 |
| P1 | `surrender` | `surrender_command.ex` | `投降` | `cmds/std/surrender.c` | 战斗中投降：清除敌对关系脱战；扣50阅历（score）；若对方仍主动攻击则被拒 |

**验收**：`逃跑` 有成功/失败反馈；`wimpy 30` 后被打到 30% 血自动触发逃跑；`投降` 立即脱战回出生点。

---

### 批次 5：社交/物品交互扩展（依赖现有通信/物品系统，低风险）

| 优先级 | LPC 命令 | Kantele 命令模块 | 中文别名 | LPC 参照文件 | 关键逻辑 |
|---|---|---|---|---|---|
| P1 | `give` | `give_command.ex` | `给` | `cmds/std/give.c` | `give <物品> <玩家>` 或 `give <物品> to <玩家>`：背包→目标背包；NPC 可拒绝（no_accept 配置）；支持数量 `give 3 gold 张三` |
| P1 | `follow` | `follow_command.ex` | `跟随` | `cmds/std/follow.c` | `follow <玩家>`：自动跟随移动；`follow none` 取消 |
| P1 | `recall` | `recall_command.ex` | `回城` | `cmds/usr/recall.c` | 回出生点/师门（有师门则回师门房间）；非战斗可用 |
| P2 | `finger` | `finger_command.ex` | `查看` | `cmds/usr/finger.c` | `finger <玩家>`：显示对方 score/public 信息（门派/等级/师父/阅历） |
| P2 | `hp` | `hp_command.ex` | `血气` | `cmds/usr/hp.c` | 单行简略状态：`气血: 120/150 内力: 180/200 精力: 100/120` |

---

### 批次 6：组队/坐骑/个性化（高级系统，可独立里程碑）

| 优先级 | LPC 命令 | Kantele 命令模块 | 中文别名 | 备注 |
|---|---|---|---|---|
| P3 | `team` 系列 | `team_command.ex` | `组队` | `team with <人>`/`team dismiss`/`team list`；队伍经验分享、跟随队长移动 |
| P3 | `ride` / `unride` | `ride_command.ex` | `骑马` / `下马` | 物品类型 `mount`，移动速度加成、负重加成 |
| P3 | `title` | `title_command.ex` | `头衔` | 称号系统：成就/门派/任务获得，`title list`/`title wear <id>` |
| P3 | `nick` | `nick_command.ex` | `昵称` | 显示名自定义，`nick <新名>`/`nick none` |
| P3 | `color` | `color_command.ex` | `颜色` | ANSI 颜色主题：`color default`/`color none`/`color full` |
| P3 | `option` | `option_command.ex` | `选项` | 个人设置位图：`option brief`/`option combat` 等 |
| P3 | `alias` | `alias_command.ex` | `别名` | 玩家自定义命令别名：`alias jl jiali` 存玩家 meta |
| P3 | `save` | `save_command.ex` | `存档` | 手动触发 `Records.save`（已实时自存，此命令仅给安心感） |
| P3 | `suicide` | `suicide_command.ex` | `自杀` | 确认两次删除角色档案（慎用，需二次确认流程） |

---

## 三、实施规范

### 1. 命令模块模板

```elixir
# lib/kantele/character/commands/<name>_command.ex
defmodule Kantele.Character.<Name>Command do
  @moduledoc """
  <中文说明>：`<英文命令>` / `<中文别名>`
  ...
  """
  use Kalevala.Character.Command
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  # ...

  def run(conn, params) do
    # 1. 参数解析与校验
    # 2. 业务逻辑（调用 Stats/Vitals/Combat/Skills 等核心模块）
    # 3. 结果渲染 + Records.save(如有持久化变更)
  end
end
```

### 2. Router 注册

在 `lib/kantele/character/commands.ex` 中，仿照现有格式新增 `module(XxxCommand) do ... end` 块。
**不要**用 `command_routes/0` 列表——系统不支持该格式。

```elixir
# ---- 技能进阶 ----
module(SkillsCommand) do
  parse("skills", :run)
  parse("myskill", :run)  # myskill 是 skills 的增强版，合并为同一模块
  parse("技能", :run)
  parse("我的技能", :run)
end

module(CheckskillCommand) do
  parse("checkskill", :run, fn command ->
    command |> spaces() |> text(:skill)
  end)
  parse("查技能", :run, fn command ->
    command |> spaces() |> text(:skill)
  end)
end

module(PrepareCommand) do
  parse("prepare", :run, fn command ->
    command |> spaces() |> word(:action) |> spaces() |> text(:perform)
  end)
  parse("备招", :run, fn command ->
    command |> spaces() |> word(:action) |> spaces() |> text(:perform)
  end)
end

# ---- 精力养成 ----
module(RespirateCommand) do
  parse("respirate", :run, fn command ->
    command |> spaces() |> text(:arg)
  end)
  parse("tuna", :run, fn command ->
    command |> spaces() |> text(:arg)
  end)
  parse("吐纳", :run, fn command ->
    command |> spaces() |> text(:arg)
  end)
  parse("炼精", :run, fn command ->
    command |> spaces() |> text(:arg)
  end)
end

# ---- 战斗/移动 ----
module(FleeCommand) do
  parse("flee", :run)
  parse("逃跑", :run)
end

# ---- 社交/物品 ----
module(GiveCommand) do
  parse("give", :run, fn command ->
    command |> spaces() |> text(:item_name) |> spaces() |> word(:name)
  end)
  parse("给", :run, fn command ->
    command |> spaces() |> text(:item_name) |> spaces() |> word(:name)
  end)
end
# ... 其余命令照此模式
```

### 3. 中文别名

中文别名**直接在 Router 的 `parse()` 中注册**，不需要单独的映射表。
参考 `commands.ex` 中已有的 `parse("北", :north, ...)` 等实现。

对于需要词边界的单字别名（如"给"），参照 `LookCommand` 的 `lookahead_not` 写法：

```elixir
parse("给", :run, fn command ->
  command |> spaces() |> text(:item_name) |> spaces() |> word(:name)
end)
```

对于多字别名（如"逃跑"、"血气"），直接 `parse` 即可，无需词边界。

完整的中文别名清单见第二节各命令行的"中文别名"列。

### 4. 测试要求

- 单测：`test/kantele/character/<name>_test.exs`（仿照 `eat_test.exs`、`exercise_test.exs` 等现有格式）
- e2e：`scripts/commands_e2e.exs` 或扩充现有 `phase_b_e2e.exs` —— 真实连接跑完整流程
- Router 别名测试：在 `test/kantele/character/router_aliases_test.exs` 中追加新别名的解析断言

---

## 四、依赖与顺序建议

```
批次1 (技能界面) → 批次2 (精力养成) → 批次3 (秘籍自学)
         ↓                                    ↓
批次4 (战斗/移动) ←─────────────────────── 复用 b 期校验链
         ↓
批次5 (社交/物品)
         ↓
批次6 (组队/坐骑/个性化) ——独立里程碑，可并行或延后
```

- 批次 1-3 依赖 a/b 期已完成的 Stats/Vitals/learn 链，**按序做最稳**
- 批次 4-5 仅依赖基础框架，**可并行或穿插**
- 批次 6 系统性大，**建议单独里程碑**，不阻塞主线

---

## 五、边界约束

- 不动 eff_* 层、不动 diff-stop、不动昏迷/毒、不动 Skill behaviour 协议
- 闭关/组队/坐骑等大系统**默认配置开关关闭**，观察期后再开
- 玩家自定义 alias 存 `meta.aliases`（Map），不落库或仅本地存
- 不执行 git commit，除非明确要求
- 所有新建文件：UTF-8 无 BOM、LF、末行换行、四空格

---

## 六、完成后

在本文件末尾追加实际做法摘要：
- 各批次完成的命令列表、偏离 LPC 的简化点
- 新增 config 开关名与默认值
- e2e 覆盖率、已知未实现的 LPC 边缘功能

供后续 d/h 期转换器/大世界搬运参考。

---

## 七、实际做法摘要（持续追加）

### Batch 4（已完成，commit 787898d）

**新增命令（3 个）：**

| 命令 | 中文别名 | 逻辑 |
|---|---|---|
| `flee` | `逃跑` | 战斗中随机出口脱逃；复用已有 FleeEvent 机制（room/flee → RandomExitEvent 提供出口 → FleeEvent 随机选 → request_movement） |
| `wimpy` | `自动逃跑` | 设置气血阈值 0-80，0 关闭；存 `character.meta.wimpy`（PlayerMeta 新增字段） |
| `surrender` | `投降` | 战斗中脱战：清空敌人 + 各敌人发 `combat/halt`，扣 50 阅历（score，扣至 0 为止），调用 Records.save |

**新增系统逻辑：**
- `CombatEvent.apply_hit` 中新增 `check_wimpy/3`：受击结算后若 qi/max_qi 百分比低于 `meta.wimpy` 阈值，自动触发 `room/flee` 事件

**偏离 LPC 的简化点：**
- `flee`：省略守卫/负重对抗（LPC fp/gp 闪避对抗、force_power 撞开玩家、`success_flee` temp flag），直接随机出口
- `surrender`：省略 `last_opponent->is_killing(me)` 拒绝逻辑（K 端无 is_killing 概念）
- `wimpy`：Router 需参数分词（`text(:arg)`），裸 `wimpy` 无参形式在 Router 层不可用（与 `run` 同 arity 默认参数冲突）；实际 `run` 内部处理空字符串 → 显示当前设置，但需输入 `wimpy <空格>` 触发

**配置开关：** 无新增。

**测试：** 新增 flee_command_test / wimpy_command_test / surrender_command_test 共 14 断言 + router_aliases_test 追加 6 断言。全量 260 tests 通过。

**已知未实现的 LPC 边缘功能：**
- `flee` 不校验负重（over_encumbranced）、不做守卫阻挡判定
- `wimpy` 自动逃跑不校验 no_fight 房间、不打印 "看来该找机会逃跑了" 与躲避语境（简化直接触发）

### Batch 5（已完成）

**新增命令（5 个）：**

| 命令 | 中文别名 | 逻辑 |
|---|---|---|
| `give` | `给` | 赠送物品：`give 物品 to 人` / `give 人 物品` / `give all to 人` / `give 数量 物品 to 人`；房间解析目标 → 收受端入包回执 → 赠与端移除落盘（round-trip） |
| `follow` | `跟随` | 跟随某人 / `follow none`；leader 移动时沿同出口自动跟随，双方互登记 |
| `recall` | `回城` | 回当前区域（zone）起始房间（`startroom` flag，无则首房） |
| `finger` | `查找` | 无参列在线玩家，带参查玩家资料（简化：无 jing 消耗/扫描冷却） |
| `hp` | `气` | 展示精气/气血/内力/精力/食物/潜能（简化：仅自身，无 -m/-g 巫师参数） |

**新增系统逻辑：**
- `PlayerMeta` 新增 `:leader`（`%{id,name,pid}`）与 `followers: []`（`[%{id,name,pid}]`）字段
- `Room.GiveRequestEvent`：`room/give` 目标按 NameMatch 解析，找不到即提示，找到则向目标发 `characters/give`
- `Room.FollowRequestEvent`：`room/follow` 目标解析，双向发 `follow/register` + `follow/set-leader`
- `GiveEvent`：收受端 `characters/give` 入包落盘并回执 `give/result`；赠与端 `give/result` 移除物品落盘
- `FollowEvent`：`set-leader`/`register`/`unregister`/`move`（`follow/move` 执行 `request_movement`）
- `MoveEvent.commit`：`notify_followers/2` —— leader 移动时对每个存活的 `meta.followers` 发 `follow/move`（带 exit_name）
- 复用 `Kantele.Character.Teleport.teleport/2`（两段 Movement + 重订阅房间频道）做回城

**偏离 LPC 的简化点：**
- `give`：数量拆分（`give N 物品`）简化为整物转移；无 `no_accept`/`give_all` 限流/日志；装备判定按快照名（快照无 instance id）
- `follow`：不做 LPC 的守卫/隔室/战斗掉队等复杂跟进规则，仅"leader 移动⟶followers 同出口移动"；followers 以 pid 存运行态（不落盘），靠 `Process.alive?` 兜底
- `recall`：LPC 用地图坐标定点，Kantele 改用"区域起始房间"（`startroom` flag / 首房）；不做 outdoors/maze/area 限制
- `finger`：去掉 jing 消耗与 10 秒扫描冷却，不做 -m 参数
- `hp`：去掉怒气/死亡保护/-m/-g 明细

**配置开关：** 无新增。

**测试：** 新增 give/follow/recall/finger/hp 五个命令测试（31 断言）+ router_aliases_test 追加 Batch 5 别名断言。全量 292 tests 通过。

**已知未实现的 LPC 边缘功能：**
- `give` 拒绝逻辑（`no_accept`/是否收下）未实现，收受端无条件入包；living 物/riding 物使其不能给的判定省略
- `follow` 不在战斗/警戒/负重等场景下自动断跟随，无 LPC 的"跟随对象隔房间自动跟上"之外的复杂行为
- `recall` 无冷却、无金币消耗（LPC 本指令无消耗，仅认证）

### Batch 6（待办）

按批次清单：team/ride/title/nick/color/option/alias/save/suicide。建议单列里程碑，与用户确认后继续。


