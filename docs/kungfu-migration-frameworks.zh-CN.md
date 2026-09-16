# kungfu 武功库迁移：框架对照与设计

> 2026-09-15 基于源码实测。参照物：LPC 源仓库 `C:\files\git\mud\kungfu`、本仓库当前实现。
> 用途：迁移 kungfu 武功库前，逐类核对 wuxia_mud_ex 是否已有对应框架，以及缺口框架的设计方案。

---

## 一、kungfu 目录构成

| 目录 | 内容 | 规模 | 文件模式 |
|---|---|---|---|
| `skill/` | 顶层=基础武功/门派武功 `.c`（`blade.c`、`bagua-quan.c`、`huashan-jian.c`…）；每个武功一个子目录放招式（perform/exert）文件 | 719 个 `.c` + 1 个 `.h`（`eff_msg.h`）+ 442 个子目录 | 基础武功 `inherit SKILL;`；子目录招式 `inherit F_SSERVER;`/`inherit F_CLEAN_UP;` |
| `condition/` | 状态效果 daemon（毒/疾病/晕醉/束缚/内息异常/官府悬赏…） | 70 个 `.c` | `inherit F_CLEAN_UP;`（部分 `inherit POISON;`），定义 `update_condition(me, duration)`、`dispel(me, ob, duration)` |
| `special/` | 转世特技（accuracy/piyi/ironskin/youth/greedy…） | 33 个 `.c` | `inherit F_CLEAN_UP;`，`int is_scborn()`、`string name()`、`int perform(object me, string skill)` |
| `class/` | 各门派师父/弟子 NPC（duan/emei/wudang/shaolin/…） | 42 个门派目录 | `inherit NPC + F_MASTER + F_COAGENT;`，`attempt_apprentice`、`permit_recruit`（在 `.h`）、`create_family`、`set_skill/map_skill/prepare_skill` |

## 二、LPC 侧关键模式（抽样实测）

### 2.1 基础武功（skill/blade.c、skill/bagua-quan.c）
- `inherit SKILL;`，基本武功极简（仅名字），门派武功含 `valid_enable`（用法匹配）、修炼/学习门槛。

### 2.2 招式文件（skill/huashan-jian/{jie,lian,long,xian}.c、skill/chousui-zhang/dan.c）
- `inherit F_SSERVER;`，`int perform(object me, object target)`（或 `exert`）。
- 先用 `notify_fail` 串行做门槛检查：`query_skill`/`query_skill_mapped`/`query_skill_prepared`、`query("can_perform/<skill>/<move>")`、`query_temp("weapon")`、`query("neili")`；
- 成功路径扣内力/气血、`start_busy`、`message_combatd` 广播、必要时 `add_temp("apply/*")` 上临时属性（如 force/power.c 按最高 skill/5 加成）。

### 2.3 内功运功（skill/force/power.c 等 exert 系列）
- `valid_types` 映射定义各类兵刃/拳脚名；`exert(me, target)` 检查 `neili`、`query_temp("power")` 防重复、`set_temp` + `add_temp("apply/"+sk, skill/5)` 持续 buff；战斗中 `start_busy`。

### 2.4 condition（condition/poison.c、drunk.c 代表）
- `inherit F_CLEAN_UP;`，`update_condition(me, duration)` 每 tick 扣减并返回 `CND_CONTINUE`/`CND_STOP`；`dispel(me, ob, duration)` 由 `exert medicine` / 解毒招式驱散。

### 2.5 转世特技（special/*.c）
- `is_scborn()` 标记转世出身；`name()` 显示名；`perform(me, skill)` 一键应用被动/主动效果（如 piyi 百毒不侵、accuracy 精准、ironskin 临时加护甲）。

