# AGENTS.md — Wuxia MUD (Elixir/Kalevala)

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
# 端口占用报 eaddrinuse，故用一次性容器（复用镜像/挂载/db，不发布端口）：
docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test app mix test

# 安装依赖 / 编译
mix deps.get && mix compile

# 格式检查（CI）
mix format --check-formatted

# Lint（CI）
mix credo --all --format=oneline

# 全量测试（需 Postgres）
MIX_ENV=test mix test

# 单个测试文件
MIX_ENV=test mix test test/kantele/world/mirror_daemon_test.exs

# 指定 seed 复现 flaky
MIX_ENV=test mix test --seed 731933

# [Windows 辅助] 进入与 Docker 对齐的本地 shell（Elixir 1.13.4 / OTP 25）
# 进入后：set MIX_ENV=test && mix test <显式文件路径>
win_toolchain.cmd
```

## Test Conventions

- **Test helper**: `test/support/test_helpers.ex` — `build_conn/1`, `build_character/1`, `player/0`
- **ConnCase/ChannelCase/DataCase** in `test/support/`
- **Flaky tests**: Use `--seed 731933` (CI seed) to reproduce
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
  - 371 extractor skeletons need manual implementation

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
| UCL parse fails | Check for stray `;` in strings, missing trailing commas in arrays |
| perform_known? missing | Use `Stats.perform_known?/2` before calling perform module |
| World load order | `kickoff_test.exs` validates loader phases; run it first after UCL changes |

## Dev Workflow

1. Edit code in `lib/kantele/`
2. `mix format && mix credo` (pre-commit)
3. `MIX_ENV=test mix test test/kantele/...` (targeted)
4. Full suite: `MIX_ENV=test mix test --seed 731933`
5. **Pre-commit check**: Before committing modified tracked files, compare with `git show HEAD:<file>` — if the new version loses significant info or is noticeably smaller, **do not commit**; investigate or report to user
6. Commit by sect/family (not per-skill): `git commit -m "Shaolin: implement damo-jian performs"`

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
- `lpc_example/ex/MIGRATION_PLAN.md` — skill migration phases (Q1-Q6 done)
- `scripts/migration/` — batch tools for skill migration