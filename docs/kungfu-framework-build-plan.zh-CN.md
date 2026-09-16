# kungfu 框架搭建计划

> 2026-09-15。承接 `docs/kungfu-migration-frameworks.zh-CN.md` 的缺口分析。
> 目标：先把 4 个缺口框架立起来（conditions 接线 + 特技系统 + 门派师父框架 + 招式移植管线），再做内容搬运。
> 验收基线：`MIX_ENV=test mix test` 全绿 + 每步一个可演示命令。

---

## 阶段总览

| 阶段 | 目标 | 依赖 | 预估量 |
|---|---|---|---|
| F1 | conditions 宿主接线 + ConditionRegistry | 无（引擎已就绪） | 小 |
| F2 | 转世特技系统 SpecialSkills | F1（被动接线复用 daemon 模式） | 中 |
| F3 | 通用门派师父框架 SectMaster | F1、既有 Family/Sects/Master | 中 |
| F4 | 招式/内功批量移植管线 | F1-F3 | 大（工具 + 内容） |

每阶段的"内容演示"以一个代表性 kungfu 文件为样板，验收通过后再整批搬运。

---

## F1：conditions 宿主接线 + 注册表

### 目标
让 `Kantele.Character.Conditions` 引擎真正在角色心跳里运行：到期/继续/清除自动流转，`do_effect` 生效。

### 步骤
1. **新建 `lib/kantele/character/condition_registry.ex`**
   - 静态 `@daemons %{"poison" => Kantele.Poison}` + `:persistent_term` 运行时增量（照抄 `Combat.Skills` 的 `register/unregister` 模式）。
   - `daemon/1`：`{:ok, mod} | :error` 供 `Conditions.affect_by/4`、`Conditions.update_condition/2` 使用。
2. **接入心跳**
   - 选型：并入 `combat_event.ex tick/2`（现状心跳唯一入口）或独立 `condition/tick` 事件。倾向**独立事件** `condition/tick`（1s 自投递），与 combat 解耦，非战斗也能跑。
   - 在 tick 里：`Conditions.update_condition(state, &ConditionRegistry.daemon/1)`；`{:continue, new}` 已由引擎写回。
   - 心跳满足条件才调度：`conditions` 非空才 `schedule_self`，空则停（省资源）。
3. **Poison 效果驱动**
   - 在 condition tick 中调用 `Poison.do_effect` 扣 jing/qi（现 `poison.ex` 的 `do_effect` 只在 `affect_by` 触发，缺主循环驱动）。
   - 中毒消息：每 tick 发 `Broadcast.publish`（`@update_msg` 沿用）。
4. **注册入口**
   - 在 `combat_event`/主进程启动处、以及 `Kantele.Combat.Skills` 同级挂 `ConditionRegistry` 静态表。
5. **测试**
   - `test/kantele/character/condition_registry_test.exs`：注册/注销、到期 `{:expire}` 清除、`{:continue}` 写回。
   - `test/kantele/character/condition_flow_test.exs`：中毒 → few ticks → jing/qi 下降 → 到期自动清除。

### 验收
- `apply_condition(poison)` 后角色每 1s 掉血出消息，到期自清。
- 新增一个假 `condition/demo` daemon 验证注册表热增（不重启进程）。

---

## F2：转世特技系统 SpecialSkills

### 目标
统一现有的散落 `special_skill/{piyi,greedy,youth}` 硬编码，提供注册表 + `special` 命令 + 被动/主动接口。

### 步骤
1. **新建 `lib/kantele/character/special_skills.ex`（注册表）**
   - 静态 `@specials %{"piyi" => SpecialSkills.Piyi, "accuracy" => ..., "youth" => ...}` 起步放 3-5 个 kungfu 已读样板做验证，其余随迁移补。
   - `all/get/known?` + 运行时增量（同 `Skills` 模式）。
2. **新建特技模块（样板 3 个）**
   - `special_skills/piyi.ex`：被动——免疫毒/病/内伤反噬（替换 `conditions.ex:121`、`poison.ex:192` 的 `special_skill/piyi` 读法为 `SpecialSkills.immune?/2`）。
   - `special_skills/greedy.ex`：被动——击杀奖励 500 加成（替换 `feature_damage.ex:476,484`）。
   - `special_skills/youth.ex`：被动——`attributes.ex:44` 容貌不衰。
   - 定义 `affect(state, opts)`（被动）与 `perform(conn, opts)`（主动，对应 LPC `perform(me, skill)`）。
3. **角色存储**
   - `meta.stats` 或 `meta.attributes` 加 `special_skills: MapSet`（`poison.ex` 已用 `attributes["special_skills"]`，统一收敛为单字段并同步 `records.ex` 持久化）。
