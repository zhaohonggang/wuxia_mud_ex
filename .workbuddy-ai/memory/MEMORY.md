# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- 无 git commit/push 除非用户明确要求（用户 2026-11-10 已授权「提交推送，然后继续推进」）。
- 改动前 Grep lib/test/docs + LPC 源 `/c/files/git/mud`（技能 `/kungfu/skill/`，命令 `/cmds/arch|adm|usr/`）确认真缺口，不臆造语义。
- 不要升级 nimble_parsec。

## 验证路径
- Docker 不可用时用 Windows 本地 OTP25 + Elixir 1.13.4（Git Bash）：
  `PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH`；
  `MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=_build_win13`；
  `ERL_LIBS=_build_win13/lib`；`MIX_ENV=test`。
- `mix compile` / `mix test --seed 831693`。全量约 9-10 分钟，建议后台跑并重定向日志。
- **基线：27 failures 全部为环境性** —— `bcrypt_elixir 2.3.0` NIF 在 Windows 未编译，级联打挂所有建用户/改密码的 `Web.*`/`ExVenture.*` 用例；容器/CI 自然通过。引擎/命令/技能/世界测试 0 失败。
- 偶发第 28 例：`Kantele.F4ExtractorTest` 在全量负载下 `System.cmd` 60s 超时，单独跑 10/0，属 flaky 非回归。
- 纯函数 harness（无 Postgres）：`mix run --no-start -e 'ExUnit.start(); Code.require_file("test/test_helper.exs"); ExUnit.run()'`。
- Docker 可用时：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`。

## 关键约定 / 坑
- **路由**：`parse/2` 裸路由只产 `%{"command"=>...}`，带参命令（`run/2` 读 `rest`/`target`/`category`）不可达。统一 `optional(spaces() |> text(:rest|:target|:category))`；新增带参命令务必检查。
- **CommandProbe** 是纯文本标记扫描（`暂未开放/暂未实现/尚未开放/系统暂未`）；`test/kantele/command_probe_test.exs` 白名单 `@whitelist %{}`（0 占位）。新命令回执不得含占位标记，否则被误判为桩。
- **daemon 惯例**（Pkd/Vote/Security/Prison）：GenServer 持有 public ETS，**写入直接 `:ets.insert` 不经 `GenServer.call`**；`ensure!/0` 需补建表（`start_link` 链接到测试进程，用例退出后表被回收但注册名可能仍在），`read_state/0` 在表不存在时返回缺省。踩过 `no process` / `ArgumentError` 的坑。
- **人格**：规范字段 = `meta.character`（不是 personality；`Combat.@applies_keys` 的 :personality 是另一概念）。LPC `set("character",...)` 仅 NPC 注册 + 转世 `updated.c:515`「国士无双」；玩家未设 = nil ≡ LPC 0：排除门不拦、包含门拦（4 个转世专属）。已落盘 `character_metadata.personality`。
- `@static` 白名单 733 唯一 id，与 `.ex` 模块一致（0 缺失 0 extra）。
- `valid_learn` 真实缺口 0：`guilty` 由 `precepts.ex` 写入（食肉 `:eat_meat` / 杀僧 `:kill_monk`），`query_condition` 经 E1 并入 `character`。
- `suicide`：`meta.password` 明文校验（本端口未引入 bcrypt）+ `Characters.delete_by_name/1`（`UPDATE_D->remove_user` 等价，rescue 降级）。
- 详细日志见 `.workbuddy-ai/memory/2026-11-{01,02,05,08,09,10}.md`。

## 已完成并 push 到 origin/kalevala（截至 2026-11-10）
- `b490fbb2` R5 动态招式表；A3 f1 Diff-stop（ZoneSupervisor/Room 用 `terminate_child` 不可 `:kill`）。
- `540b4d0e`/`938d6340`/`e1848f4b` Task #302-317（锁阳丹/转世门控/张三丰鹤嘴劲/4 AskHandler）+ B1 stub batch1/2。
- `b1702540` F4 @static 白名单补全（未 push）；`7a609e9c`/`4534d108` valid_learn 全量 + 长尾批次1-3。
- `dfa8d0e7` E4 套件清理（105→27 环境性）+ E5 W3 14 命令显式化 + B1 `suicide` 真化。
- `77516528` C `brothers` 跨角色同步（离线亦可 + rumor + 房间事件转发）。
- `a53445e2` 饥饿/口渴食物侧；`625c2196` 饮水侧。
- 期间完成的 Phase 2-8：`scheme` 计划执行器、S7/E2 转世落盘、S8/E3 戒律 `guilty`、S1 ask/answer 配对、S2 `pkd`、S4 `vote`、S6 生物 `clone` —— 均在上述 commit 中一并推送。
- 全量演进：7382 → 7392 → 7409 → **7437 tests / 27 failures**（每批均 0 新增回归）。

## B2 — 12 个 W3 arch 命令（**6/12 全部可建模命令已完成**；commits `3a0c7188` / `ef35bf9a` / 第三批）
- 已真化 6：`grant`（`Kantele.Admin.Security` 授权注册表 ETS）、`throw`（`Kantele.Admin.Prison` 禁闭 daemon，`heal_up` 的 `in_prison?` 桩已接入）、`purge`（`Characters.delete_by_name/1` + rumor）、`changeuser`（LPC `changename.c` 中文名校验 + `Characters.rename_by_name/2`）、`register`（`Users.register_by_username/2` + `register_changeset/2` 以 `email_verified_at` 表登记态，免 DB 迁移）、`smash`（LPC `smash.c` 2-hop 雷劈事件链）。
- 门控统一 `WizArch.guard` + `Access.archwizp`（arch-only，对应 LPC `valid_grant(me,"(arch)")`）；DB 调用全 rescue/catch 降级。
- `wiz_arch_test.exs` 的 `@deferred` 现余 **6 条（全引擎绑定）**；`command_probe` 未误报。
- **三个关键坑**：① `ExVenture.Characters` 里裸 `update(...)` 被 `import Ecto.Query` 的 `update/2` 宏抢占（宏优先于同名本地函数）→ 直接写 changeset + `Repo.update()`。② daemon 用 `start_link` 链接测试进程，ETS 表随用例退出被回收 → 直接 ETS 写入 + `ensure!/0` 补建表 + `read_state/0` 表缺失返缺省。③ `Damage.die/1` 前必须 `ensure_death_state`（`meta.combat` 默认 nil → FunctionClauseError；`meta.damage` nil → BadMapError，R24 掉线教训）；`is_player?/1` 认 `"player:"` 前缀；`receive_damage` 别传 killer（`character.name(who)` 会崩）。
- 引擎绑定 6（**保持显式「W3 对象系统未建模」回执，真实实现非桩，不臆造 LPC driver 能力**）：`call`/`reboot`/`shutdown`/`possess`/`restore`/`build`。要推进需立项设计 W3 对象引擎，属 A1/A2/A4 同量级大工程。
- 状态文档：`docs/remaining-work-checklist.zh-CN.md` 建议优先级第 7 条 + 已完成表格行；`game-commands-testing-guide` 的 W3 条已加过时注记。
- 全量演进：7382 → 7392 → 7409 → 7437 → 7453 → **7465 tests**；基线恒为 **27 bcrypt NIF 环境性失败**（另偶发 1 例 `F4ExtractorTest` 全量负载 `System.cmd` 60s 超时，单独跑 10/0，非回归）。

## 剩余 backlog
- A1/A2/A4 大工程（T1 转换器投入最大，需立项排期）。
- D 节 v2 技术债：疾病/光线/季节封路、真·clone 动态目标、search/explore 入位校验、count>1 逐件交付（明确推迟）。
