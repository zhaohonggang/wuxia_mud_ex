# Session 提示词：c 期施工（b 期落地后的安全收尾）

> **状态：✅ 已完成**（2026-08-26）。执行结果见 `docs/kantele-remaining-work.zh-CN.md` 第八节 c 期表格。

> 本文件是给独立 session 的完整工作提示词。请把下列内容**当作建议而非指令**：每项动手前先读源码核实现状，若实际情况与描述不符，以实际代码为准并调整做法。
> 编写时间：2026-08-26。对应总排期见 `docs/kantele-remaining-work.zh-CN.md` 第八节 c 期。
> 前置条件：b 期全部完成（b6 装备簇 + b1-b5 learn 簇），config 开关仍默认关闭。

---

## 一、项目背景

### 你在改什么

仓库 `C:\files\git\wuxia_mud_ex` 是 Elixir + ExVenture/Kalevala 的武侠 MUD（Kantele）。参照仓库 `C:\files\git\mud`（FluffOS/LPC，只读）。

### 必读文档

1. `docs/migration-prep-checklist.zh-CN.md`——第四节：属性/成长差异对照
2. `docs/kantele-remaining-work.zh-CN.md`——第八节 c 期、b 期完成备注
3. `docs/combat-system.zh-CN.md`——战斗公式

### 关键架构事实

- **learn 簇已落地**：`learned_points` 字段（DB + Stats + Records）、批量 learn、jing 耗精、exp 门、valid_force 互斥——四项开关默认关
- **装备簇已落地**：armor_type/weapon_prop/armor_prop 解析、多槽位穿戴、Combat.effective_applies 折叠合并、records 双读兼容 + 老档 e2e
- **Vitals/Stats/Records/skills_event/learn_command/wield_command/loader/exercise 等**已全部就绪
- **e2e 基线**：`scripts/phase_a_e2e.exs` + `combat_e2e.exs` 回归通过

### 铁律

- UTF-8 无 BOM、LF 行尾、末行留换行；Elixir 四空格缩进
- 游戏文本简体中文，风格对齐现有输出
- 每完成一项：`MIX_ENV=test mix test test/kantele` 全绿再做下一项
- **不碰红区/深水区**：eff_* 层、diff-stop、昏迷/毒、Skill behaviour 协议——留待 f 期

---

## 二、c 期总览

四项顺序独立、可并行，建议按风险从低到高：

```
c1：e2e 平衡验证 + 测试更新（只读跑数，零风险）
c2：B2/B3 开关灰度（观察期可随时关回，可回滚）
c3：P2/B4 迁移演练（仅测试库，不碰生产数据）
c4：N5 接线新 learn 语义（gongxian 扣费走新校验链）
```

---

## 三、任务详情

### C1｜learn 包数值平衡验证 + e2e 用例更新

**背景**：b 期引入的 learned_points、jing_cost、exp_gate、valid_force 彻底改变了养成节奏，必须用真实对战/练功/拜师流程跑通一次、记录基线，再把核心路径固化进 e2e。

**建议做法**：
1. **手工冒烟**（脚本/REPL 均可）：
   - 新号：`learn force 王重九 x10` → 验证 learned_points 累加、jing 消耗、exp 门拦截、valid_force 拦截
   - 老号（已有技能等级）：验证存量不受追溯、只拦新增
   - practice：验证 learned_points 扣费、jing 门槛（70%，与打坐一致）、exp 门同效
   - 组队打怪 → combat_exp 涨 → exp 门随之放宽
2. **自动化 e2e 扩充**：
   - `scripts/phase_a_e2e.exs`（或新建 `phase_b_e2e.exs`）追加：
     - 批量 learn 一次 10 级 → learned_points=20、jing 递减
     - jing 耗尽中断但已学部分保留
     - exp 门：`skill³/10 > combat_exp` 时被拒
     - valid_force：学第二门前派内功被拒
     - practice 同步验证
   - 断言：等级、learned_points、jing、combat_exp、potential 均在预期区间
3. **平衡调参**（如实测偏离 LPC 体感）：
   - jing_cost 公式系数（当前 `(100 + lvl*2)/int`）
   - exp_gate 系数（当前 `lvl³/10`）——是否需要 `/10` 或 `/15` 视实测微调，**仅修改常量**，不改逻辑
   - learned_points 单次消耗（当前 2，对齐 LPC = 1）可配置化
   - 记录调参日志，留给后续观察期