### 2.6 门派师父 NPC（class/wudang/yu.c、wudang.h、bagua.c 代表）
- `set_name`/`set_skill`/`map_skill`/`prepare_skill`/`create_family("武当派", 2, "弟子")`；
- `set("no_teach", ([...]))` 禁授表；`set("inquiry", ([...]))` 问答授绝招（校验 gongxian/shen/技能门槛后 `me->set("can_perform/...")` + `add("gongxian", -N)`）；
- `attempt_apprentice(ob)` 调用 `permit_recruit(ob)`（门派誓约/叛师检测）后再查 shen/exp/心法门槛，通过则 `command("recruit "+id)` 并继承 `class`（如 taoist）。

## 三、wuxia_mud_ex 已有框架对照

### ✅ 已就绪

| kungfu 概念 | wuxia_mud_ex 对应 | 证据 |
|---|---|---|
| SKILL 继承 + 招式表 | `Kantele.Combat.Skill` behaviour | `lib/kantele/combat/skill.ex`：`valid_enable`/`valid_learn`/`practice_cost`/`query_action`/`@actions` 招式表 |
| 武学注册表 | `Kantele.Combat.Skills` | `skills.ex`：静态 `@static` + 运行时 `:persistent_term` `register/unregister`；`get/all/known?` |
| 招架/刀剑/拳脚 enable 映射 | `Skills.enabled_for/2` + `Stats.mapped` | `stats.ex:75-76`（基本+特技叠加） |
| perform/exert 分派 | `perform_list`/`exert_list` → `perform_command.ex`/`exert_command.ex` | 已通 `liuxin-jian.liu`、`taiji-quan.extreme`、`exert powerup` |
| 技能增益/死亡惩罚 | `skill_adjust/3`、`skill_death_penalty/2` | 对应 `feature/sadjust.c`、`feature/skill.c` |
| 逐出师门惩罚 | `skill_expell_penalty/2` + `guards_special?/1` | `skills.ex:113-143` |
| 内功反击/学习门槛 | `Kantele.Combat.Force` | `force.ex`：`hit_ob/5` 反震、`valid_learn?/1` |
| 内力上限 | `Kantele.Character.NeiliLimit` | `neili_limit.ex` |
| 状态引擎 | `Kantele.Character.Conditions` | `conditions.ex`：`apply/query/clear/update_condition/affect_by`，纯函数 + 宿主注入 daemon |
| 毒系统 | `Kantele.Poison` | `poison.ex`：实现 `daemon/1` + `do_effect/3` + `update_condition/1`（唯一落地的 condition daemon） |
| 门派/家族 | `Kantele.Character.Family`、`Kantele.Sects` | `family.ex`：`create_family/recruit_apprentice/is_apprentice_of?`；`sects.ex`：39 门派原型（scale/class/skills/maps/preps/carry） |
| 师徒 NPC 逻辑 | `Kantele.Npc.Master`、`Kantele.Npc.ZhangSanfeng` | `master.ex`：`prevent_learn?/2`、`attempt_detach/3`；`zhang_sanfeng.ex`：武当问答授艺 |
| 学艺流 | `learn_command.ex` → `skills/learn` → `skills/teach` → `skills/learn-result` | `skills_event.ex` 全套 + `LearnGate`（b1 潜能池/b4 exp 门/b5 内功互斥） |
| 打坐/吐纳 | `exercise_event.ex`、`respirate_event.ex` | 1s tick 增长内力的成长循环 |
| NPC 心跳/定时 | `Kantele.Scheduler` | 周期回调（对应 set_heart_beat/call_out） |
| 装备 | `wield/wear` 双槽 + `meta.combat.equipped` | 武器 damage/skill_type、护甲 armor |

### ⚠️ 框架在但未接线 / 内容空

