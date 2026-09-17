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

> 已拍板（`8d4648f`）：本阶段只做**注册表 + 测试注入**，散落读取点保持原样，`special` 命令维持占位。下方步骤为完整蓝图，逐条执行时以拍板范围为准。
1. **新建 `lib/kantele/character/special_skills.ex`（注册表）**
   - 静态 `@specials %{"piyi" => SpecialSkills.Piyi, "accuracy" => ..., "youth" => ...}` 起步放 3-5 个 kungfu 已读样板做验证，其余随迁移补。
   - `all/get/known?` + 运行时增量（同 `Skills` 模式）。
2. **新建特技模块（样板 3 个）**
   - `special_skills/piyi.ex`：被动——免疫毒/病/内伤反噬（替换 `conditions.ex:121`、`poison.ex:192` 的 `special_skill/piyi` 读法为 `SpecialSkills.immune?/2`）。
   - `special_skills/greedy.ex`：被动——食物/饮水上限 `f+500`/`w+500`（饕餮转世，`greedy.c` 原文"增加你的食物及饮水上限"；替换 `feature_damage.ex:476,484` `max_food_capacity/2`/`max_water_capacity/2`。⚠️ 此前文档把 greedy 误记为"击杀奖励 500"，已纠正）。
   - `special_skills/youth.ex`：被动——`attributes.ex:44` 容貌不衰。
   - 定义 `affect(state, opts)`（被动）与 `perform(conn, opts)`（主动，对应 LPC `perform(me, skill)`）。
3. **角色存储**
   - `meta.stats` 或 `meta.attributes` 加 `special_skills: MapSet`（`poison.ex` 已用 `attributes["special_skills"]`，统一收敛为单字段并同步 `records.ex` 持久化）。
4. **`special` 命令（替换 `special_command.ex` 占位）**
   - `special` 列出已学特技；`special <name>` 调主动 `perform`（如 iro skin 类加临时 buff）。
5. **接线替换**（piyi/免疫链路已完成，见阶段状态；greedy/emperor/youth 旧旗标兼容保留）
   - 已改：`conditions.ex affect_by`、`poison.ex check_immunity`、`attributes.ex per`、`condition_event.ex tick` 喂 `special_skills`。全库 grep 剩余 `special_skill/` 引用：`feature_damage.ex`（greedy 物品形）、`room.ex`（emperor）、`skills_command.ex`（格式展示），均不在 piyi 免疫链路。
6. **测试**
   - 注册、grant、查列；piyi 免疫链路（中毒后 apply 返回 `{:immune}`）；youth 属性不改。

### 验收
- `special` 列出已学；`special piyi` 触发百毒不侵语义；无硬编码残留（grep 干净）。

---

## F3：通用门派师父框架 SectMaster

### 目标
用数据驱动替代 `ZhangSanfeng` 单例，让任意门派师父 NPC 支持学艺、禁授、收徒门槛、问答授绝招。

### 步骤
1. **UCL 字段扩展**（`data/world/*.ucl` characters 块，与 loader.ex 已解析形状对齐）
   - `teach`：`%{family, teach_skills: %{技能 => %{max, gongxian}}, no_teach: [...]}`。⚠️ loader `parse_teach/1`（loader.ex:512）键是 **`teach_skills`**（非 `skills`），已支持 `%{max}`/`%{max, gongxian}` 两种值。
   - `apprentice`：⚠️ loader `parse_apprentice/1`（loader.ex:481）已产出 `%{family, min_shen, min_exp, min_skills: %{技能 => 等级}, no_recruit: [...]}`；**`class` 继承尚不在产物里**，本阶段补。
   - `inquiries`：⚠️ 键是复数且为 **顶层**字段；loader `parse_inquiries/1`（loader.ex:455）已解析，授绝招配置 map 值经 `parse_inquiry_value/1` 键归一为字符串——兼容 `%{skill, min_gongxian, min_shen, min_levels, cost_gongxian, perform_id}`。kyu 真身（`class/wudang/yu.c`）还把 `huzhua-shou>=120`（min_levels）与同门校验塞进 `ask_me`，实现时一并覆盖。