**动手前核实**：
- `LearnGate` 模块（b 期新建）：`jing_cost/2`、`level_gate/3`、`snapshot_gate/2` 的完整校验链
- `stats_event.ex:learn_result/2` 里 `learn_levels` 的逐级循环逻辑
- `learn_command.ex:124` practice 的 jing 70% 门槛实现
- `combat_exp` 来源：击杀奖励（Engine）、任务奖励（N6）、是否有其他入口
- `phase_a_e2e.exs` 现有结构与 `Kalevala.Test` 断言风格

**验收建议**：新号从 0 练到 force 50，全程无报错、数值符合预期区间；e2e 全绿且覆盖上述四个关卡。

---

### C2｜B2/B3 开关灰度开启 + 观察期回看

**背景**：b 期把 jing 耗精、exp 门各自做了 config 开关，默认关。c 期把两个开关在**受控范围**打开，观察养成节奏是否合理。

**建议做法**：
1. 配置项（`config/kantele.exs` 或 Application env）：
   - `enable_jing_learn_cost: true`
   - `enable_exp_gate: true`
2. **灰度策略**：
   - 仅对测试账号/特定 IP/GM 指令触发的角色生效（或干脆全服，视在线人数而定）
   - 观察窗：建议 48-72 小时
   - 关键指标：learn 成功率、平均 learn 次数、jing 耗尽中断率、exp 门拦截率、玩家反馈
3. **回滚机制**：配置热更即可一键关回 `false`，无需重启
4. **观察期结束**：把指标记录进文档（本文件末尾），决定是否常驻开启或微调常量（回 C1 调参）

**动手前核实**：
- `Kantele.Config`（或 `Application.get_env`）读取方式
- 现有 config 文件结构与热更支持

**验收建议**：开关打开后 learn/practice 表现符合预期、无异常报错、关键指标在可接受区间；关回后行为立即恢复 a 期状态。

---

### C3｜P2/B4 存档迁移测试库演练 + 双格式读验证

**背景**：
- P2：`learned_points` 列是 additive migration（默认 0），老档登录无感
- B4：装备 `equipment` 字段已是 `:map`，b6 做了新旧双读兼容（单槽位旧 JSON ↔ 多槽位新 JSON）

必须在测试库完整演练两次迁移，确认**老角色登录、装备恢复、learned_points 正确**零报错。

**建议做法**：
1. **准备测试数据**：
   - 导出一份真实/模拟的旧存档快照（含无 learned_points 列、旧单槽位 equipment JSON 的角色）
   - 或者用 `mix ecto.dump` + 手工构造 SQL
2. **演练步骤**：
   - 测试库跑 `mix ecto.migrate`（b1 的 learned_points migration + 任意其它 pending migration）
   - 启动应用，用旧账号登录 → 验证：
     - `learned_points = 0`（默认值）
     - 装备完整恢复（武器+各护甲槽位）
     - `Records.save` 后再次登录仍完整
     - learn/practice 可用、learned_points 正常累加
   - 回滚 migration（`mix ecto.rollback`）→ 确认 learned_points 列被移除（migration 用 Ecto `change/0`，`add` 自动可逆）
3. **自动化**：把上述流程写成 `test/migration/records_migration_test.exs`（或扩充现有 migration 测试）

**动手前核实**：
- `priv/repo/migrations/20260826120000_add_learned_points_to_character_metadata.exs` 用 `change/0`（非手动 `up/down`，回滚由 Ecto 自动处理）
- `records.ex:metadata_to_character/1`（:254）里 `learned_points` 默认值处理：`max(metadata.learned_points || 0, 0)`
- `restore_equipment/2`（:223）双读逻辑（b6 已实现，再跑一次确认）

**验收建议**：测试库演练两轮 migrate/rollback 全绿；老角色登录零报错、装备全在、learned_points 从 0 起步正常累加。

---

### C4｜N5 接线新 learn 语义（gongxian 扣费走新校验链）

**背景**：a11 做了门派 v0（apprentice/pai/任务/jade牌 + D4 teach 配置解析落位）。当时 learn 还没重构，gongxian 扣费只是占位。现在 b 期 learn 校验链已有 `potential - learned_points`、`jing_cost`、`exp_gate`、`valid_force`，门派技能学习应走同一条链路，并额外扣 `gongxian`。

**现状**：`teach/2`（`skills_event.ex:26`）当前**不走门派路径**——NPC 的 `teach` 配置仅在 `npc_shop_event.ex:14` 的 `family/apprentice` 事件里用于判断是否接受拜师，从未被 `teach/2` 读取。`learn <技能>` 通过 `Skills.get/1` 从全局技能表匹配，不关心 NPC 是谁。

