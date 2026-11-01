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

## @static 白名单当前：733 唯一 id（与 733 `.ex` 模块一致，0 缺失 0 extra）。

## 进行中（待 commit）
- **poison（性格门，已实现，待 commit）**：`meta.character` 基础设施已补全（`PlayerMeta` 加 `:character`；`learn_command.ex` 透传 `student_character`；`skills_event.ex` 切片加 `:character`）；`poison.ex` 实现 `valid_learn/2`（光明磊落拒绝）+ `practice_cost/0`，moduledoc 标 `**已迁移：**`；单测 `test/kantele/combat/poison_test.exs` 5/5；Docker `mix compile` exit 0；combat+character 4054/36（36 均为预存在，零回归）。`docs/待办实施计划.zh-CN.md` 新增 C-PVE26；`docs/待办对照代码核查.zh-CN.md` 移除 poison 遗留项。等待用户 commit。
- **gun（已迁移，非真缺口）**：`valid_learn/2` 调用 `Kantele.Admin.Access.wizardp(character)`，无需改动。
- base 12 技能 valid_enable/practice_cost 修复：已迁，待 commit（C-PVE25）。
- lingbo-weibu / huoyan-dao：valid_learn/2 + practice_cost/0 已迁，待 commit。
