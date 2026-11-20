# AGENTS.md — Wuxia MUD (Elixir/Kalevala)

## 0. 项目宪章 — 最高优先级（2026-11-17 用户确立 · 永久生效）

> 本章是**整个项目的最高行为准则**，优先级高于本文件其余所有章节。
> 每次会话开始必须先读本章，并以此约束全部决策与行动。
> 本章是现行准则，**不受下方「归档声明」的历史快照定性影响**。

### 0.1 项目身份与使命（不可动摇）
1. **完整移植**：本项目是把 LPC 原版 `C:\files\git\mud` **完整移植**到 Elixir/Phoenix 端口
   （`Kantele`）——不是简化重写，不是挑重点实现，不是"意思到了就行"。
2. **结果标准**：最终结果必须是 **ex 的内容 ≥ lpc**。覆盖范围、机制细节、判定顺序、
   阈值、文案、公式，只多不少、不丢失信息。
3. **缺口主动报告 + 建计划**：一旦发现任何「lpc 有、ex 没有」的缺口，**必须主动向用户报告**，
   并**立即建立移植计划**（写入任务列表 + 文档 `docs/*移植计划*.md`）。不得沉默略过，
   不得用「简化版 / 保真降级 / 文本备注」搪塞了事。
4. **长期工程，禁止简化**：本项目计划用很长时间完成。**绝不因为省时间、省工作量而选择简化方案。**
   凡有疑问，回到 LPC 源码逐条核对，按原版实现；宁可多花时间，不可丢信息。

### 0.2 我的角色定位
- **资深项目经理 + 架构师 + 程序员**，精通项目设计与编程。
- 以工程化方式推进：先审计现状 → 建立计划/任务列表 → 逐项实现 → 测试回归 →
  文档与记忆归档。决策标准是「长期可维护 + 忠实原版 + 零信息丢失」。

### 0.3 工作性格
- **积极、热心、愿意多做工作。**
- 遇到任何困难、障碍，都**积极、耐心地解决**，而不是逃避、偷懒、走捷径或找借口。
- 发现缺口是「工作量」不是「麻烦」——主动承接、主动规划、主动完成。

### 0.4 全量回归由用户决定（2026-11-19 用户确立 · 永久生效）

1. **AI 永远不自行运行全量回归** —— 即不自行执行 `mix test`（全部 663 个测试文件），
   也不自行分 chunk 跑完整套。
2. 当某批改动按项目惯例「本该跑全量回归」时（见 §Dev Workflow 第 5 条），
   **不要跑**，改为把该批登记到 `docs/待全量回归清单.zh-CN.md`，然后**继续推进下一批**。
3. 用户审阅该清单并明确指示后，才执行全量回归，并把结果回填到清单对应条目。
4. **定向测试不受此限**：改动相关的测试文件（如 `mix test test/kantele/xxx_test.exs`）
   仍应自行运行 —— 改动是否正确必须自己验证，不得跳过。
5. 禁令同样适用于后台/异步执行、脚本包装、或「只跑一部分 chunk」等任何变体。

---

> ## 📌 归档声明 · 全库待办清零（2026-11-12）
>
> 本文件为**历史过程文档 / 阶段性快照**。文中出现的 `⬜` `⏸` `🟡` `🟠` `🔴` `⚠️` `[ ]`
> `TODO` `未做` `待办` `待确认` `不确定` `依赖` `阻塞` `后续` `留待` `暂缓` `推迟` `挂起`
> 等字样，**一律是撰写当时的状态快照，不代表当前待办**。
>
> 截至 2026-11-12 全库代码待办已清零：所有条目或已实现并回归通过，或已由用户决议不做 /
> 已证实不可实施 / 已定性为保真降级。**本文件不含任何剩余待办项**；复选框已统一按
> 「已结案」勾选（结案 = 已实现 / 已决议不做 / 已证实不可实施），原文保留作历史取证，无需排期。
>
> **唯一状态入口**：`.workbuddy-ai/memory/MEMORY.md` 与
> `docs/待办对照代码核查.zh-CN.md` §三 / §6.2。本文件其余状态描述一律不再代表现状。


**沟通语言**: 优先使用中文与用户交流。

## 运行环境（务必遵守）

- **运行 / 测试的唯一权威环境 = Docker**。启动用 `dev_start.bat`（或
  `docker compose -f docker-compose.dev.yml up app`）。镜像工具链 = Elixir **1.13.4** /
  Erlang **OTP 25.3.2.6**（见 `Dockerfile.dev`、`.tool-versions`，后者是版本真源）。
