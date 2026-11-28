# 北京领赏（`reward` 问询）LPC → ex 移植计划

> 建立日期：2026-11-28
> 对应缺口：统一执行计划 UG-03 / A-5-c（`reward` 组，8 个 `unimplemented` 占位）
> 工作流约束：AGENTS.md §0.4 —— 不得自行跑全量回归；定向测试不受限；未授权不得 commit/push；未提交批次登记 `docs/待全量回归清单.zh-CN.md`。
> 宪章：LPC 有 ex 无 → 主动报告 + 建计划 + 逐片实现，零信息丢失（机制/门序/阈值/文案/公式只多不少），严禁简化。

---

## 1. 结论先行（审计判定）

| 项目 | 判定 |
|---|---|
| 8 个占位键 | **REAL_GAP** |
| 是否需要新设计 | **NEEDS_DESIGN**（引擎级 + 系统级，跨 4 个子系统） |
| 是否纯文本回填 | ❌ 否。两者都是真实闭包 `ask_reward()`，带门序、状态写入、传送/奖励副作用 |
| 是否可以并入已实现 handler | ❌ 否。`jobs_job` / `ask_weiwang` / `teleport_service` 语义均不同 |
| 当前执行指针影响 | 保持在 **A-5-c**，不得跳过；本计划拆成 C1–C6 子片，逐片检查→实现→定向验证 |

8 个占位全部位于 `data/world/beijing.ucl`，两个 NPC 各 4 键：

| NPC | UCL 块 | 键 | LPC 源 |
|---|---|---|---|
| 康熙大帝 | `characters "kangxi"`（第 6876 行起） | `reward` / `请赏` / `赏赐` / `领赏` | `mud/d/beijing/npc/kangxi.c:33-38, 55-113, 115-196` |
| 御前侍卫 | `characters "yuqian1"`（第 9056 行起） | `reward` / `请赏` / `赏赐` / `领赏` | `mud/d/beijing/npc/yuqian1.c:34-39, 65-94` |

依赖的守护进程/资源：`mud/adm/daemons/invasion/invasiond.c`、`mud/adm/daemons/invasion/npc/invader.c`、`mud/mudcore/system/kernel/simul_efun/bitmap_font.c`（+ `fonts/HZK16?`, `fonts/ASC16`）。

---

## 2. 为什么不是简单回填

两个 `ask_reward()` 都不是返回字符串，而是执行 Closure，依赖以下 ex 侧当前**缺失或不完整**的能力：

1. **入侵守护进程 record 查询**：LPC `INVASIOND->query("record")` / `record/all_killed` / `record/born_time`。
   - ex 有 `Kantele.World.Invasion`（GenServer），但只暴露 `status/1`（`wave_number / wave_active / total_killed / all_killed / invaders_alive`），**没有波次级 `born_time`**，也没有可供问询 handler 调用的公开查询 API。
   - LPC `record/born_time` 由 `invasiond.c:25` 在每波 `main()` 开头统一置一次，所有入侵者共享；ex 目前每个 invader 在 spawn 时各自取 `System.system_time(:second)`（`invasion.ex:310`），语义有偏差。
2. **玩家 `waidi/*` 状态**：LPC 击杀入侵者时在 `invader.c:151-160` 写 `me->set("waidi/born_time", ...)` / `me->add("waidi/number", 1)`；`waidi/word` 由康熙 `ask_reward()` 写入，`do_answer()` 读取后清除 `waidi`。
   - ex 击杀路径 `combat_event.ex:1691 notify_invasion_killed/2` 只调用 `Invasion.on_died/2`，**没有写玩家 `waidi/*`**。
   - ex 的 `meta.env` 即 LPC `set()` 属性仓库（`party.ex:6` 等已确认），是 `waidi` 落点。
3. **康熙殿试 `answer` 链**：LPC `do_answer()`（`kangxi.c:115-196`）在 `ask_reward()` 出题后由 `answer xxx` 作答——校验 `waidi/word`、发潜能/黄金/丹药、全服 `message("invasion", ...)`。
   - ex `AnswerCommand` 只有 Forge / quest_gift / ask_you 三条路径，**没有殿试路径**。
   - 出题用 `bitmap_font(word, 16)` 显示点阵汉字谜面；ex **没有点阵字库原语**，LPC 资源在 `mudcore/system/kernel/simul_efun/fonts/`（HZK16×9 + ASC16）。
4. **御前侍卫传送链**：LPC `ask_reward()` 成功时把玩家 + 自己 move 到 `/d/beijing/hg`，多段 `command("say")` + `message_vision`，再令自己返回 `startroom`。
   - ex 有 `TeleportService` / `Kantele.Character.Teleport`（两段 Movement），可复用；但本链是「玩家 + NPC 联动 + 台词顺序 + 回程」，需新切片。

