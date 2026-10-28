# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- No `git commit` unless explicitly asked. HEAD == origin/kalevala. P5 乞讨系统 (#143), fuse (#144 5 灵石), 战斗闲聊 (#144), S0/S1a/S1b/S1c 均为本地未提交，待用户决定 push。
- No local Erlang — Docker 是验证路径：
  `docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`
- 全量回归分块：容器内 `find test -name '*_test.exs' | ... | split -n l/4`，逐块 `mix test $(cat /tmp/chunk_XX | tr '\n' ' ')`。
- UCL (Elias): newline 分隔块、无逗号、裸 key（含中文）、`newline=""`；`"..."` 内仅 `\"`/`\'` 和 `\`+word 合法；数组逗号分隔、无尾逗号。
- clone_lib 去重铁律：NPC 有 clone_lib 主定义者，数据必须落 clone_lib；zone 同名块按名合并覆盖。
- Handler 回调：`run(conn, params)` 返回 `:not_handled` 放弃；需向玩家送达提示时**必须返回 conn**。

## Completed (tests green)
- condition/drunk (2026-10-26): Kantele.Drunk, ConditionRegistry 注册 "drunk", drink_command 累加醉度，ConditionEvent 出站通道 (state.condition_messages / state.condition_unconcious)。
- Force.Dispel + sleep 门控 (2026-10-26): 读 session["conditions"] 替代 character.meta.conditions; Conditions.dispel/3, Kantele.Drunk.dispel_condition/2, Conditions.blocked_by_vitals/3, sleep_command 双消息; 测试 15/0。
- 房间 water flag 回填: LPC 48 处 → UCL flags "water" (32 区/47 房), scripts/backfill_room_water_flag.py, room_water_flag_backfill_test.exs。
- P3 liquid/max_liquid 全链: Item.Meta.liquid, parse_liquid/1, item_liquid.ex (定义侧共享只读，喝一口写实例侧 liquid_*), drink/fill 按 LPC, room.snapshot 加 "water", Records 只序列化液体四键 (:book 刻意不存), backfill_item_liquid.py (+348 行), sleep_room_flags_test.exs。
- P5-9 #9 一次性场景 6 切片完成 (638/0); weiqi_test 21/0; P5-6 暗语链 yanziwu:lanyue (8 测试).
- P5 乞讨系统 (2026-10-27): beg_command 门控链, room.ex BegRequestEvent, beg_debit/credit_event, 17 测试全绿; 全量回归 ~4996/0。
- P5 fuse 熔炼切片 (2026-10-27): fuse_command.ex (12 测试), data/world/clone_lib.ucl stone1..5, commands.ex fuse 路由 text(:rest); 全量回归 4972/0。
- P5 NPC 战斗闲聊 #144 (2026-10-27): combat_event.ex 心跳 chat, 6 测试全绿; combat+events 574/0; 全量回归进行中.
- P5 打造 S1b+S1c: forging_accept.ex (KeyError 修复 + refund), forging_answer.ex (moye.c do_answer 移植), answer_command.ex, commands.ex, room.ex ForgeAnswerRequestEvent, events.ex 注册, give_event.ex forge_refund; forging_answer_test.exs 8/0。
- R21 clone_lib 同名同房: wuji4 块缺收尾 `}` 导致 4 块吞掉，已修复 (characters 489 / items 537); clone_fallback_test 回归 8/0。

## Test gotchas
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

## Next steps (backlog)
- S2 Task #155 (干将接收 forge/handoff + 6 段 vision): ✅ 完成 (ganjiang_event.ex), 测试 2/2 绿。
- S2 Task #156: ✅ 完成 `注内力` 命令 (zhuneili_command.ex): 门控 status="inputing" && can_help=true; 门槛 jing≥180/qi≥300/neili≥800/max_neili≥1000; 扣 jing180/qi300/neili200/max_neili200; point += point*force/800; can_help→false; 路由已注册; 测试 9/9 绿。
- S2 Task #157: 注内力命令 route 已注册；需运行 S1b/S1c/S2 + 回归 Docker，确保 0 失败。
- S3 #152: ✅ 完成 ForgeCustomizeCommand (name/desc/wieldmsg/unwieldmsg/finish) + 动态物品模板注册 + 持久化; 13 测试全绿 (Docker verified). 关键修复: %Item{} → %Kalevala.World.Item{} (ItemDef alias), Kantele.World.Item.Instance 不存在 → 用 Kalevala.World.Item.Instance, CommandView 别名需是 Kantele.Character.CommandView, 会话字段写入用 Map.put 而非 \|> 更新语法, 各子动词需独立 handler 函数 (run_name/run_desc/run_wieldmsg/run_unwieldmsg/run_finish) 因为路由会剥离动词前缀, rest 参数不含动词名.
- S4 #153: discard/refund ((value*8/10+9999)/10000 金, 仅 item_make && owner_id==player), 乾坤袋 branch, timeout.
- #154: 全量 4 块 Docker 回归验证.