- **Windows 原生环境只作辅助**（`mix format` / `mix credo` / 少量单测），且**版本必须与
  Docker 对齐**：用仓库根的 `win_toolchain.cmd` 进入对齐 shell（该工具链已装在
  `%USERPROFILE%\tools\erl-25.3.2.6` 与 `%USERPROFILE%\tools\elixir-1.13.4-otp25`）。
- **不要**用系统安装的 Elixir 1.20.4 / OTP 29 直接跑本项目 —— 该版本在 `mix.lock` 支持的窗口
  之外（`ecto 3.6.2` 的 `@opaque dynamic` 在 Elixir ≥1.14 编译失败），历史上只靠陈旧 `_build`
  产物 + 手工改 `deps/cowlib/src/cow_sse.erl` 才勉强跑通，**已不再支持**。

## 环境位置（Environment locations）

> 只用下面这些位置；不要猜、不要用系统 PATH 里的其他 Elixir/Erlang。

| 用途 | 位置 |
|------|------|
| **版本真源** | `.tool-versions`（`elixir 1.13.4-otp-25` / `erlang 25.3.2.6` / `nodejs 20.19.5`） |
| **Docker 镜像定义** | `Dockerfile.dev`（`hexpm/elixir:1.13.4-erlang-25.3.2.6-debian-trixie`）+ `docker-compose.dev.yml` |
| Docker 启动 | `dev_start.bat` → 容器 `wuxia_mud_dev-app-1`，DB 容器 `wuxia_mud_dev-db-1` |
| Docker 源码挂载 | 仓库根 → `/app`（bind mount，改动实时可见） |
| Windows Erlang | `%USERPROFILE%\tools\erl-25.3.2.6`（erts-13.2.2.3） |
| Windows Elixir | `%USERPROFILE%\tools\elixir-1.13.4-otp25`（源码编译，`compiled with Erlang/OTP 25`） |
| Windows 隔离 MIX_HOME | `%USERPROFILE%\tools\mix-1.13`（hex/rebar 为 1.13.4 构建） |
| Windows GNU make | `%USERPROFILE%\tools\make\bin\make.exe` |
| Windows MSVC（NIF 依赖） | 由 `vswhere` 自动定位并 `call vcvars64.bat`（本机为 VS 18 Community） |
| Windows 入口脚本 | 仓库根 `win_toolchain.cmd`（自动设置 PATH / MIX_HOME / MIX_BUILD_PATH / ERL_LIBS / MSVC） |
| Windows 构建产物 | `_build_win13`（**不要**与 Docker/Linux 的 `_build` 混用） |

Windows 原生编译注意：

```bat
win_toolchain.cmd            REM 进入对齐 shell（已含 MSVC + 上述变量）
mix deps.get
mix compile
```

- `MIX_BUILD_PATH` 必须是**绝对路径**：相对路径会让 Mix 传给 rebar3 的 `REBAR_CONFIG`
  变成相对路径，rebar3 在 `deps/<app>` 内解析不到，静默退回默认配置（`include/` 丢失，典型报错
  `can't find include file "yamerl_*.hrl"`）。
- `ERL_LIBS=<build>/lib` 是 Windows 上编译 `vendor/kalevala` 路径依赖所必需的（否则
  `Jason.Encoder` 报 `could not load module ... :unavailable`）。
- `vendor/kalevala/_build` / `vendor/kalevala/deps` 是**历史独立构建残留**，会遮蔽根项目的依赖；
  若存在请删除。
- NIF 依赖（`bcrypt_elixir`）需要 MSVC 的 `nmake`；未加载 `vcvars64` 时会报 `"nmake" not found`。

## Quick Commands

> 命令**默认在容器内 / 对齐 shell 内**执行；Windows 主机请先 `win_toolchain.cmd`。