4. **`special` 命令（替换 `special_command.ex` 占位）**
   - `special` 列出已学特技；`special <name>` 调主动 `perform`（如 iro skin 类加临时 buff）。
5. **接线替换**
   - 全库 grep `special_skill/` 引用点，逐一改为 `SpecialSkills` 查询。
6. **测试**
   - 注册、grant、查列；piyi 免疫链路（中毒后 apply 返回 `{:immune}`）；youth 属性不改。

### 验收
- `special` 列出已学；`special piyi` 触发百毒不侵语义；无硬编码残留（grep 干净）。

---

## F3：通用门派师父框架 SectMaster

### 目标
用数据驱动替代 `ZhangSanfeng` 单例，让任意门派师父 NPC 支持学艺、禁授、收徒门槛、问答授绝招。

### 步骤
1. **UCL 字段扩展**（`data/world/*.ucl` characters 块）
   - `teach`：`%{family, skills: %{技能 => %{max}}, no_teach: [...]}` —— loader.ex parse 时透传（loader 已解析 `teach.family`，见 loader.ex:506）。
   - `apprentice`：`%{min_shen, min_exp, min_skills: %{技能 => 等级}, class}`。
   - `inquiry`：`%{关键字 => %{skill, min_gongxian, min_shen, min_levels, cost_gongxian, perform_id}}`（授绝招配置）。
2. **`lib/kantele/npc/sect_master.ex`（纯函数，类 `Master`）**
   - `teachable?(npc_stats, student_stats, skill, config)`：等级差 + `no_teach` + `valid_learn`。
   - `recruit_gate?(player_stats, config)`：shen/exp/心法门槛。
   - `inquiry_grant(player_stats, npc_stats, config)`：返回 `{:ok, perform_id, cost}` | `{:error, msg}`。
3. **接入事件**
   - `skills_event.ex teach/2`：改用 `SectMaster.teachable?`（保留 `prevent_learn?` 门派校验）。
   - `recruit` 命令 + `family/apprentice` 事件：按 `config` 检查门槛 → `Family.recruit_apprentice` + class 继承 → `gongxian` 初始化。
   - `family/detach`：`Master.attempt_detach` → `Skills.skill_expell_penalty`（已就绪）。
   - inquiry：`ask`/`chat` 匹配 `inquiry` 关键词 → `SectMaster.inquiry_grant` → `Stats.learn_perform` + `add(:gongxian, -cost)`。
4. **样板内容**
   - 把 `class/wudang/yu.c`（俞莲舟）翻译成一份 UCL 师父配置挂进测试世界：no_teach（三绝张真人亲传）、门槛（shen 20000/exp 150000/武当心法 80/taoism 80）、inquiry 授「虎爪绝户手」（gongxian 400/shen 100000/force 180）。
5. **测试**
   - `Npc.SectMaster` 纯函数单测 + 一条 e2e：拜师 → 学艺 → 门槛拦截 → 问答得绝招 → 叛师惩罚。

### 验收
- 任意 UCL 声明 `teach/apprentice/inquiry` 的 NPC 即可当师父，无需改代码加新门派。

---

## F4：招式/内功批量移植管线

### 目标
把 `kungfu/skill/` 442 个子目录的 perform/exert 与顶层武功翻译为 Elixir 模块，先给工具，再批量搬运。

### 步骤
1. **招式提取器（脚本）**
   - `scripts/translate_perform.exs`：扫描 `kungfu/skill/<skill>/<move>.c`，按 `F_SSERVER` + `perform|exert` 签名分类。
   - 模板化映射表（门槛模式）→ 输出 `.ex` 骨架：`with <- notify_fail` 链 → `Broadcast.publish` + 扣资源 + `busy`。
   - 输出到 `lib/kantele/combat/skills/performs/<skill>/<move>.ex`。
2. **技能元数据**
   - 顶层 `.c` 抽 `valid_enable`/types → 生 cost 常量与 `perform_list.exert_list` 映射。
3. **人工校对清单**
   - 无法自动化的（`query_temp("weapon")` 分支、`query_skill_mapped` 多段、`lvl` 分段公式）标 `TODO(migrate)` 由样本校对。
4. **样板 3 个**
   - `huashan-jian/jie.c`（截手式）、`chousui-zhang/dan.c`（毒掌）、`force/power.c`（内功加力）。
   - 挂进 `Skills.register` 验证 perform/exert 全链路。
5. **回归**
   - combat perform/exert e2e 扩到新样例。

