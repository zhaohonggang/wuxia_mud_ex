# 续做提示词：kalevala/wuxia_mud_ex NPC 私有动作通道（P5-1c）

## 1. 本轮已完成（上一轮会话产出）

NPC 私有动词分发层已打通，首个样板 `yun` 已落地。以下文件已创建/修改：

| 文件 | 内容 | 状态 |
|---|---|---|
| `lib/kantele/world/npc_action.ex` | `Kantele.World.NpcAction` 行为契约，`run(conn, params)` | ✅ 新建 |
| `lib/kantele/world/npc_action_dispatcher.ex` | `extract_verb/1` + `resolve/3` + `dispatch/3`，按稳定 `room_id` 索引 | ✅ 新建 |
| `lib/kantele/world/npc_action_handlers.ex` | 房间级注册表 `lookup/2` / `registered?/2` / `registered_rooms/0` | ✅ 新建 |
| `lib/kantele/world/npc_actions/yun.ex` | `arg == "roar"` → `Helpers.broadcast_vision/3` 广播，否则 `:not_handled` | ✅ 新建 |
| `lib/kantele/character/controllers/command_controller.ex` | 在 `RoomActionDispatcher.dispatch` 之后、`Commands.call` 之前插入 `NpcActionDispatcher.dispatch` | ✅ 修改 |
| `test/kantele/world/npc_action_dispatcher_test.exs` | dispatcher 单测（动词提取/CJK/空白、resolve/hit/unimplemented/no-room、dispatch 正向/dormant/handler返回:not_handled） | ✅ 新建 |
| `test/kantele/world/npc_action_handlers_test.exs` | 4 个 yun 房间已注册/未注册房间-verb/registered?/registered_rooms 长度=4 | ✅ 新建 |
| `test/kantele/world/npc_actions_yun_test.exs` | roar → rooms 频道 vision 广播 + `:handled`；非 roar → `:not_handled`；room_id nil 降级 | ✅ 新建 |

已注册 4 个 `yun` 房间（经 UCL 回源确认）：
- `tulong:huichang_back`、`tulong:huichang`（殷素素）
- `tulong:jiulou`、`tulong:was_dayuan`（赵一伤）

LPC 源回源自 `d/tulong/tulong/npc/yin.c`、`d/tulong/yitian/npc/zhao.c`：`arg == "roar"` → `message_vision` + `return 1`，否则 `return 0`。

**设计关键点（下一轮不要重踩坑）：**
- 注册表按 **`room_id`**（UCL `zone:key`，重启不变）索引，**不使用** `Character.generate_id()`（运行期随机 id）。
- 空注册表 → P7 dormant，对全局命令零行为影响（只有已注册的 `yun` 房间会被拦截）。
- `NonPlayerMeta.init.add_actions` 已由 loader 读入（`parse_enter_init/1`），现由 `NpcActionDispatcher` 消费；`room` 进程 `state.private.characters` 里是完整 NPC 结构体（含 `meta.init.add_actions`）。
- `conn.private.room` 在引擎里不保证恒非 nil（`RoomActionDispatcher.get_room_actions` 已有同样处理：优先 `actions_by_id`，缺失时返回 `[]` 安全降级）。

## 2. 环境问题（已知，需下一轮解决）

本沙箱**未预装 Elixir**，已通过 winget 装好 Erlang/OTP 29 + Elixir 1.20.4。`mix deps.get` 已拉齐依赖，但 **`mix compile` 受 transitive dep `:ssl_verify_fun`（hackney → postgrex 链）阻塞**：

```
could not compile dependency :ssl_verify_fun
src/ssl_verify_fun_cert_helpers.erl:13:14: can't find include lib "public_key/include/public_key.hrl"
```

头文件实际存在于 `/c/Program Files/Erlang OTP/lib/public_key-1.21.8/include/public_key.hrl`，但 rebar3 找不到（环境/路径问题，**与本次代码无关**）。

**下一轮第一件事**：解决 `:ssl_verify_fun` 编译，跑全量 `mix test --seed 12345`，确认：
- 新增 3 个测试文件（约 30 条用例）全部 pass
- 失败集保持 34 个与基线一致（无新增回归）

若无法解决，保留当前代码，交由有完整 Elixir 环境的机器验证。

## 3. 下一轮优先任务（按价值排序）

参考 `docs/npc-private-actions-survey.zh-CN.md` §7 推荐顺序：