```bash
# Docker dev shell（Elixir 1.13.4 / OTP 25 / Node / inotify-tools）
docker compose -f docker-compose.dev.yml run --rm app sh

# 一次性容器跑测试：app 容器若在跑 phx.server（PID1），docker exec 会因 4000/4646
# 端口占用报 eaddrinuse，故用一次性容器（复用镜像/挂载/db，不发布端口）。
# ⚠️ 必须显式传 TEST_DATABASE_URL：config/test.exs 的默认值
# `localhost:15432` 是**宿主机**的映射端口，容器内那个地址是空的。
docker compose -f docker-compose.dev.yml run --rm \
  -e MIX_ENV=test \
  -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test \
  app mix test

# 安装依赖 / 编译
mix deps.get && mix compile

# 格式检查（CI）
mix format --check-formatted

# Lint（CI）
mix credo --all --format=oneline

# 全量测试 / 单文件 / 指定 seed —— 一律在容器内跑（容器是权威环境）
# 把最后一个参数换成测试文件路径或 --seed 即可：
#   ... app mix test test/kantele/world/mirror_daemon_test.exs
#   ... app mix test --seed 731933
docker compose -f docker-compose.dev.yml run --rm \
  -e MIX_ENV=test \
  -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test \
  app mix test

# [Windows 辅助，非权威] 只在不想起容器时做单文件冒烟。
# 注意：宿主 `_build_win13` 与容器 `_build` 不通用；两者结果不一致时以容器为准。
win_toolchain.cmd
# 进入后：set MIX_ENV=test && mix test <显式文件路径>
```

## Test Conventions

- **Test helper**: `test/support/test_helpers.ex` — `build_conn/1`, `build_character/1`, `player/0`
- **ConnCase/ChannelCase/DataCase** in `test/support/`
- **Fake rooms must not squat production `:global` names** (see R16): `Room.npc_characters_by_id/1`
  resolves `{:global, {Kalevala.World.Room, room_id}}`, and real world loads register the *same*
  ids. `:global.register_name/3` returns `:no` **silently** when the name is taken (the resolver
  is never called), so a fixture that ignores the return value will read someone else's process
  and fail later as a bare `assert_receive` timeout. Rules: (1) prefer a unique id
  (`"ytest:#{System.unique_integer([:positive])}"`); (2) when the id is hardcoded in the module
  under test, `unregister_name` the old holder first and restore it in `on_exit`; (3) always
  `register_name/2` + assert `:yes`.
- **Flaky tests**: Use `--seed 731933` (CI seed) to reproduce
- **Sandbox handover window** (see R17): the three Case templates put the SQL sandbox into
  `{:shared, self()}` for `async: false` tests — a **global** mode. When the owning test process
  exits, the manager only reverts to `:manual` after it handles the `DOWN`; in that window the
  next bare `ExUnit.Case` test can borrow the *dead* owner's connection and get
  `** (EXIT) shutdown: "owner <pid> exited"` (an exit, so `rescue` cannot catch it). Both sides are
  guarded now: `on_exit` resets the mode synchronously, and `Records.save/1` has `catch :exit`.
  Do not remove either. Regression guard: `test/kantele/db_sandbox_handover_test.exs`.
- **`Records.save/1` never raises/exits**: it returns `:ok | :error`. Tests that never check out a
  connection (48 files, ~134 call sites) rely on it swallowing `DBConnection.OwnershipError`.
- **Never rebind an accumulator inside `Enum.each` / `for`**: the rebinding is a fresh local that
  gets discarded, so `lines = lines ++ [line]` inside `Enum.each` silently produces nothing — no
  compile warning, and `mix credo` misses it. Use `Enum.map` or `Enum.reduce` and carry the
  accumulator out. This exact bug shipped 4 times (R20) and one instance made `make` (medicine
  crafting) never consume herbs, i.e. infinite crafting.
- **A "list source" and its "list renderer" must agree on shape**: `Auction.list_auctions/0` was
  returning ETS `{id, record}` tuples while both callers demangled them as records (R19), and
  `Money.money_str/1` only takes an integer while two callers passed a denomination map (R18).
  Both compiled fine and only blew up with real data. When adding a helper that reads ETS or
  money, add one test that inserts a row / a non-zero amount.
- **Key test files** (from README):
  - `test/kantele/quest/chain_walk_test.exs` — quest chains
  - `test/kantele/world/signature_npc_test.exs` — signature NPCs
  - `test/kantele/quest/tutorial_step_wiring_test.exs` — newbie chain
  - `test/kantele/world/mirror_daemon_test.exs` — MirrorDaemon
  - `test/kantele/world/kickoff_test.exs` — world load recovery

## Project Structure

```
lib/
├── ex_venture/           # Phoenix app (web, users, zones)
└── kantele/              # Core MUD logic
    ├── character/        # Commands, Combat, Stats, Events
    ├── combat/           # Skills, Performs, Buffs, Engine
    ├── quest/            # Quest system, Rewards
    └── world/            # GameTime, Weather, Story, Invasion, MirrorDaemon
```