### 验收
- 提取器跑通输出 3 个样板 + 战斗内可施展；内功互斥 `valid_force` 生效。

---

## 依赖与风险

| 风险 | 应对 |
|---|---|
| conditions 心跳与 combat 心跳并发写 `meta` | 独立 `condition/tick` 事件串行化，tick 内只读一次 state 全量更新 |
| 特技被动查询点分散 | F2 统一 `SpecialSkills` 入口，逐点替换并 grep 清零 |
| 师父配置数据量大 | F3 只做样板；批量由 UCL 生成器（另文）承接 |
| 招式翻译质量 | F4 抽取器只管骨架，语义靠人工校对 + 测试锁定 |

## 执行顺序建议

```
F1（接线+注册表）→ F2（特技系统）→ F3（门派师父框架）→ F4（移植管线）
每步先跑 mix test + 每步一个可演示命令，绿了再进下一步。
```

---

## 当前进度（2026-09-16，如实盘）

### 切片 1：loader 收徒配置接线（已测通、已提交、已推送）
- 在 `loader.ex` 新增 `parse_apprentice/1` 函数：把 UCL 数据里的 `apprentice` 段解析成 `%{min_shen/min_exp/no_recruit/...}` 结构；`NonPlayerMeta` 结构体新增 `:apprentice` 字段（在 `character.ex`），并同步了 `apprentice_id` 字段。
- loader 元数据测试全绿。测试夹具确认了一个关键契约：`Family.name/1` 接收的参数是 **map**（如 `%{name: "武当派"}`），不是字符串——见 `room.ex:402/2458`。
- 提交号 `6413383`，已推送 `origin/kalevala`。

### 切片 2：sect_master.ex 纯函数模块（代码已写、测试未通过、未提交未推送）
- `lib/kantele/sect_master.ex`（106 行）：`teachable?/3`、`recruit_gate?/3`、`detach_penalty?/2` 三个函数已写好。
- 取数全走真实宿主函数链：`Family`（`name/1`、`same_family?/2`、`is_apprentice_of?/2`）、`Master.prevent_learn?/3`、以及 `student_stats/1`（直接读 `meta[:shen]`、`meta[:combat_exp]`）。
- 测试 `test/kantele/sect_master_test.exs` 已写；**容器实测 4 条失败**，未通过、未提交、未推送。失败原因：测试夹具的 `family` 形状曾是字符串（形状不对），已改正为 map 形状；**改正后未重新实测，所以不声称已通过**。
- 纪律：**实测通过才提交；红不提交、不推送、不臆造**。

### 当前断言
| 条目 | 真实状态 |
|---|---|
| loader 接线（容器测试） | 绿 |
| 切片 2（容器测试） | **红**（未通过） |
| `origin/kalevala` | `6413383`（切片 1）已推送；切片 2 未推送 |

---

## 开发与测试方法

### 环境
- 项目宿主盘：`C:\files\git\wuxia_mud_ex`；容器：`wuxia_mud_dev-app-1`（挂载 `/app`）。

### 开发
1. 改代码前**先读真宿主**（用宿主 Read/grep 直接钉函数名/结构形状，容器 `docker exec` 内嵌 shell 会被宿主 PowerShell 吞掉管道/括号/引号，慎用）。
2. 任何贫口名、结构字段、事件键**必须先从宿主读盘钉真**，不臆名（反例：`Stats.attribute/3` 臆名，Stats 真宿主只有 `skill/2`、`effective/2`，容器实测红）。
3. 每写一片，先落测试夹具，夹具形状与真宿主契约对齐。
4. 全库 grep 校验引用点，不硬编码在调用方散落复制。

### 测试
```
# 单个测试文件（避开 dev 端口占用：MIX_ENV=test）
docker exec wuxia_mud_dev-app-1 sh -lc 'cd /app && MIX_ENV=test mix test test/kantele/sect_master_test.exs'

# loader 元数据接线
docker exec wuxia_mud_dev-app-1 sh -lc 'cd /app && MIX_ENV=test mix test test/kantele/world/loader_test.exs'

# 全量（验绿门）
docker exec wuxia_mud_dev-app-1 sh -lc 'cd /app && MIX_ENV=test mix test'
```
注意：宿主 PowerShell 执行 docker exec 时 `sh -lc '...'` 内嵌的 `(` / `|` / 双引号会被吞，把 grep/read 等读真刀放宿主测（Read/grep 工具），把 `mix test` 放容器测。

### 提交纪律
- **容器实测绿 → 才提交 + 推到 `origin/kalevala`**；红不提交不推。
- 每刀独立提交，绿一门推一门；预算不够就分多次提交，不把红刀混进绿推。