---

## 3. LPC 原文语义（必须逐字保真）

### 3.1 御前侍卫 `ask_reward()`（`yuqian1.c:65-94`）

门序（`command("say")` 即 NPC 私聊回话；`message_vision` 房间广播）：

1. `me->query_condition("killer")` 为真 → `return 1`（**沉默**，无任何输出）。
2. `! find_object(INVASIOND) || ! INVASIOND->query("record")` → `say 如今并无异族联军入侵呀！`
3. `! INVASIOND->query("record/all_killed")` → `say 圣上并未恩准赏赐，尔等速速离去！`
4. `me->query("waidi/born_time") != INVASIOND->query("record/born_time")` → `say 你的赏赐已经过期了！`
5. `environment(me) == find_object("/d/beijing/hg")` → `say 你快快向皇上领赏吧！`
6. 否则成功链（顺序固定）：
   - `say 啊，原来是抗击异族联军的义士，快请快请！`
   - `say 在下这便带你入宫面见圣上！`
   - `message_vision(HIW "\n$N" HIW "大步地走进皇宫大殿，$n" HIW "紧随其后。\n\n" NOR)`（NPC=$N，玩家=$n）
   - `me->move("/d/beijing/hg")`、`this_object()->move("/d/beijing/hg")`
   - `say 好了，我带你到大殿了，你可以面见圣上领赏了。`
   - `message_vision("$N头也不回地离去了。\n")`
   - `this_object()->move(query("startroom"))`
   - `message_vision("$N急匆匆的走了过来。\n")`

### 3.2 康熙 `ask_reward()`（`kangxi.c:55-113`）

1. 随机抽词：`word = w[random(sizeof(w))]`，词池为 `kangxi.c:63-87` 的 200 个二字词（含重复项，必须**保留重复**，不可去重，否则改变随机权重）。
2. `environment(this_object()) != find_object("/d/beijing/hg")` → `say 怪哉，朕如何不在皇宫！` + `message_vision("$N急急忙忙地离开了。\n")` + NPC `move("/d/beijing/hg")` + `return 1`。（注意：此门在 invasion 门**之前**。）
3. 门 2/3/4 同御前侍卫，文案分别为：
   - `say 如今并无异族联军入侵呀！`
   - `say 朕并未恩准赏赐，尔等速速离去！`
   - `say 尔之赏赐已过期了！`
4. 成功链：
   - `say 原来是抗击异族联军的义士，不错不错！`
   - `say 朕一生最赏识的便是文武双全的能人志士，这位<RANK_D respect>杀敌勇猛，足见武艺出众，\n              但朕尚要出道殿试之题，看看你的文采若何。`（`\n` 为真实换行，14 空格缩进）
   - `say 你看看朕写的这两个是什么字？(可用answer xxx 作答)`
   - `me->set("waidi/word", word)`
   - `write(bitmap_font(word, 16) + "\n")`（点阵谜面，16 号随机字体）

### 3.3 康熙 `do_answer()`（`kangxi.c:115-196`）

门序：

1. `! me->query("waidi/word")` → `say 又没人给你出过题，你答什么答！`
2. invasion record 不存在 → `say 如今并无异族联军入侵呀！`
3. `! all_killed` → `say 朕并未恩准赏赐，尔等速速离去！`
4. `waidi/born_time != record/born_time` → `say 尔之赏赐已过期了！`
5. `! arg` → `say 你要回答什么?`
6. `waidi/word != arg` → 两段 say：
   - `say 可惜，这位<respect>虽然武艺出众,但是目不识丁，朕不能给你赏赐了。`
   - `say 你还是速速离去吧！`
   - `me->delete("waidi")`
7. 答对（奖励公式，必须保真）：
   - `pot = 100 * me->query("waidi/number") + random(300)`
   - `gn = me->query("waidi/number") + random(2)`；`if (gn > 10) gn = 10`
   - `reward = ob_list[random(sizeof(ob_list))]`，`ob_list`（`kangxi.c:121-140`，18 项，含重复）：`linghui1`×2、`lingzhi1`、`lingzhi2`、`full1`×2、`xuelian1`、`xuelian2`、`neili1`、`neili2`、`renshen1`、`renshen2`、`va1`…`va6`
   - `unit = ob->query("base_unit") || ob->query("unit")`
   - gold：`new("/clone/money/gold")` + `set_amount(gn)`
   - `me->add("potential", pot)`；`gold->move(me,1)`；`ob->move(me,1)`
   - `say 不错，不错，这位<respect>不但武艺出众,文采亦是不菲，朕要大大的赏赐于你。`
   - `message("invasion", HIR"【外敌入侵】"...)` 全服圣旨文案（`kangxi.c:186-191`，含 `chinese_number(pot)`、`chinese_number(gn)`、`ob->query("name")`、`<unit>`）
   - `me->delete("waidi")`