| 缺口 | 现状 | 需要补 |
|---|---|---|
| **conditions 宿主接线** | `conditions.ex` 引擎完整、`poison.ex` 是唯一 daemon。**F1 已落地**（提交 `37f233d`）：独立 `condition/tick` 事件（`condition_event.ex`，1s 自投递）驱动 `Conditions.update_condition/2` + 每存活条件 `affect_by` 跳 `do_effect`，与 combat 解耦；`condition_registry.ex` 注册表（静态 + `:persistent_term` 热增）就位 | 补 F1 验收测试（`condition_registry_test.exs`/`condition_flow_test.exs` 尚缺）+ 其余 ~69 个 `condition/*.c` 按 daemon 接口移植 |
| **condition 内容量** | 只有 poison 一个 | ~70 个 `condition/*.c` 待按 daemon 接口移植 |
| **performs/exerts 内容量** | 只有 liuxin-jian、taiji-quan、powerup 三个 | 442 个子目录的招式文件待移植 |
| **内功内容量** | 只有 `force.ex` 泛型 + liuxi-neigong | 各门派内功（有效互斥 `valid_force`）待移植 |

### ❌ 完全没有（迁移前必须新建）

| 缺口框架 | kungfu 参照 | 说明 |
|---|---|---|
| **转世特技（special）系统** | `special/*.c` 33 个 | **F2 已落地一半**（提交 `8d4648f`，拍板「保持原样、只写注册表+测试」）：`special_skills.ex` 注册表 + 测试注入，`special_command.ex` 仍是"暂未开放"占位；散落硬编码未替换——`conditions.ex:121`/`poison.ex:192`（piyi 免疫）、`feature_damage.ex:476/484`（greedy = 食物/饮水上限 `f+500/w+500`，**非**击杀奖励）、`attributes.ex:44`（youth 容貌不衰，属实）。另注意 `conditions.ex:121` 读 `state.special_skill.piyi`、`poison.ex:192` 读 `state.attributes["special_skills"]`，两处形状不一且 `condition_event.ex tick` 构造的 state 未喂该键——piyi 免疫目前名义存在、心跳里未生效，待 F2 接线 |
| **通用门派师父数据驱动框架** | `class/<sect>/*.c` | 现仅 `ZhangSanfeng` 单例硬编码；`Sects` 只用于随机 NPC 生成，非师父 NPC 配置 |
| **师父收徒/叛师闭环** | `F_MASTER` `attempt_apprentice`/`permit_recruit` | `recruit`/`family/*` 事件已注册但无完整拜师流程（shen/exp/心法门槛、class 继承、`no_teach`/`inquiry` 授绝招） |

## 四、缺口框架设计

### 4.1 转世特技系统（SpecialSkills）

```
lib/kantele/character/special_skills.ex     # 注册表 + 应用入口（对应 special/*.c 集）
lib/kantele/character/special_skills/*.ex   # 每个特技一个模块（daemon 接口）
```

**模块契约**（对齐现有 Conditions daemon 风格）：

```elixir
defmodule Kantele.Character.SpecialSkills.Piyi do
  @name "piyi"
  # daemon/1 → {:ok, Piyi}  (供 registered daemon 解析)
  def name, do: "诸邪辟易"
  # 被动应用：在 affect_by / feature_damage / attributes 查询点被调
  def affect(state, opts), do: ...
  # 主动施展（对应 LPC perform(me, skill)）
  def perform(conn, opts), do: ...
end
```

**接线点**（替换现有散落硬编码）：
- `conditions.ex affect_by/4`：把 `special_skill/piyi` → `SpecialSkills.daemon("piyi").affect` 免疫判定。
- `feature_damage.ex` greed → `SpecialSkills`。
- `attributes.ex:44` youth → `SpecialSkills`。
- 新增 `special <name>` 命令（替换 `special_command.ex` 占位）。
- 转世入口：`reborn`/`create` 时按 `LPC is_scborn` 语义授予（本期可先做玩家初始选取或卷轴道具）。

### 4.2 通用门派师父框架（SectMaster）

