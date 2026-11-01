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
- F4 valid_learn 长尾补全——16 个 arity-1/arity-2 技能（已实现，未 commit）：
  - arity-1 (12): baicao-jue/baji-quan/culture-cognize/huntian-baojian/huzhao-shou/japanese/necromancy/russian/tadpole/technic-cognize/wuxing-jueming/xuwen-qixingding
  - arity-2 (4): wuyue-blade/wuyun-jianfa/xuanfeng-leg/xuantian-shengong
  - 测试：skills_valid_learn_partial_batch2_test.exs（12技能），skills_valid_learn_partial_batch3_test.exs（4技能），均绿（54/0）
  - batch1 已 commit（linji-zhuang/longxiang-gong，7a609e9c，11/0）
