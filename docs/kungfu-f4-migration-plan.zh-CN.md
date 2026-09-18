# Kantele F4 招式/内功批量迁移执行计划

> 状态：草案（待拍板架构决策项 D1–D7）
> 上游：`docs/kungfu-framework-build-plan.zh-CN.md`（F4 章节）
> 数据清单：`docs/kungfu-f4-migration-checklist.zh-CN.md`（644 条）
> 工具：`scripts/translate_perform.exs`、`scripts/f4_checklist.exs`
> 参照物：LPC `C:\files\git\mud\kungfu\skill`（只读）

---

## 1. 背景与现状

F4 管线的前半段已完成并推送：

- **提取器**：`scripts/translate_perform.exs`（`Scripts.TranslatePerform`）已跑通全量，产出 644 个 perform/exert 骨架（428 个 skill 目录）。输出默认落 `tmp/perf_out/`（暂存区，不进编译路径）。
- **三个样板**已实装并测试锁定，覆盖 perform/exert 全链路：
  - `force/power`（运功自我增益，`Skills.Force`）
  - `huashan-jian/jie`（攻击型 + 目标侧结算，`Skills.HuashanJian`）
  - `chousui-zhang/dan`（远程 + 目标侧 + 回执扣费，`Skills.ChousuiZhang`）
- **校对清单**：`docs/kungfu-f4-migration-checklist.zh-CN.md`，按复杂度分档：
  | 档 | 含义 | 数量 |
  |---|---|---|
  | T1 | 自我增益 exert（无目标、无条件） | 86 |
  | T2 | 无目标 perform（自我/治疗/位移等） | 193 |
  | T3 | 攻击型 perform（`do_damage`，走目标侧结算） | 169 |
  | T4 | 状态/毒型（`affect_by` 非空，需条件宿主） | 12 |
  | T5 | 需 `prepare_skill`（当前被 prepare 门槛阻塞） | 184 |

**剩余工作 = 把这 644 条从骨架变成可玩内容**，并对齐技能本身（招式表 / 学习门槛 / 练习消耗）。

### 1.1 规模盘点（LPC 侧）

| 项 | 数量 |
|---|---|
| skill 目录（含 perform/exert） | 442 |
| 顶层技能文件 `<skill>.c` | 719 |
| 含 action 招式表 | 447 |
| `perform_action_file` | 464 |
| `exert_function_file` | 106 |
| `valid_enable` | 652 |
| `valid_learn` | 690 |

### 1.2 引擎现状（关键落点）

| 能力 | 位置 | 现状 |
|---|---|---|
| 武学注册表 | `lib/kantele/combat/skills.ex` `@static` | 仅 7 门（硬编码 map） |
| 武学行为契约 | `lib/kantele/combat/skill.ex` | `@actions` 数据 + `perform_list/0` + `exert_list/0` |
| 命令分派 | `commands/perform_command.ex`、`exert_command.ex` | 可用；`exert` 有 force 公共运功 fallback |
| 绝招习得标记 | `character/stats.ex` `perform_known?/2`、`learn_perform/2`（`performs` MapSet） | 可用 |
| 授予链路 | `sect_master.ex`、`events/npc_script_event.ex`、`commands/learn_command.ex`、`item/qianzhumiji.ex` | 已有样板，但未批量覆盖 |
| 攻击型目标侧结算 | `events/combat_event.ex` `perform_incoming/2` | **硬编码 `cond` 匹配 `perform_id`**（仅 jie/dan） |
| 回执 | `combat_event.ex` `perform_feedback/2` | 通用（neili_cost/busy） |
| 显示 | `commands/checkskill_command.ex` | 读 `perform_list`/`exert_list` |

---

## 2. 目标与验收标准

**总目标**：442 门技能的 perform/exert 与技能元数据全部落地，玩家/师父可获得并施展，数值与 LPC 对拍。

**分批验收（每批）**：

1. 该批每个骨架的 `TODO(migrate)` 清零或被明确降级（写成文档化差异）。
2. 该批技能可 `enable`、可 `practice`、可 `perform`/`exert`（实机命令走通）。
3. 单测覆盖：门槛全分支、资源扣减、效果落账；攻击型另加目标侧三分支（命中/闪避/死亡）。
4. `checkskill` 正确列出招式/运功。
5. 全量 `MIX_ENV=test mix test` 绿。
6. 提取器重跑不覆盖手写实现（见 D7）。
7. 独立提交推 `origin/kalevala`。

---

## 3. 架构缺口与决策项（Phase 0 前拍板）

