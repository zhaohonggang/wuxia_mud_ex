# Session 提示词：b 期施工（learn 校验链重构 + 装备多槽位）

> **状态：✅ 已完成**（2026-08-26）。执行结果见 `docs/kantele-remaining-work.zh-CN.md` 第八节 b 期表格。

> 本文件是给独立 session 的完整工作提示词。请把下列内容**当作建议而非指令**：每项动手前先读源码核实现状，若实际情况与描述不符，以实际代码为准并调整做法。
> 编写时间：2026-08-26。对应总排期见 `docs/kantele-remaining-work.zh-CN.md` 第八节 b 期。
> 前置条件：a 期全部完成（B6 兜底、D1/D2、打坐养成链、别名层、商店/门派/任务 v0）。

---

## 一、项目背景

### 你在改什么

仓库 `C:\files\git\wuxia_mud_ex` 是 Elixir + ExVenture/Kalevala 框架的武侠 MUD（Kantele）。参照仓库 `C:\files\git\mud`（FluffOS/LPC，只读）。

### 必读文档

1. `docs/migration-prep-checklist.zh-CN.md`——第四节：属性/成长差异对照
2. `docs/kantele-remaining-work.zh-CN.md`——第〇节高危纪律、第七节依赖关系、第八节 b 期
3. `docs/combat-system.zh-CN.md`——战斗公式

### 关键架构事实

- **世界内容**：`data/*.ucl` → `loader.ex` 解析 → `kickoff.ex` 启动/更新 zone/room/NPC 进程；`reload` 热更（B6 rescue 已就位）
- **Vitals 结构**（`lib/kantele/character.ex`）：qi/jing/neili 各带 qi/max_qi/base_qi 三值
- **Stats 结构**（同文件）：skills（技能等级表）、mapped（映射）、performs（绝招）、combat_exp、potential
- **learn 流程**：`learn_command.ex` → 房间 `skills/learn` → NPC `skills_event.ex:teach/2` → 回执 `skills/learn-result` → `learn_result/2` 落等级/扣潜能
- **practice 流程**：`learn_command.ex:PracticeCommand` → `valid_learn` + `spend_potential`（固定扣 2）+ `improve_skill`（+1 级）
- **装备快照**：`wield_command.ex` 写 `meta.combat.equipped`（%{weapon: %{name,skill_type,damage}, armor: %{name,armor}}），`records.ex` 序列化到 `character_metadata.equipment`（string-key JSON）
- **NPC teach 配置**（A11/D4）：`meta.teach` = `%{family, teach_skills, no_teach, gongxian}`，已解析落位但消费端（learn 校验链）留待 b 期

### 铁律

- UTF-8 无 BOM、LF 行尾、末行留换行；Elixir 四空格缩进
- 游戏文本简体中文，风格对齐现有输出
- 每完成一项：`MIX_ENV=test mix test test/kantele` 全绿再做下一项
- **不要碰红区/深水区**：eff_* 层改造、昏迷/毒、diff-stop、Skill behaviour 钩子协议

---

## 二、b 期总览——两簇独立，b6 先行

两个施工簇相互独立（文件交集仅 records.ex 的不同函数；b6 无需 DB 迁移），先做哪个都不阻塞对方。**建议 b6 先行**：登录杀手风险趁存档少时退役，且 D3 解析可复用 a4 刚落的 loader_meta_test 模式。

```
① b6 (装备多槽位+UCL 字段)   ← 先行：动 loader/wield/combat/records(装备函数)
② b1 (learned_points 数据层) ← migration + Stats + Records 字段
③ b2→b5 (learn 校验链捆绑)   ← 四项挤同一校验链，拆开 = 反复重写 skills_event + PracticeCommand
```

learn 簇内部仍须捆绑一次改完；b6 与 learn 簇之间无依赖。

---

## 三、任务详情

### B6｜D3 装备 UCL 字段 + B4 多槽位多键

**背景**：
- LPC 装备支持多部位护甲（armor_type 决定槽位：head/neck/body/legs/...），每部位互斥（equip.c:34）
- Kantele 当前只支持单槽 armor + 单槽 weapon（`wield_command.ex`、`Combat.equip/unequip`）
- `character_metadata.equipment` 是单层 JSON：`%{"weapon" => snap, "armor" => snap}`

**建议做法**：