---

## 4. ex 落点与子切片（按依赖顺序，逐片检查→实现→定向验证）

> 每一片结束后都必须更新 `.workbuddy-ai/memory/2026-11-28.md` 与本计划状态；全部完成前 A-5-c 保持进行中。

### C1 — 入侵守护进程 record 查询与波次 `born_time`
- 落点：`lib/kantele/world/invasion.ex`（+ `lib/kantele/world/invasion/behaviour.ex` 如需）
- 实现：在 `start_wave/2` 置波次级 `born_time`（对齐 LPC `invasiond.c:25`），spawn 的 invader 共享该值；新增公开 `record/0`（或 `query/1`），返回 `%{exists :: boolean, all_killed, born_time, total_killed, wave_active, wave_number}`，进程不存在时安全返回 `exists: false`。
- 验证：`mix test` 相关 invasion 定向测试（若已有），新增 record 查询单元测试。

### C2 — 玩家 `waidi/*` 状态与击杀写入
- 落点：`lib/kantele/character.ex`（`meta.env[:waidi]` 说明）、`lib/kantele/character/events/combat_event.ex:743/1691`
- 实现：击杀入侵者时按 `invader.c:151-160` 写 `env[:waidi] = %{born_time: ..., number: n+1}`（跨波重置 number=1）。注意 `notify_invasion_killed/2` 当前无返回值、杀手为 killer map；需在杀手侧事件（`combat/enemy-died`）或 Invasion.on_died 回执里写入，保持不破坏现有击杀奖励链。
- 验证：构造击杀入侵者定向用例，断言杀手 `meta.env[:waidi]`。

### C3 — 点阵字库原语 `bitmap_font`（✅ 已完成，UTF-8 索引方案）
- 落点：`lib/kantele/world/bitmap_font.ex` + `priv/fonts/hzk16.pack`（UTF-8 码点索引 pack，9 变体 × 7478 字，2.4MB）+ `priv/fonts/asc16` + 一次性脚本 `scripts/build_hzk16_utf8_pack.py`。
- **方案（用户 2026-11-28 指定）**：ex 侧全程 UTF-8，**运行时零 GBK 换算**。GBK→码点换算在构建期由脚本完成（Python 权威 `gbk` codec 枚举 0xA1A1–0xF7FE 区位，`offset = 32 × ((b1−0xA1)×94 + (b2−0xA1))` 读 32 字节点阵），产出 `码点 → 位图` pack；ex 运行时按 UTF-8 字符直查。点阵字节与 LPC `read_buffer` 同源，仅索引方式从运行时算术变为构建期直查。
- 语义对齐：16 号（汉字 32B、scale=2）、`fill="8"`/`bg="-"`、位掩码展开、16 号九变体随机（`font:` 选项可固定）、缺字形返回 LPC 同款错误串。
- 验证：`scripts/build_hzk16_utf8_pack.py` 用 LPC 原算法（Python 复刻）生成期望值 `test/fixtures/bitmap_font/*.txt`；`mix test test/kantele/world/bitmap_font_test.exs` → 7 tests / 0 failures，其中 4 组「汉词/ASCII/混排 × 变体」与 LPC 算法输出**逐行一致**。

### C4 — 康熙 `ask_reward` 问询 + 殿试 `answer` 链
- 落点：新增 `lib/kantele/world/inquiry_handlers/beijing_reward.ex`（kind `beijing_reward`，profile `kangxi` / `yuqian1` 复用或分两 handler）、`lib/kantele/character/commands/answer_command.ex`（新增 `waidi/word` 殿试路径）
- 实现：按 §3.1–§3.3 保真门序、文案、随机权重、奖励公式、全服圣旨。respect 用 `Kantele.World.NpcActions.Helpers.respect/1`（已对齐 LPC rankd）；`chinese_number` 复用现有私有实现需提升为共享 helper 或在 handler 内复刻。
- 验证：每个门一个定向测试 + 成功链奖励/广播断言；词池长度与重复项断言。

