# Workspace Memory — wuxia_mud_ex

## 🚨 首批动作
- 改 `.ucl` → 先读 `docs/UCL语法参考.zh-CN.md`；改 `.ex` → 先读 `docs/Elixir语法参考.zh-CN.md`。与实测冲突 → 实测后改文档。

## 宪章（最高优先级）
- LPC `C:\files\git\mud` → Kantele **完整移植**，零信息丢失（机制/顺序/阈值/文案/公式只多不少）。
- 「lpc 有 ex 无」→ 主动报告 + 建 Task + 写 `docs/*移植计划*.md`，严禁简化。

## 全量回归禁令（AGENTS.md §0.4 · 永久）
- **永不自行跑全量回归**。该跑的批次 → 登记 `docs/待全量回归清单.zh-CN.md` 后继续下一批；用户明确指示后才跑并回填。
- **定向测试不受限**，改动相关测试必须自己跑。

## Iron rules
- 改 `lib/**/*.ex` → 普通 `mix compile` 必过（`--warnings-as-errors` 会因基线告警失败，不要求）；改 `data/**/*.ucl` → `python scripts/validate_ucl.py <文件>` 必过。
- 无 commit/push 除非明确要求。改动前 Grep lib/test/docs + LPC 源确认真缺口。
- 回填 inquiries 后必 `git diff | grep '^-'` 审查：历史事故曾误删 NPC combat 块，战斗属性改动要加断言。
- `character_metadata_backup.sql` 启动时自动生成，提交前还原。

## 验证环境（Windows Git Bash）
- `PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH`；`MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=/c/files/git/wuxia_mud_ex/_build_win13`；`ERL_LIBS=$MIX_BUILD_PATH/lib`；`MIX_ENV=test`；**`ERL_CRASH_DUMP_BYTES=0` 必须**。
- 大测试文件整体跑易 OOM → 用 `mix test path:LINE` 或按 tag 隔离跑。

## 关键约定 / 坑
- UCL：块内赋值换行无逗号；数组末项**无尾逗号**；标识符不能含数字（`msg_one`）。`teach` 必须 wrapper `{family=... teach_skills={...} no_teach={...}}`；`teach_skills` 必须 `{max=N gongxian=0}`（裸数字归零）。
- `no_teach` flat list=仅展示；map/`unlock`=条件解锁（`require_mark_only` 只认 mark）；string=硬拒。`give_item` 负 `cost_gongxian` = LPC `add("gongxian",+N)`。
- inquiries 键 `_`→`-` 归一：`min_levels`/`level_deny`/`level_order`/`improve_skills`/`min_skills`/`min_skills_deny`/`recruit_skill_order`；**`min_skill_levels`（give_item）不归一**。`min_max_neili` 是下界。`no_family_check`/`master_id` 可能加载为字符串 `"true"`。
- **区域文件优先 clone_lib**（`dereference/3` 先查 zone.characters）；`IO.write` 中文 Windows 抛 `:no_translation` → 用 `File.write!/2`；无 `Path.join/3`/`File.rm/2`。
- **字面 `\n` 不换行**，显示文案一律别写。`Stats` 无 `:family`/`:max_neili`（测试用 `Map.put`）；`coagents` 加载为 string-key map；`recruit_gate?/3` 成功返回 `:ok`；收徒成功文案键 `accept_msg`。

## 引擎门速查
- **apprentice gate_order**（loader allowlist）：`permit_first`(默认)、`gender_first`、`lpc_xiaoyao`、`lpc_wuyazi`、`lpc_xuanming`、`lpc_mingjiao`、`lpc_ouyang`、`lpc_meizhuang`、`lpc_taohua`、`lpc_wudang`、`lpc_quanzhen`。默认 exp 在 skills 前；`lpc_xuanming`/`lpc_mingjiao` 是 shen→skills→exp；`lpc_ouyang` 是姓名→出身→叛门→他派→性别→exp。
- **inquiry grant gate_order**（另一套）：`lpc_masterd`(teach_pfm 逐字门序；`level_order`+`max-neili` 伪键；`no_family_check=true` ↔ `free:1`)、`lpc_kunlun`、`lpc_duan`、`lpc_emei`、`lpc_meizhuang`、`lpc_jiumozhi_fen/yan`、`lpc_hong`、`lpc_ouyang`(负 `max_shen`；勿与只有 min_shen 的 lpc_kunlun 混用)、`lpc_quanzhen`。
- `teach_pfm` 的 `neili` = `query("max_neili")`（masterd.c:201-205），UCL 写 `max-neili`。详细门序见 `lib/kantele/sect_master.ex`、`lib/kantele/world/loader.ex`、`test/kantele/world/*_test.exs`。

## 当前工作流
- Task #619 按门派顺序回填 UCL；已回填见 `docs/待全量回归清单.zh-CN.md` #1-#17；逐门缺口见 `docs/*教学门控移植计划.zh-CN.md`。
- 最近完成：明教（#932-#934）、慕容派（#763）、欧阳世家（#940-#943，GAP #961-#967 → Task #944-#950）。全真教审计完成（#951-#966），正在实现。
- daily log append-only。
