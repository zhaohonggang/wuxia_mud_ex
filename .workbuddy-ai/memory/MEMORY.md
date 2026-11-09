# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- 无 git commit/push 除非用户明确要求。
- 改动前 Grep lib/test/docs + LPC 源 /c/files/git/mud/kungfu/skill/ 确认真缺口。
- 不要升级 nimble_parsec。

## 验证路径
- Docker 可用时：compile = `docker compose -f docker-compose.dev.yml run --rm --no-deps -e MIX_ENV=test app mix compile`；test = `... run --rm -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test <path>`。
- Docker 不可用（2026-11-08 起）：Git Bash 手设 OTP25+Elixir1.13.4 — `PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin`；`MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=_build_win13`；`ERL_LIBS=_build_win13/lib`；`MIX_ENV=test`。测试无 Postgres → `mix run --no-start -e 'ExUnit.start(); Code.require_file("test/test_helper.exs"); ExUnit.run()'`；纯函数 harness 手起 Items/League/FamilyFame。

## 人格（personality）建模——已定案
- 规范字段 = meta.character（PlayerMeta moduledoc 第12行；poison.ex 读 character.meta.character；LearnCommand 下发作 student_character）。
- LPC set("character",...) 仅 2 处：NPC 注册 + 转世(updated.c:515「国士无双」)。玩家侧未设=nil≡LPC 0：排除门(==X 则拒)→nil 不拦；包含门(!=X&&!=Y 则拒)→nil 拦（4 个转世专属）。
- 批前 32 文件误读 meta.personality→已改 :character。Combat.@applies_keys 的 :personality 是另一概念（人格魅力/镶嵌），不动。marks 随 skills/learn 下发(student_marks)，mark 门才真正生效。

## @static 白名单：733 唯一 id（与 .ex 模块一致，0 缺失 0 extra）。

## 已结案（已 push 到 origin/kalevala，除非标注未 push）
- R5 动态招式表迁移（b490fbb2）。
- A3 f1 Diff-stop：kickoff cleanup_stale_processes（ZoneSupervisor/Room 须 terminate_child 正常摘除，不可 :kill）。
- Task #302-317：锁阳丹/转世门控/张三丰鹤嘴劲/4 个 AskHandler 真化（540b4d0e/938d6340/e1848f4b）。
- B1 stub 真化 batch1：talk/ansuan/top/push/hand/secularize（e1848f4b）；batch2：remove/top2/topp/驯兽五/special/stab/touch（含 FameBoard/FamilyFame/ItemUse/SpecialSkill/BeastState/BeastTaming）。
- F4 @static 白名单补全（733 id，b1702540，未 push）+ valid_learn 全量 + 长尾批次1-3（7a609e9c/4534d108 已 push）。

## B1 自包含占位桩 — 全部真化完毕
- CommandProbe.stubs/0 已清零（0 占位）：to 于 Phase 5 S3 真化，clone 于 Phase 8 S6 真化。`test/kantele/command_probe_test.exs` 白名单 `@whitelist %{} `与之严格一致。
- CommandProbe 是纯文本标记扫描（暂未开放/暂未实现/尚未开放/系统暂未）；stub 仅由占位文案触发，command_probe_test 白名单严格一致。
- **`scheme`（计划执行器）已于 2026-11-09 真化**（S5，B5 Phase 2，未 commit/push）：`scheme start` 落地 LPC 全部门控 + REPEAT/LOOP/BREAK 控制流 + cmd:case 失败动作（RETRY/CONTINUE/BREAK/IGNORE/默认 fallback）；`lib/kantele/character/{scheme.ex(纯引擎),scheme_step_event.ex(定时步进),scheme_command.ex(start/stop/halt)}`，events.ex 已注册 character/scheme_step。测试 41/0（含 command_probe）。已知差异：Vitals 无 food/water→饥饿门跳过；doing 态用 conn.private[:scheme]（运行期不落盘）；CLOSE_D user_closed/opened 未耦合（closed 命令本身仍 stub）。
- **Phase 3 — S7+E2 / S8+E3 已于 2026-11-09 完成（未 commit/push）**：
  - S7/E2 转世 + `meta.character` 落盘：`Reborn.zhuan_player` → `set_reborn_identity` 置 `meta.character="国士无双"`，`trigger/1`→`Records.save` 写 `character_metadata.personality`，`apply_to_character` 重登恢复。`reborn_includes_gate_test.exs` 5/0，4 包含门技能解锁与 LPC 一致。
  - S8/E3 戒律 `guilty` 写入：新增 `lib/kantele/character/precepts.ex`（`violate/2`/`guilty_of/1`/`clear/1` + `meat_item?/1`/`monk_name?/`）；`PlayerMeta` 新增 `:guilty: 0`（已修正不落盘的陈旧注记）；`Metadata` schema + `save/1` + `apply_to_character` 镜像 `personality` 模式读写 `character_metadata.guilty`；新增迁移 `20261109000000_add_guilty_to_character_metadata.exs`。写入端：`eat_command.ex`（食肉 `:eat_meat` +1）、`combat_event.ex:enemy_died`（击杀僧侣 `:kill_monk` +1）。读取端 `hunyuan-yiqi` / `buddhism` `guilty_of` 自动生效，guilty>0 时真正拦截。`precepts_test.exs` 12/0。