### C5 — 御前侍卫传送链 ✅ 已完成（第 63 批）
- 落点：同 C4 handler（`profile: "yuqian"`）。
- 实现：门序逐字（killer condition 静默 return 1 → 无 record → 未全歼 → born_time 过期 → 已在皇宫 → 护送链）；护送 = 两段 say + vision（$N/$n → `{npc}`/`{name}`）+ 玩家 `Teleport.teleport(hg)` + 侍卫 `npc/goto`×2。LPC `query("startroom")` 未显式 set → 等价于侍卫当前房间，回程用问询时 npc_room_id（**无需补 UCL startroom 字段**，初判已修正）。
- 验证：6 tests（五门序含 killer 静默 + 护送全链 npc/goto 顺序断言）；dianshi 21 / 既有链 28 全过；**yuqian1 4 键回填后 `unimplemented` 全 data/world 计数 = 0（UG-03 清零）**。
- 残留（引擎级，另立 UG）：侍卫 `accept_fight` 的 `apply_condition("killer",500)`（ex 无 killer condition apply 方）；康熙入场语 init greet 机制；黄金数量字段。

### C6 — 奖励物品与 UCL 回填 + 收尾 ✅ 已完成（C4 第 62 批随带 + C5 第 63 批）
- 已完成：8 占位全部回填（康熙 4 键第 62 批、yuqian1 4 键第 63 批）；`clone_lib.ucl` 补 `va1`/`va4`/`gold` + 10 味丹药 `unit`（LPC base_unit）。
- 实现：物品定义以 LPC `clone/fam/pill/*` 与 `clone/fam/etc/va*` 为准，保 `base_unit` / `unit` / 名称；回填 8 键。
- 验证：`python scripts/validate_ucl.py data/world/beijing.ucl`（+ clone_lib 若改）、`mix compile`、C1–C5 全部定向测试；登记 `docs/待全量回归清单.zh-CN.md`，更新统一计划 A-5-c 状态与执行指针。

---

## 5. 风险与红线

- **不得简化**：不可用「如今并无异族联军入侵呀」单句替代整条门序；不可去掉点阵谜面；不可去重词池/ob_list。
- **不得自行全量回归 / commit / push**：全部子片完成后登记待全量回归，等授权。
- **随机语义**：词池、ob_list、字体变体、random(300)/random(2) 都必须保留随机与权重；测试用可注入随机或种子。
- **跨进程**：全服圣旨广播用 `Communication.announce("waidi", ...)`（与 `invasion.ex:388` 一致），断言看广播内容。
- **数据优先级**：`beijing.ucl` 与 `clone_lib.ucl` 谁实际加载需按统一计划 §1.2 确认；kangxi/yuqian1 在 `beijing.ucl` 有独立完整块，以 zone 块为准。

---

## 6. 变更记录

| 日期 | 变更 |
|---|---|
| 2026-11-28 | 初版：A-5-c 8 键审计完成，判定 REAL_GAP + NEEDS_DESIGN；拆 C1–C6 子片，记录 LPC 原文门序/文案/公式与 ex 四项基础设施缺口。 |
| 2026-11-28 | C1 完成（第 61 批前半）：Invasion 增波次级 `born_time` + 公开 `record/0|1` 查询；顺带修复 `pick_spawn_rooms/0` 元组匹配崩溃与 `start/stop_wave` 状态不回写两处既有 bug。4 tests / 0 failures。 |
| 2026-11-28 | C2 完成（第 61 批后半）：invader NPC meta 携带波次 born_time（invasiond.c:84 对齐）；击杀链 reward 增 `waidi_born_time`；`enemy_died/2` 新增 `apply_waidi_kill/2` 按 invader.c:151-160 写 `meta.env[:waidi]`（跨波重置/同波累加）。6 tests / 0 failures；flow_test+record 18 tests / 0 failures。C3–C6 待续。 |
| 2026-11-28 | C3 完成（第 61 批收尾）：点阵字库按用户指定改为 **UTF-8 索引 pack** 方案（ex 全程 UTF-8，运行时零 GBK 换算，换算在构建期脚本完成）；`priv/fonts/hzk16.pack`（9 变体 × 7478 字）+ `asc16`；`BitmapFont.render/3` 位掩码展开与 LPC 逐条对齐，4 组与 Python 复刻的 LPC 原算法输出逐行一致。7 tests / 0 failures。C4–C6 待续。 |
| 2026-11-28 | C4 完成（第 62 批）：康熙领赏问询（五门序逐字 + `npc/goto` NPC 自移原语）+ 殿试 answer 链（词池实测 **216** 项含重复、ob_list 18 项含重复、pot/gn 奖励公式、chinese_number 逐条移植、全服圣旨 waidi 广播）+ clone_lib 补 va1/va4/gold 与 10 味丹药 base_unit。dianshi 15 tests / 0 failures；answer+invasion+bitmap 29 tests / 0 failures。占位剩 4（yuqian1，C5）/ 全量 149。C5/C6 待续。 |