#### D3 装备 UCL 字段扩展
1. `loader.ex:parse_item_meta` 增加装备专属字段：
   - `armor_type`：槽位名（"head"/"body"/"legs"/"waist"/"hands"/"feet"/"cloak"/"neck"/"finger"等）
   - `weapon_prop`：多键属性表（如 `%{dodge: -10, parry: -5}`）——对齐 LPC weapon_prop/armor_prop 多键合并
   - `armor_prop`：同上（多键护甲加成）
2. `item.meta` 结构增补这些字段

#### B4 多槽位穿戴
3. `wield_command.ex` 重写：
   - `wear` 命令根据物品的 `armor_type` 决定槽位（不再统一写 `:armor`）
   - 同槽位穿戴互斥（"你已经穿戴了同类型的护具了"）
   - `Combat.equip/unequip` 改为按槽位 key（`:head`/`:body`/...）而非统一 `:armor`
   - weapon_prop/armor_prop 多键合并进 `Combat.effective_applies`
4. **新旧双读兼容**：`Records.restore_equipment/2`（:264）能同时识别旧格式（单层 `%{"weapon" => snap, "armor" => snap}`）和新格式（多槽位 `%{"weapon" => snap, "head" => snap, "body" => snap, ...}`）——e2e 加老存档登录用例
5. `Combat.effective_applies/1`（引擎从 equipped 快照合并属性到 Fighter.applies）需支持多槽位叠加

**动手前核实**：
- `Combat` 模块（`character/combat.ex`）的 `equip/unequip/effective_applies` 实现细节
- `Kantele.Combat.Fighter.from_character/1` 如何从 equipped 取 applies
- `records.ex:serialized_equipment/1`（:154-161）和 `restore_equipment/2`（:264-271）的当前格式
- LPC 的 armor_type 槽位名列表（equip.c:34 的 `query_temp("armor/" + type)` 模式）
- `Combat.apply_temp/2` 的 `@applies_keys` 白名单（attack/defense/damage/unarmed_damage/dodge/parry/armor）

**范围约束（防红区）**：weapon_prop/armor_prop 的 v0 **只支持 `@applies_keys` 内的键**。
LPC prop 表可含技能类加成（如 sword+5），那需要打通 Fighter.skills 通道，
超出本期范围——遇到白名单外的键显式忽略并 Logger.warn，不做静默合并。

**验收建议**：
- 同类型护甲穿戴互斥提示正确
- 多件不同槽位护甲可同时穿戴
- 旧格式存档登录后装备正常恢复（e2e 测试）
- weapon_prop/armor_prop 多键正确合并到战斗属性

### B1｜P2 潜能池 learned_points

**背景**：LPC 的 `potential - learned_points` 才是真正的可用潜能（learn.c:124）。Kantele 目前直接用 `potential` 字段，每 learn 一次扣固定值，没有 learned_points 概念。

LPC 机制（learn.c:189）：每次 learn 成功 `add("learned_points", 1)`。校验：`potential - learned_points >= times`（:124）。learned_points 是**累计已用潜能点数**，potential 是**总获得潜能点数**，差值才是余额。

**建议做法**：
1. `character_metadata` 加 `learned_points` 字段（integer，默认 0）；migration 先演练测试库
2. `Stats` 结构加 `:learned_points` 字段
3. `records.ex` 序列化/反序列化 `learned_points`
4. **校验公式**：`potential - learned_points >= 消耗`（替代当前 `potential >= 2`）
5. learn/practice 每次成功后 `learned_points += 消耗量`

**动手前核实**：
- `character_metadata` migration 的生成方式（`mix ecto.gen.migration` 目录结构）
- `Records.apply_to_character/2` 里 potential 的默认值处理（:183 `max(metadata.potential, 100)`）——learned_points 新字段无旧数据，默认 0 即可，不破坏旧档

**验收建议**：新角色 potential=100, learned_points=0 → learn 10 次后 learned_points=20 → 潜能不足提示出现；存档重登后 learned_points 保持。

---

### B2｜P1 learn 批量参数 + 校验链重写

**背景**：当前 learn 已支持 xN 后缀（`learn_command.ex:parse_times`），但 `skills_event.ex:teach/2` 的校验逻辑只检查师徒差距和基础潜能，没有整合 b1 的 learned_points、b3 的 jing 消耗、b4 的 exp 门、b5 的 valid_force 互斥。五项必须一次改完。

**建议做法**：
1. 统一校验链（在 `skills_event.ex:teach/2` 或新建一个 `LearnGate` 模块集中处理）：
   - 师父有此技能（已有）
   - 师父等级 > 学生等级（已有）
   - 学生 `potential - learned_points >= cost * times`（b1 接入）
   - jing 校验挂点（b3 接入；开关关闭时直接跳过，见 b3）
   - 学生 `can_improve_skill`（b4 接入：`lvl³/10 <= combat_exp`）
   - valid_force 互斥检查（b5 接入）