2. **`lib/kantele/sect_master.ex`（纯函数，类 `Master`）**——⚠️ 模块在**顶层** `Kantele.SectMaster`（切片 2 已建），不在 `npc/` 子目录
   - `teachable?(teacher, student, skill)`：同门派非嫡传（`Master.prevent_learn?`）+ 师父不高于学生（切片 2 已实现，切片 3 已接入 `teach/2`；⚠️ 实际 3 元而非早期草案 4 元）。
   - `recruit_gate?(teacher, student, gate \\ nil)`：shen/exp/心法门槛，读 `meta.apprentice`（切片 2 已实现，待接 NPC 侧事件）。
   - `inquiry_grant(player_stats, npc_stats, config)`：返回 `{:ok, perform_id, cost}` | `{:error, msg}`（**切片 4 已实现**，镜像 `yu.c` `ask_me`：已会→同门→`skill<1`→`min_gongxian`→`min_shen`→`min_levels`；`config` 字符串键 `%{perform_id, skill, min_levels, min_gongxian, min_shen, cost_gongxian}`；入参可为 `%Stats{}` 或等形 map，`:family` 双方都带才比较）。调用方据 `cost` 扣 `gongxian` 并 `Stats.learn_perform/2`（接线待续）。
 3. **接入事件**
   - `skills_event.ex teach/2`：改用 `SectMaster.teachable?`（保留 `prevent_learn?` 门派校验）。
    - `recruit` 命令 + `family/apprentice` 事件：**切片 6 已接**——NPC 回执带 `apprentice` 配置；玩家侧 `FamilyEvent.result/2` 用 `SectMaster.recruit_gate?/3` 复核门槛（不过则不落盘并提示），通过则写 `meta.family` + `class` 继承（bonze/eunach 不传播，对齐 `Family.recruit_apprentice` 判据）+ `gongxian` 兜底初始化；`class` 随 family map 持久化（records.ex `serialize_family`/`restore_family`）。`parse_apprentice/1` 已补 `class`。
    - `family/detach`：**切片 5 已修链路**——新增 `Room.DetachRequestEvent`（room.ex 注册 `family/detach`→转发目标 NPC）；玩家侧 `events.ex` 注册 `family/detach-result`→`DetachEvent.detach_result/2`；`NpcFamilyEvent.detach/2` 改从 `teach.family` 取门派身份（不再读 `NonPlayerMeta` 的 `:family`，消除 KeyError）并只回执身份；**玩家侧**据自身 family 用 `Master.attempt_detach` 判定嫡传/惩罚（`old_family` 暂传 `nil`=正常叛师必罚；转世免罚待历史字段）。惩罚降武功改为按 `stats.skills` 归约（`Stats.all/1` 不存在，编译告警已消）。⚠️ 仍用「各技能 -1 到最小 1」简化，未接 `Skills.skill_expell_penalty`（其需逐技能 type/enable 元数据，来源暂缺）。
    - inquiry：**切片 7 已接**——`NpcAskEvent.handle_scripted_answer` 命中脚本 `perform_id` → 派发 `npc/perform`（带 config + NPC `teach.family`）；玩家侧 `NpcScriptEvent.perform_result/2` 用自身 `%Stats{}` 调 `SectMaster.inquiry_grant/3`，`{:error,msg}` 只提示不落盘，`{:ok,perform_id,cost}` 则 `Stats.learn_perform` + 扣 `gongxian`（不为负）后 `Records.save`。loader `parse_inquiry_value/1` 顺带把嵌套 `min_levels` 键归一为字符串（下划线→连字符），否则技能门槛永远查 0 级。
    - ~~其余缺口 (3) apprentice recruit_gate / (6) class 继承~~：**切片 6 已修**；inquiry（`ask`→`npc/perform`→`inquiry_grant`）**切片 7 已接**。
