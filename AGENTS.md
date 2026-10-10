# AGENTS.md — Wuxia MUD (Elixir/Kalevala)

**沟通语言**: 优先使用中文与用户交流。

## Quick Commands

```bash
# Install deps & compile
mix deps.get && mix compile

# Format check (CI step)
mix format --check-formatted

# Lint (CI step)
mix credo --all --format=oneline

# Run all tests (needs Postgres)
MIX_ENV=test mix test

# Run single test file
MIX_ENV=test mix test test/kantele/world/mirror_daemon_test.exs

# Run tests with specific seed (reproduce flaky)
MIX_ENV=test mix test --seed 731933

# Docker dev shell (has Elixir 1.11, OTP 23, Node, inotify-tools)
docker-compose -f docker-compose.dev.yml run --rm app sh

# In container: run tests against mounted code
docker exec wuxia_mud_dev-app-1 sh -c 'cd /app && MIX_ENV=test mix test'
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

- **Dev image**: `Dockerfile.dev` (hexpm/elixir:1.11.1-erlang-23.0.2-alpine-3.12.1 + build tools)
- **Compose**: `docker-compose.dev.yml` mounts source, runs `sh` by default
- **Test DB**: Postgres 12, `stein_example_test` / `postgres:postgres`

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