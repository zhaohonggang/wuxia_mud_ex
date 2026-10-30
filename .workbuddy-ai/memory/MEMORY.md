# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- No `git commit` unless explicitly asked. HEAD == origin/kalevala. P5 乞讨系统 (#143), fuse (#144 5 灵石), 战斗闲聊 (#144), S0/S1a/S1b/S1c 均为本地未提交，待用户决定 push。
- No local Erlang — Docker 是验证路径：
  `docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`
- 全量回归（4 块）**统一在所有改动完成后跑一次**，改动过程中不要零碎跑（Docker 易崩：偶发 `unexpected EOF` / 拉 `postgres:12-alpine` 失败）。命令：容器内 `find test -name '*_test.exs' | ... | split -n l/4`，逐块 `mix test $(cat /tmp/chunk_XX | tr '\n' ' ')`，用 `set -e` 且**不要** `| tail`（teardown 会截断尾部，看不到各块 `tests, N failures`）；改用 `grep --line-buffered "tests, "` 抓摘要。过程中若需冒烟，仅用单文件 `mix test <path>`。
- **改动前检查铁律（防重复实现）**：认定某技能/功能是「真缺口」并动手前，必须先对 `C:\files\git\wuxia_mud_ex` 做**关键词搜索**（Grep 覆盖 `lib/`、`test/`、`docs/`），确认没有早已实现（如某 `valid_learn/2`、`@actions` 已填、已注册 `Skills.@static`、已有同名测试文件），再动手。LPC 源 `/c/files/git/mud/kungfu/skill/` 也要先查。基类（`unarmed.c`/`sword.c` 等仅 `inherit SKILL` + 空 `skill_improved`）是假阳性缺口，别碰。「先检查，确认是缺口，再做」始终适用。
  - 实测提醒（2026-10-30）：`valid_learn/1` 与 `practice_cost()` 在大量技能里**早已存在**（`grep "def valid_learn"` 数百处，多数为 `(_stats), do: :ok` 或空壳；`practice_cost` 大量 `%{qi:, neili:}` 或 `nil` 占位）。1339 `TODO(migrate)` 的真缺口往往是「把占位/空壳改成 LPC 保真逻辑」，而非「从零新增」——搜过才不会重写已有实现。