4. **样板内容**（**切片 8 已完成**）
    - `class/wudang/yu.c`（俞莲舟）已翻译为 `data/world/signature.ucl` 的 `characters "yulianzhou"`：`teach`（含 `no_teach` 三绝张真人亲传）、`apprentice`（shen 20000/exp 150000/武当心法 80/taoism 80、class="taoist"）、`inquiries["绝户神抓"]`（`perform_id="huzhua-shou/juehu"`，gongxian 400/shen 100000/force 180/huzhua-shou 120）。落位「观云阁」，同一份 UCL 数据驱动四类行为，零代码新增门派。
    - `signature_npc_test.exs` 增 `yulianzhou` 键 + 逐字段解析断言（6 位特色 NPC）。
5. **测试**（**切片 8 已完成**）
    - `test/kantele/f3_sect_master_e2e_test.exs`：读真实 UCL 的俞莲舟，串起 拜师门槛拦（杀气不足不落盘）→ 达标拜师（family+class="taoist"）→ 学艺（`skills/teach` 走 `teachable?`）→ 问答得绝招（`ask`→`npc/perform`→`inquiry_grant`，扣 contrib 500→100）→ 叛师惩罚（同门嫡传→降功/清贡献/清门派）。
    - `NpcScriptEvent.perform_result/2` 顺带补 `stats_with_family/1`：把玩家 `meta.family` 门派名并入传给 `inquiry_grant`，否则 yu.c 的「非同门」分支永不触发（新增单测覆盖）。

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

### 进度（F4 slice1 已完成并推送）
- **步骤 1 提取器**：`scripts/translate_perform.exs`（模块 `Scripts.TranslatePerform`）。递归 `<src>/<skill>/<move>.c`，按顶层 `int perform(`/`int exert(` 签名分类（`F_SSERVER`/`F_CLEAN_UP` 继承一并记录）；抽取事实：level 门槛、变量赋值门槛（`lvl=query_skill(...)` + `lvl<120`）、`query_skill_mapped`/`_prepared`、资源门槛、`add`/`set` 消耗、`set_temp`/`add_temp("apply/..")`、`affect_by`、`do_damage`、`start_busy/is_busy` 行、首条 `notify_fail`。输出 `performs/<skill>/<move>.ex` 骨架（幂等；与人工实装同模板，未自动化处标 `TODO(migrate)`——即步骤 3 校对清单）。
- **步骤 2/4 元数据与样板**：3 个 LPC 样本以 fixture 形式入库（`scripts/fixtures/kungfu/skill/{huashan-jian/jie.c,chousui-zhang/dan.c,force/power.c}`，回归数据源）。样板 1 已实装：`Kantele.Combat.Skills.Force` + `performs/force/power.ex`（运功 `power`：force≥200 / martial-cognize≥120 / neili≥100 门槛、内力清零、攻防加成 cognize/5、战斗中 busy 3）；`exert` 命令补公共运功 fallback（`Skills.get("force")` 的 `exert_list`，对应 `kungfu/skill/force/*` 由各内功共享）。`valid_force` 互斥已在 F2/b5 生效；`Force` 注册后需在 `LearnGate.force_conflict` 排除基本 `force`（非可选内功）。
- **步骤 5 回归**：`test/kantele/f4_extractor_test.exs`（分类/事实抽取/骨架落盘与幂等）+ `test/kantele/combat/force_power_test.exs`（门槛/生效/busy/fallback），全量 2411/0。
- **待续（slice2/3）**：`huashan-jian/jie`（目标侧 busy，需新增 `perform -> target` 事件）、`chousui-zhang/dan`（远程伤害 + `fire_poison` + 护甲损耗，含 `TODO(migrate)` 项）。引擎现有 perform 均为自身 buff，攻击型 perform 的目标侧结算通道是 slice2 的前置。

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