> 以下 7 项是批量迁移的真正瓶颈；不先解决，逐个手写 644 个模块不可持续。

### D1 目标侧分派去硬编码 【建议：做，且优先】

现状 `combat_event.ex:308-312` 用 `cond` 硬编码 `perform_id`。169 个攻击型招式不能逐个加分支。

建议：
- 新增 `Kantele.Combat.Performs` 注册表：`perform_id -> 攻击侧模块`（可由 `Skills` + `perform_list` 反查，或显式注册）。
- 攻击侧模块增加**可选回调** `resolve_incoming(conn, target_character, attacker_snapshot, data)`（目标侧）与 `interactive?/0`（是否需要目标）。
- `combat_event.perform_incoming/2` 改为：按 `perform_id` 查模块 → 有回调则调用，否则忽略。
- `jie`/`dan` 的 `resolve_*` 迁到各自模块，删除硬编码分支。
- 回执 `send_feedback` 提为公共 API（`Kantele.Combat.Performs.feedback/3`）。

### D2 技能元数据提取（步骤 2）【建议：做】

顶层 `<skill>.c` 的 `mapping *action`（447 个）格式规整，可自动抽取 `name/action/force/attack/parry/dodge/damage/lvl/damage_type` 八字段；`valid_enable`/`valid_learn`/`practice_skill` 半结构化。

建议：
- 扩展提取器（或新增 `scripts/translate_skill.exs`）解析顶层文件 → 生成数据。
- 生成物二选一：
  - (a) `Kantele.Combat.Skills.Generated` 一个数据模块（`skill_id => %{actions:, enables:, costs:}`）；
  - (b) 每技能一个 `skills/generated/<skill>.ex`。
- 复杂 `valid_learn`/`practice_skill`/`hit_ob`/`valid_damage`/动态招式仍人工实装，数据模块提供兜底。

### D3 简单 perform/exert 声明式解释器 【建议：做，收益最大】

T1+T2 = 279 条（43%）多为固定模式：门槛链 → 扣资源 → set_temp/apply 加成 → busy。可把提取器升级为输出**结构化 spec**，由通用解释器执行，人工只校对 spec（diff 小）。

建议：
- spec 形状（Elixir 数据）：`%{gates: [...], costs: [...], effects: [...], busy: n, on_fail: msg}`。
- 通用模块 `Kantele.Combat.Performs.Simple`（exert）与 `...Perform.Simple`（perform）。
- 超出 spec 表达力的（动态分档、多段、目标交互、条件附加）回退手写模块。
- 目标：T1 ≥90%、T2 ≥70% 走声明式。

### D4 `prepare_skill` 状态与命令 【建议：做，解锁 T5】

184 条 T5 卡在 `query_skill_prepared` 门槛；LPC 有 `prepare <skill>` 命令把某用法预备到招式。

建议：`stats.prepared`（MapSet 或 map，`usage => skill_id`）+ `prepare` 命令 + 门槛读取；迁移后 T5 的 `prepared:` 门槛改为真实校验。

### D5 绝招习得/授予链路 【建议：做，否则做了也发不出】

每个 perform 由 `Stats.perform_known?("skill/move")` 门控，但批量招式目前**无处可学**。已有样板路径可复制：
- 师父/门派：`sect_master.ex` `inquiry_grant` + UCL `perform_id` 配置；
- NPC 对白脚本：`npc_script_event.ex`；
- 书本/物品：`qianzhumiji.ex` 模式。

建议：随技能迁移，生成对应 `can_perform/<skill>/<move>` 的授予配置（门派师父批量由 UCL 生成器承接，见 F3 遗留）。

### D6 注册规模 【建议：做】

`Skills.@static` 手写 428 行不可维护。

建议：生成 `Skills` 静态表（或单独的 `generated_skills.ex`），手写实现优先、生成兜底。

### D7 提取器覆盖保护 【建议：做】

`write_skeleton/3` 会把已存在文件重渲染覆盖；一旦 `KUNGFU_OUT` 指向 `lib/`，会把手写实现打回骨架（本次已发生过一次）。

建议：若目标文件存在且**不含**「由 translate_perform.exs 骨架生成」标记，则跳过并计入 `skipped(手写保护)`。

---

## 4. 分阶段计划

### Phase 0 — 基础设施（阻塞全部内容批）

