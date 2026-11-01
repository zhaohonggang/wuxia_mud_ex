# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- 无 `git commit`/`push` 除非用户明确要求（HEAD == origin/kalevala 时不要自行 push）。
- 无本地 Erlang → Docker 是唯一验证路径。
  - 单测：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`
  - 提交前体检：`... run --rm --no-deps -e MIX_ENV=test app mix compile`（exit 0 即可，warning 忽略；不做回归，用户最后跑）。
- **改动前检查铁律**：认定「真缺口」动手前先 Grep `lib/`/`test/`/`docs/` + LPC 源 `/c/files/git/mud/kungfu/skill/`。基类仅 `inherit SKILL`+空 `skill_improved` 是假阳性。
- 不要升级 nimble_parsec（`commands.ex` 冷编译 ~28s 正常）。

## Test gotchas (CRITICAL)
- **`valid_learn` 2 元陷阱**：真实门槛在 `valid_learn/2(stats, character)`，行为对 arity-1 提供默认 `def valid_learn(_stats), do: :ok`。测试必须写 2 元 `valid_learn(stats, %{})`，否则门槛被绕过。
- `alias Kantele.Character.Stats` 不会由 `use Kantele.Combat.Skill` 带入，每个迁移文件须自己加。
- `Stats.effective/3` = LPC `query_skill`（基础折半）。基础属性用 `Stats.int/dex/str/con/1`（有 `_->0` 回落）。
- `Engine.rand(rng,n)` 返回 `rng.(n)-1`（0-indexed，对齐 LPC `random(n)`）。
- `practice_cost()`：`nil` → 只能靠学；`%{qi:, neili:}` → 扣减。
- `Conn.put_character`/`conn.private` 是结构体；同一 handler 内「取最新角色」只能读 `conn.private.update_character || conn.character`（惯例 `defp current/1`），**绝不能用 `conn.character` 重取**（那是入口快照）。
- `hit_ob` 契约：`{wound, msg, affects, extra}`，`extra` 支持 `:plain_damage`/`:victim_neili`/`:attacker_neili`；2/3 元组仍合法。

## `valid_learn` 迁移状态
- 白名单 `@static` 624 个唯一 id（lib/kantele/combat/skills.ex）。
- **322 个带非平凡 `valid_learn` 的技能已全部 LPC 保真迁移**（wave1 116 + wave2 178 + wave3 28，通过 `gen_valid_learn.py` 生成 + 手写）。**已无真缺口。**
- **89 个「部分迁移」已全部重生成并提交**（commit 10068b35，已推送 origin kalevala）。`gen_valid_learn.py --verify` / `verify_messages.py` 零问题。
- 生成器三条铁律：① `strip_comments` 先 `mask_strings` 保等长；② `notify_fail` 只取 if 自身语句体 + 块内顶层（`_brace_depth == 1`）；③ 参数须纯字面量，先 `COLOR_RE.sub` 去掉 `HIR`/`NOR` 等宏。
- 生成器：`C:/tmp/gen_valid_learn.py`（`--write`/`--show ID`/`--verify`）。改完必须 `--force` 编译看 warning。

## 已知偏差/未建模
- `meta.character` 恒 nil → 性格门/家族门在 LPC 侧未设定时返回 0，Elixir `nil` 比较结果一致 → 直接 `== "X"` / `!= "X"`；无需 nil 守卫。
- `max_neili`/`neili` 缺字段要 `nil` 跳过（否则误拦）。
- `can_learn/` 与 `can_perform/` 条件门一律跳过（恒假）。
- `query_action` 落空返回 0（无招）vs 本实现回落首式——0 级持械退化场景有意偏差，引擎 `select_action` 拿 `%{}` 会在 `"\n" <> Map.get(action,"action")` 处崩。
- `xuedao-dafa` `hit_ob` 刻意跳过（引擎无跨进程二次出招基础设施）。
- `hamagong`/`xiantian-gong` 攻击方 `neili` 自耗、`prepared` 门控、`query("character")` 性格门未建模。

## 当前未提交更改（待 commit）
- `test/test_helper.exs`：DB 可选（try/rescue 围绕 `Ecto.Adapters.SQL.query!`，DB 不可用时跳过 TRUNCATE 并打印警告，純函数测试可无 DB 运行）。
- 21 个 per-skill valid_learn 测试文件：已补充 `combat.equipped.weapon.skill_type` 并将 `combat` 嵌套至 `meta.combat`（匹配 `Skill.wielding?/1` 的 `%{meta: %{combat: %{equipped: equipped}}}`）。
- `.workbuddy-ai/memory/2026-10-31.md` 和 `MEMORY.md` 自身。
- 批注：`@static` 有 12 个既有同模块重复 id（无害，未清理）；22 基础用法不注册。

## Docker / DB 连接不稳定
- `run --rm` 有时 `KeyError: :password` / `connection refused`；`exec -T` 在运行中容器内有时可行。`run --rm` 带显式 `TEST_DATABASE_URL` 间歇可行。`test_helper.exs` 已改为 DB 可选，pure-function 测试可无 DB 跑。

## Docker 命令参考
- 启动：`docker compose -f docker-compose.dev.yml up -d`
- 测试：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`
- 编译体检：`docker compose -f docker-compose.dev.yml run --rm --no-deps -e MIX_ENV=test app mix compile`