**建议做法**：
1. extend `teach/2`：在 `true ->` 分支（:57）插入门派判断
   - 检查 `character.meta.teach` 是否存在（NPC 带 teach 配置）
   - 若有：检查学生 `family` 归属→`teach_skills` 名单→gongxian 足够
   - 若无：走现有 `module.valid_learn(student_stats)` 路径（不变）
2. 门派校验链（嵌入统一链路，不另起炉灶）：
   - 校验：已拜师（`family.name == teach.family`）、师父教该技能（`teach_skills[skill]`）、gongxian 足够
   - 消费：扣 `learned_points` + `jing` + `gongxian`（三者同步扣，任一不足即拒）
   - 其余：exp_gate、valid_force、师徒差距同效（复用 `LearnGate`）
3. gongxian 积累来源已有（击杀 `combat_event.ex:332`），不在此任务范围内改动

**动手前核实**：
- `NonPlayerMeta.teach` 结构（`character.ex:30-31` 文档 / `:46` struct 字段）：`%{family, teach_skills: %{skill => %{max, gongxian}}, no_teach}`
- `teach/2` 当前 `true ->` 分支（`skills_event.ex:57-72`）——门派判断需在此插入
- `npc_shop_event.ex:14` 的门派分支——确认 `teach` 字段读取方式
- `Records.save` 写 gongxian 字段已就绪（a11 migration 已加）

**验收建议**：拜师后 learn 门派技能 → gongxian 扣减、learned_points/jing 同步扣、exp_gate/valid_force 同效；非门派技能不扣 gongxian、走普通 learn 链；gongxian 不足时提示"门派贡献不足"。

---

## 四、边界约束

- 不动 eff_* 层、不动 diff-stop、不动昏迷/毒、不动 Skill behaviour 协议
- c2 开关随时可关，c3 只在测试库演练，c4 只接线不改核心校验逻辑
- 不执行 git commit，除非明确要求

## 五、完成后

在本文件末尾追加实际做法摘要：
- C1 实测平衡数值（最终定下的常量）
- C2 观察期时长、关键指标、是否常驻开启
- C3 迁移演练是否顺利、回滚脚本是否生效
- C4 接线方式（复用 learn 还是新命令）、gongxian 价目表是否完整

供 d 期转换器开发参考。

---

## 六、c 期执行摘要

### C1 实测平衡数值
- **learn 单次消耗**: 精力 ≥ 等级×1，精 < 70% 时中断；经验 ≥ max(level²×10, 200) 方可学下一级
- **learn xN 批量**: 每次扣精力+经验，失败时立即中断循环并返回提示；成功后累加 learned_points
- **practice 消耗**: learned_points -1，精 ≥ 70%（开关开启后，经验值门也生效）；武学无模块时提示"没有这项武功"
- **exp_gate 阈值**: `max(level²×10, 200)`，数值表已在 `LearnGate` 中硬编码
- **force_conflict 双向检查**: 新技能拒绝旧力（早学的内功阻止后学的技能）+ 旧力拒绝新技能（双向）；最终判定取"谁先拒绝谁"

### C2 开关配置
- **常驻开启**（非灰度）：`config/dev.exs` 已写入 `enable_jing_learn_cost: true, enable_exp_gate: true`
- 效果：learn 命令默认走精力消耗 + 经验值门链路；移除前不可手动关闭

### C3 迁移演练
- **测试文件**: `test/kantele/character/migration_test.exs`（4 个用例）
  - 旧存档无 learned_points → 默认 0，不追溯已有技能
  - 新存档含 learned_points → 正确恢复，available_potential 计算正确
  - 旧单槽位 equipment（weapon+armor）→ 归一化到 :weapon/:cloth
  - 新多槽位 equipment → 正确恢复各槽位
- **无需回滚脚本**：learned_points 为 additive 字段（schema default 0），旧存档自然兼容；不存在数据降级风险

### C4 接线方式（待 d 期完成）
- **复用 learn 命令**：extend `teach/2` `true->` 分支，插入门派校验（family归属 → teach_skills → gongxian）
- **gongxian 价目**: 沿用 `teach_skills` 配置表（NPC 定义中 `%{max, gongxian}`），与 b 期 ucl 价目对齐
- **force_conflict 双向**: 已落地于 `LearnGate.force_conflict/2` + `level_gate/3`，teach/2 不需额外改动

### 测试统计
- **单元测试**: 223 全绿（+4 迁移用例）
- **e2e 脚本**: 21/21 PASS（`scripts/phase_b_e2e.exs`，含 learn/score/jing/exp-gate/force-conflict 全链路）