### 阶段状态（F1/F2 已在 git 史，补记）
- **F1 conditions 接线**（初版提交 `37f233d`，早于本计划切片）：`condition_registry.ex`（静态 `@daemons %{"poison" => Kantele.Poison}` + `:persistent_term` 热增，`daemon/1`）+ `condition_event.ex`（独立 `condition/tick` 1s 自投递心跳，conds 非空才续投）+ `poison.ex do_effect` 只扣 jing/qi 不递减 remain（避免与 update_condition 双递减）。
- ⚠️ **F1 初版是空转的（本次已修，见下）**：补验收测试时发现初版有 4 个真 bug，且在无测试覆盖下全量绿是假象——(1) `ConditionEvent` **未注册**进 `Kantele.Character.Events`（`poison/apply`/`condition/tick` 都不路由，心跳从不启动）；(2) `apply/2` 读 `data["target"]`/`data["poison"]` 字符串键，而 `daub_command` 发的是**原子键** `%{target:, poison:}`（自毒判定恒 false）；(3) `tick` 的 `affect_by` 结果契约是 `{:ok, do_effect 返回值}`（batch6 锁定），`Poison.do_effect` 自己又返回 `{:ok, state}` → 双层 `{:ok, {:ok, state}}`，reduce 只解一层导致 `state.attributes` 首跳即崩；(4) 混毒 prev 读 `meta.temp["conditions"]`（无人写、恒 nil），应读 session。
- **F1 修正 + 验收测试**（本次提交）：注册 `ConditionEvent` 两个 topic；`apply` 改原子键并真正走 `Poison.mixed_poison/2`（prev 读 session）；`tick` reduce 解双层；新增 `test/kantele/character/condition_registry_test.exs`（注册/注销/覆盖/`all`）+ `condition_flow_test.exs`（经 `Kantele.Character.Events.call/2` 锁路由：自毒→掉血→到期自清→停跳、混毒等级叠加）。
- **F2 特技注册表**（提交 `8d4648f`，早于本计划切片）：`special_skills.ex` 注册表 + `special_skills_test.exs`；拍板（两个）：**保持原样**（散落读取点 `poison.ex`/`conditions.ex`/`attributes.ex`/`feature_damage.ex`/`room.ex` 不改写）、**只写注册表+测试**（`special` 命令维持「暂未开放」占位契约，`special_command_test.exs` 已锁）。
- ⚠️ **piyi 免疫实际未生效 → 已接线（F2 切片 F2-piyi）**：两读取点收敛为 `SpecialSkills.owned?/immune?/2`（统一宿主形状 `attributes["special_skills"][id] == true`，兼容旧字符串旗标 `"special_skill/<id>"`；因 `tick` 的 state 用**原子键** `:special_skills`，`owned?` 同时兼容原子键）；`conditions.ex affect_by` 与 `poison.ex check_immunity` 改走该入口；`condition_event.ex tick` 把 `character.attributes["special_skills"]` 喂进 state.attributes —— 现在 `attributes["special_skills"]["piyi"] == true` 时中毒心跳**不掉血**（`{:immune}` 短路，测试 `condition_flow_test` piyi 用例 + `special_skills_test` 两形状断言锁定）。`attributes.ex per` 也改走 `owned?(opts, "youth")`（旧旗标兼容）。`feature_damage greedy`/`room.ex emperor` 保持原样（非 F2-piyi 范围）。

### 切片 1：loader 收徒配置接线（已测通、已提交、已推送）
- 在 `loader.ex` 新增 `parse_apprentice/1` 函数：把 UCL 数据里的 `apprentice` 段解析成 `%{min_shen/min_exp/no_recruit/...}` 结构；`NonPlayerMeta` 结构体新增 `:apprentice` 字段（在 `character.ex`），并同步了 `apprentice_id` 字段。
- loader 元数据测试全绿。测试夹具确认了一个关键契约：`Family.name/1` 接收的参数是 **map**（如 `%{name: "武当派"}`），不是字符串——见 `room.ex:402/2458`。
- 提交号 `6413383`，已推送 `origin/kalevala`。