## Data-Driven (UCL)

- World data: `data/world/*.ucl` (liuxi.ucl, signature.ucl, nature/weather.ucl)
- **Parser**: Elias (`:stein` dep). **Gotcha**: No `;` inside strings, arrays need trailing commas
- Object refs: `{ id = items.xxx.id }` → loader resolves to `"zone:key"`
- Item ID format: `zone:key` (e.g., `liuxi:changjian`, `liuxi:task/xxx`)

## Migration Pipeline (F4 Skills/Performs)

- **Source**: `kungfu_source/kungfu/skill/<skill>/<move>.c` (LPC)
- **Full LPC repo**: `C:\files\git\mud` — contains all original game logic; **target is full migration with zero info loss**
- **Extractor**: `scripts/translate_perform.py` (Python port of `translate_perform.exs`)
  - `python3 scripts/translate_perform.py` → outputs to `/tmp/perf_out/`
  - Env: `KUNGFU_SRC`, `KUNGFU_OUT`
- **Batch migrate**: `scripts/migration/batch_migrate.exs`
  - Reads `tmp/skill_out/*.ex` → writes `lib/kantele/combat/skills/*.ex`
  - **Never overwrites existing** — checks `File.exists?` first
- **Perform dir**: `lib/kantele/combat/skills/performs/<skill>/<move>.ex`
  - 59 hand-written restored from `e4dfc66` (never overwrite)
  - 371 extractor skeletons: 动态公式以 `TODO(migrate)` 保真注释留档，已定性为
    文档化保真降级（非待办；F4 武功迁移于 2026-11-12 结案）

### Migration Principle

**Never discard information** from `C:\files\git\mud`. If the extractor can't fully convert a construct:
1. **Preserve as comments** in the generated `.ex` skeleton
2. **Add `@todo` tags** for manual follow-up
3. **Document gaps** in `scripts/migration/` or commit messages

This ensures future passes can complete the conversion without re-reading LPC.

**Game logic authority**: For any unresolved game logic questions during conversion, **consult `C:\files\git\mud` LPC source** — it is the definitive reference for all mechanics, formulas, and behaviors.

### Script Language Preference

- **Python** (`.py`) for all conversion/migration/extraction scripts (e.g., `scripts/translate_perform.py`, `scripts/migration/`, `scripts/*.py`)
- **Elixir** (`.ex`/`.exs`) only for:
  - Game runtime code in `lib/`
  - Tests that must execute inside the game (`test/**/*_test.exs`)
  - Mix tasks that integrate with the app (`mix ecto.*`, custom tasks)

## Code Style

- **Formatter**: `mix format` (imports ecto, phoenix; line length 120 via credo)
- **Credo**: `mix credo --all` (strict: false, TagTODO exit_status: 2)
- **Max line**: 120 (Readability.MaxLineLength)
- **ModuleDoc ignored** for *Channel, *Controller, *Command, *Event, *View

## GenServer Patterns

- All long-lived processes: `Behaviour` with `prompt/1`, `init_state/1`, `start_round/1`, `stop_round/1`, `status/1`
- **Schedule once**: chain `Process.send_after(self(), :tick, ms)` — avoid `send_interval`
- **Error handling**: `safe_run/2` / `safely/1` wrapper to prevent crashes

## Common Gotchas

| Issue | Fix |
|-------|-----|
| `mix test` hangs on recompile | Exclude `reload_command_test` (known flaky 60s timeout) |
| 测试中途生成 10GB+ `erl_crash.dump` 占满系统盘 | BEAM 遇 `eheap_alloc` 等不可恢复错误会往 cwd 写 crash dump（= 全进程堆 + 全 ETS 快照）。跑任何 `mix` 前 `export ERL_CRASH_DUMP_BYTES=0`；`verify.sh` 已内置 |
| UCL parse fails | Check for stray `;` in strings, missing trailing commas in arrays |
| perform_known? missing | Use `Stats.perform_known?/2` before calling perform module |
| World load order | `kickoff_test.exs` validates loader phases; run it first after UCL changes |

## Dev Workflow

