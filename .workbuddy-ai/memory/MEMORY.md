# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Conventions (iron rules)
- **No `git commit`** unless explicitly asked. P6 housekeeping pending user approval.
- **No local Erlang** — Docker is the authoritative verify path:
  `docker exec -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test wuxia_mud_dev-app-1 sh -c "cd /app && mix test <path>"`
  Plain `mix test` fails (localhost:15432 unresolved in-container). Containers: `wuxia_mud_dev-app-1`, `wuxia_mud_dev-db-1`.
- **UCL (Elias parser)**: block members newline-separated, NO commas; bare keys (incl. Chinese); `newline=""`. **String escapes**: inside `"..."` only `\"`/`\'` and `\`+word (`\n`/`\t`) are legal; **`\\` is a syntax error**; **real newline in string is a syntax error**. Encode order: escape backslash/quote FIRST, then newline→`\n`. **Arrays**: comma-separated, NO trailing comma. Illegal in `"..."`: `[` `]` `;`. `validate_ucl.py` enforces `EliasStrings`.
- **Markdown 表格（`docs/*.md`）**：code span 内 `|` **必须转义 `\|`**（GFM 静默丢内容）；表格行间**不留空行**；写完按"表头列数逐行比对"自检（`re.split(r"(?<!\\)\|", row)`）。
- **Backfill discipline (G1–G8)**: dry-run → backup `tmp/backup-<name>-<TS>/<zone>.ucl` → apply (`newline=""`) → `validate_ucl.py` green → idempotent re-run = 0 pending.

## 动态出口消费端 — 全部 DONE（注册表 92 房，`do_*` verb 已清零）
P5-4ae(6)/4ag(5)/4ah(10,do_break)/4aj(8,do_push)/4ak(2,do_open/close)/4al(6,do_knock/pull)/4am(8,触发器)/4an(11,do_move+push)/4ap(6,shenfeng+panlong) 均绿。共享原语：`dynamic_exit.ex`（open/close/close_after/cancel_close；TRef 是 tuple `{:ok,{:once,ref}}`，`is_reference/1` 守卫使 cancel 变 no-op）、`break.ex`（`unconcious/1` 不清内力、`pass_out/1` 清零+昏厥）、`push.ex`、`knock_pull.ex`、`trigger.ex`、`move_stone.ex`（含 `room_temp`/`busy?`/`start_busy`）。Test 全集：`test/kantele/world/`=**1378/0**；full `mix test`=**4443/0**（post P5-4ap）。
- **跳过/延后**：`shaolin:zhonglou1`(add_action 被注释死代码)、`room:panlong:*` 原 LPC 三房仅 qianting/zoudao 各 2 条（huayuan=do_sit、shufang=do_sign 注释）→ 已移植；`huanggong:shufang`(press desk 目标房不存在)。
- **勘误（survey 假阳性 ×3）**：`do_wang`「48」是调用点数非房间数；`room:panlong:*`「9」实为 2+2；survey 房号按文件名生成（`quanzhen:fu-woshi`≠真实`fu_woshi`）。**survey 计数须逐房 grep `add_action` 复核。**

## 地形穿行 `TerrainMove` (P5-4aq-A, DONE 32/0)
`lib/kantele/world/room_actions/terrain_move.ex` 数据驱动，`@terrain` 按 `{room_id, 归一化动词}` 索 12 verb-handler。verb 别名 pa→climb/tiao→jump/you→swim；守卫 busy/fighting；qi(<100→unconcious)/dodge(`:raw` shuiliandong<60/<140, `:effective` eyutan>120) 门控分支，fail 时 unconcious；room/target `broadcast_vision`(含 `exclude_actor`)+玩家 `write`。11 房注册：`hengyang:{outzhushendong,outzigai,shuiliandong,xuanyadi}` + `jueqing:{eyutan1,eyutan2,eyutan3,ontree1,ontree3,undertan,underya2}`。UCL `actions` 经 `backfill_array_form_actions.py --apply` 回填（备份 `scripts/tmp/backup-array-actions-20261023-005922/`）。原延后的 4 硬房已由 P5-4aq-B 补齐（见下节）；`jueqing:zhifang` 为 `add_action` 注释死代码（假阳性）。

## 绝情谷 4 硬房 (P5-4aq-B, DONE 44/0)
`lib/kantele/world/room_actions/jueqing/{duanchang,underya,xiangfang1,jianshi}.ex`，注册表 4 房 9 handler。**关键原语**：LPC `call_out` 延时移动/昏厥玩家复用既有 `trap/effect` 事件（`lib/kantele/character/events/trap_event.ex`，按角色 pid 下发 `:force_move`/`:faint`/`:delete_temp`/`:text`）——`:timer.apply_after` 回调无 `conn`，`Teleport.teleport/2` 无 by-id 变体，这是唯一安全的按 pid 副作用通道。`duanchang`: do_jump 两步（temp `marks/跳` 确认）→ random(6)+6s 落 underya+faint。`underya`: do_bao(temp `marks/抱`)/do_climb(瞬移 jueqing)/do_jump(`tiao` 已置 no-op；抱石→underya2；未抱石→置 `tiao`+6s 冲回)。`xiangfang1`: do_turn 房间 state `marks/转` 开关洞口（LPC `set("long",...)` 无等价物→广播近似）；do_jump 须已开→random(4)+3s 落 eyutan2（回调 `Room.tell_room` 向 eyutan1 播报**直嵌角色名**，tell_room 不做 `{npc}` 归一）；**未做** `remove_call_out`（timer ref 进 meta.temp 有序列化风险，多定时器均落 eyutan2 幂等）。`jianshi`: do_pull state `marks/拉`；do_pick 门控 `marks/拉`（LPC `marks/君`/`marks/女` 死代码），`Items.get`+`Helpers.give_item/3` 实例化 `junzijian`/`shunvjian`，taken 用房间 state 防重复取。测试 44/0（4 模块 37 + registry 7）。

## 拱猪子系统 (P5-4ad, wired)
`Kantele.World.PigGame`(pure fns)+`RoomActions.City.PigRoom`(verb dispatch/land)+`Character.PigEvent`(lands `temp["pigging_seat"]`)。Cards 0..51(`suit=div(card,13)`,`rank=rem(card,13)`); special `SPIG=10 HACE=25 DSHEEP=35 CTRANS=47`. `sell` 全局命令冲突已修（仅 seated 时算 sell）。`look` 键 `"pig_table"`/`"pig_scoreboard"`。剩余 fidelity：same-IP 不共享桌；`pig_played`/`pig_score`/`pig_head` temps；`improve_skill("feed-power")`。

## Inquiry system
- `ask_skill`(no kind)→`SectMaster.inquiry_grant/3`→`Stats.learn_perform/2`(扣 gongxian)。`ask_me*`→kind="give_item"→`InquiryHandlers.GiveItem`。
- **shen 缺口已修**(P5-4ap)：`SectMaster` 支持 `max_shen`(`shen>max_shen`→拒)、`min_shen` 缺省不拦；`GiveItem` 加 `max_shen`/`min_combat_exp`/`max_skill_levels` 三门控+deny 文案；`Loader` 加 `normalize_inquiry_field("max_skill_levels",...)`. `wudu.ucl` 3 处 `min_shen=-999999999` sentinel 改 `max_shen=-20000/-35000/-40000`。
- **太极图缺口已修**(P5-4ar)：新增 kind=`counter_perform` + `InquiryHandlers.CounterPerform`（计数器式渐进授招，`can_perform/...` 存 `meta.marks` 持久化）。全库仅 `kungfu/class/wudang/zhang.c ask_skill6` 用该模式；loader 加 `level_deny` 键归一；`wudang.ucl` 张三丰「太极图」改走该 kind。测试 15/0（含整库加载端到端）。
- **问询闭合度 survey + 两批回填：P5-4at 已完成**。`scripts/survey_inquiry_closures.py` 全库扫 LPC `set("inquiry")` 与 Elixir UCL `inquiries` 逐键比对（产出 `tmp/inquiry_survey.json`）；`scripts/backfill_inquiry_strings.py` 纯字符串回填（dry-run/`--apply`/备份/幂等）。survey 修 5 个自身 bug（非贪婪正则→花括号配平、跨区键撞车加区名背书、CLASS_D 区别名 38 项、同区同名歧义文件名键优先、块末条漏计加 `\s*$`）。两批共回填 **68 键 / 17 NPC**：第一批 `ask_skillN` 绝招 + give_item（任我行5/无尘3/宝象1/胜谛1/齐云敖3+毒经中篇+平四4），引擎加 `min_max_neili` 门控与 7 个 `*_deny` 文案键；第二批纯字符串 55 键/12 NPC（封不平4/劳德诺2/张淡月5/齐云敖5/石破天6/南贤2/武修文2/苗人凤4/黄药师13/商剑鸣1/干将5/莫邪4）。`test/kantele/world/`+sect_master 回归 **1477/0**。
- **已知缺口（survey 现状）**：剩余 **92 键 / 11 NPC，全为闭包**（需逐 NPC 读 LPC 移植），**text-backfillable 0**。黄药师21/莫邪24/苗人凤15/商剑鸣9/干将5/张三丰5(太极图 prerequisite 已走 counter_perform)/桑三娘4/平四3(传送服务有意不回填)/刘处玄2/青阳子2/lingxiao:cheng2(LPC 缺陷)。另有 14 文件 NPC 未移植。⚠️ clone_lib 重复内联（如 `taohua:dating` 同时引区副本 `huangyaoshi` 与 clone_lib `taohua_huang`），移植闭包须落在玩家真正碰到的那份并去重。

## Backlog（下一步）
- **LPC `add_action` array 形式 `({"v1","v2"})` UCL 回填：已全部完成**。全库核查 26 处：P5-4aq-A 地形 11 房（TerrainMove）+ `hengyang:xuanya`/`inzhushendong`（既有 actions 块）+ `jueqing:duanchang/underya/xiangfang1/jianshi`（P5-4aq-B 批 `--apply` 回填，备份 `scripts/tmp/backup-array-actions-20261023-011217/`）+ `jueqing:zhifang`/`shaolin:zhonglou1` 为 `add_action` 注释死代码（假阳性，跳过）。幂等重跑全跳过、`validate_ucl` 干净。
- **消费端 handler（4 间硬房）：P5-4aq-B 已完成**（见上节，44/0）。array-form 回填 + 硬房消费端整条线清零。
- **太极图 counter_perform：P5-4ar 已完成**（见上节，15/0）。
- **问询闭合度 survey + 两批回填：P5-4at 已完成**（见上节，68 键/17 NPC，回归 1477/0）。
- **survey 遗留（下一步）**：剩余 92 键/11 NPC 全为闭包，需逐 NPC 读 LPC 移植（黄药师21/莫邪24/苗人凤15/商剑鸣9/干将5/张三丰5/桑三娘4/平四3有意跳过/刘处玄2/青阳子2/lingxiao:cheng2 LPC缺陷）；14 文件 NPC 未移植。另：P5-9 smith job/working 链；P5-3/P5-8 动态 spawn（lingshezhang/shezhang/meng-zhu）。

## Test gotchas
- **`:global` name race**: 不重复 stop/start 同名进程；`setup_all` 注册一次 + 每测试 `reset/1`(清 exits/state + cancel `exit_timer:*`)。
- **FakeRoom + 唯一房号模式**（putiyuan/jianzhong/xiangfang1/jianshi）：`start_supervised!({FakeRoom, {room_id, []}})`，房号 `"#{@room}:test#{System.unique_integer([:positive])}"`。⚠️ 唯一房号**不在** `@registry`，故这类用例**直接调 `Module.run/2` 显式传 room_id**（绕开 dispatcher 查找）；要走 dispatcher 的用例房号必须是注册表真实 id。
- **延时回调测试**：`:timer.apply_after` 回调按 pid 发事件，测试字符须 `pid: self()`（否则 `is_pid` 守卫 FunctionClauseError 炸 timer 进程）；消息落测试进程邮箱无人读取，无害。
- **Duplicate def**: Elixir 同名同参只匹配首条 → 静默错配；勿重复 `defp cfg/0`。
- **conn 复用**: `conn.private.channel_changes` 累积，断言 `published` 取 `List.last` 或逐次新建 conn。`Helpers.broadcast_vision/4` 归一 `$N`→`{npc}`，断言用 `{npc}`。`Room.exits` 是 `%Exit{}` list。
- **`Helpers.give_item/3`** 收 `conn`，不能塞进 pipeline 当中转（`|> give_item(item)` 会缺参）；`broadcast_vision` 返回 conn 可续 pipe。
- **`setup_all` 不能放 `describe` 内**（ExUnit 编译错）；**`world.characters` 的角色 `id` 是加载时生成的哈希**（非 UCL key），定位按 `name` + `room_id`；`NpcActions.Helpers.say/4` 是房间广播（"NPC说道："），不在 `conn.output`，断言去 `channel_changes` 的 `rooms:` 发布里找。
- **字母序**: 手插位置易错，**直接从注册表输出重排整块字面量**（如 `room_action_handlers_test.exs` 的 sorted list）。
