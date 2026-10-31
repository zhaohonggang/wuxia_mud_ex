# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- No `git commit` unless explicitly asked. HEAD == origin/kalevala 时不要自行 push。
- 无本地 Erlang → Docker 是唯一验证路径。
  - 单测：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`（**不带** `--no-deps`，需起 db）
  - 提交前体检：`... run --rm --no-deps -e MIX_ENV=test app mix compile`，退出码 0 即可（既有 warning 忽略）。**不做回归**，全量回归由用户最后跑一次。`mix compile` 不覆盖 `.exs`，用 `mix run --no-start` + `Code.string_to_quoted!` 做语法解析。
- 全量回归（4 块）：容器内 `find test -name '*_test.exs' | split -n l/4`，逐块 `mix test $(cat /tmp/chunk_XX | tr '\n' ' ')`，`set -e`、**不要** `| tail`，`grep --line-buffered "tests, "` 抓摘要。
- **改动前检查铁律**：认定「真缺口」动手前先 Grep `lib/`/`test/`/`docs/` + LPC 源 `/c/files/git/mud/kungfu/skill/`。真缺口多为「占位→LPC 保真」而非「从零新增」。基类（`unarmed.c`/`sword.c` 仅 `inherit SKILL` + 空 `skill_improved`）是假阳性。
- UCL (Elias)：newline 分隔块、无逗号、裸 key（含中文）、`newline=""`；`"..."` 内仅 `\"`/`\'` 与 `\`+word 合法；数组逗号分隔、无尾逗号。
- clone_lib 去重：NPC 有 clone_lib 主定义者，数据必须落 clone_lib；zone 同名块按名合并覆盖。
- Handler 回调：`run(conn, params)` 返回 `:not_handled` 放弃；需向玩家送达提示时**必须返回 conn**。
- **不要升级 nimble_parsec**。`commands.ex` 冷编译 ~28s 正常（452 parse → 452 defparsecp）。

## Test gotchas (CRITICAL — 动 skills/combat/items 前必读)
- **技能双通道**：`query_action/2` vs 可选 `/3(level, rng, attacker)`（`%Fighter{}`）；`valid_enable/1` vs 可选 `/2(usage, character)`；`valid_learn/1` vs 可选 `/2(stats, character)`（`%{meta: %{vitals: %{max_neili: _}, env: %{gender: _}, spouse: _}}`）。宏有默认回落。
- **`valid_learn` 1 元调用陷阱（CRITICAL）**：`Kantele.Combat.Skill` 行为对 arity-1 提供默认 `def valid_learn(_stats), do: :ok`，而真实门槛写在 `valid_learn/2(stats, character)`。测试里写 `Skill.valid_learn(stats)`（1 元）会**绕过所有真实门槛直接返回 `:ok`**，使 `{:error, _}` 断言静默失败。必须写 2 元 `Skill.valid_learn(stats, %{})`（character 用 `%{}` 即默认「男性」、无配偶）。`t1_exerts_test.exs` 全部 `valid_learn` 调用已统一收到 2 元（2026-10-31）。
- `alias Kantele.Character.Stats` **不会**由 `use Kantele.Combat.Skill` 带入，每个迁移文件须自己加。
- `Stats.effective/3` = LPC `query_skill`：`div(skills[usage],2) + skills[special] + apply`，**基本技能折半**。`self` 等级 = `Stats.skill(stats, id())`。**基础属性一律 `Stats.int/dex/str/con/1`**（有 `_ -> 0` 回落），别写 `stats.int`。
- `practice_cost()`：`nil` → 只能靠学；`%{qi:, neili:}` → `Vitals.damage(:qi, …)` + neili 扣减。
- `Skill.reborn?/1` 看 `stats.reborn` 任一非零；`Skill.mark?/2` 读 `meta.marks` 顶替 LPC `can_learn`。
- `Fighter.weapon_skill_type` 存**原始** `skill_type`（不套 `pin → sword` 归一）。
- condition daemon 纯函数不拿 conn → 发声/改状态走 `state.condition_messages` / `condition_unconcious`，由 ConditionEvent flush。生命周期两跳：先递减、后效果。
- `@type` 是保留属性，字符串键常量加前缀（`@key_type`）。
- 物品定义 vs 实例：`%Kalevala.World.Item{}` 全局只读，`%Item.Instance{}` 才带状态。`Records.inventory` 只存 item_id；跨登录状态进 `serialize_inventory_item/1`（`:book` 刻意不存）。
- `Conn.put_character` 写 `conn.private.update_character`，断言读 `conn.private.update_character || conn.character`。`conn.private` 是**结构体**：`%{conn | private: %{conn.private | room: %{characters: [...]}}}`，`put_in(conn.private[:room], …)` 会炸。
- `:global` name race：setup_all 注册一次 + 每测试 `reset/1`。`Item` 无 `:value/:unit`（在 `item.meta`）。Elixir `0` 为 truthy。
- Elias 三坑：①裸 `#` 行报 syntax error；②列表 `[a.id, b.id]` **逗号后不能有空格**；③块漏 `}` 会吞后续兄弟块。①②会让**整区加载失败**。
- `Room.message_vision/3` 是**死接口**。房间 vision 用 `RoomActions.Helpers.broadcast_vision/4`。
- 房间角色 `:id` 是**带 zone 的完整 id**（`signature:ganjiang`）。
- LPC 数字文案一律 `Kantele.Util.ChineseNumber.to_chinese/1`（照抄 `chinesed.c`：110→「一百十」）。
- 锻造：报价「两黄金」记账「文」，1 两 = 10000 文；`ForgingTimeout.schedule/4` 取消用 `:timer_token`；**顺序**先 `Forging.put` 再 `cancel/1`；落盘不能 `Jason.encode!(%Item{})`；`file_name/1` 把 `:` 换 `-`。`forge_timing_scale` 生产 1 / 测试 0。
- **事件模块命名铁律**：`use Kalevala.Event.Router` 的 `module(X)` 按 `scope` 前缀拼名，写错只在**运行时**炸。新事件模块一律放 `Kantele.Character.*`。

