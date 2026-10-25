# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- No `git commit` unless explicitly asked. **2026-10-21~24 用户已通过简短指令批准并分批提交，P5-1c~P5-9 代码全部已落库；#9 六切片（casino ×2 / banquet / qiyuan / loveroom order / chaoyang，commit `e515b04d`）已落库；P5-5 丹药子系统、P5-8 on_board、P5-6 门容器批、R23/R24 修复仍待 `git commit` 批准（~10+ 文件）**；memory 各日志里「未提交待批准」仅对当时成立，勿再当作现状。
- No local Erlang — Docker is the verify path:
  `docker exec -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test wuxia_mud_dev-app-1 sh -c "cd /app && mix test <path>"`
  （URL 必须整串引号，否则丢 `//`。）
  **全量回归优先分块跑**（2026-10-25：本机 Docker Desktop 引擎三次在 7~9 分钟处宕机杀掉单次整库跑，
  app 容器 `Exited (255)`）：`find test -name '*_test.exs' | grep -v reload_command_test | sort > /tmp/all_files.txt
  && split -n l/4 -d /tmp/all_files.txt /tmp/chunk_`，再逐块 `mix test $(cat /tmp/chunk_XX | tr '\n' ' ')`。
- UCL (Elias): blocks newline-separated, NO commas, bare keys (incl. Chinese), `newline=""`. In `"..."` only `\"`/`\'` and `\`+word legal; `\\` syntax error; real newline syntax error. Arrays comma-separated, NO trailing comma. `validate_ucl.py` enforces `EliasStrings`.
- clone_lib 去重铁律：NPC 有 clone_lib 主定义者，数据必须落 clone_lib；zone 同名块会被按名合并覆盖（写 zone 必被 shadow）。
- Handler 回调：`run(conn, params)` 返回 `:not_handled` 放弃（分发器丢弃 conn，输出会丢）；需向玩家送达提示时**必须返回 conn**（分发器按 `{:handled, conn}` 送达 output）。`Family.name(nil)` 会崩，`family_ok?` 须 `is_map` 守卫。

## Completed work (tests green)
- 动态出口消费端：92 房，`do_*` verb 清零。`test/kantele/world/`=1378/0；full `mix test`=4443/0。
- TerrainMove (P5-4aq-A)：32/0，11 房。
- 绝情谷 4 硬房 (P5-4aq-B)：4 房 9 handler，44/0。
- 拱猪子系统 (P5-4ad)：wired。
- Inquiry：shen 门控 (P5-4ap)；太极图 counter_perform (P5-4ar, 15/0)；两批回填 68 键/17 NPC (P5-4at, 1477/0)；苗人凤 10 绝招+5 给物 (0 缺失)；桑三娘+刘处玄 (P5-4av, 1483/0)；商剑鸣 7 绝招 (P5-4aw, 1412/0)。全量回归 1483/0。
- pingsi 传送服务 (kind="teleport_service")：`guanwai.ucl` 3 entry，test 已更新。
- survey `resolve()` 修正：baseline 现 5 键/2 NPC（text-backfillable 0）：`lingxiao:cheng` 2（LPC 目标缺失，skip）+`hu:平四` 3（teleport_service 已回填）。
- **P5-3/P5-8 动态 spawn（DONE）**：`lingshezhang`/`shezhang` `convert`→spawn `lingshe`/`snake`；蛇 `bian`→还原法杖。
  - UCL `baituo.ucl`：`lingshezhang`→`convert_lingshe`，`shezhang`→`convert_snake` ✅（validate 绿）。
  - `lib/.../item_actions/convert_bian.ex` ✅：编译修（`&:not_handled` 非法、piped render 三元、`family_ok?` nil-safe）；`build_npc/3` 带 `zone_id`+`initial_events: []`；zone 从 `room_id` 推导（`split(":") |> hd()`）。
  - `lib/.../npc_actions/convert_bian.ex` ✅（`broadcast_vision`；`bian` 全局兜底）。
  - `item_action_handlers.ex` / `npc_action_handlers.ex` 已注册 ✅。
  - 测试三件套 **15/0**：`item_actions_convert_bian_test.exs`(8) + `npc_actions_convert_bian_test.exs`(6) + `integration_convert_spawn_test.exs`(1)。
  - `test/kantele/world/` 整库 **1427/0**，无回归。
- **P5-5 effect/invocation 数据驱动丹药子系统（DONE）**：`do_effect` 15 丹药数据驱动（`invocation` 18 战斗驱动出范围）。
  - `lib/.../item/effect/pill.ex`：`Pill.plan/2`（冷却/满状态/非pill/放行）+ `apply_cooldown/2`（戳 `PlayerMeta.pill_cooldowns[key]`）+ `apply_busy/2`（`Combat.start_busy`）；治愈数学委托既有 `Effect.consume/3`（读 `meta.medicine` 的 `@restorable` qi/jing/neili）。
  - `lib/.../character/commands/eat_command.ex`：`pill?`→`Pill.plan`→`Effect.consume`→`apply_cooldown`/`apply_busy`→掉实例→`render_actor_vision`（含 `self_text`，`{npc}`→`你`）→广播。
  - `lib/.../character.ex`：`PlayerMeta` 加 `:pill_cooldowns`；`lib/.../world/item.ex`：`Item.Meta` 加 `:effect`；`lib/.../world/loader.ex`：`parse_item_meta` 读 `meta.effect`。
  - 回填脚本 `scripts/backfill_pill_effects.py --apply`：6 UCL 文件 15 丹药（beijing 10 / city / lingjiu / shaolin / xueshan / yanziwu），`validate_ucl.py` 全过。
  - 测试：`pill_test.exs`(11) + `eat_command_test.exs` 集成(4) + `pill_backfill_test.exs`(3) = 18 新；回归 `test/kantele/item/` 113/0、character eat/drink 26/0，全绿。
  - 余 `do_effect` 53 项（解毒/毒/永久加属性 `add("max_*")`/`potential`）无引擎模型 → §11 免实现；原文档「108 行 / 2 名」为复制粘贴误植（真实 `do_effect`=68 + `invocation`=18）。**代码+文档均待 `git commit` 批准**。
- **P5-9 smith job/working 链（DONE）**：襄阳铁匠 `xiangyang:tiejiangpu`。
  - `lib/.../npc_actions/smith.ex`：gu/dapi/cuihuo（busy 守卫→未领活斥责广播→reward：工钱入 `meta.coins` + 经验/潜能 `Stats.improve_potential` + `mark/job_smith` + 掉气 + `Combat.start_busy(3)`）+ repair/xiuli 两段确认链（consistence 在实例 `meta`，世界数据无一定位恒走「似乎不需要在这里修理吧？」忠实分支）。
  - `lib/.../inquiry_handlers/smith_job.ex`（kind="smith_job"）：ask_me 判定链 + random(3) 派活写 `smith/*` temp。
  - UCL：smith inquiries 占位改 map（job/工作 kind=smith_job）+ add_actions 五连。
  - 顺修 719700be 数据 bug：liumang 缺 `}` + 尾部多 `}`（相抵致 mujiang 被 elias 吞掉、validate 红）；修复后 validate ✅、mujiang 恢复。
  - 测试：`npc_actions_smith_test.exs`(23) + `inquiry_handlers_smith_job_test.exs`(12) + handlers 注册表(26 房)。
- **P5-8 `on_board` 定时载具（DONE，半条 #8）**：heimuya 吊篮（up2→basket→up3 / up3→basket→up4）+ guiyun 渡船（taihu↔matou via duchuan）。
  - `lib/.../world/room_actions/vehicle.ex`：共享原语 `check_trigger/3` + `on_board/2` + `arrive/2` + `close_passage/2` + `schedule/cancel`（`:timer.apply_after`，tref 存房间 state 等价 remove_call_out）。复用 `Room.set_exit/delete_exit/has_exit_by_id?/tell_room/put_state_by_id/get_state_by_id/delete_state_by_id`（同 DynamicExit 的 `:sys.replace_state` 通道）。
  - `lib/.../world/room_actions/vehicle_trigger.ex`：`use RoomAction` 数据驱动，4 触发房按 room_id 查配置（文案逐字取自 LPC up2.c/up3.c/taihu.c/matou.c），`run/2` → `Vehicle.check_trigger`；附 `config/1` 供测试取真配置。
  - 注册表 `room_action_handlers.ex`：4 房 verb 绑定（heimuya:up2/up3 do_insert；guiyun:taihu/matou do_yell/do_cross/do_shang）。UCL 已由转换器写出 `actions` 块，无需改 UCL。
  - 测试 `test/kantele/world/room_actions_vehicle_test.exs` **14/0**（注册表 + 触发链路 + on_board/arrive/close_passage 三回调直接单元 + already/busy 门控）；room_actions 子集回归 **500/0**。
  - **未提交，待 `git commit` 批准**。#8 另一半 `relay_emote`（NPC 对玩家社交动词表情回应，city tao1–6、huashan lao-denuo）需新引擎 hook，待建。
- **P5-9 #9 一次性场景（DONE 6 切片，2026-10-25 全绿）**：
  - 赌场 `city:bet` + 长安大堂 `changan:duchang`（复用 `City.Bet`，`changan:duchang2` 是 LPC 禁用桩**刻意不注册**）：`casino.ex` 纯逻辑 + `room_actions/city/bet.ex` + `events/casino_payout_event.ex`；测试 30/0。
  - 宴席 `city:furong`/`meigui`/`mudan`：`room_actions/banquet.ex`（`do_order` 三档 20000/30000/查50000付**40000**（LPC 查付不一致忠实保留）+ `do_broadcast`）；18/0。
  - 棋苑 `city:qiyuan2/3/4`：`world/weiqi.ex` 纯引擎（`new_game`/`translate`/`play`/`undo`/`render`，胜则 `status=not_playing` 且不换手）+ `room_actions/city/qiyuan.ex`（7 动词）；`weiqi_test` 21/0 + `room_actions_city_qiyuan_test` 44/0。
  - 杭州楼外楼 `hangzhou:loveroom`：`room_actions/hangzhou/loveroom/order.ex`（`do_order` 单档 20000，owner 检测 + `meta.coins -= 20000` + `Room.put_state_by_id` + `broadcast_vision`；`order end` 清状态并广播）；`room_action_handlers` 注册 `do_order`；测试 11/0。
  - 华山朝阳 `huashan:chaoyang`：`room_actions/huashan/chaoyang.ex`（`do_la` 拉青藤设 `temp.la_teng_huashan`，`do_jump` 跳崖死亡路径）；测试 27/0；`room_action*` 回归 630/0。
  - **两处 LPC 怪癖勿「修正」**：① `do_undo` 的「上一步」文案取**悔棋前**的 `turn` 色（先判后翻），与 `do_refresh` 取**对方**色的写法相反；② `do_new` 轮次文案的 `$N` 指「轮到的一方」而非行动者 → 本引擎只能定位行动者，故直写玩家名。
  - 共同缺口（已写各自 moduledoc）：`valid_leave` 移动命令侧未接线；`Room.move_object/2` 空实现（宴席物品不入房）；`check_players` 3s 掉线清座未起定时器。
  - **跳崖类死亡路径的三个坑**：① `PlayerMeta.combat` 无默认值 → 必须 `|| %Combat{}`；② `Stats.query_dex/1` 内部 `Map.get(stats.skills, ...)`，`skills` 为 nil 会 BadMapError；③ `Damage.die` 末尾 `clear_die_flags` 删 `die_reason` + `move_to_death_room` 改 `room_id` → 不能断言「死在原地」或 die_reason 留存，只能断言 `qi==1 && jing==1 && damage.ghost && room_id != 目标`，且测试 id 须 `player:` 前缀。
  - `beijing:pavillion` 经核实**无 `add_action`**，旧文档误列，已剔除。

## Test gotchas
- **「无值返回 nil」的函数，调用点必须判空**（R24，2026-10-25 线上实击）：`%{map | key: f(x)}` 会把 nil
  顺手灌进字段；`Conn.Text.data` 是 list，混入 nil 编译期/渲染期都不报，只在
  `Kalevala.Output.Tags.parse_string/4` 才 FunctionClauseError → cowboy websocket 进程退出、玩家掉线。
  **新原语必须连调用点一起测**（`long_description/1` 单测只断言「无 long 返回 nil」反而把坏契约锁死，
  让 4653/0 的全量回归漏掉了它）。写视图/事件类回归时，**把渲染结果喂给 `Kalevala.Output.Tags`**。
- `Room.LookEvent` 已补首个测试 `test/kantele/world/room_look_event_test.exs`（4/0，`async: false`，
  `Loader.load()` + `ZoneCache.cache` 播 zone + 手搓 `%Context{}`）；改 look/房述链路时跑它。
- `:global` name race：`setup_all` 注册一次 + 每测试 `reset/1`。
- FakeRoom：唯一房号 `System.unique_integer`，直接调 `Module.run/2` 显式传 room_id。
- 延时回调：测试字符须 `pid: self()`（否则 `is_pid` 守卫 FunctionClauseError）。
- conn 复用：`channel_changes` 累积，断言取 `List.last` 或逐次新建 conn。
- `Helpers.give_item/3` 收 `conn`，不能 pipeline。
- 结构体在 `Kantele.*`（`Zone`/`MiniMap`/`Room`）；`Room` 双模块：`Kalevala.World.Room`(GenServer) + `Kantele.World.Room`(callback)。
- `Kalevala.World.Room.start_link` 收 **map**（含 `genserver_options` 键），keyword list → `:badarg`。
- spawn 集成测（仿 `mirror_zixu_spawn_test.exs`）：自建 zone+Room+CharacterSupervisor → `start_character` → `Process.sleep(400)` → 查 `Kantele.Communication.subscribers("rooms:<id>")`。
- 此环境 `Enum.none?/2` 报 undefined → 用 `not Enum.any?/2`。
- `put_character/2` 返回新 conn，断言须取 handler 返回值。
- `Kalevala.World.Item` 无 `:value`/`:unit` 字段——在 `item.meta["value"]/["unit"]`；测试实例可直挂 `item:` 绕开缓存。
- `prompt(...)` 渲染条目 data 非 iodata → 测试输出须过滤 `%Conn.Text{}` + `IO.iodata_to_binary`。
- **Elixir `0` 是 truthy，LPC `query_temp` 的 0 是假**——「恰好派了一个活」类断言须显式排除 0/false/nil/""。

## Next steps (backlog)
- **P5-5 代码+文档均待 `git commit` 批准**（归 ~29 pending files）。
- 剩余 P5 子系统：#8 `on_board` 定时载具已落地（`relay_emote` 半条待建，需新引擎 hook）、#9 一次性场景（8 区 `room_actions/` 已建，其余逐房待建）。
- **14 NPC-absent 文件**：out of scope。
- **ucl-comment-todo 已清空（2026-10-24）**：B（guarded_exit 16 房，`check_guarders`+`Guarder.permit_pass`）、C（18 条自定义函数走 `Kantele.World.Trap` 副作用通道）、D（gender migration `20261003000000` + `meta.env` 写入）、E（P5-4a/P5-9）、F（city:mudren enter 正式免除）、G（两份文档已同步为「计划 vs 实际」）均已完成/决议。
- **#7 学徒/门派早已落地（2026-10-24 核实，勿重复实现）**：`NpcFamilyEvent.apprentice`（npc_shop_event.ex L140）+ `FamilyEvent.result` + `SectMaster.recruit_gate?/3` 全链，`f3_sect_master_e2e_test.exs` 15/0。数据仅 `signature.ucl` 俞莲舟 1 处配 `apprentice`；其余 17 处 teach 无配置（LPC `kungfu/class/**` 不在语料，§11 exempt，min 全 0 恒过不误拦）。
- **#6 门/容器已完结（2026-10-24 深夜，勿再当缺口）**：36 房 door verbs 全部落地——收尾批做了 5 `do_knock`（`guanwai:jingxiu`/`huashan:xiaolu2` 共用 `RoomActions.RestKnock`；`hengyang:liufugate`；`shaolin:zhonglou7`；`yanziwu:lanyue` 暗语链 knock+say 均已落地）+ 2 `do_open`（`tiezhang:mishi`/`wudu:mishi`）+ 2 `do_break`（`yanziwu:tingyu`/`tulong:boat2`），P5 进度 6/9。新原语：`Helpers.carried_item/2`、`Room.long_description/1`（房 state `"long"` 覆盖静态 description）。**注册表铁律**：新 verb 要合并进该房已有 `%{verb => handler}` 条目；另起同名 key 会 `will be overridden` 告警并丢掉原 verb。另修 4 个引擎 bug：`Damage.ghost?` KeyError（玩家首死必崩）、`process_death`/`handle_unconcious` 的 `if` 块重绑定不外泄、`liufugate` `do_push` 恒锁（读 `temp["marks"]` 而 knock 写 `marks/liufu`）。
- **进度文档已大补写（2026-10-24）**：`docs/data-world-comments-progress.zh-CN.md` §13 补 14 行（10-23/24 全批次）、看板/M9/§9/§10/§11/§12(+D25/D26)/§14(+R21/R22) 同步更新；该文档是「唯一记录做到哪了」的文件，**每完成批次必须回填它**（§0 四件事）。

## Current focus
P5-9 #9 一次性场景 **6 个切片全部完成**（赌场 ×2 / 长安大堂 / 宴席三厅 / 棋苑三室 / 杭州楼外楼 order / 华山朝阳 chaoyang），P5 进度 **9/9**；整体约 **92%**。
`room_action*` 全集 **638/0**（586 + 棋苑 44 + loveroom 11 + chaoyang 27 + lanyue say 8）；`weiqi_test` 21/0。
#9 已无剩余切片，全部落库并验证绿。
**R24（2026-10-25 已修）**：P5-6 批的 `Room.LookEvent` 房述覆盖把 `nil` 写进 `room.description` → 每次 `look` 都
`parse_string/4` FunctionClauseError、websocket 掉线（bot 实击 4 次）。已改「仅非空 binary 才覆盖」+ 补
`room_look_event_test.exs` 4/0（revert 后 3/4 红，与线上报错逐字相同）。容器重启后 `grant` 重连零崩溃。
剩余：P3 五个等框架字段、37 个非 ask_* 闭包、R21 clone_lib 同名同房排查。
下一步：等待用户批准 `git commit`（**~10+ 待提交文件**：lanyue say 源码+测试+注册表 + P5-5 丹药子系统 + P5-8 on_board + P5-6 门容器批 + R23/R24 修复 + docs 与 memory 回填）。#9 六切片已全部落库（e515b04d）。
