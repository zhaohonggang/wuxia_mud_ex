# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- 无 `git commit`/`push` 除非用户明确要求。
- 无本地 Erlang → Docker 是唯一验证路径。
  - 编译体检：`docker compose -f docker-compose.dev.yml run --rm --no-deps -e MIX_ENV=test app mix compile`（exit 0 即可，warning 忽略）。
- 改动前先 Grep `lib/`/`test/`/`docs/` + LPC 源 `/c/files/git/mud/kungfu/skill/`，确认真缺口。
- 不要升级 nimble_parsec。

## R5 迁移（已全部结案，92 个真缺口已迁移，待 commit）
- 真缺口清单：`C:/tmp/r5_true_gaps_v2.txt`（92 个，LPC `query_action` 动态但 Elixir 侧无可用 `query_action/2`）。
- 批次顺序：Batch1 sword(33) → Batch2 blade(15) → Batch3 staff/club/whip(18) → Batch4 strike/cuff/finger/claw/hand(17) → Batch5 dagger/axe/hammer(8) → Batch6 parry ranmu-daofa(1)。
- 结果：25 动态 + 67 静态 = 92 个，全部已迁移 `@actions`/`@ultimate`+`query_action/2,/3`+`def actions()`，14 动态技能额外新增 `ultimate_values/2`。
- 参考模板：`dagou_bang.ex`（动态极意 `pick_action_with_ultimate`）+ `banruo_zhang.ex`（标准静态 `@actions`+`query_action/2,/3`）。
- 已知偏差：`qiufeng-chenfa` 按非动态处理（无 `ultimate_values/2`，`query_action/3` 委托 `/2`）；`sun-finger` 用 `action_finger` 变量名（regex 已支持任意变量名）。
- 生成器：`C:/tmp/r5_migrate_apply.py`（10 处 bug 已修复）。
- 验证：Docker `mix compile` exit 0，无迁移相关 warning；`test/kantele/combat` 回归绿。
- 状态：**全部 96 个文件已改动，未 commit（等待用户确认提交）**。

## Docker 命令参考
- 启动：`docker compose -f docker-compose.dev.yml up -d`
- 编译体检：`docker compose -f docker-compose.dev.yml run --rm --no-deps -e MIX_ENV=test app mix compile`
- 测试：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`