- UCL (Elias): newline 分隔块、无逗号、裸 key（含中文）、`newline=""`；`"..."` 内仅 `\"`/`\'` 和 `\`+word 合法；数组逗号分隔、无尾逗号。
- clone_lib 去重铁律：NPC 有 clone_lib 主定义者，数据必须落 clone_lib；zone 同名块按名合并覆盖。
- Handler 回调：`run(conn, params)` 返回 `:not_handled` 放弃；需向玩家送达提示时**必须返回 conn**。
- **不要升级 nimble_parsec**（用户明确要求）。`commands.ex` 单文件冷编译 ~28s 是正常代价，不是卡死。根因：452 个 `parse` → 452 个 `defparsecp`，nimble_parsec 0.6.0 代码生成慢。详见 `2026-10-28.md`。

## Test gotchas (CRITICAL — read before touching skills/combat/items)
- **技能招式表两条通道**：`query_action/2`（无角色，只能空手表）与**可选** `query_action/3(level, rng, attacker)`（attacker 是 `%Fighter{}`，含 `:skills`/`:weapon_name`/`:weapon_skill_type`）。同理 `valid_enable/1` vs **可选** `valid_enable/2(usage, character)`（character 是 `%Kalevala.Character{}`，读 `meta.stats`/`meta.marks`）以及 `valid_learn/1` vs **可选** `valid_learn/2(stats, character)`（character 是 `%{meta: %{vitals: vitals}}`，用于 max_neili 等 vital 门槛）。宏里有默认实现回落，新技能只覆盖需要的那个。
- `Skill.reborn?/1` 以 `stats.reborn` **任一非零加成**判定已转世（引擎无布尔标记、无 `reborn/count`）；`Skill.mark?/2` 读 `meta.marks` 顶替 LPC `can_learn/...`。
- `Fighter.weapon_skill_type` 存**原始** `skill_type`（不套 `attack_skill` 的 `pin → sword` 归一），因为 `never-defeated` 按 `skill_type == "whip"` 分表。
- condition daemon 是纯函数，不拿 conn → 发声/改状态走 state.condition_messages / state.condition_unconcious，由 ConditionEvent flush。
- 生命周期两跳：update_condition/1 先递减，do_effect/3 后效果（看到递减后的值）。
- `@type` 是 Elixir 保留属性，字符串键常量加前缀 (@key_type)。
- 无值返回 nil 调用点须判空；Conn.Text.data 含 nil 在 Tags.parse_string/4 才 FunctionClauseError → 掉线。
- 物品定义 vs 实例：%Kalevala.World.Item{} 全局共享只读，%Item.Instance{} 才是实例状态；写实例 meta，不污染定义。
- Records.inventory 只存 item_id；跨登录保留的实例状态进 serialize_inventory_item/1；:book 刻意不存。
- Conn.put_character 写 conn.private.update_character；断言读 `conn.private.update_character || conn.character`。
- :global name race: setup_all 注册一次 + 每测试 reset/1。
- put_character/2 返回新 conn；Kalevala.World.Item 无 :value/:unit（在 item.meta）；Elixir 0 为 truthy。
- Elias UCL 括号吸收：块漏 `}` 会吞后续兄弟块；Elias.parse 后深搜失踪 key。
- Elias 另两坑（会让**整区加载失败**→ loader 测试大面积 invalid）：①**裸 `#` 行**（注释符后空）报 `syntax error before: "\n"`；②列表 `[a.id,b.id]` **逗号后不能有空格**（`[a.id, b.id]` 解析失败）。
- `Room.message_vision/3` 是**死接口**：发 `{:vision_message, ...}`，Foreman 只处理 `{:room_message, ...}`。房间 vision 一律用 `Kantele.World.RoomActions.Helpers.broadcast_vision/4`（`$N`→`{npc}` 由 VisionView 分流「你」/姓名）。
- `Stats.effective/3` = LPC `query_skill`：`div(skills[usage],2) + skills[special] + apply`。基本技能**折半**！装备 `armor_prop` 走 `Combat.skill_applies/1` 传入。
- LPC 数字文案一律 `Kantele.Util.ChineseNumber.to_chinese/1`（照抄 `chinesed.c`：110→「一百十」、1010→「一千零十」）。`Money` 已委托它，勿再写第二份。
- 锻造币值：报价「两黄金」、记账「文」，1 两 = 10000 文（`moye.c` `val *= 10000`）。
- **事件模块命名铁律**：`use Kalevala.Event.Router` 的 `module(X)` 按 `scope` 前缀拼名。`scope(Kantele.Character)` 下写 `module(Foo)` 得到 `Kantele.Character.Foo`，写成 `Kantele.World.Foo` 会在**运行时** UndefinedFunctionError（编译不报）。新事件模块一律放 `Kantele.Character.*`。
- `conn.private` 是 `%Kalevala.Character.Conn.Private{}` **结构体**（不是 map）：注入房间快照用 `%{conn | private: %{conn.private | room: %{characters: [...]}}}`，`put_in(conn.private[:room], ...)` 会炸。`Room.characters_for_conn/1` 认这个字段。
- 房间角色 `:id` 是**带 zone 的完整 id**（`signature:ganjiang`），不是裸名；按裸名比对永远找不到（`npc_shop_event` / `kneel` 都是按 `character.id` 比）。
- 锻造定时：`Kantele.World.ForgingTimeout.schedule/4` + `Process.send_after` 投回 NPC 进程；取消用 `:timer_token` 令牌（不是 ref）。`forge_timing_scale` 生产 1 / 测试 0。
- **顺序陷阱**：`Forging.put(new_session)` 之后再 `ForgingTimeout.cancel/1` —— 反了会被 new_session 里的旧令牌覆盖，等于没取消。
- 锻造物品持久化：不能用 `Jason.encode!(%Kalevala.World.Item{})` 落盘（走 Meta.Trim 只剩 damage/armor）；`file_name/1` 把 id 里的 `:` 换成 `-`（Windows 非法字符）。`config :ex_venture, :forge_dir`。

