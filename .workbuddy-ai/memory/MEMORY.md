# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- No `git commit` unless explicitly asked. Branch `kalevala` ahead of `origin/kalevala` by 3 commits (`e515b04d` #9 loveroom+chaoyang, `d1bab7bd` MEMORY record, `54a4e70e` lanyue say), **`git push` 尚未执行**；工作区另有 P3 `liquid` 批（6 改 + 1 新 + 2 脚本 + 64 UCL + 3 新测试 + 3 改测试 + 文档）**未提交待批准**。
- No local Erlang — Docker is the verify path:
  `docker exec -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test wuxia_mud_dev-app-1 sh -c "cd /app && mix test <path>"`
  （URL 必须整串引号，否则丢 `//`。）
- Full regression prefer chunked: `find test -name '*_test.exs' | grep -v reload_command_test | sort > /tmp/all_files.txt && split -n l/4 -d /tmp/all_files.txt /tmp/chunk_`，再逐块 `mix test $(cat /tmp/chunk_XX | tr '\n' ' ')`。
- UCL (Elias): newline-separated blocks, NO commas, bare keys (incl. Chinese), `newline=""`. In `"..."` only `\"`/`\'` and `\`+word legal; `\\`/real newline syntax error. Arrays comma-separated, NO trailing comma. `validate_ucl.py` enforces `EliasStrings`.
- clone_lib 去重铁律：NPC 有 clone_lib 主定义者，数据必须落 clone_lib；zone 同名块按名合并覆盖（写 zone 必被 shadow）。
- Handler 回调：`run(conn, params)` 返回 `:not_handled` 放弃；需向玩家送达提示时**必须返回 conn**。`Family.name(nil)` 会崩，`family_ok?` 须 `is_map` 守卫。

## Completed work (tests green)
- **房间 `water` flag 回填（2026-10-26，全量 4906/0）**：LPC 48 处 `set("resource/water",1)` → UCL 房间 `flags` 加 `"water"`（32 区 / 47 房：45 新建 flags 块 + 2 并入已有数组）。`scripts/backfill_room_water_flag.py` 是**独立脚本**而非扩 `backfill_l1_fields.py`——后者 ①`resource/water` 被折叠进 `key_field_map.json` 的父键 `resource`(manual) 选不到，②遇已有 `flags` 块整块跳过；并入数组要动一行（补逗号）故 insertion-only 硬闸不适用，改设 G1 校验器回归为空 / G2 flag 只增不减且只允许 water / G3 行数增量等于预期。`test/kantele/world/room_water_flag_backfill_test.exs` 走真实 `Loader.load()` 断言。
- **P3 收尾（2026-10-26）**：`liquid`/`max_liquid` 全链打通 —— `Item.Meta.liquid` + `loader.parse_liquid/1`（缺 `remaining`/非 map→nil 回落药水）+ 新建 `lib/kantele/world/item_liquid.ex`（**定义侧 `Item.Meta.liquid` 是全局共享只读，喝一口只能写实例侧 `liquid_*` 四键**，否则一人喝光全服酒袋皆空）+ `drink_command` 三路 cond（容器→药水→不可饮）+ `fill_command` 按 LPC `fill.c` 顺序重写 + `room.ex` snapshot 加 `"water" in flags` + `Records` 只序列化液体四键（**秘籍 `:book` 刻意不存**，保持重启重掷语义）+ `scripts/backfill_item_liquid.py` 回填 32 区/59 块/+348 行。`sleep_room` DoD 补 `test/kantele/character/sleep_room_flags_test.exs`（起真房间走 `Room.snapshot/1` 全链）。
- P5-9 #9 一次性场景 6 切片全部完成（赌场 ×2 / 长安大堂 / 宴席三厅 / 棋苑三室 / 杭州楼外楼 order / 华山朝阳 chaoyang），P5 进度 **9/9**。`room_action*` 全集 **638/0**；`weiqi_test` 21/0。
- P5-6 暗语链 `yanziwu:lanyue` knock+say 已落地（`do_say` 答「光复大燕」→传送 `yanziwu:huanshi`），8 测试，已合入 `54a4e70e`。
- 其余已落库：动态出口、TerrainMove、绝情谷、拱猪、Inquiry 门控/太极图/苗人凤/桑三娘刘处玄/商剑鸣、pingsi 传送、survey resolve、P5-3/P5-8 动态 spawn、P5-9 smith job/working、P5-8 on_board 载具、#9 六切片。

## Test gotchas
- **全量回归分块跑时，`split` 的输入清单必须在容器内生成**（宿主机 `/tmp` 与容器 `/tmp` 不共享）；`ls dir/*_test.exs` 会漏子目录（`test/kantele/world/{npc_actions,room}` 3 个文件），须用 `find`。Docker 引擎 2026-10-26 又崩 2 次（单目录 world 各死在 1m7s/1m30s），`docker start wuxia_mud_dev-app-1` 恢复后切块即全绿。
- **`@type` 是 Elixir 保留属性**（typespec 专用）→ 写模块属性 `@type "liquid_type"` 编译期报 `invalid type specification: "liquid_type"`。字符串键常量一律加前缀（`@key_type`）。
- 无值返回 nil 的函数，调用点必须判空（`%{map | key: f(x)}` 会灌 nil；`Conn.Text.data` 含 nil 在 `Kalevala.Output.Tags.parse_string/4` 才 FunctionClauseError → 掉线）。新原语须连调用点一起测；渲染结果喂给 `Kalevala.Output.Tags`。
- **物品定义 vs 实例**：`%Kalevala.World.Item{}` 全局共享只读，`%Item.Instance{meta: %{}}` 才是每实例状态。任何「喝一口/用一次」只能写实例 meta（`Kantele.World.Item.Liquid` 是范例），写定义会污染全服。
- `Records` 的 `inventory` 列只存 `item_id` → 需跨登录保留的实例状态必须显式进 `serialize_inventory_item/1`；反之每次登录该重掷的（秘籍 `:book`）**刻意不存**。
- `Room.LookEvent` 测试 `test/kantele/world/room_look_event_test.exs`（4/0，`async: false`）；改 look/房述链路时跑它。
- `:global` name race：`setup_all` 注册一次 + 每测试 `reset/1`。FakeRoom 房号 `System.unique_integer`，直接调 `Module.run/2` 显式传 room_id。
- 延时回调测试字符须 `pid: self()`。conn 复用：`channel_changes` 累积，断言取 `List.last` 或逐次新建 conn。`Helpers.give_item/3` 收 `conn`，不能 pipeline。
- `Kalevala.World.Room.start_link` 收 map（含 `genserver_options`），keyword list → `:badarg`。`Enum.none?/2` 此环境 undefined → 用 `not Enum.any?/2`。
- `put_character/2` 返回新 conn，断言须取 handler 返回值。`Kalevala.World.Item` 无 `:value`/`:unit`（在 `item.meta["value"]/["unit"]`）。
- Elixir `0` 为 truthy，LPC `query_temp` 的 0 为假——显式排除 0/false/nil/""。
- 跳崖死亡路径：`PlayerMeta.combat` 须 `|| %Combat{}`；`Stats.query_dex/1` `skills` 须非 nil map；`Damage.die` 删 `die_reason` + `move_to_death_room` 改 `room_id` → 只能断言 `qi==1 && jing==1 && damage.ghost && room_id != 目标`，测试 id 须 `player:` 前缀。

## Next steps (backlog)
- P3 剩余 3 组字段（框架均已就绪，消费端等 P5 子系统）：
  - `no_beg`：框架✅（room.flags），消费端❌（beg_command.ex 是桩）→ 等 P5 乞讨系统
  - `can_make`/`not_make`/`power_point`/`item_origin`：框架✅（Item.Meta 已加），消费端❌（打造命令未建）→ 等 P5 打造子系统
  - `chat_msg_combat`/`chat_chance_combat`：框架✅（NonPlayerMeta 已加，254/256 NPC 有数据），消费端❌（NPC AI 聊天未接线）→ 等 P5 NPC AI 聊天子系统
- P3 `liquid` 遗留（已登记 §11，非本轮范围）：`condition/drunk` 醉度行为、`water` 摄入（饥渴系统）、`Kantele.Item.Liquid.extra_long/1` 与 `Kantele.Item.ExtraLong` 全族零生产调用点（未建「look 物品详述」子系统）。房间 `resource/water` 数据缺口**已补**（2026-10-26）。
- 37 个非 ask_* 闭包
- R21 clone_lib 同名同房排查
- `git push` 将 3 个本地提交推送到 `origin/kalevala`

## Notes
- `docs/data-world-comments-progress.zh-CN.md` 是「唯一记录做到哪了」的文件，每完成批次必须回填（§0 四件事）。
- 14 NPC-absent 文件 out of scope。ucl-comment-todo 已清空。#7 学徒/门派、#6 门/容器已完结，勿重复实现。