## C 相位 F4 武功迁移（LPC `kungfu/skill/*.c` → `lib/kantele/combat/skills/*.ex`）
- **整桶收口 (2026-10-29)**：`@actions` 202 空壳 + `valid_enable` 70（69 保真）+ `performs/` 728 模块全实现。`kungfu-f4-migration-checklist.zh-CN.md` 已标 ⚠️ 过时。
- **招式表补齐 ≠ 能用**：必须一并查 `Skills.@static`（195/733 白名单）。不在表里的技能 `Skills.get/1` → nil，「没有这项武功」，钩子全是死代码。
- **`valid_learn`/`practice_cost` 长尾已收口**：累计 **90 技能**（16 批，`f0bc5536`…`cf7d6b45`）。余 `TODO(migrate)` 里 `query_skill`(227) 实为 `query_skill_name`（招式名）、`prepare_skill`(81) 是 D4 已实现的 `@doc` 注释——**都不是缺口**。
- **性别门 23 技能已迁移**（`da511099`）：性别**早已建模**为 `meta.env[:gender]`（`Records.apply_to_character/2` 写入，默认「男性」），`meta.spouse` 对应 `couple/have_couple`。**「本模型暂无性别字段」全部是过时说法**。范式：`gender_of/1`。特殊：`shenghuo-xinfa` 门控圣火神功>100；`surge-force` 性别门最先；`yujiashu` 性别门在 force 门后；`hunyuan-yiqi` 已婚→非男→buddhism/force。
- **授艺快照管线 bug 已修**：`world/room.ex` 的 `skills/learn`→`skills/teach` 原先只转发 `skill/times/student_stats/reply_to`，丢掉 `student_vitals`/`student_family` → 师父侧 `max_neili` 门与 `SectMaster` 门派门**长期静默失效**。现已转发 `student_vitals/family/env/spouse`（`learn_command.ex` 发、`skills_event.ex` 组装 `%{meta: %{vitals:, env:, spouse:}}`）。**以后加 `valid_learn/2` 新门若需新字段，必须同时改这三处。**
- **`valid_damage/5`（防守方 invocation）已落地**（`26672db1`）：`skill.ex` 5 元 callback + fallback `{damage, nil}`；`Fighter` 加 `:max_neili`；`Round` 加 `:counter_damage`；`damage_calc` 双端调用（攻击方 mapped 攻击技能 + 防守方 parry/dodge mapped），折叠 2/3 元返回、合并 counter、拼 segments。27 技能保真迁移（`me`=防守方→`victim`，`ob`=攻击方→`attacker.skills`，`random(n)`→`rng.(n)-1`，`damage=-damage` 反弹→`{0,msg}`，剥色码保留 `$N/$n/$l`）。测试 `skills_valid_damage_test.exs` 覆盖 27 技能（`zero_rng()` 恒 1 让化解胜出、`two_rng()` 恒 2）。**`Engine.rand(rng,n)` 返回 `rng.(n)-1`（0-indexed，对齐 LPC `random`）**。
  - 遗留：`counter_damage` 跨进程作用到攻击方未接；`mp>=100` 分支因 `count` 技能未落 `stats.skills` 而休眠。