2. **快照 vs 实时的分工必须明确**：teach/2 在 NPC 进程执行，拿到的
   student_stats 是学生入场时快照——门槛判定（差距/exp 门/互斥）用快照；
   逐级扣费（learned_points/jing）在学生进程 `learn_result/2 → learn_levels`
   实时执行。两侧不得重复扣费，批量学习中途潜能/精尽由学生侧逐级判定中断。
3. learn 成功后：学生侧逐级扣 `learned_points` + 扣 `jing`（b3 开关控制）
4. PracticeCommand 同步改：`spend_potential` 改用 `learned_points`；加入 jing 门槛
   （practice 不扣 jing，但要求 jing ≥50% 上限——LPC 出处待核，exercise 用 70%，
   若查不到依据就与 exercise 统一为 70%）
5. `learn_result/2` 的 `learn_levels/5` 已做逐级学习——`learned_points` 在此逐级累加

**动手前核实**：
- `skills_event.ex:teach/2` 当前完整校验链（:33-70）
- `PracticeCommand:spend_potential/1`（:120-126）和 `check_vitals/2`（:112-118）
- `learn_result/2` 的 `learn_levels/5`（:163-172）——逐级扣 potential，需改为逐级累加 learned_points

**验收建议**：learn x10 一次连学 → learned_points 累加正确 → jing 被逐次扣除 → 学到 exp 门槛处被拒 → 练功（practice）同理。

---

### B3｜B2 jing 耗精激活

**背景**：LPC learn 每次消耗 jing：`jing_cost = (100 + my_skill * 2) / int`（learn.c:117）。初学技能 jing_cost 翻倍（:119）。jing 归零则学习中断（:161-175）。Kantele 的 jing 字段目前零消耗纯展示。

**建议做法**：
1. 在 b2 的校验链中加入 jing 消耗：`jing_cost = (100 + skill_level * 2) / int`（初学时 ×2）
2. 学习循环中逐次 `Vitals.damage(:jing, jing_cost)`，归零则中断并给出"你太累了"文案
3. **config 开关**：`Kantele.Config`（或 Application env）加 `enable_jing_learn_cost: false`，默认关闭；开启后才生效
4. 中断时已学的部分不回滚（对齐 LPC:199-203 的部分学习机制）

**动手前核实**：
- Kantele 有无现成的 config 模块（搜索 `Application.get_env` 或 `config/` 目录）；若无则新建简单开关模块
- `Vitals.damage/3` 的签章（character.ex:110-116）

**验收建议**：关闭开关时 learn 行为与 a 期一致（无 jing 消耗）；开启后 learn 消耗 jing，精尽时中断但已学部分保留。

---

### B4｜B3 exp 上限门

**背景**：LPC 武功类技能 `等级³/10 ≤ combat_exp` 才许升级（skill.c:278）。Kantele 完全没有此门槛，技能可以无限学。

**建议做法**：
1. 在 b2 的校验链中加入：武功类技能（`type == :martial`）需 `level³/10 <= combat_exp`，否则拒绝并提示"缺乏实战经验"
2. **只拦学习不追溯**：已学的存量技能不受影响，只对未来的 learn/practice 生效
3. **config 开关**：`enable_exp_gate: false`，默认关闭
4. 是否扣 exp：LPC learn 不扣 exp，只拦。建议保持一致——exp 门是门槛不是消耗
5. Skill behaviour 需要 `type()` 回调——核实每个 skill module 有无返回 `:martial` / `:knowledge` 等

**动手前核实**：
- `Kantele.Combat.Skill` behaviour 有无 `type` callback（combat/skill.ex）；若无则本期只对已知武功硬编码
- 现有 skill module 有哪些（`combat/skills/*.ex`），各自的 practice_cost 返回值
- LPC 的 `can_improve_skill`（skill.c:255-284）——知识类/技术类不受限

**验收建议**：关闭开关时 learn 无门槛；开启后技能等级过高而 combat_exp 不足时被拒；存量已学技能不受影响。

---

### B5｜P10 valid_force 内功互斥

**背景**：LPC can_learn（learn.c:229-251）检查：学新内功时，如果与已学内功冲突（`valid_force` 返回 false），则拒绝。Kantele 当前无此检查。