```
data/world/<map>.ucl 的 characters 块扩展字段（与 loader.ex 实际解析形状对齐）：
  teach: %{family: "武当派", teach_skills: %{"taiji-jian" => %{max: N, gongxian: M}}, no_teach: [...]}
  apprentice: %{family, min_shen, min_exp, min_skills: %{技能 => 等级}, no_recruit: [...]}
  inquiries: %{关键词 => 文本|授绝招配置 map}（顶层；loader `parse_inquiries/1` 已解析，map 值键归一为字符串）
```

**数据驱动**，替代硬编码 `ZhangSanfeng`：
- UCL 里声明师父的 `teach_skills`、`no_teach`、`inquiries`（问答→授绝招配置：门槛 gongxian/shen/技能 + 扣除额）、收徒门槛 `apprentice: %{min_shen, min_exp, min_skills}` 与 `no_recruit`（`class` 继承**尚不在** loader `parse_apprentice/1` 产物里，F3 待补）。
- `SkillsEvent.teach` 改用 `SectMaster.teachable?`（切片 3 已接入 `skills_event.ex teach/2`；同门判定走 `meta.family` map，NPC 侧用 `teach.family` 合成）。
- 拜师流程：`recruit` → `Family.recruit_apprentice` + class 继承 + `gongxian` 初始化（切片 2 的 `SectMaster.recruit_gate?/3` 门槛函数已就绪，接 NPC 侧应答事件待 F3 续）。
- 叛师：`Master.attempt_detach` → `Skills.skill_expell_penalty`（已就绪）。

### 4.3 conditions 宿主接线 + 注册表

```
lib/kantele/character/condition_registry.ex   # 名 → daemon 模块 映射（静态 + :persistent_term 增量）
lib/kantele/character/events/condition_event.ex # 或并入 combat_event.tick
```

- `ConditionRegistry` 建 `daemon/1`（同 `Skills` 静态+运行时增量模式）。
- 在每角色心跳（`combat_event.tick` 或独立 `condition/tick`）：`Conditions.update_condition(state, &ConditionRegistry.daemon/1)`，返回 `{:expire}` 的自动清除，并驱动 `do_effect`。
- 内容移植顺序按依赖：先纯伤害型（中毒已有、流血/灼烧/寒冷），再资源型（food/water、jing 消耗），最后剧情类（官差/比武）。

### 4.4 招式/内功批量移植管线

- 招式筛选器：按 `F_SSERVER`/`F_CLEAN_UP` + `perform|exert object` 模式从 `kungfu/skill/` 子目录提取 → 翻译为 `perform_list.exert_list` 子模块。
- 门槛常用模式可以模板化：`notify_fail` 串行检查 → with 链；`message_combatd/start_busy/扣内力` 映射为 `Broadcast.publish` + `Combat.busy` + `Vitals.damage(:neili)`。
- 内功 `valid_force` 互斥：归入 `LearnGate.force_conflict`（b5 已实现）。

## 五、优先级建议

1. **conditions 宿主接线 + 注册表**（4.3）——框架最小、是一切状态效果与特技被动效果的前提，Poison 已就绪可直接验证。
2. **转世特技系统**（4.1）——独立性强、替换散落硬编码后语义统一。
3. **通用门派师父框架**（4.2）——依赖 Family/Sects/Master 已有件，解锁大批门派 NPC 数据。
4. **招式/内功批量移植管线**（4.4）——工程量最大，放最后做内容搬运时并行。

## 六、相关文件索引

- kungfu 参照：`C:\files\git\mud\kungfu\{skill,condition,special,class}`
- 本仓库引擎：`lib/kantele/combat/{skill,skills,force,engine}.ex`、`lib/kantele/character/{conditions,family}.ex`、`lib/kantele/poison.ex`、`lib/kantele/sects.ex`、`lib/kantele/npc/{master,zhang_sanfeng}.ex`
- 事件：`lib/kantele/character/events/{combat,skills,exercise,respirate}_event.ex`
- 命令：`lib/kantele/character/commands/{perform,exert,learn,special}_command.ex`