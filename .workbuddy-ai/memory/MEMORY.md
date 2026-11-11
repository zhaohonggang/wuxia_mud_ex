# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- 无 git commit/push 除非用户明确要求（2026-11-10 已授权「提交推送，然后继续推进」）。
- 改动前 Grep lib/test/docs + LPC 源 `/c/files/git/mud` 确认真缺口，不臆造语义。
- 不要升级 nimble_parsec。

## 验证路径
- Docker 不可用（Windows Git Bash）：`PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH`；`MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=_build_win13`；`ERL_LIBS=_build_win13/lib`；`MIX_ENV=test`。
- `mix compile` / `mix test --seed 831693`（全量约 9-10 min，建议后台重定向日志）。
- Docker 可用：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`。
- 纯函数 harness（无 Postgres）：`mix run --no-start -e 'ExUnit.start(); Code.require_file("test/test_helper.exs"); ExUnit.run()'`。
- 基线：27 失败全为 `bcrypt_elixir` NIF 环境性（Web.*/ExVenture.* 建用户/改密码），引擎/命令/技能/世界测试 0 失败。偶发 `F4ExtractorTest` `System.cmd` 60s 超时，单独跑 10/0，非回归。

## 关键约定 / 坑
- **路由**：`parse/2` 裸路由只产 `%{"command"=>...}`；带参命令需 `optional(spaces() |> text(:rest|:target|:category))`，新增带参命令务必检查。
- **CommandProbe**：扫描占位标记（`暂未开放/暂未实现/尚未开放/系统暂未`）；白名单 `@whitelist %{}`（0 占位）。新命令回执不得含占位标记。
- **daemon 惯例**（Pkd/Vote/Security/Prison）：GenServer 持 public ETS，写入直接 `:ets.insert` 不经 `GenServer.call`；`ensure!/0` 补建表；`read_state/0` 表缺失返缺省。
- **人格**：字段 `meta.character`（非 personality）；`set("character",...)` 仅 NPC 注册 + 转世；玩家 nil ≡ LPC 0：排除门不拦、包含门拦（4 个转世专属）。已落盘 `character_metadata.personality`。
- `@static` 白名单 733 唯一 id，与 `.ex` 模块一致（0 缺失 0 extra）。
- `valid_learn` 真实缺口 0：`guilty` 由 `precepts.ex` 写入（食肉 `:eat_meat` / 杀僧 `:kill_monk`）；`query_condition` 经 E1 并入 `character`。
- `suicide`：`meta.password` 明文校验 + `Characters.delete_by_name/1`（rescue 降级）。
- 已踩坑：`ExVenture.Characters` 裸 `update(...)` 被 `import Ecto.Query` 宏抢占 → 用 changeset + `Repo.update()`；`Damage.die/1` 前需 `ensure_death_state`（`meta.combat` nil → FunctionClauseError）；`is_player?/1` 认 `"player:"` 前缀；`receive_damage` 别传 killer。

## Elixir 1.13.4 / Windows Git Bash 特殊坑（2026-11-11 新增）
- `String.to_integer/1` 返回**裸整数**而非 `{:ok, int}`（本环境差异），匹配时用 `is_integer()` 保护句，不要用 `{:ok, amount}`。
- `List.to_atom/1` 不接受字符串；模块名构造须用 `String.to_atom(Enum.join(...))`，否则 `/clone/*` 路径会 `list_to_atom` 崩溃。
- `zone.items` 在 zone map 缺少 `:items` key 时抛 `KeyError`；改用 `Map.get(zone, :items, %{})`。
- `~s[#{...}]` 中 `]` 会提前闭合 sigil，后续插值丢失；改用常规 `"[#{...}] ..."` 字符串。
- `IO.write` 经 `:io.put_chars` 在 Windows 下对中文抛出 `:no_translation`；改用 `File.write!(path, entry, [:append])` 写 UTF-8 字节。
- `Path.join/3` 不存在，用 `Path.join([...])`；`File.rm/2` 不存在，用 `File.rm!/1`。
- `match?/2` 不绑定变量；测试中用 `{:ok, %Struct{}} = expr` 直接模式匹配。

## 已完成并 push 到 origin/kalevala（截至 2026-11-10）
- `e20116fe`：`prepare` 拳术组合真化（`SkillCombos.valid_combine?/2` + `Stats.mapped/2` + `stats.prepared[type]`），`skill_combos_test.exs` 10 例，`prepare_command_test.exs` 组合路径，文档同步，`extract_valid_combine.py` 改 INFO。
- 全量：7477 tests / 27 failures（全部 bcrypt 环境性，0 回归）。
- 此前已合并推送：R5 动态招式表；A3 f1 Diff-stop；Task #302-317 + B1 stub 批次1-2；F4 @static 白名单；valid_learn 全量 + 长尾；E4 套件清理（105→27）；E5 W3 14 命令显式化；B1 `suicide`；C `brothers` 跨角色同步；饥饿/口渴（食物+饮水）；Phase 2-8（`scheme`、S7/E2 转世落盘、S8/E3 戒律 `guilty`、S1 ask/answer、S2 `pkd`、S4 `vote`、S6 生物 `clone`）。
- 测试演进：7382 → ... → 7477 → 7548 tests，基线恒 27（全 bcrypt 环境性，0 回归）。
- `192d883e`：test: add tests for pingsi teleport service handler (#114) — 15 例全绿，覆盖注册/asker_id 守门/family 门禁/startroom 门禁/缺失降级/全流程广播+Teleport 意图+成功回话，vision_name/vision 回落。
- `1bd36b54`：test: add 苗人凤 item_grant inquiry key tests (#113) — 59 行，覆盖腾龙剑/剑谱上册/上册/剑谱下册/下册 5 个 give_item 门控字段 + 别名一致性；18 例全绿，0 回归。
- `3d4d4fc0`：test: add UCL validation for dynamic spawn lingshezhang/shezhang (#119) — 4 例，覆盖 lingshezhang/shezhang 物品 convert handler + lingshe/snake 角色 bian 动作；19 例动态生成测试全绿，0 回归。
- `c1e52c53`：Phase 1 疾病/雪原事件 + Q1-T3 clone/count 逐件交付 + B2 W3 计划文档（21 文件，+1838/−187）。
- `60150343`：feat: B2 W3 对象引擎 MVP —— `W3ObjectEngine` 核心 + `call`/`reboot`/`shutdown` 真化（15 文件，+741/−36）；全量 7626 tests / 27 failures（bcrypt 基线，0 回归）。

## B2 — 12 个 W3 arch 命令（全部已落地：8 已建模 + call/reboot/shutdown 真化 + 3 后续 deferred）
- 已真化（可建模 8）：`grant`、`throw`、`purge`、`changeuser`、`register`、`smash`、`var`、`setsk`。
- W3 对象引擎 MVP（2026-11-11 已完成并 push `60150343`）：`call`/`reboot`/`shutdown` 经 `Kantele.World.W3ObjectEngine`（GenServer + 公共 ETS `w3_objects`）+ `WizArch.system_action/4` 实现；reboot/shutdown 默认 dry-run（`config :ex_venture, W3ObjectEngine, allow_system_actions: true` 才真实停机/重启）。
- 后续阶段（保留 `not_modeled`）：`possess`（预留 `Kantele.World.Possession`）、`restore`（预留 `Kantele.World.ObjectRestore`）、`build`（预留 `Kantele.World.Builder`）。
- 文档：`docs/B2-W3-对象引擎实施计划.zh-CN.md`（计划）、`docs/D-节-v2-技术债-前置条件实施计划.zh-CN.md` §Phase 4（已标记 ✅）。
- `wiz_arch_test.exs` `@deferred`：`call`/`reboot`/`shutdown` 已移出，`possess`/`restore`/`build` 保留；`command_probe` 白名单 `%{}`，新命令不含占位标记。

## P5-5 丹药效果系统（已完成并 push）

核心：LPC `do_effect(object me)` → UCL `meta.effect`（kind="pill"）+ `meta.medicine`，数据驱动。

- `lib/kantele/item/effect/pill.ex`（纯 planner）：`plan/2` → `{:ok, %Pill{}}` / `{:reject, :cooldown|:full|:not_pill, text}`；校验 `pill_cooldowns` 冷却 + `full_vital` 满状态拒服；`apply_cooldown/2` 戳时间戳入 `meta.pill_cooldowns[key]`；`apply_busy/2` 经 `Combat.start_busy/2` 累加轮次
- `lib/kantele/item/effect.ex`（consume 引擎）：`consume/3` 读 `meta.medicine`（qi/jing/neili 治疗钳 max；stats 四维增量软上限 30；food/poison），返回 `{:ok, %{vitals, stats, parts, food?, medicine?, poison?}}`
- `lib/kantele/character/commands/eat_command.ex`（消费端）：`pill?/1` + `eat_pill/5` 委托 `Pill.plan` + `Effect.consume` + `apply_cooldown` + `apply_busy`；房间广播 `vision_text`（$N→你，exclude_actor）+ 自述 `self_text`
- `scripts/backfill_pill_effects.py`：LPC do_effect → UCL 回填（medicine + effect + "eat" verb），幂等 + backup + validate_ucl.py 校验，失败回滚
- 测试：`pill_test.exs`（7 例）+ `pill_backfill_test.exs`（3 例），全绿，0 回归

UCL 约束：嵌套 map 空格分隔（无逗号）；字符串列表逗号+空格（无尾逗号）；`\n` 为换行；booleans 为 "true"/"false" 字符串。

已回填物品：养精丹（jing+冷却+满 jing 拒服+广播）、少林金创药（qi，无冷却/满状态约束）、黑玉断续膏（self_text 自述）。

- Task #138 Item.Meta `liquid` 字段 + loader 解析（`loader.ex` `parse_item_meta/1`，`max_liquid`/`liquid` 归一化）已落地，`scripts/backfill_item_liquid.py` 回填脚本已就绪。
- Task #139 `drink_command` 容器液体消费端已实装（余量-1、房间广播、喝空提示、饮水度+30 封顶、醉酒累加、最后一口不挂醉度），19 例全绿。
- Task #142 乞讨系统（`beg_command.ex` 丐帮门禁+`no_beg`/`no_fight` 闸门+`beg/attempt` 事件；`beg_credit_event.ex`/`beg_debit_event.ex` 跨进程结算），12 例全绿。

## 剩余 backlog
- D 节 v2 技术债：
  - Q2 v2 疾病/雪原封路：✅ 已完成（2026-11-11，Phase 1 全部三项），`illness.ex` 五族 daemon + `season_event.ex` 正午发病 + `snow_region.ex`/`snow_region_event.ex` 雪原寒冷，测试 91 例全绿，全量 suite 0 回归。
  - Q1-T3 真·clone 动态目标：✅ 已完成（2026-11-11，Phase 2），`object_clone.ex` + `clone_command.ex`，`commands.ex` 路由更新，测试 27/0 全绿，全量 suite 0 回归。
  - Q1-T3 search/explore 入位校验：Q2-T0 已落地，已实装于 `quest_event.ex` `report/2`（`target_room` 经 `quest.ex` `task_meta` 持久化，`Room.snapshot/1` 查玩家在场）。
  - Q1-T3 count>1 逐件交付：✅ 已完成（2026-11-11，Phase 3/T4）。`Supply.generate/1` count=3..8，`Deliver.generate/1` count=5..10，`start_room` 入位门控，`turnin_request/2` 逐件扣减与部分交付提示，`scale_rewards_by_count` 按件比例奖励，`task_meta` 新增 `:count`/`:start_room`。测试：`quest_turnin_multi_test.exs` 6 例 + `quest_daemon_test.exs` generator 断言，全绿；全量 suite 7601 tests / 27 failures（bcrypt 基线，0 回归）。
  - 详细前置条件计划见 `docs/D-节-v2-技术债-前置条件实施计划.zh-CN.md`（Phase 1 季节/事件系统 ✅ 已完成 → Phase 2 克隆/授权基础设施 ✅ 已完成 → Phase 3/T4 count>1 逐件交付）。
- A1/A2/A4：已清零（A1 转换器已落地并归档；A2 永远不做；A4 终测/分区搬运已验收完毕），不再作为 backlog 项。