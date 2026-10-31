# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- 无 `git commit`/`push` 除非用户明确要求（HEAD == origin/kalevala 时不要自行 push）。
- 无本地 Erlang → Docker 是唯一验证路径。
  - 单测：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`
  - 提交前体检：`... run --rm --no-deps -e MIX_ENV=test app mix compile`（exit 0 即可，warning 忽略；不做回归，用户最后跑）。
- **改动前检查铁律**：认定「真缺口」动手前先 Grep `lib/`/`test/`/`docs/` + LPC 源 `/c/files/git/mud/kungfu/skill/`。真缺口多为「占位→LPC 保真」而非「从零新增」。基类仅 `inherit SKILL`+空 `skill_improved` 是假阳性。
- 不要升级 nimble_parsec（`commands.ex` 冷编译 ~28s 正常）。

## Test gotchas (CRITICAL — 动 skills/combat 前必读)
- **`valid_learn` 2 元陷阱**：行为对 arity-1 提供默认 `def valid_learn(_stats), do: :ok`。真实门槛在 `valid_learn/2(stats, character)`（`character :: %{meta: %{vitals: %{max_neili: _}, env: %{gender: _}, spouse: _}}`）。测试写 `Skill.valid_learn(stats)`（1 元）会绕过门槛静默返回 `:ok` → `{:error,_}` 断言失败。必须写 2 元 `valid_learn(stats, %{})`（%{} = 默认男性、无配偶）。
- `alias Kantele.Character.Stats` **不会**由 `use Kantele.Combat.Skill` 带入，每个迁移文件须自己加。
- `Stats.effective/3` = LPC `query_skill`：`div(skills[usage],2)+skills[special]+apply`（基础折半）。`self` 等级=`Stats.skill(stats, id())`。基础属性用 `Stats.int/dex/str/con/1`（有 `_->0` 回落），别写 `stats.int`。
- `Engine.rand(rng,n)` 返回 `rng.(n)-1`（0-indexed，对齐 LPC `random(n)`）。
- `practice_cost()`：`nil` → 只能靠学（learn_command.ex:74 拦 practice）；`%{qi:, neili:}` → 扣减。
- 其它坑见历史：condition daemon 不拿 conn、Elias 三坑（裸#/逗号后空格/漏}）、`Conn.put_character`/`conn.private` 是结构体、`Room.message_vision` 死接口、事件模块 `module(X)` 按 scope 拼名运行时才炸、锻造 `forge_timing_scale`。

## C 相位 F4 武功迁移（LPC `kungfu/skill/*.c` → `lib/kantele/combat/skills/*.ex`）
- **整桶收口 (2026-10-29)**：@actions 202 空壳 + valid_enable 70 + performs/728 全实现。
- **`hit_ob/5` + `valid_damage/5` 整批已落地（本仓未 commit）**：Option1 纯额外创伤 16 技能、Option2 中毒/condition 14 技能、combatd.c:707 force 路径 7 内功（jiuyang/jiuyin/longxiang/taixuan/kuihua/shenghuo/yunv）、freezing-force/hanbing-zhenqi 冰封被动。测试：test/kantele/combat 1793/0。force 路径第 3 参传 `damage_bonus`（非 damage）。
- **`Skill` 行为回调完整性已 survey (2026-10-31)**：对 @static 可达技能已无真缺口。结论 F4 combat/学习钩子实质完成；`practice_check` 全 lib 无消费者（死回调，跳过）；`skill_improved` LPC 非平凡体均不修 modeled 基础属性 → 默认保真。
- **引擎未建模层（要动先补基础设施）**：alignment（`meta.character` 恒 nil）、`ultrap`、`guilty`、`valid_practice` 回调、`valid_learn` 须持械/空手（`character` 快照不含持械）。
- **`valid_learn/2` 曾是最大盲区（2026-10-31 发现并开补）**：@static 624 个技能里 **322 个**源有非平凡 `valid_learn`，Elixir 侧只有基类默认 `:ok`（零门槛可学）。早前「F4 无真缺口」只覆盖 `hit_ob`/`valid_damage`。**已补 294 个**（wave1 116 无装备依赖 + wave2 178 持械门，见 `2026-10-31.md`）；**剩 28**：性格门 18（`meta.character` nil）、家族门 3、`guilty`/`learned_literate`/`wizardp`/`query_condition` 等 7。
- **持械门基础设施已就位（2026-10-31）**：teach 切片带 `meta.combat.equipped`（`learn_command` → `room.ex` → `skills_event`）；`Kantele.Combat.Skill.wielding?/1` / `secondary_wielding?/1` / `wielded_skill_type/1` 同时吃完整 Character 与切片。再遇到 `query_temp("weapon")` 类判定直接用这三个。
- **`LearnGate.force_conflict/2` 已特判 `@basic_force`**：LPC `force.c` 无 `valid_enable`/`valid_force` → learn.c 首句直接放行；不特判会让「学过特技内功的人学不了基本内功」（`f3_sect_master_e2e_test` 曾因此挂）。
- **生成器在 `C:/tmp/gen_valid_learn.py`**（`--write`/`--show ID`/`--maxg N`）+ 调查 `C:/tmp/survey_vl2.py`。后续 wave 直接复用，但**改完必须 `--force` 编译看 warning**（未用形参要 `_` 前缀、`alias Stats` 要按需）。

## 已完成：37 个 phantom 内功空壳迁移（batch，不 commit）
- 背景：`Skills.@static` 仅 195/733。38 个 `valid_force` 缺 override 者全为 phantom（空壳 @actions [] + 仅 valid_enable），但被 `data/world/*.ucl`/`clone_lib.ucl` 引用（NPC 可能传授）→ 不在 @static 则 `Skills.get`=nil 不可学。用户决定「全量 37 内功」逐批迁保真并注册。
- **已完成（2026-10-31）**：全部 37 已迁保真并注册 @static。其中 `longxiang-gong` 早在 7 force hit_ob 批内已完整迁移；本批迁剩余 **36 空壳**：30 简单壳（valid_force + practice_cost=nil，valid_learn 继承基类默认 :ok）+ 6 复杂壳（hamagong/xiantian-gong/xuedao-dafa/shennong-xinjing/tianchi-neigong/yunv-xinfa，含 faithful valid_learn/2 + 性别/max_neili 门 + hit_ob）。
- **已立范式**：`valid_learn` 继承基类→不 override（默认 :ok）；`practice_skill` notify_fail("只能用学")→`practice_cost(), do: nil`；`valid_force(force) :: force in [...]`。
- **已知偏差/未建模**：① `yunv-xinfa` LPC `hit_ob` 内部 `query_skill("yunv-xinjing")` 取自身等级（疑似源内别名），按本技能 id 取；② `hamagong`/`xiantian-gong` 攻击方 `neili` 自耗（-30/-50）、`prepared` 门控未迁移（Fighter 无 `prepared` 字段，引擎 `apply_force_hit_ob` 用 `function_exported?` 守卫）；③ `xuedao-dafa` `hit_ob` 为「血量越低越易触发二次出招（COMBAT_D->do_attack）」机制，本引擎无跨进程二次出招基础设施→**刻意跳过 hit_ob**（引擎安全回退 `{0,nil,[]}`）；④ `hamagong`/`xiantian-gong` LPC `query("character")` 性格门（光明磊落/国士无双等）因 `meta.character` 恒 nil 未建模→跳过。
- 注册位置：`lib/kantele/combat/skills.ex` `@static` 白名单（格式 `"id" => Kantele.Combat.Skills.Xxx`）。

## 待办
- **valid_learn 补全进度（2026-10-31）**：322 → 已补 **294**（wave1 116 + wave2 178）→ **剩 28**（性格门 18 需先建模 `meta.character`；家族门 3 需切片带 family；其余 7 为零散写法）。回归基线：**combat+character+f3 e2e = 4028/0**。后续 wave 直接复用 `C:/tmp/gen_valid_learn.py`。
- ✅ **编译 + 回归已验证（2026-10-31，Docker UP）**：`mix compile` exit 0（仅 tonggui_jian/fen.ex、drive_command.ex 既有无关 warning）；`test/kantele/combat`=1793/0、`test/kantele/character`=2051/0（合计 3844/0，无回归）。
- ✅ **单测已补并全绿（2026-10-31）**：新增 `test/kantele/combat/skills_phantom_force_test.exs`，37 tests/0 failures。覆盖 36 门空壳的 `Skills.get` 注册 + `valid_enable("force")` + `practice_cost()==nil` + `valid_force` 白名单往返；以及 hamagong/xiantian-gong/xuedao-dafa/shennong-xinjing/tianchi-neigong/yunv-xinfa 的 `valid_learn/2` 门槛（含 str/con/int/dex/gender/max_neili/各技能等级门）。
- ⚠️ hit_ob/5 整批（Option1+2+707 force 7 内功）+ 36 phantom 改动 + 新增单测 **全部未 commit**（iron rule），待用户决定。
- 全量回归由用户最后跑（`find test -name '*_test.exs' | split -n l/4` 四块；重点 combat + character，已先跑过这俩）。
- **白名单补全（新工作流，batch1-5 已完成）**：@static 唯一 id 255→**624**。**batch1** 52「有招式·无 performs·无门槛」+ **batch2** 200「有招式+带 performs」+ **batch3** 105「空招式但非攻击类」+ **batch4** 8（知识类无招式 5 + 纯 perform 暗器 3）+ **batch5** 4（招式表已迁的攻击类）均已注册（`skills.ex` @static 末尾 + 测试）。回归：combat 1916/0、character 2051/0。22 基础用法不注册。注：@static 有 12 个既有的同模块重复 id（无害，未清理）。**未 commit。** 详见 `2026-10-31.md`。
- **batch4 关键纠正（check-first 结论）**：原清单「12 个需迁移」有 8 个是误判——`@actions []` 对它们本就是**保真**：5 个知识类（idle-force/mihun-dafa/qimen-wuxing/yunlong-xinfa/zuoyou-hubo）源 `type()=="knowledge"` 且无 `query_action`；3 个暗器（xiaoli-feidao/xuanyuan-arrow/yufeng-zhen）源只有 `perform_action_file`、无 `query_action`。真正缺口只是 `valid_learn/2` + `practice_cost/0`。源无 `valid_enable` 时（LPC 调用未定义函数即失败）→ `valid_enable(_) -> false` 是保真写法。
- **batch4 保真细节**：`xuanyuan-arrow` 源第二条 `query_skill("xuanyuan-arror")` 是拼写错误（该技能不存在 → 恒取 0）→ 死代码，不迁移（已注释说明）。`yufeng-zhen` 用 `Stats.query_dex/1`（派生：base+tattoo+reborn+dodge/10），**不是** `Stats.dex/1`；且 `query_dex` 头是 `%Stats{}` 结构体，测试必须传真结构体。`zuoyou-hubo` 用 `Stats.int/1`（裸属性，非 query_int）；`special_skill/qinzong|tiandao` 走 `SpecialSkills.owned?(character.attributes, id)`（learn 事件切片不带 attributes → 恒 false，已知限制）；`force < div(lvl*3, 4)` 是 C 整数除法。
- **剩余 4 个真缺口 → 已迁（batch5，2026-10-31）**：`qingyun-bian`（10 式，force=max_neili/4、damage=shen/1500 动态）、`qixian-wuxingjian`（unarmed 7 + sword 7 双表）、`tanzhi-shentong`（6 式 + 极意，**均匀随机不过滤等级**）、`yiyang-zhi`（finger 12 + 极意 + staff 5 双表）。@static 620 → **624**。combat 1916/0、character 2051/0。
- **`Fighter.shen` 已补**（batch5 前置）：`defstruct` 加 `:shen`（默认 0），`from_character` 取 `stats.shen || 0`。qingyun-bian 的 `damage = shen/1500` 依赖它。LPC `query("shen")` 正邪值。
- **batch5 保真要点（易踩）**：
  - **两表等级过滤符号不对称**：`qixian-wuxingjian`/`yiyang-zhi` 空手表用 `level >= lvl`（源），持械表用 `level > lvl`。基类 `Skill.pick_action` 只实现 `>`，故空手表须本地 `pick_action_ge`。
  - `NewRandom` 细节：count=2 时恒取索引 0（LPC 同）；count=3 且 `rng=fn n->n end` 取索引 2。测试用 `rng_max/rng_min` 精确断言。
  - **0 级持械退化场景有意偏差**：源 `query_action` 落空返回 0（无招），本实现回落首式 —— 引擎 `select_action` 拿 `%{}` 会在 `"\n" <> Map.get(action,"action")` 处崩。
  - `qingyun-bian` 第 6 式「剪虹」源缺 `damage_type`（保真不补）；`qixian`/`yiyang` 持械表源无 `skill_name`（保真不补）。
  - 招式 `"weapon"` 字段（`无形剑气`/`一阳指力`）LPC 只用于替换文案武器名，引擎不消费。
  - 动态「极意」五项公式（tanzhi/yiyang 与 huashan-jian 同构）：force=f/2+rand(f)、attack=fi/4+rand(fi/2)、dodge=d/6+rand(f/3)、parry=p/6+rand(p/3)、damage=f/4+rand(fi/2)。
- **hit_ob 已补（batch5 尾，2026-10-31）**：`qixian-wuxingjian`（七弦音攻 busy 1）、`tanzhi-shentong`（弹指穴道 busy 2）、`yiyang-zhi`（一阳指穴道；空手 busy 2、持械支源内**不** start_busy）。combat 1940/0、character 2051/0。
- **新基础设施：`busy` 保留字 affect**（`combat_event.ex apply_round_conditions/2` 首子句）——`hit_ob` 回传 `{"busy", %{"rounds" => n}}` 即落到防守方 `character.meta.combat.busy`（`Combat.start_busy/2` 取 max，同 LPC 语义）。**不走条件 daemon**（busy 是临时计数而非可累积中毒）。poison 的 `{cnd, para}` 子句不受影响（字符串不匹配 `"busy"`）。
- **hit_ob 契约已扩至 4 元素**（2026-10-31）：`{wound, msg, affects, extra}`，`extra` 支持 `:plain_damage`（无创伤 qi 伤害，叠进 Round.damage）/ `:victim_neili`（防守方内力削减，本进程直接落地）/ `:attacker_neili`（攻击方自耗，经 `combat/attacker-cost` 事件回传）。2/3 元组仍合法（`normalize_hit_ob/1` 兜底）。①②③ 三个旧缺口已全部补齐，不再"只能注明未建模"。
- **⚠️ `put_character/2` 只写 `conn.private.update_character`，不改 `conn.character`**（`import Kalevala.Character.Conn`）。同一 handler 内要「取最新角色」只能读 `conn.private.update_character || conn.character`（本仓惯例 `defp current/1`），**绝不能用 `conn.character` 重取**——那是 handler 入口快照。我曾在 `resolve_incoming/5` 里 `character = conn.character` 想取最新，结果把 `Combat.add_enemy` 加的敌人覆盖为空（flow_test 4 例挂）。
- **`valid_learn` 全量收口（2026-10-31，322 个，wave1-3）**：白名单 624 个里带非平凡 `valid_learn` 的 322 个已全部 LPC 保真迁移（`gen_valid_learn.py` 生成 294 + 手写 28）。工具链：`C:/tmp/gen_valid_learn.py`（`--write` / `--show ID` / `--verify`）+ `C:/tmp/verify_messages.py`（文案级校验）+ `C:/tmp/handwrite_vl.py`。测试：batch1 17/0、batch2 14/0、batch3 22/0。
- **生成器三条铁律（踩过的坑）**：① 必须 `strip_comments`（先 `mask_strings` 保等长），否则 `/* */`、`//` 里注释掉的 `if (...) return notify_fail(...)` 会被迁成真门槛（`pona-gong`/`qinna-shibada`/`yinlong-bian`/`dispel-poison` 曾中招）；② `notify_fail` 只能取 **if 自身语句体 + 块内顶层**（`_brace_depth == 1`），且所有位置都要记进 `handled`，否则跳过的门会被「裸 `return notify_fail`」兜底重新认领（曾产出 `None ->` 子句）；③ 参数须纯字面量，判残留前先 `COLOR_RE.sub` 去掉 `HIR`/`NOR` 等宏。
- **天性/门派门不需要 nil 守卫**：LPC 未设定时 `query("character")` / `query("family/family_name")` 返回 0，`0 == "X"` 假、`0 != "X"` 真；Elixir `nil` 比较结果完全一致 → 直接 `personality == "X"` / `family_name != "少林派"`。反例：`max_neili`/`neili` 缺字段要 `nil` 跳过（否则误拦）。
- **`can_learn/` 与 `can_perform/` 条件门一律跳过**：源内由副作用或任务置位，本端口未建模恒假。`jiuyang-shengong`、`wudoumi-shengong` 靠这条收口。
- **`for (usage_skills)` 循环门**：手写成 N 条 cond 子句（按数组顺序展开，零 helper），比 `Enum.any?` + 中文名映射表更简单且顺序保真。中文名用既有约定：unarmed 基本拳脚 / strike 基本掌法 / sword 基本剑法 / blade 基本刀法 / staff 基本杖法 / whip 基本鞭法 / finger 基本指法 / claw 基本爪法 / hand 基本手法 / cuff 基本拳法 / dodge 基本轻功 / parry 基本招架 / force 基本内功 / throwing 基本暗器。
- **下一批真实缺口：89 个「部分迁移」的 `valid_learn`**（audit 已定位，均无 `# LPC \`valid_learn(object me)\`` 标记 = 既有代码）：**35 个 arity-1 `valid_learn(stats)` 占位**（典型 `feilong-zhang`：源 5 门只实现 1 门）+ **54 个 arity-2 门数不足**（典型 `banruo-zhang`：源 4 门只实现 3 门，缺空手门）。arity-1 经基类 `def valid_learn(stats, _character), do: valid_learn(stats)` 回落，**确实生效但看不见 vitals/装备**，是「半保真」而非零门槛。修法：删旧块 → 跑 `gen_valid_learn.py --write` 重生成（这批 89 个基本都在生成器能力内）。清单见 `C:/tmp/audit.txt`。
