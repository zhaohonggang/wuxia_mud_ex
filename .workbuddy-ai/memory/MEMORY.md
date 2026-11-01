# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- 无 `git commit`/`push` 除非用户明确要求。
- 无本地 Erlang → Docker 是唯一验证路径。
  - 编译体检：`docker compose -f docker-compose.dev.yml run --rm --no-deps -e MIX_ENV=test app mix compile`（exit 0 即可，warning 忽略）。
  - 测试：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`
- 改动前 Grep `lib/`/`test/`/`docs/` + LPC 源 `/c/files/git/mud/kungfu/skill/`，确认真缺口。
- 不要升级 nimble_parsec。

## 已结案（已 commit）
- R5 动态招式表迁移：92 个真缺口全部迁移，`test/kantele/combat` 回归绿，commit b490fbb2。
- F4 @static 白名单补全 batch6：109 个未注册特技全部注册，@static 唯一 id 733（与 .ex 模块数一致），commit b1702540（分支 kalevala，未 push）。
- valid_learn 全量迁移：已注册技能里带 non-trivial valid_learn 的全部 LPC 保真迁移，review_messages.py 全部通过，commit 10068b35 + 03a0e120。
- F4 valid_learn 长尾补全批次1：linji-zhuang/longxiang-gong（arity-2 character/vitals 门），commit 7a609e9c，11/0。
- F4 valid_learn 长尾补全批次2+3：12 arity-1 + 4 arity-2 共 16 技能补 valid_learn，测试 54/0；commit 4534d108（已 push origin kalevala）。

## @static 白名单当前：733 唯一 id（与 733 `.ex` 模块一致，0 缺失 0 extra）。

## 进行中
- valid_learn 长尾补全过程：批次1（7a609e9c）+ 批次2+3（4534d108，已 push）已全量提交；剩余 87 个「部分迁移」缺口（16 arity-1 仅 query_skill + 52 arity-2 _character + 17 隐藏 arity-1）见 2026-10-31.md 末尾清单，下一批需逐对照 LPC 源补齐缺失门槛。