## C 相位 F4 武功迁移（LPC `kungfu/skill/*.c` → `lib/kantele/combat/skills/*.ex`）
- **整桶收口 (2026-10-29)**：静态 `@actions` 表（202 保真空壳）+ `valid_enable`（70 空壳，69 保真）+ `performs/`（728 模块；414 条清单 `[ ]` 全部已实现并注册 `perform_list`，缺模块 0 / 未注册 0）。**F4 三桶功能完整、0 真缺口**；`kungfu-f4-migration-checklist.zh-CN.md` 已加 ⚠️ 过时声明。
- PVE 高频真缺口已补（Docker 全绿，全量 **5423/0**）：`luohan-quan`(18/0)、`dagou-bang`(13/0，含 lvl200 动态「极意」)、`kuangfeng-jian`(13/0)、`banruo-zhang`(18/0)、`cibei-dao`(18/0)。均按 LPC 补齐 `@actions`+`query_action/2,/3`+`query_skill_name` 并注册 `Skills.@static`。**教训：招式表补齐 ≠ 能用**，必须一并查 `Skills.@static`（195/733 白名单）；生成器改文件时旧占位符单行形式（`@actions []`）最易漏，改完 `grep -n "^  @actions"` 数 >1 即残留。
- **余 1339 `TODO(migrate)` = 动态公式门槛**：`valid_learn`(680)/`practice_skill`(628)/`query_skill`(1121 多为基本技能基础类)/`prepare_skill`(62)/`valid_damage`(17)/`surge`(5)。基类（`unarmed.c`/`sword.c` 等仅 `inherit SKILL` + 空 `skill_improved`）是**假阳性缺口**，别碰。LPC 源在 `/c/files/git/mud/kungfu/skill/`（1162 条，扁平 `.c`）。
- **契约已扩** `valid_learn/2(stats, character)`（含 max_neili 门槛），并贯通 learn 事件（`learn_command` 传 `student_vitals` → `skills_event` `do_teach` 调 `valid_learn(student_stats, %{meta: %{vitals: student_vitals}})`）。真实迁移 = 首批 `banruo_zhang.ex`（force<30 / max_neili<100 / strike<self 拒 + `practice_cost()=%{qi:65,neili:64}`）+ `dagou_bang.ex`（dex<26 / max_neili<1500 / staff<100 / staff<self 拒 + `practice_cost()=%{qi:75,neili:80}`）；第二批（2026-10-30，代码+测试已落、待统一回归）`kuangfeng_jian.ex`（max_neili<200 / dodge<90 / dex<28 / sword<self 拒 + `practice_cost()=%{qi:60,neili:36}`）、`cibei_dao.ex`（max_neili<100 / force<30 / blade<self 拒 + `%{qi:55,neili:58}`）、`luohan_quan.ex`（force<20 / max_neili<50 / cuff<self 拒 + `%{qi:25,neili:6}`；原 moduledoc 误记 dex>=30/max_neili>=3000+lvl*15，已按真实 LPC `valid_learn`（空手/force>=20/max_neili>=50/cuff>=self）纠正）。均照 LPC 保真；banruo 测试 **25/0**、dagou **21/0**、learn_times **8/0**、分块 aa **1438/0** / ab **672/0** 已验证（teach 贯通修复 3 失败）。ac/ad 因用户指示暂停测试未重跑。

## 待办（开放中）
- ~~跑 banruo-zhang 新测试 + 全量 4 块 Docker 回归~~ ✅ 已完成（2026-10-30）：banruo **25/0**、learn_times **8/0**、aa **1438/0**、ab **672/0**（teach 贯通修复 3 失败）。ac/ad 因用户指示暂停测试未重跑（前序 5423/0 基线 + 本批次仅触及 teach/do_teach 与 banruo/dagou，二者均有专项绿灯，ac/ad 不受影响）。
- **改动前检查铁律（2026-10-30 用户指示，已写入 Iron rules）**：认定真缺口动手前，先对 `C:\files\git\wuxia_mud_ex` 做关键词搜索（Grep 覆盖 `lib/`/`test/`/`docs/`）+ LPC 源 `/c/files/git/mud/kungfu/skill/`，确认没早已实现再改。实测：`valid_learn/1` 与 `practice_cost()` 在数百技能里**早已存在**（多为 `(_stats), do: :ok` / `nil` 占位），故真缺口多为「占位→LPC 保真」，非「从零新增」。
- **回归统一收尾（2026-10-30 用户指示）**：Docker 易崩，改动过程中不零碎跑全量；所有改动做完后统一跑 4 块一次。抓摘要用 `grep --line-buffered "tests, "`，**不要** `| tail`。
- 第二批 1339 `TODO(migrate)` 长尾已补 ✅（2026-10-30，代码+测试已落、待统一回归）：`kuangfeng-jian`/`cibei-dao`/`luohan-quan` 的 `valid_learn/2`（含 max_neili 门限）+ `practice_cost` 真实门槛均已照 LPC 迁移（moduledoc 同步）。下一轮继续 1339 长尾：按 LPC 源逐技能查 `valid_learn`/`practice_skill`/`prepare_skill`/`valid_damage`/`surge` 真实公式，每技能先 Grep 工作区 + LPC 源确认是「真缺口」再改；基类（`unarmed.c`/`sword.c` 等仅 `inherit SKILL` + 空 `skill_improved`）是假阳性缺口，别碰。
- ac/ad 全量回归待 Docker 抖动恢复 + 所有长尾改动收齐后统一跑（由用户自行执行，2026-10-30）；本次（banruo + dagou + kuangfeng-jian + cibei-dao + luohan-quan）改动已于 2026-10-30 经用户授权 `git commit` + `git push`（commit `f0bc5536`，12 文件）。
- 打工闭环 / 注内力 / 锻造 等 S0-S4 任务见各日期日志（均已 push，详见 `2026-10-28.md` 等）。

## 已交付（历史，均已 push，详见 git log / 各日期日志）
condition/drunk、Force.Dispel+sleep、房间 water/liquid、P5 乞讨/fuse/战斗闲聊/打造(S1b+S1c)、R21 clone_lib、注内力(S2#156)、乾坤袋(S4)、币值勘误、LPC 全面对齐(ChineseNumber/Stats.effective)、打工闭环+yelvqi 覆命奖励。