### 切片 2：sect_master.ex 纯函数模块（已测通、已提交、已推送）
- `lib/kantele/sect_master.ex`：`teachable?/3`、`recruit_gate?/3`、`detach_penalty?/2` 三个纯函数。
- **修掉的 4 类红因**（对照真宿主逐条钉）：
  1. `alias Kantele.Character.Master` 指向不存在模块——真身是 `Kantele.Npc.Master`；
  2. `Master.prevent_learn?/3` 入参误传 meta/stats 壳——真契约是 `(my_family, _me, asker_family)` 三张 family **map**；
  3. `min_shen/min_exp` 取数链虚构 `family.config`——真门槛在 `meta.apprentice`（切片 1 `parse_apprentice/1` 产出）；
  4. 测试夹具 `family` 摘要仍为字符串、`detach_penalty?` 直传字符串——`Family.name/1` 只吃 map（room.ex:402/2458 契约）。
- 另外一桩：切片 1 纪要里 `student_stats/1` 写的是读 `meta[:shen]`/`meta[:combat_exp]`，**与真宿主不符**——真身是 `character.meta.stats` 里的 `shen/combat_exp`（`%Stats{}`，records.ex:143/153、combat_event.ex:608、pai_commands.ex:35 实证），已改读 `meta.stats`。
- `teachable?/3` 镜像 skills_event.ex:38-69：`Master.prevent_learn?`（同门派非嫡传拦，文案「你已入别派」）+ 师父已不高于学生拦；`recruit_gate?/3` 走 `meta.apprentice` 的 min_shen/min_exp/min_skills；`detach_penalty?/2` family map 近似（同门=罚）。
- 全量 `MIX_ENV=test mix test`：**2351 tests, 0 failures**。

### 切片 3：skills_event teach/2 接入 SectMaster.teachable?（已测通、已提交、已推送）
- `sect_master.ex` `family_of/1` 支持两条真宿主读法：先 `meta.family` map，缺失则从
  `teach.family`（字符串）合成 `%{name:}`——NPC（NonPlayerMeta）没有 `:family` 字段，
  门派身份只在 `teach.family`（skills_event.ex:38-39 同源），合成后同门非嫡传判定与 host 等价，
  **否则会把同门非嫡传静默放行**。
- `skills_event.ex teach/2` 原手工 `my_family == student_family.name` +
  `Master.prevent_learn?` 块替换为 `SectMaster.teachable?/3`（保留 LearnGate
  snapshot_gate b1/b4/b5 与 do_teach 主链，语义等价）；顺带清掉存量 unused `Family` alias。
- 新增 e2e 2 条（learn_times_test：同门非嫡传拦「你已入别派」/ 异门正常授艺）+
  sect_master 单测 2 条（NPC 仅 teach.family 身份、student_family 直传 map）。
- 全量 `MIX_ENV=test mix test`：**2355 tests, 0 failures**。

### 当前断言
| 条目 | 真实状态 |
|---|---|
| F1 conditions 接线（`37f233d` → 本次修正） | 修正后：宿主路由 + 原子键 + 双层解包 + 混毒全通；`condition_registry_test`/`condition_flow_test` 补上 |
| F2 特技注册表（`8d4648f`） | 已提交；注册表+测试注入绿；命令/读取点保持占位（拍板） |
| loader 接线（容器测试） | 绿 |
| 切片 2（容器测试） | **绿**（2351/0） |
| 切片 3 teach/2 接线（容器测试） | **绿**（2355/0） |
| 本次 F1 修正 + 测试（容器测试） | **绿**（2364/0，+9 测试） |
| `origin/kalevala` | `6413383`（切片 1）已推送；F1/F2、切片 2、3、文档修正均已推送 |

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