- **Phase 4 — S1 聊天 ask/answer 配对（已完成）**：
  - `lib/kantele/character/commands/answer_command.ex`：forge 路径保留；新增 quest_gift Y/N（`meta.temp[:quest_gift]` → `Stats.gongxian` 扣点 + `Items.get!/1` 发放）与 `answer_you` 房间广播；返回 `{:ok, conn}`；stub 文案改为「回答系统目前不支持该选项」避免 CommandProbe 误报。
  - `lib/kantele/character/commands/shop_commands.ex`：`AskCommand.handle_quest_gift_offer/3` — `ask <npc> quest` 且 NPC `meta.quest_gift` 存在时，在 asker 写入 `temp[:quest_gift]`，输出 "answer Y/N" 提示。
  - `lib/kantele/character.ex`：`NonPlayerMeta` 新增 `{:quest_gift, nil}` 字段。
  - 新建 `test/kantele/character/commands/answer_command_test.exs`：18 例全绿。
  - `test/kantele/command_probe_test.exs`：移除 `"answer_command"` 白名单条目。
  - `mix compile` exit 0；25 个测试全绿。未 commit/push，待授权。

- **Phase 6 — S2 PK 场 daemon（`pkd`）已完成**：
  - 新建 `lib/kantele/character/pkd.ex`：GenServer + ETS 表 `:kantele_pkd`，赛事状态机（`:none`/`:ready`/`:starting`/`:pking`），竞争者列表；`is_ready/0`、`is_pking/0`、`query_all_competitor/0`、`reject_join/1`、`join/1`、`quit/1`、`set_state/2`。
  - 重写 `lib/kantele/character/commands/pkd_command.ex`：`pkd` 显示赛事状态 + 竞争者列表；`pkd join` 报名；`pkd quit` 退赛。
  - `lib/kantele/world/npc_actions/sign.ex`：`do_sign` 接入真实 `Pkd.reject_join/1`。
  - 新建 `test/kantele/character/pkd_command_test.exs`：11 例全绿。
  - `test/kantele/command_probe_test.exs`：移除 `"pkd_command"` 白名单条目。
  - `mix compile` exit 0；13 个测试全绿（pkd_command / command_probe）。未 commit/push，待授权。

- **Phase 7 — S4 投票 daemon（`vote`）已完成**：
  - 新建 `lib/kantele/character/vote.ex`：GenServer + ETS 表 `:kantele_vote`，动议状态机（`:active`/`:passed`/`:failed`/`:finished`），`is_voting?/0`、`query_all_votes/0`、`create_vote/3`、`cast_vote/2`、`tally/1`、`cancel_vote/1`；读缺省/写静默 no-op，测试可 `ensure!/0`。
  - 重写 `lib/kantele/character/commands/vote_command.ex`：`vote` 显示动议列表；`vote chblk/unchblk <某人>` 发起或附议；重复发起自动转附议；自身动议不可自附议。
  - `lib/kantele/character/commands.ex`：`VoteCommand` 路由改 `optional(empty() |> spaces() |> text(:rest))`。
  - 新建 `test/kantele/character/vote_command_test.exs`：16 例全绿。
  - `test/kantele/command_probe_test.exs`：移除 `"vote_command"` 白名单条目。
  - `mix compile` exit 0；16 个测试全绿（vote_command / command_probe）。未 commit/push，待授权。

