# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- 无 `git commit`/`push` 除非用户明确要求。
- 无本地 Erlang → Docker 是唯一验证路径。
  - 编译体检：`docker compose -f docker-compose.dev.yml run --rm --no-deps -e MIX_ENV=test app mix compile`（exit 0 即可，warning 忽略）。
- 改动前先 Grep `lib/`/`test/`/`docs/` + LPC 源 `/c/files/git/mud/kungfu/skill/`，确认真缺口。
- 不要升级 nimble_parsec。

## R5 动态招式表迁移（已结案，已 commit b490fbb2）
- 92 个真缺口全部迁移（6 批次：sword 33 / blade 15 / staff/club/whip 18 / strike/cuff/finger/claw/hand 17 / dagger/axe/hammer 8 / parry 1），25 动态 + 67 静态。
- 每个技能新增 `@actions`/`@ultimate`+`query_action/2,/3`+`def actions()`，14 动态技能额外新增 `ultimate_values/2`。
- 已知偏差：`qiufeng-chenfa` 按非动态处理；`sun-finger` 用 `action_finger` 变量名。
- 生成器：`C:/tmp/r5_migrate_apply.py`（10 处 bug 已修复）。
- 验证：Docker `mix compile` exit 0；`test/kantele/combat` 回归绿。

## F4 @static 白名单补全 batch6（已完成，编译通过，待 commit）
- 动机：`@static` 白名单 624 个唯一 id，但 `.ex` 模块 733 个，有 109 个技能有 `.ex` 实现却未注册 → `Skills.get/1` 返回 nil。
- 核查口径：按 `data/world/*.ucl` 中 `skill = "..."` 的 distinct 文件数（ref_file_count）降序。
  - 核心 22 个（ref > 0）：dodge(65)/parry(65)/unarmed(62)/sword(52)/blade(48)/strike(32)/cuff(20)/staff(18)/finger(17)/hand(17)/claw(16)/whip(13)/club(11)/hammer(11)/throwing(10)/dagger(7)/medical(4)/poison(4)/axe(3)/tanqin-jifa(3)/chuixiao-jifa(2)/guzheng-jifa(2)。
  - 其余 87 个（ref = 0，按字母序补全）。
- 实现：在 `lib/kantele/combat/skills.ex` `@static` 末尾追加 109 条，无重复键，无引用缺失模块。
- 验证：Docker `mix compile` exit 0，无新增 warning。
- @static 唯一 id：624 → **733**（与 `.ex` 模块数一致，0 缺失，0 extra）。
- 文档同步：`docs/待办实施计划.zh-CN.md` 新增 C-PVE24；`docs/待办对照代码核查.zh-CN.md` §表格与 §6.2 F4 条目已更新。
- 状态：**已改动，未 commit（等待用户确认提交）**。

## Docker 命令参考
- 启动：`docker compose -f docker-compose.dev.yml up -d`
- 编译体检：`docker compose -f docker-compose.dev.yml run --rm --no-deps -e MIX_ENV=test app mix compile`
- 测试：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres@db:5432/ex_venture_test app mix test <path>`
