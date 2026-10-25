# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- No `git commit` unless explicitly asked. **2026-10-21~24 用户已通过简短指令（items/remove/envs/board/connect/fix/exit/npc_script_event.ex/cl/c）批准并分批提交，P5-1c~P5-9 代码全部已落库（最新 `beda630e`）**；memory 各日志里「未提交待批准」仅对当时成立，勿再当作现状。文档类改动仍未提交。
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
- **P5-9 smith job/working 链（DONE）**：襄阳铁匠 `xiangyang:tiejiangpu`。
  - `lib/.../npc_actions/smith.ex`：gu/dapi/cuihuo（busy 守卫→未领活斥责广播→reward：工钱入 `meta.coins` + 经验/潜能 `Stats.improve_potential` + `mark/job_smith` + 掉气 + `Combat.start_busy(3)`）+ repair/xiuli 两段确认链（consistence 在实例 `meta`，世界数据无一定位恒走「似乎不需要在这里修理吧？」忠实分支）。
  - `lib/.../inquiry_handlers/smith_job.ex`（kind="smith_job"）：ask_me 判定链 + random(3) 派活写 `smith/*` temp。
  - UCL：smith inquiries 占位改 map（job/工作 kind=smith_job）+ add_actions 五连。
  - 顺修 719700be 数据 bug：liumang 缺 `}` + 尾部多 `}`（相抵致 mujiang 被 elias 吞掉、validate 红）；修复后 validate ✅、mujiang 恢复。
  - 测试：`npc_actions_smith_test.exs`(23) + `inquiry_handlers_smith_job_test.exs`(12) + handlers 注册表(26 房)。

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
- **14 NPC-absent 文件**：out of scope。
- **ucl-comment-todo 已清空（2026-10-24）**：B（guarded_exit 16 房，`check_guarders`+`Guarder.permit_pass`）、C（18 条自定义函数走 `Kantele.World.Trap` 副作用通道）、D（gender migration `20261003000000` + `meta.env` 写入）、E（P5-4a/P5-9）、F（city:mudren enter 正式免除）、G（两份文档已同步为「计划 vs 实际」）均已完成/决议。
- **#7 学徒/门派早已落地（2026-10-24 核实，勿重复实现）**：`NpcFamilyEvent.apprentice`（npc_shop_event.ex L140）+ `FamilyEvent.result` + `SectMaster.recruit_gate?/3` 全链，`f3_sect_master_e2e_test.exs` 15/0。数据仅 `signature.ucl` 俞莲舟 1 处配 `apprentice`；其余 17 处 teach 无配置（LPC `kungfu/class/**` 不在语料，§11 exempt，min 全 0 恒过不误拦）。
- **#6 门/容器已完结（2026-10-24 深夜，勿再当缺口）**：36 房 door verbs 全部落地——收尾批做了 5 `do_knock`（`guanwai:jingxiu`/`huashan:xiaolu2` 共用 `RoomActions.RestKnock`；`hengyang:liufugate`；`shaolin:zhonglou7`；`yanziwu:lanyue` 暗语链）+ 2 `do_open`（`tiezhang:mishi`/`wudu:mishi`）+ 2 `do_break`（`yanziwu:tingyu`/`tulong:boat2`），P5 进度 6/9。新原语：`Helpers.carried_item/2`、`Room.long_description/1`（房 state `"long"` 覆盖静态 description）。**注册表铁律**：新 verb 要合并进该房已有 `%{verb => handler}` 条目；另起同名 key 会 `will be overridden` 告警并丢掉原 verb。另修 4 个引擎 bug：`Damage.ghost?` KeyError（玩家首死必崩）、`process_death`/`handle_unconcious` 的 `if` 块重绑定不外泄、`liufugate` `do_push` 恒锁（读 `temp["marks"]` 而 knock 写 `marks/liufu`）。
- **进度文档已大补写（2026-10-24）**：`docs/data-world-comments-progress.zh-CN.md` §13 补 14 行（10-23/24 全批次）、看板/M9/§9/§10/§11/§12(+D25/D26)/§14(+R21/R22) 同步更新；该文档是「唯一记录做到哪了」的文件，**每完成批次必须回填它**（§0 四件事）。

## Current focus
P5-6 门/容器收尾批完成（2026-10-24 深夜落地，2026-10-25 full suite 定论）：9 缺口清零，36 房 door verbs 完结，P5 进度 **6/9**；整体约 **88%**。
full `mix test` **4660 tests / 0 failures**（2026-10-25 R24 修复后分 4 块跑：1302+606+1417+1332=4657，排除 reload_command_test）+ `reload_command_test` 隔离 **3/0**；R22 recompile flaky 族零残留。
**R24（2026-10-25 已修）**：P5-6 批的 `Room.LookEvent` 房述覆盖把 `nil` 写进 `room.description` → 每次 `look` 都
`parse_string/4` FunctionClauseError、websocket 掉线（bot 实击 4 次）。已改「仅非空 binary 才覆盖」+ 补
`room_look_event_test.exs` 4/0（revert 后 3/4 红，与线上报错逐字相同）。容器重启后 `grant` 重连零崩溃。
剩余：#5 effect/invocation、#8 通信中继·载具、#9 一次性场景（246 名/8 区已建）、P3 五个等框架字段、
37 个非 ask_* 闭包、R21 clone_lib 同名同房排查、`yanziwu:lanyue` 的 `whisper`（do_say，答「光复大燕」进 huanshi，非 door verb 批次）。
下一步：接 #8 通信中继·载具（规模较大）或取得 `git commit` 批准（P5-6 批 + R23/R24 共 ~31 个文件待提交）。