- **Phase 8 — S6 生物克隆（`clone` 命令生物部分）已完成**：
  - `lib/kantele/world.ex`：新增 `find_npc_definition/1` —— 按 `"zone:name"` 精确 id 或 name 在 ZoneCache 里检索 NPC 定义（LPC `clone.c` 的 `new(file)` 等价）。
  - `lib/kantele/character/commands/clone_command.ex`：`find_target/1` 先检 NPC 定义再检物品；新增 `handle_character_clone/2` —— 拷贝 NPC 定义，重设 `id: Character.generate_id()` 与 `room_id` 为施法者所在房间，巫师门控保留；物品克隆分支不动。
  - `lib/kantele/character/commands.ex`：`CloneCommand` 路由改 `optional(empty() |> spaces() |> word(:target))`，裸 `clone` 与 `clone <target>` 皆可达。
  - 新建 `test/kantele/character/clone_command_test.exs`：10 例全绿。
  - `test/kantele/command_probe_test.exs`：白名单 `@whitelist %{} `（移除 `clone_command`）。
  - `mix compile` exit 0；clone_command_test 10/0 + command_probe_test 2/0。未 commit/push，待授权。

## 路由死代码修复（重要）
- parse/2 裸路由只产 %{"command"=>...}，带参命令(run/2 需 rest/target/category)不可达。统一 optional(spaces+text(:rest|:target|:category))；SecularizeCommand.run/2 的 %{} 前置子句改通配 _params。新增带参命令务必检查。

## 已知遗留（跨会话）
- valid_learn 真实缺口已收至 0：hunyuan-yiqi 的 guilty 经 S8/E3 已有真实写入路径，guilty>0 时真正拦截；qiankun-danuoyi 的 query_condition 经 E1 接入（learn_command/skills_event 在调 valid_learn 前把 session conditions 以 :conditions 并入 character）。
- **E4 既有套件失败清理已完成（2026-11-09）**：全量 seed 831693 下 **105 → 27**。E4 收口时 `7370 tests`；E5 落地 `wiz_arch_test.exs`（14 例）后升至 **7382 tests, 27 failures**。剩余 27 例**全部为环境性**——`bcrypt_elixir 2.3.0` NIF 在 Windows 本地未编译（`deps/bcrypt_elixir/priv/` 空、无 gcc/cc/make/cl），级联打挂所有建用户/改密码的 `Web.*`/`ExVenture.*` 用例；容器/CI 中 NIF 可编译、自然通过。引擎/命令/技能/世界测试 **0 失败**。E4 工作**未 commit/push**（iron rule）。
- **E5（W3 arch 14 命令）已完成（2026-11-09，未 commit/push）**：14 命令全部显式化——非巫师 `Access.wizardp/1` 拒绝、巫师明确回执；新增共享 `wiz_arch.ex`（`guard/3` + `not_modeled/2`，注释避开 CommandProbe 5 个占位标记）。真化 2 条：`var`（`PlayerMeta.put_temp` 读写 `meta.temp`）、`setsk`（`Stats.set_skill/3` 写 `meta.stats` + `Records.save/1`）。其余 12 条（`build/call/changeuser/grant/possess/purge/reboot/register/restore/shutdown/smash/throw`）属对象系统管理面、本端口无引擎能力 → 显式「W3 对象系统未建模」回执 + Deferred（有意保留，非隐藏桩）。验证：定向 `wiz_arch_test` 14/0、`set_command_test` 3/0、`command_probe_test` 2/0（白名单 `@whitelist %{}`）；全量 **7382 tests, 27 failures**，27 例与 E4 基线完全一致（bcrypt 环境性），grep E5 命令命中 NONE → 0 新增回归。B5 文档第 6 节已记执行记录。

- **B1 `suicide` 已真化（2026-11-09，未 commit/push）**：LPC `cmds/usr/suicide.c` 落地 `suicide -f <密码>` → 校验 `meta.password`（明文，由 `passwd` 写入；本端口未引入 bcrypt，沿用既有约定）→ `ExVenture.Characters.delete_by_name(name)` 链删 Character + PlayableCharacter（新增 `delete_by_name/1`：按 name 查、缺失返回 `{:error,:not_found}`、DB 异常 `rescue` 降级）→ 房间「化作轻烟」广播（排除自身）+ combat_exp>=1000 时 `Communication.announce("rumor", ...)`。删除后告别语 + `halt()` 断开。`PlayerMeta` 新增 `:password` 字段（`passwd_command` 此前因缺字段调 `%{meta|password:}` 会崩，顺手修复）。15 秒 `halt` 倒计时窗口为有意简化（与端口单步命令模型一致）。`suicide_command_test.exs` 7/0。全量复跑预期 7382/27、无新增回归（进行中）。
- meta.character 已落盘（character_metadata.personality，转世置"国士无双"），4 包含门技能转世后即可学（与 LPC 一致）。
- 详细日志见 .workbuddy-ai/memory/2026-11-{01,02,05,08,09}.md。