1. Edit code in `lib/kantele/`
2. `mix compile` —— **日常改动只需编译通过即可，不必每次都跑全量测试**（判定标准见 Core Rules #1）
3. `mix format && mix credo` (pre-commit)
4. Targeted test in container (可选，仅在涉及核心逻辑变更或修复 Bug 时运行)：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:ex_venture_test app mix test test/kantele/...`
5. Full suite（**AI 不得自行运行 · §0.4**）：仅在用户审阅 `docs/待全量回归清单.zh-CN.md`
   并明确指示后执行；同第 4 条命令，加 `--seed 731933`。
   未获指示时 —— 把本批改动登记到该清单，然后直接继续下一批。
6. **Pre-commit check**: Before committing modified tracked files, compare with `git show HEAD:<file>` — if the new version loses significant info or is noticeably smaller, **do not commit**; investigate or report to user
7. Commit by sect/family (not per-skill): `git commit -m "Shaolin: implement damo-jian performs"`

## Core Development Rules (必读，贯穿全程)

| # | 规则 | 说明 |
|---|------|------|
| 1 | **提交前必编译** | 改动 `lib/**/*.ex` → 提交前必须 `mix compile` 通过。**改动 `test/**/*.exs` → 必须 `mix test <该文件>` 通过**：`.exs` 是脚本、不参与编译，语法错误只在加载/运行时暴露，`mix compile` 查不出来。改动 `config/*.exs`、`mix.exs` → 至少确认 `mix` 命令能正常启动。**跑过定向测试即视为编译已验证**，不必再单独 `mix compile` 一遍。不必跑全量回归（见 §0.4）。 |
| 2 | **改动前先核实现有状态** | 开始任何改动前，都先核实一下现有状态（grep 代码、读文档、查 git log）。如果该功能已经做了，不要重新做，只更新相关文档和记忆，把它标记完成。 |
| 3 | **改动后必更新文档与记忆** | 做完每一个改动，都要更新相关文档（如 `docs/*.md`、`AGENTS.md`）和记忆（`.workbuddy-ai/memory/` 日志与 MEMORY.md），并在文档中把该项标记完成，以免之后重新做。 |

## Docker Notes

- **Dev image**: `Dockerfile.dev` (`hexpm/elixir:1.13.4-erlang-25.3.2.6-debian-trixie` + git/make/gcc/node/inotify-tools)
- **Compose**: `docker-compose.dev.yml` mounts source, runs `sh` by default; dev DB container `wuxia_mud_dev-db-1`
- **Test DB**: Postgres, user `postgres:postgres`

## Dev Reload (Hot Reload)

| Change Type | Path | Reload Method |
|-------------|------|---------------|
| UCL world data | `data/**/*.ucl` | In-game `reload` command |
| Elixir source | `lib/**/*.ex` | Auto-compile via bind mount; or `docker restart wuxia_mud_dev-app-1` |
| JS/React frontend | `assets/js/**/*.{js,jsx}` | Browser F5 (after `docker cp` + restart) |
| Elixir tests | `test/**/*.exs` | `mix test` inside container |
| Mix config | `config/*.exs` | Restart server |

**UCL `reload` supports**: NPC stats/skills/dialog, room desc/exits, item props, shop goods, skill config  
**UCL `reload` does NOT support**: New NPCs/rooms (needs full world reparse), brain behavior tree changes

### Docker Management

```bash
# View logs
docker logs wuxia_mud_dev-app-1 --tail 30

# Restart (most common refresh)
docker restart wuxia_mud_dev-app-1

# Sync file to container
docker cp <local> wuxia_mud_dev-app-1:/app/<path>

# Health check
docker exec wuxia_mud_dev-app-1 wget -q -O- http://127.0.0.1:4000/_health
```

**Source location**: Repo is bind-mounted at `C:\files\git\wuxia_mud_ex` → `/app` in container. Data volumes in WSL2 at `\\wsl$\docker-desktop\var\lib\docker\volumes\`.

### Port Conflicts (Windows)

```powershell
# Find process on port 4000 (web) or 4646 (telnet)
netstat -ano | findstr :4000
taskkill /PID <PID> /F
# Or kill all beam.smp
Get-Process beam.smp -ErrorAction SilentlyContinue | Stop-Process -Force
```

## References

- `README.md` — full architecture, test guide, UCL examples
- `docs/dev-test-config.zh-CN.md` — dev / test 配置总表（每个开关的取值 + `文件:行`，改端口/换库/查开关先看它）
- `lpc_example/ex/MIGRATION_PLAN.md` — skill migration phases (Q1-Q6 done)
- `scripts/migration/` — batch tools for skill migration