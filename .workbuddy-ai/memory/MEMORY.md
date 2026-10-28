# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- No `git commit` unless explicitly asked. HEAD == origin/kalevala. P5 乞讨系统 (#143), fuse (#144 5 灵石), 战斗闲聊 (#144), S0/S1a/S1b/S1c 均为本地未提交，待用户决定 push。
- No local Erlang — Docker 是验证路径：
  `docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`
- 全量回归分块：容器内 `find test -name '*_test.exs' | ... | split -n l/4`，逐块 `mix test $(cat /tmp/chunk_XX | tr '\n' ' ')`。
- UCL (Elias): newline 分隔块、无逗号、裸 key（含中文）、`newline=""`；`"..."` 内仅 `\"`/`\'` 和 `\`+word 合法；数组逗号分隔、无尾逗号。
- clone_lib 去重铁律：NPC 有 clone_lib 主定义者，数据必须落 clone_lib；zone 同名块按名合并覆盖。
- Handler 回调：`run(conn, params)` 返回 `:not_handled` 放弃；需向玩家送达提示时**必须返回 conn**。
- **不要升级 nimble_parsec**（用户明确要求）。`commands.ex` 单文件冷编译 ~28s 是正常代价，不是卡死。根因：452 个 `parse` → 452 个 `defparsecp`，nimble_parsec 0.6.0 代码生成慢。详见 `2026-10-28.md`。

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
- `Room.message_vision/3` 是**死接口**：发 `{:vision_message, ...}`，Foreman 只处理 `{:room_message, ...}`。房间 vision 一律用 `Kantele.World.RoomActions.Helpers.broadcast_vision/4`（`$N`→`{npc}` 由 VisionView 分流「你」/姓名）。
- `Stats.effective/3` = LPC `query_skill`：`div(skills[usage],2) + skills[special] + apply`。基本技能**折半**！装备 `armor_prop` 走 `Combat.skill_applies/1` 传入。
- LPC 数字文案一律 `Kantele.Util.ChineseNumber.to_chinese/1`（照抄 `chinesed.c`：110→「一百十」、1010→「一千零十」）。`Money` 已委托它，勿再写第二份。
- 锻造币值：报价「两黄金」、记账「文」，1 两 = 10000 文（`moye.c` `val *= 10000`）。
- **事件模块命名铁律**：`use Kalevala.Event.Router` 的 `module(X)` 按 `scope` 前缀拼名。`scope(Kantele.Character)` 下写 `module(Foo)` 得到 `Kantele.Character.Foo`，写成 `Kantele.World.Foo` 会在**运行时** UndefinedFunctionError（编译不报）。新事件模块一律放 `Kantele.Character.*`。
- `conn.private` 是 `%Kalevala.Character.Conn.Private{}` **结构体**（不是 map）：注入房间快照用 `%{conn | private: %{conn.private | room: %{characters: [...]}}}`，`put_in(conn.private[:room], ...)` 会炸。`Room.characters_for_conn/1` 认这个字段。
- 房间角色 `:id` 是**带 zone 的完整 id**（`signature:ganjiang`），不是裸名；按裸名比对永远找不到（`npc_shop_event` / `kneel` 都是按 `character.id` 比）。
- 锻造定时：`Kantele.World.ForgingTimeout.schedule/4` + `Process.send_after` 投回 NPC 进程；取消用 `:timer_token` 令牌（不是 ref）。`forge_timing_scale` 生产 1 / 测试 0。
- **顺序陷阱**：`Forging.put(new_session)` 之后再 `ForgingTimeout.cancel/1` —— 反了会被 new_session 里的旧令牌覆盖，等于没取消。

## Next steps (backlog)
- S2 Task #155 (干将接收 forge/handoff + 7 段 vision): ✅ 完成 (ganjiang_event.ex)，2026-10-28 改为 LPC `call_out` 分步时序（prepare 1s → step1 5s → step2 6s → step3 3s → step4 5s → step5 3s → step6 2s），step6 才 `inputing` 并排 240s 等待。`ganjiang_event_test` 6/0。
- S2 Task #156: ✅ 完成 `注内力` 命令 (zhuneili_command.ex)：门控恢复 LPC 精确的 `status=="waiting" && can_help`（**6 秒窗口**，inputing 必须拒绝）；门槛 jing≥180/qi≥300/neili≥800/max_neili≥1000；扣 jing180/qi300/neili200/max_neili200；point += point*force/800；can_help→false；测试 12/12 绿。
- S2 Task #157: 注内力命令 route 已注册；需运行 S1b/S1c/S2 + 回归 Docker，确保 0 失败。
- S3 #152: ✅ 完成 ForgeCustomizeCommand (name/desc/wieldmsg/unwieldmsg/finish) + 动态物品模板注册 + 持久化; 13 测试全绿 (Docker verified). 关键修复: %Item{} → %Kalevala.World.Item{} (ItemDef alias), Kantele.World.Item.Instance 不存在 → 用 Kalevala.World.Item.Instance, CommandView 别名需是 Kantele.Character.CommandView, 会话字段写入用 Map.put 而非 \|> 更新语法, 各子动词需独立 handler 函数 (run_name/run_desc/run_wieldmsg/run_unwieldmsg/run_finish) 因为路由会剥离动词前缀, rest 参数不含动词名.
- S4 #153: discard/refund ((value*8/10+9999)/10000 金, 仅 item_make && owner_id==player), 乾坤袋 branch, timeout.
- #154: 全量 4 块 Docker 回归验证。
- S3 #152 后续 (2026-10-28): ✅ 锻造物品持久化可恢复。`Kantele.World.ForgeTemplates`(encode/decode/save/load_all/file_name) + `Kantele.World.Items.initialize/1` 启动灌入 + `config :ex_venture, :forge_dir`。关键：**不能**用 `Jason.encode!(%Kalevala.World.Item{})` 落盘（走 Meta.Trim 只剩 damage/armor）；`file_name/1` 把 id 里的 `:` 换成 `-`（Windows 非法字符）。全量 5047/0。
- S4 乾坤袋 (2026-10-28): ✅ `show 乾坤石` 两段说明 / `give 乾坤石` 无背包报价 500 两黄金 / 有背包免费 +5 / ≥100 拒绝 / 付钱给如意乾坤袋+销毁石头。关键：**背包扩展格写实例 meta**（`Forging.instance_extra/1`），改全局定义会摊到所有玩家；`give_command` 用 `bag_extra` 把背包格数带给莫邪进程。数据 `signature:qiankun_stone`(30000)/`qiankun_bag`(storage_bag=1)。全量 5055/0。乾坤石暂无刷新点。
- S1b 币值勘误 (2026-10-28): ✅ 锻造记账单位是**文**、报价是**两**，1 两 = 10000 文。LPC `moye.c` L381 `val *= 10000` 是权威（`money.c value()=amount*base_value`，`gold.c base_value=10000`）。`handle_material` 补 `* 10_000`；顺带补巫师特权（L382-388，value=1，`data.wizard` 沿 give 事件链下发）。成品 `meta.value` 与 `discard` 退款 `(v*8/10+9999)/10000` 因此自洽。全量 5056/0。
- LPC 全面对齐 (2026-10-28): ✅ 用户指示「都按照lpc来做」。(a) 新 `Kantele.Util.ChineseNumber`（移植 `chinesed.c`），接入锻造报价 + `Money` 委托它；(b) `Stats.effective/3` 改 LPC `query_skill`（基本折半 + 特技 + apply），新增 `Combat.skill_applies/1`，21 调用点全接线；(c) `注内力` 重写为 `do_help` 全语义（失败把该 vital **归零**，已扣 jing/qi 不退）；(d) 修 `ganjiang_event` 6 段 vision 从未送达（`Room.message_vision` 是死接口 → `Helpers.broadcast_vision`）。全量 **5080/0**。