- [x] 0.0 **已知缺陷清理**（见 §6 风险 R1/R2/R11，均已修复）：
  - `combat_event.ex` `resolve_dan` 的「火毒」块**重复两次**，会双倍附毒；已去重（`891604f`）。
  - `performs/chousui_zhang/dan.ex` `check_handing` 对缺键 map 用点取会 raise；已改 `Map.get`（`891604f`）。
  - `combat_event.ex` `resolve_dan` 护甲损耗重绑陷在 `if` 作用域内（死代码，扣甲不生效、文案恒「肌肤」）；已抽 `wear_armor/1` 返回落账（`98959a1`）。
- [x] 0.1 D1 目标侧注册表 + 可选回调；迁移 `jie`/`dan` 的 `resolve_*`；提公共 `feedback`（`93d17d4`）：
  - 新增 `Kantele.Combat.Perform` behaviour（`run/1` + 可选 `resolve_incoming/4`）与
    `Kantele.Combat.Performs`（`lookup/1`、`resolve_incoming/5`、`feedback/3`）。
  - `combat_event.ex` `perform_incoming` 删除 `perform_id` 硬编码 `cond`；`resolve_jie`/`resolve_dan`
    迁入各自模块的 `resolve_incoming/4`；新增 `performs_test`（5 例）。
- [x] 0.2 D2 技能元数据提取器 → 生成数据模块（本提交）：
  - 新增 `scripts/translate_skill.exs`（`Scripts.TranslateSkill`）：解析顶层 `<skill>.c` 的
    静态招式表（归一 `name`→`skill_name`、`dmage`→`damage`）、`valid_enable` 用法集合、
    `practice_skill` 消耗，并列出动态招式数与钩子/条件清单。
  - 产出 `tmp/skill_out/<skill>.ex` 骨架（`Kantele.Combat.Skills.Generated.*`）+ `_summary.md`；
    全量 719 门已跑通，`String.valid?` 与 `Code.compile_file` 复检 0 失败。
  - 新增 `test/kantele/f4_skill_extractor_test.exs`（10 例）。
- [ ] 0.3 D3 spec + `Simple` 解释器（先支持 exert，再 perform）。
- [ ] 0.4 D4 `prepare_skill` 状态 + `prepare` 命令。
- [ ] 0.5 D6 注册生成器 + D7 覆盖保护。
- [ ] 0.6 批次工程化：`f4_checklist` 支持勾选回写/筛选；批量补注册脚本；测试模板。

### Phase 1 — T1 exert 自我增益（86）

- [ ] 分批（建议 4 批 × ~20）：`powerup`/`shield` 占多数，可高度声明式。
- [ ] 差异项：`suck`/`freeze`/`dispel`/`heal`/`regenerate` 等带吸取/条件分支，手写。
- [ ] 每批补 `exert` 命令回归（含 force fallback）。

### Phase 2 — T2 无目标 perform（193）

- [ ] 分批（建议 8–10 批 × ~20）。
- [ ] 先做 `heal`/`recover`/自我 buff 类声明式；后做带内部状态/随机分档的手写。

### Phase 3 — T3 攻击型 perform（169）

- [ ] 依赖 0.1；分批（建议 8 批 × ~20）。
- [ ] 统一模式：门槛（known/target/weapon/level/mapped/neili）→ 发 `perform-incoming` → 目标侧 `resolve_incoming` → 回执扣费。
- [ ] 按武器/伤害类型分组对拍，收敛 `resolve` 公共逻辑。

### Phase 4 — T4 状态/毒型（12）

- [ ] 依赖 0.1 + 条件宿主（F1 已有 `ConditionEvent`）。
- [ ] 逐个实装（`affect_by` 条件 id 需在 `ConditionRegistry`/`@daemons` 对齐）。

### Phase 5 — T5 需 prepare（184）

- [ ] 依赖 0.4；解锁后按 T2/T3 模式批量回填 `prepared:` 门槛。
- [ ] 与对应技能族合并迁移，避免二次返工。

---

## 5. 每批标准作业流程（SOP）

1. **选批**：从 `docs/kungfu-f4-migration-checklist.zh-CN.md` 取 ≤20 条，标注批次号。
2. **生成**：`KUNGFU_SRC=/tmp/kungfu_skill RUN_EXTRACTOR=1 mix run scripts/translate_perform.exs` → `tmp/perf_out/`。
3. **校对**：逐条对照 `.c` 源，确认门槛/效果事实；能声明式的写 spec，否则手写模块。
4. **实装**：挑入 `lib/kantele/combat/skills/performs/<skill>/<move>.ex`；技能元数据补 `skills/`。
5. **注册**：更新 `Skills`（生成表）+ 生成对应 `perform_list`/`exert_list`。
6. **测试**：每招式至少 1 组门槛分支 + 1 组效果断言；攻击型加目标侧三分支。
7. **全量**：`MIX_ENV=test mix test` 绿。
8. **文档**：勾选 checklist；在 `kungfu-framework-build-plan` 记本批进度。
9. **提交**：独立 commit 推 `origin/kalevala`。

