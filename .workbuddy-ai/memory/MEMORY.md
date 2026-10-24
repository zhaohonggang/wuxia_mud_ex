# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- No `git commit` unless explicitly asked. P6 housekeeping pending user approval.
- No local Erlang — Docker is the verify path:
  `docker exec -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test wuxia_mud_dev-app-1 sh -c "cd /app && mix test <path>"`
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
- **P5-3/P5-8 动态 spawn**：`lingshezhang`/`shezhang` `convert`→spawn `lingshe`/`snake`；蛇 `bian`→还原法杖。
  - UCL `baituo.ucl`：`lingshezhang`→`convert_lingshe`，`shezhang`→`convert_snake` ✅（validate 绿）。
  - `lib/.../item_actions/convert_bian.ex` ✅（编译已修：`&:not_handled` 非法、piped `render(conn,…)` 三元、`family_ok?` nil-safe）；守门返回 conn 送达提示。
  - `lib/.../npc_actions/convert_bian.ex` ✅（编译已改用 `RoomHelpers.broadcast_vision`；`bian` 全局兜底）。
  - `item_action_handlers.ex` / `npc_action_handlers.ex` 已注册 ✅。
  - `test/.../item_actions_convert_bian_test.exs` ✅（8 测，守门+落空+分派）。
  - `test/.../npc_actions_convert_bian_test.exs` ✅（6 测，arg 落空+房间未运行+成功路径 @todo Docker）。
  - `test/kantele/world/` 整库 **1426/0**，无回归。

## Test gotchas
- `:global` name race：`setup_all` 注册一次 + 每测试 `reset/1`。
- FakeRoom：唯一房号 `System.unique_integer`，直接调 `Module.run/2` 显式传 room_id。
- 延时回调：测试字符须 `pid: self()`（否则 `is_pid` 守卫 FunctionClauseError）。
- conn 复用：`channel_changes` 累积，断言取 `List.last` 或逐次新建 conn。
- `Helpers.give_item/3` 收 `conn`，不能 pipeline。

## Next steps (backlog)
- **P5-3/P5-8 残余**：Docker 集成测试（成功 spawn 路径，需真实房间 GenServer，`start_character`+`SpawnController`；`broadcast_vision` 本身可无房间订阅）。
- **P5-9 smith job/working 链**：`xiangyang.ucl` `smith` `ask_me`（job/working/halt_working，materials/cost），per-room 模块。
- **14 NPC-absent 文件**：out of scope。
- **ucl-comment-todo B/C/D/F/G**：`guarded_exit`(16 房)，`check_dirs`/`check_out`/`ob->refuse`(18)，player gender(11)，`city:mudren` `enter` 门户(exempt)，更新 plan docs。
- **Await `git commit` 审批**（iron law）。
- **Update `docs/ucl-comment-implementation-plan.zh-CN.md`**（G，严重滞后）。

## Current focus
P5-3/P5-8 单测全部绿。可进入 Docker 集成测试（spawn 路径），或转 P5-9 smith 链，或取得 `git commit` 批准。