**现状澄清（动手前必读）**：Skill behaviour **没有 valid_force callback**。
`liuxi_neigong.ex:14` 的 `valid_enable(usage)` 是映射校验（允许 enable 到哪个用法），
与内功互斥是两码事——不要混淆。

**建议做法**：
1. `Kantele.Combat.Skill` behaviour 新增 `valid_force/1` callback
   （入参为新学内功的 skill module 或 id），`defoverridable` 给默认实现；
   现有 `LiuxiNeigong` 补一个合理实现（如"仅允许自身/无冲突"）
2. 在 b2 的校验链中加入：学新内功时（`valid_enable("force")` 为 true 的技能），
   遍历学生已学的其他内功，调用其 `valid_force(new_skill)` 检查冲突
3. **只拦新增学习，不追溯已学**：存量角色如果已经同时学了冲突内功
   （理论上不会发生），不追溯删技能

**动手前核实**：
- LPC `valid_force` 的语义——每个内功 skill 定义"接受哪些其他内功共存"
- Skill behaviour 的 defoverridable 模式（combat/skill.ex:72）

**验收建议**：学第二门与前派冲突的内功被拒且提示；只学一门内功时无影响。

---

---

## 四、建议施工顺序

1. **b6**（装备簇先行）：D3 解析层（armor_type/weapon_prop/armor_prop + 测试）→ B4 Combat 多槽位折叠与同槽互斥 → wield_command 重写 → records 双读兼容 + 老档登录 e2e 用例
2. **b1**（learned_points）：migration + Stats + Records——纯数据层，不影响现有行为
3. **b2+b3+b4+b5**（learn 校验链）：改 `skills_event.ex` + `learn_command.ex:PracticeCommand`——四项捆绑一次改完
4. 每步做完跑 `MIX_ENV=test mix test test/kantele`

---

## 五、边界约束

- 不动 eff_* 层、不动 diff-stop、不动昏迷/毒、不动 Skill behaviour 协议（defoverridable）
- 不执行 git commit，除非明确要求
- config 开关（b3/b4）本期默认关闭——观察期后再开
- b5 存量角色不追溯

## 六、完成后

在本文件末尾追加实际做法摘要（哪些校验链放了集中模块、b3/b4 开关默认值、装备槽位数量与 LPC 的差异），供 c 期衔接。

---

## 七、实施摘要（2026-08-26 实际做法）

> 本期 b1-b6 全部完成，219 测试全绿。以下为落地差异记录。

### 装备槽位（B6）

- 槽位白名单：`cloth/head/feet/waist/hands/neck/cloak/finger`（`Combat.armor_slots/0`）。
  **与文档示例的差异**：采用 LPC 实际出现过的 `cloth`（衣袍）而非通用 `body`；
  `body` 在解析层归一化为 `cloth` 兼容（`Item.Meta.normalize_armor_type/1`）
- 快照结构扩展：武器 `%{name, skill_type, damage, prop}`、护甲 `%{name, armor, prop}`；
  prop 为白名单键 map（`Combat.applies_keys/0` 七键），白名单外的键在 loader 解析时丢弃
- 存档双读：新格式每槽位一键；旧格式单层 `"armor"` 键归入 `:cloth` 槽位
- 同槽互斥在命令层判定（`Combat.occupied?/2`），equip 本身允许覆盖

### learn 校验链（B1-B5）

- 集中模块：**`Kantele.Character.LearnGate`**——快照总闸 `snapshot_gate/2`
  （师父侧）+ 单级闸 `level_gate/3` 与结算 `pay_level/3`（学生侧逐级）
- **潜能经济保持每次 2 点**（LPC 是 1 点/次，沿用 Kantele 既有 `@learn_cost 2`，
  差异已确认接受）；potential 字段不再减少，消耗累计进 learned_points
- **开关默认值**：`:enable_jing_learn_cost => false`、`:enable_exp_gate => false`
  （`Application.get_env(:ex_venture, ...)`，均未写入 config 文件，观察期后手动开启）
- practice 的 jing ≥70% 门槛为自定统一值（与打坐一致），LPC practice.c 无此门
- b5 始终启用（无开关）：`valid_force/1` callback 加入 Skill behaviour，
  默认 true（无冲突）；柳溪内功覆写为 false（不接受任何其他内功共存）
- learn xN 批量：中途潜能/精尽即停，文案"但是你今天太累了，学习了 N 次以后只好先停下来"

### 迁移

- `20260826120000_add_learned_points_to_character_metadata.exs`（integer default 0），
  测试库与开发库均已执行
