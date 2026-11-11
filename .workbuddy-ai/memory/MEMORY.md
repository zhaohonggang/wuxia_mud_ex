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

## 已完成并 push 到 origin/kalevala（截至 2026-11-10）
- `e20116fe`：`prepare` 拳术组合真化（`SkillCombos.valid_combine?/2` + `Stats.mapped/2` + `stats.prepared[type]`），`skill_combos_test.exs` 10 例，`prepare_command_test.exs` 组合路径，文档同步，`extract_valid_combine.py` 改 INFO。
- 全量：7477 tests / 27 failures（全部 bcrypt 环境性，0 回归）。
- 此前已合并推送：R5 动态招式表；A3 f1 Diff-stop；Task #302-317 + B1 stub 批次1-2；F4 @static 白名单；valid_learn 全量 + 长尾；E4 套件清理（105→27）；E5 W3 14 命令显式化；B1 `suicide`；C `brothers` 跨角色同步；饥饿/口渴（食物+饮水）；Phase 2-8（`scheme`、S7/E2 转世落盘、S8/E3 戒律 `guilty`、S1 ask/answer、S2 `pkd`、S4 `vote`、S6 生物 `clone`）。
- 测试演进：7382 → ... → 7477 tests，基线恒 27。

## B2 — 12 个 W3 arch 命令（6/12 可建模命令已完成）
- 已真化：`grant`、`throw`、`purge`、`changeuser`、`register`、`smash`。门控 `WizArch.guard` + `Access.archwizp`；DB 调用 rescue/catch 降级。
- `wiz_arch_test.exs` `@deferred` 余 6 条（全引擎绑定）；`command_probe` 未误报。
- 引擎绑定 6（保持显式「W3 对象系统未建模」回执）：`call`/`reboot`/`shutdown`/`possess`/`restore`/`build`。推进需立项设计 W3 对象引擎，与 B2 已完成量级相当（A1/A2/A4 已清零）。

## 剩余 backlog
- D 节 v2 技术债：
  - Q2 v2 疾病/雪原封路：Deferred（季节/事件系统未建模）；光线：Q2-T2 `Weather.light/0` 已就绪，可接。
  - Q1-T3 真·clone 动态目标：Deferred（Chei/Pawning，高成本）。
  - Q1-T3 search/explore 入位校验：Q2-T0 已落地，已实装于 `quest_event.ex` `report/2`（`target_room` 经 `quest.ex` `task_meta` 持久化，`Room.snapshot/1` 查玩家在场）。
  - Q1-T3 count>1 逐件交付：Deferred to T4。
  - 详细前置条件计划见 `docs/D-节-v2-技术债-前置条件实施计划.zh-CN.md`（Phase 1 季节/事件系统 → Phase 2 克隆/授权基础设施 → Phase 3/T4 count>1 逐件交付）。
- A1/A2/A4：已清零（A1 转换器已落地并归档；A2 永远不做；A4 终测/分区搬运已验收完毕），不再作为 backlog 项。