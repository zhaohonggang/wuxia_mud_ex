# Workspace Memory — wuxia_mud_ex（Elixir/Phoenix LPC MUD port）

## 项目宪章（最高优先级 · 2026-11-17 用户确立 · 永久生效）
- **完整移植** LPC `C:\files\git\mud` → `Kantele`，非简化重写，零信息丢失（ex ≥ lpc：机制/顺序/阈值/文案/公式只多不少）。
- 发现「lpc 有、ex 无」→ **主动报告用户 + 立即建计划**（TaskList + `docs/*移植计划*.md`），严禁简化或文本搪塞。
- 角色：资深项目经理 + 架构师 + 程序员；审计→计划→实现→回归→归档。积极、热心、不逃避。

## Iron rules
- 无 git commit/push 除非用户明确要求（2026-11-10 已授权「提交推送，然后继续推进」）。
- 改动前 Grep lib/test/docs + LPC 源确认真缺口，不臆造语义；不要升级 nimble_parsec。
- `character_metadata_backup.sql` 是游戏启动时自动生成的时间戳变更，不属任务产物，提交前还原。

## 验证环境（Windows Git Bash，Docker 不可用）
- `PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH`
- `MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=/c/files/git/wuxia_mud_ex/_build_win13`（绝对路径）；`ERL_LIBS=$MIX_BUILD_PATH/lib`；`MIX_ENV=test`。
- `mix compile` / `mix test --seed 831693`；全量约 9-10 min，建议后台重定向日志。
- 基线 27 failures 全为 `bcrypt_elixir` NIF 环境性；引擎/命令/技能/世界测试 0 失败。最新全量 7971/27（2026-11-19 前）。

## 关键约定 / 坑
- 路由：`parse/2` 裸路由只产 `%{"command"=>...}`；带参命令需 `optional(spaces() |> text(:rest|:target|:category))`。
- CommandProbe：白名单 `@whitelist %{}`；新命令回执不得含占位标记。
- daemon：GenServer 持 public ETS，直接 `:ets.insert`；`ensure!/0` 补建表。
- 人格字段 `meta.character`（非 personality）；玩家 nil ≡ LPC 0。
- 两条死亡管线：战斗击杀 `CombatEvent.die/3`；`smash`/房间 `break` → `Feature.Damage.die/2`；公共尸体 `Corpse.spawn/1`。
- 物品缓存 key `<zone>:<key>`；`is_player?/1` 认 `"player:"` 前缀；`receive_damage` 别传 killer。
- UCL 语法：块内赋值换行分隔且无逗号；数组末项不能带尾逗号；标识符不能含数字（用 `msg_one`）；无单独一行 `#`。
- **UCL `teach` 必须 wrapper**：`teach = { family = "..." teach_skills = { ... } no_teach = [...] }`；裸 `teach_skills` 被 loader 静默丢弃。
- `no_teach` 平坦 list → 仅展示；`no_teach` map → `no_teach_deny` 硬拒（华山 #742 已接消费端）。
- `inquiries` 的 `min_levels`/`level_deny` 等 map 键由 loader 归一 `_`→`-`；`min_skill_levels` 不归一。
- **区域文件优先于 clone_lib**：`dereference/3` 先用 `zone.characters`，找不到才回退 clone_lib。同名 NPC 同时存在于 `data/world/<zone>.ucl` 与 `clone_lib.ucl` 时，必须改区域文件才生效（wudang 教训）。
- `Elias.parse/1` 对 `value = { ... }` 字段解析正常；字段缺失先看是否被区域定义覆盖，不要盲目改 UCL 语法。
- `min_max_neili` 是 inquiry/apprentice 的下界字段；`max_neili_deny` 可覆写文案。
- `IO.write` 中文在 Windows 抛 `:no_translation` → 用 `File.write!/2`；`Path.join/3`、`File.rm/2` 不存在。
- 编辑被 `git checkout` 丢失时可从 session transcript jsonl 的 `function_call.arguments` 精确还原。

## 里程碑（已完成，免重复核查）
- A1/A2/A4、B1(22 命令桩)/B2(12 arch 命令)/B3、C 类跨角色同步全部清零。
- F4：@static 白名单 733；valid_learn 322/322；R5 动态招式表 33 技能。
- #640-644：剃度（峨嵋/血刀/雪山）、NAME_D（794f7972）、PKS/MKS/WPK 持久化（da85c8ba）、detach/betrayer 落盘（9c8c838f）、清无 gate_order。
- #695-698 新手拜师门派指南 39 门派配置（88d8520c）。
- #543 严格狩猎掉落（148390c8）；#724-729 全量回归 7941/27。
- Task #619 已回填：丐帮（c073fc77 等）、古墓（1a14da4c）、红花会（b7bfc2df）、关外胡家（#737）、华山 8 NPC（#740）、绝情谷 3 NPC（#745）、慕容 3 NPC（527c1621）、白驼 2 NPC（4b28b5a8）、全真 22 NPC、日月 7 NPC、昆仑（#750-#755）、少林（ca37e867）。
- #736 `min_dex` 门控 + `dex_deny`；#740 新增剑宗上限门控、`no_teach_deny`、直授/破式 handler；#745 `reject_master_name`/`no_min_shen`/`gate_order="lpc_masterd"`。
- 吴樂/名流/其他历史批次（详见 daily log）：拱猪子、死亡→地府→还阳、19/19 quarry NPC 掉落、猎人教 hunting。

## 已报告缺口（必须建计划，严禁简化）
- 关外胡家：#738 `recognize_apprentice` 按技能授课门控（cheng.c）；#739 `no_teach` 闭包解锁 `can_learn/hufei/*`。
- 华山：#741 `recognize_apprentice` 按技能门控（feng.c/linghu.c）；#742 `no_teach_deny` 消费端（已实现）；#743 独孤九剑按武器类型破式数组；#744 QUEST_D 历练问询 + `apprentice_available`。
- 绝情谷：#747 QUEST_D；#748 masterd `maxed`/`msg2` random 文案；#749 樊一翁 coagents。
- 日月：任我行 `ren.c` 有 ask_skill1~5 + inquiry + no_teach 但无 UCL 块（待新建任务）。
- 武当：见 `docs/武当派教学门控移植计划.zh-CN.md`（如存在）；`ask_jiuyang` 任务链解锁 + `try_to_learn_jy` 逐条门控、`recognize_apprentice` 按技能门控为已识别缺口。
- 计划文档：`docs/关外胡家教学门控移植计划.zh-CN.md`、`docs/华山派教学门控移植计划.zh-CN.md`、`docs/绝情谷教学门控移植计划.zh-CN.md`、`docs/日月教教学门控移植计划.zh-CN.md`。

## 当前工作流
- Task #619 按门派顺序回填 UCL 教学数据；状态以 TaskList 为唯一权威入口。
- 已保留缺失（非缺口）：柳溪 王重九无 LPC source；gaibang_jian 青竹令为升袋交互非技能授予。

## 归档
- `docs/` 78 份文档已扫描，59 份历史待办文档加「📌 归档声明」；`docs/待对照代码核查.zh-CN.md` §6.2 已标记完结。
- 历史会话日志在 `.workbuddy-ai/memory/YYYY-MM-DD.md`（append-only），超过 30 天蒸馏到本文件。
