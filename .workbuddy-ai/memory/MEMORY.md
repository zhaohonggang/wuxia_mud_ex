# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- 无 git commit/push 除非用户明确要求。
- 无本地 Erlang → Docker 是唯一验证路径：
  - 编译：`docker compose -f docker-compose.dev.yml run --rm --no-deps -e MIX_ENV=test app mix compile`（exit 0 即可，warning 忽略）。
  - 测试：`docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`
- 改动前 Grep lib/test/docs + LPC 源 /c/files/git/mud/kungfu/skill/ 确认真缺口。
- 不要升级 nimble_parsec。

## 已结案（已 push 到 origin/kalevala）
- R5 动态招式表迁移：92 真缺口全部迁移（b490fbb2）。
- F4 @static 白名单补全：733 唯一 id 与 .ex 模块一致（b1702540，未 push）。
- valid_learn 全量迁移 + 长尾批次1-3（7a609e9c/4534d108 已 push）。
- A3 f1 Diff-stop：kickoff.ex cleanup_stale_processes 等；ZoneSupervisor/Room 必须 terminate_child 正常摘除（详见 2026-11-05.md）。已 push。
- Task #302-317：锁阳丹/转世门控/张三丰鹤嘴劲/4 个 AskHandler 真化（540b4d0e/938d6340/e1848f4b 已 push）。
- B1 stub 真化 batch1：talk/ansuan/top/push/hand/secularize（e1848f4b 已 push）。
- B1 stub 真化 batch2：remove/top2/topp/驯兽五/special/stab/touch + 新增 FameBoard/FamilyFame/ItemUse/SpecialSkill/BeastState/BeastTaming（已随本轮提交并 push，见 git log）。

## 人格（personality）建模——已定案
- 规范字段 = meta.character（PlayerMeta moduledoc 第12行；poison.ex 读 character.meta.character；LearnCommand 下发作 student_character）。
- LPC set("character",...) 仅 2 处：NPC 注册 + 转世(updated.c:515「国士无双」)。玩家侧未设=nil≡LPC 0：排除门(==X 则拒)→nil 不拦；包含门(!=X&&!=Y 则拒)→nil 拦（4 个转世专属）。
- 批前 32 文件误读 meta.personality→已改 :character。Combat.@applies_keys 的 :personality 是另一概念（人格魅力/镶嵌），不动。
- marks 随 skills/learn 下发(student_marks)，mark 门才真正生效。

## @static 白名单：733 唯一 id（与 .ex 模块一致，0 缺失 0 extra）。

## B1 自包含占位桩 — 全部真化完毕
- CommandProbe.stubs/0 实测剩余 6 占位：answer/pkd/to/vote/scheme/clone。B1 范围内自包含可独立真化命令已全部清零。
- 剩余 6 全依赖未建后端（见 docs/remaining-work-checklist.zh-CN.md B4 小节）：answer(聊天配对)/pkd(PK场)/scheme(计划执行器)/to(聊天·邮件)/vote(投票)/clone(巫师命令)。
- 原 B1 收尾 (M3)/(M4)/(W2) tag 错误（与 MIGRATION_PLAN.md 不符），已改描述性子系统名。
- CommandProbe 是纯文本标记扫描（暂未开放/暂未实现/尚未开放/系统暂未）；6 stub 仅由占位文案触发，command_probe_test 白名单严格一致。

## 路由死代码修复（重要）
- parse/2 裸路由只产 %{"command"=>...}，带参命令(run/2 需 rest/target/category)不可达。统一 optional(spaces+text(:rest|:target|:category))；SecularizeCommand.run/2 的 %{} 前置子句改通配 _params。新增带参命令务必检查。

## 验证路径（2026-11-08 起 Docker 不可用）
- win_toolchain.cmd 被安全策略拦；改用 Git Bash 手设 OTP25+Elixir1.13.4（PATH/MIX_HOME/MIX_BUILD_PATH=_build_win13/ERL_LIBS/MIX_ENV=test）。
- mix test 别名强依赖 Postgres（无）→ mix run -e + Code.require_file("test/test_helper.exs") + ExUnit.configure(seed:N)+ExUnit.run()；纯函数 harness 手起 Items/League/FamilyFame。

## 已知遗留（跨会话）
- valid_learn 真实缺口 21→2：仅 hunyuan-yiqi(guilty 未建模)、qiankun-danuoyi(query_condition 未建模)。批次4-7 已提交。
- 全量套件 105 个既有失败（ForceRegenerate 模块缺失 / 测试传裸 map 而 impl 要 Stats 结构体 / chongling-jian 空手期望），与 B1 无关。
- meta.character 运行态不落盘、无玩家侧赋値入口（转世未实现）→ 4 个包含门技能当前不可学（与 LPC 一致）。
- 详细日志见 .workbuddy-ai/memory/2026-11-{01,02,05,08}.md。
