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

## F4 @static 白名单补全 batch6（已 commit b1702540）
- 全部 109 个未注册特技已注册（非预估的 387，实际扫描为准）：按 `data/world/*.ucl` 引用次数降序，核心 22 个有 UCL 引用（dodge/parry/unarmed/sword/blade/strike/cuff/staff/finger/hand/claw/whip/club/hammer/throwing/dagger/medical/poison/axe/tanqin-jifa/chuixiao-jifa/guzheng-jifa），其余 87 个 ref=0 按字母序。
- 在 `lib/kantele/combat/skills.ex` `@static` 末尾追加 109 条，无重复键，无引用缺失模块。
- 验证：Docker `mix compile` exit 0，无新增 warning。
- @static 唯一 id：624 → **733**（与 `.ex` 模块数 733 一致，0 缺失，0 extra）。
- 文档同步：`docs/待办实施计划.zh-CN.md` 新增 C-PVE24；`docs/待办对照代码核查.zh-CN.md` §表格与 §6.2 F4 条目已更新。
- **已 commit b1702540**（分支 kalevala，未 push）。

## valid_learn 全量迁移（已 commit 10068b35 + 03a0e120）
- 白名单 624 个已注册技能里 322 个源有非平凡 `valid_learn` → 全部 LPC 保真迁移（gen_valid_learn.py wave1 116 + wave2 178 + wave3 28 手写）。
- 审计工具 `gen_valid_learn.py --verify` + `verify_messages.py` 全部通过（322/322 零偏差）。
- 修复：`LearnGate.force_conflict/2` 特判 `@basic_force`（基本内功 force 放行）；`test_helper.exs` DB 不可用时跳过 Ecto sandbox。
- 注册 624 / 带 valid_learn 533（其余 91 个源内无门槛，无需迁）。
- 未 commit 部分：无（已全部提交）。

## F4 @static 白名单当前：733 唯一 id（与 733 `.ex` 模块一致，0 缺失 0 extra）。

## 进行中（已文档同步，待 commit）
- lingbo-weibu / huoyan-dao：valid_learn/2 + practice_cost/0 已迁，`mix compile` exit 0，测试无回归，待 commit。
- base 12 技能（dodge/parry/unarmed/sword/blade/strike/cuff/staff/hand/claw/finger + literate）：修复 valid_enable(_)->false 为 usage == "<技>"（literate 知识类保持 false，按 batch4 保真），补充 practice_cost() = %{qi:50, neili:30}，valid_learn 继承基类默认 :ok，moduledoc 已标 `**已迁移：**`。`mix compile` exit 0，character+combat 测试无回归，**文档已同步（C-PVE25 + 对照核查 §F4）**，待 commit。
- 技能 gap 重新评估：skills_gap_analysis.csv 已过时（300+ 技能已有 valid_learn/2）。comm 对比 LPC 源与 Elixir 模块后，仅剩无法立即迁的缺口：poison（性格门，meta.character 恒 nil，需 infra）、gun（wizardp 门，巫师技能）。其余 knowledge类均按 default :ok 正常。

## Docker 命令参考
- 启动：`docker compose -f docker-compose.dev.yml up -d`
- 编译体检：`docker compose -f docker-compose.dev.yml run --rm --no-deps -e MIX_ENV=test app mix compile`
- 测试：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres@db:5432/ex_venture_test app mix test <path>`