- **`hit_ob/5` 已落地（C-PVE23，本会话，未 commit）**：契约 `hit_ob(attacker, victim, damage, factor, rng) :: {extra_wound, msg} | {extra_wound, msg, affects}`，`affects :: [{cnd, para}]`（对应 LPC `victim->affect_by(cnd, para)`）。第 3 参按 LPC `combatd.c:816` 取**已算出的 `damage`**（护甲折减后），**不是** force bonus（与 `:707` 的 force 技能 `hit_ob` 两路区分）。在 `damage_calc` 内 `wound_split` 之后调用：`extra_wound` 加进 `wounded`，`hit_msg` 拼 segments，`affects` 落 `Round.conditions`。旧 `hit_ob/3` 在 `parry_check` 里返回 Fighter delta，与 LPC 不符，已废。**顺带修 `accumulate_counter/2` 参数顺序 bug**（`Enum.reduce/3` 回调是 `(element, acc)`）。测试 `skills_hit_ob_test.exs` 18 tests / 0 fail。
  - **Option 1（纯额外创伤族，16 技能）**：bizhen-qingzhang/dabei-zhang、六脉系 6（guanchong/shangyang/shaochong/shaoshang/shaoze/zhongchong-sword）、jiuqu-zhegufa/jiuyin-baiguzhao/shou-yin/sad-strike/piaoxue-zhang/tie-zhang/xianglong-zhang/pixie-jian；`dugu_jiujian`/`taiji_quan` 旧签名改 5 元。**顺带注册 15 个遗漏技能**（此前 `@actions` 非空但不在 `@static` → `Skills.get` 恒 nil，钩子死代码）。刻意跳过：`gun`（wizard-only）、`qishang-quan`（伤自己）、`shenlong-baiwei`（`userp` 门）。
  - **Option 2（中毒/condition 通道，14 技能）**：`hit_ob` 第三参改 `damage` + `Round` 新增 `:conditions`；`combat_event.resolve_incoming` 在 `apply_hit` **之前**调 `apply_round_conditions` → `ConditionEvent.apply_poison_condition/3`（缺 `remain` 按 `level*duration` 折算）。公共骨架 `lib/kantele/combat/poison_hit.ex` 的 `PoisonHit.strike/5`（参数 `skill/cnd/msg/min_lvl/min_jiali/div1/div2`）覆盖除 shenzhaojing/xuanming-zhang 外的 12 个；shenzhaojing（自断骨特效 + `shenzhao` 条件）、xuanming-zhang（strike≥300 + force 映射 xuanming-shengong + neili≥300 + `xuanming_poison` level=flvl*3）为自定义。**12 个 condition daemon** 经 `ConditionRegistry.@poison_family` 全部路由到 `Kantele.Poison`（`Poison.family/0` 含 bingcan_duzhang/cuixin_zhang/sha_poison/ice_poison/huagu/ningxue_shenzhao/qianzhu_wandushou/shenzhao/tougu_zhen/xuanming_poison/xuantian_zhi/yinfeng_dao，各带中文名 + `do_effect` 发作文案 + shenzhao/xuantian_zhi/xuanming_poison 的 `jing_div/qi_div`）。**注册 14 个遗漏技能**进 `Skills.@static`（此前全部死代码）。**刻意跳过 `freezing-force`/`hanbing-zhenqi`**：依赖 FORCE 基类 `hit_ob`（`Kantele.Combat.Force`，返回 `:neili_consume/:damage/:counterattack`，非 Skill behaviour）+ `query_temp("freezing")`，未建模。测试 `skills_poison_hit_ob_test.exs` 7 tests / 0 fail（与 hit_ob 批合计 25/0）。
- **假阳性（勿再当缺口）**：`force.c` `valid_learn` = `{return 1;}`；`force_lifeheal/power/roar/shot` 是 **Perform 模块**（`kungfu/skill/force/*.c` 是 exert 函数文件）不是技能；`xuehai-mogong` 仅 `return ::valid_learn(me)`。无消费者的回调（`difficult_level`/`query_effect_parry`/`query_effect_dodge`/`query_neili_improve`）现在迁移=死代码。
- **引擎未建模层（要动先补基础设施）**：alignment（`query("character")`，本仓 `meta.character` 恒 nil）、`ultrap`（大宗师）、`guilty`、`valid_practice` 回调、`valid_learn` 里须持械/空手（`character` 快照不含持械）。

## 待办（开放中）
- **`hit_ob/5` 整批（Option 1 + Option 2）待 commit**（用户未在本批明确要提交；iron rule 不主动 commit）。编译干净（`mix compile` exit 0），测试 25/0 全绿。
- **17 个既有 `valid_learn` 测试失败 — 已修复（2026-10-31，测试_only，未动技能）**：13 文件套件 124/0 全绿。根因分两类：① 12 个 `skills_*.exs` 是 fixture **基本技能值 ≥ 目标技能**导致 `base < self` 门不触发 → 按 LPC 逐个核对后**下调 fixture**（含 mingwang 期望文案「火候有限」修正、sanku-shengong 补 `force=>100` 满足 `force>=40`）；② 5 个 `T1ExertsTest` 失败实为**测试用 1 元 `valid_learn(X)` 命中行为默认 `:ok`**、绕过真实 `valid_learn/2` 门槛 → 全部 `valid_learn(X)` 改为 `valid_learn(X, %{})`。注意 ExUnit 在首个 `assert` 失败即中止该 `test` 块，故每个失败块里**后续 `{:error,_}` 断言从未被执行**，需一并修（如 xiuluo-yinshagong、sanku-shengong 都是这样被暴露的）。
- 打工闭环 / 注内力 / 锻造 等 S0-S4 见各日期日志。

## 已交付（历史，均已 push，详见 git log / 各日期日志）
condition/drunk、Force.Dispel+sleep、房间 water/liquid、P5 乞讨/fuse/战斗闲聊/打造(S1b+S1c)、R21 clone_lib、注内力(S2#156)、乾坤袋(S4)、币值勘误、LPC 全面对齐(ChineseNumber/Stats.effective)、打工闭环+yelvqi 覆命奖励。