**Definition of Done（每批）**：§2 的 7 条全满足。

---

## 6. 风险登记

| ID | 风险 | 影响 | 对策 |
|---|---|---|---|
| R1 | `resolve_dan` 火毒块重复 | 中毒双倍，数值错 | 已修 `891604f` + 断言测试 |
| R2 | `check_handing` 对缺键 map 用 `handing.meta` | 可能 raise | 已修 `891604f`（改 `Map.get`） |
| R3 | 目标侧 `cond` 硬编码 | 无法扩展 169 招式 | D1 注册表 + 回调 |
| R4 | 招式无授予链路 | 实装后玩家学不到 | D5 随批生成授予配置 |
| R5 | 技能元数据（招式表/学习/练习）未迁移 | 只有绝招、无平砍 | D2 提取器已就绪（`translate_skill.exs`，719 骨架见 `tmp/skill_out/`）；待分阶段实装 |
| R6 | `prepare_skill` 未实现 | 184 条阻塞 | D4 |
| R7 | 提取器覆盖手写实现 | 回退事故 | D7 标记保护 |
| R8 | 428 门注册/编译规模、启动时长 | 启动慢、编译久 | D6 生成表；观测 `mix compile`/启动指标 |
| R9 | NPC 战斗 AI 不施放 perform | NPC 强度不符 | 记入后续（`npc.ex` 仅 behaviour，无实现） |
| R10 | 数值对拍缺口（动态招式/分段公式） | 平衡偏差 | 每批抽样对拍；差异写文档 |
| R11 | `resolve_dan` 护甲损耗重绑陷在 `if` 作用域（死代码） | 扣甲不生效、文案恒「肌肤」 | 已修 `98959a1` + `wear_armor/1` |

---

## 7. 里程碑（相对顺序，不排日历）

```
Phase 0.0 清理 ─┐
Phase 0.1 目标侧分派 ─┼─> Phase 3 T3 ─┐
Phase 0.2 元数据提取 ─┤               ├─> Phase 5 T5（依赖 0.4）
Phase 0.3 声明式解释器 ┼─> Phase 1 T1 ─┤
Phase 0.4 prepare ─────┘   Phase 2 T2 ─┘
                            Phase 4 T4（依赖 0.1）
```

建议顺序：**0.0 → 0.1 → 0.3 → Phase 1（T1）→ 0.2 → Phase 2 → 0.4 → Phase 3 → Phase 4 → Phase 5**。先打通最简档（T1）验证声明式管线，再扩大。

---

## 8. 附录：关键文件与命令

**实现**
- `lib/kantele/combat/skills.ex`、`lib/kantele/combat/skill.ex`
- `lib/kantele/combat/skills/{force,huashan_jian,chousui_zhang,liuxin_jian,taiji_quan,...}.ex`
- `lib/kantele/combat/skills/performs/{force/power,huashan_jian/jie,chousui_zhang/dan}.ex`
- `lib/kantele/character/commands/{perform_command,exert_command,checkskill_command}.ex`
- `lib/kantele/character/events/combat_event.ex`（`perform_incoming/2`、`perform_feedback/2`）
- `lib/kantele/character/stats.ex`（`perform_known?/2`、`learn_perform/2`）
- `lib/kantele/sect_master.ex`、`lib/kantele/character/events/npc_script_event.ex`、`lib/kantele/item/qianzhumiji.ex`

**工具**
- `scripts/translate_perform.exs`（骨架提取）
- `scripts/f4_checklist.exs`（清单生成）
- `docs/kungfu-f4-migration-checklist.zh-CN.md`（644 条）

**常用命令**
```sh
# 提取（容器内）
docker exec wuxia_mud_dev-app-1 sh -lc "cd /app && KUNGFU_SRC=/tmp/kungfu_skill RUN_EXTRACTOR=1 mix run --no-start scripts/translate_perform.exs"
# 清单
docker exec wuxia_mud_dev-app-1 sh -lc "cd /app && KUNGFU_SRC=/tmp/kungfu_skill RUN_CHECKLIST=1 mix run --no-start scripts/f4_checklist.exs"
# 测试
docker exec wuxia_mud_dev-app-1 sh -lc "cd /app && MIX_ENV=test mix test"
```

**验证 UTF-8（勿用 iconv 同编码，直通不校验）**
```elixir
String.valid?(File.read!("path"))   # 唯一可信判定
```