1. ✅ 钱庄动词别名（`6944ffaf`）—— 已完成
2. ✅ NPC 分发层 + `yun` 首个样板（本轮）—— 已完成
3. **🟨 下一批：`ride*` 十连**（10 个 verb / 10 次调用，一份参数化实现）
   - 源：`d/beijing/npc/matong.c` 注册 10 个动词 `ridedl`/`rideem`/`ridefs`/`ridefz`/`ridehz`/`ridesz`/`ridexy`/`rideyd`/`rideyl`/`rideyz`
   - 实现体在 10 个头文件 `matongdl.h` … `matongyz.h`，几乎逐字相同，只差**目的地**与马名池
   - 语义：马童快速旅行（八卦门专属）。检查门派 → 检查是否已骑乘 → `random(3)` 抽马名 → 沿 `front_yard → gate → di_anmen → dahejiewest → bingying → majiu` 逐房间 `move` 并 `tell_room` 播报 → 落点「跃下马来」
   - 需 `Helpers.move_to/2`（已有，委托 `Teleport.teleport/2`） + `Helpers.broadcast_vision/3`（已有）
   - 注册到 `NpcActionHandlers`，key 为 `d/beijing` 区内马童所在房间的 `room_id`

4. 然后：`bi` / `compare` / `yao` / `decide`（26 次，有状态+随机，最贵，最后做）
5. 排除：`adm/`（42 次，巫师工具）、`join`（死功能，10 次）
6. 物品侧 `play`（11 次）→ 另开 item 通道（Kantele 仍缺 item `actions` UCL 入口）

## 4. 关键文件与路径

- 仓库根：`C:\files\git\wuxia_mud_ex`
- LPC 源语料：`C:/files/git/mud`（`d/*/npc/*.c`、`d/*/npc/obj/*.c`、`inherit/...`）
- UCL 世界数据：`data/world/*.ucl`（`tulong.ucl` 里 `yin`/`zhao1` NPC 已有 `add_actions = ["yun", "exert"]`）
- 全局命令表：`data/verbs.ucl`、`lib/kantele/character/commands/`
- 房间通道参考模式（NPC 通道已仿此构建）：`lib/kantele/world/room_action_dispatcher.ex`、`lib/kantele/world/room_action_handlers.ex`、`lib/kantele/world/room_actions/helpers.ex`

## 5. 验证命令（下一轮）

```bash
export PATH="/c/Program Files/Elixir/bin:/c/Program Files/Erlang OTP/bin:$PATH"
cd C:\files\git\wuxia_mud_ex
mix deps.clean ssl_verify_fun   # 或尝试修复 public_key 头文件路径
mix compile                      # 期望：无与本次代码相关的错误
MIX_ENV=test mix test --seed 12345 test/kantele/world/npc_action_dispatcher_test.exs test/kantele/world/npc_action_handlers_test.exs test/kantele/world/npc_actions_yun_test.exs
MIX_ENV=test mix test --seed 12345   # 全量，期望失败集 = 基线 34 个，无新增
```

## 6. 文档已同步（本轮已做）

- `docs/npc-private-actions-survey.zh-CN.md`：§6 改为「NPC 分发层已落地 + `yun` 首个样板」；§7 把钱庄别名 + yun 标为 ✅ 已完成，`ride*` 十连上升为下一批
- `docs/data-world-comments-progress.zh-CN.md`：§529 之后新增一行「P5-1 NPC 通道分发层 + `yun` 首个样板」
- `docs/data-world-comments-continuation-plan.zh-CN.md`：§417 第 1 行更新，NPC add_actions 不再标「加载后无人分发」，改为「分发层已落地，首个样板 `yun` 已注册到 4 个房间」
- `.workbuddy-ai/memory/2026-10-17.md`：追加了续做 30（代码落地）和续做 31（文档同步）

## 7. 下一轮会话的首个动作

1. 解决 `:ssl_verify_fun` 编译问题 → 跑全量 `mix test` 验证无回归
2. 若测试绿，提交本轮代码（`git commit`）
3. 开始 `ride*` 十连：阅读 `d/beijing/npc/matong.c` + `matongXX.h`，理解 10 个头文件的差异点，写 `Kantele.World.NpcActions.Ride*`（或复用参数化模块），注册到 `NpcActionHandlers`，加测试

---
*本提示词由上一轮会话自动生成，供下一轮会话直接作为上下文使用。如需更多细节，见上述文档与代码文件。*