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
- **房间级 UCL 不能写裸 `$n`/`$N`**（`validate_ucl.py` Chars 对非 object_only 文件是 **exit 1 硬失败**；clone_lib.ucl 因 object_only 豁免）。msg_one 写 `{npc}`(=NPC)/`{name}`(=提问者)；`SectMasterGrant.render_msg1/2` 已同时替换 `{npc}/{name}` 与 `$n/$N`。
- **Elixir 同 name/arity 的 `defp` 是「重定义」**（仅告警、后者覆盖前者）→ 危险：新 helper 若与既有同名（如 `below_min_force?/2` 读 `min_force`）会被静默覆盖，务必改唯一名（任我行用 `below_min_force_level?/2`）。

## 引擎门速查
- **apprentice gate_order**（loader allowlist）：`permit_first`(默认)、`gender_first`、`lpc_xiaoyao`、`lpc_wuyazi`、`lpc_xuanming`、`lpc_mingjiao`、`lpc_ouyang`、`lpc_meizhuang`、`lpc_taohua`、`lpc_wudang`、`lpc_quanzhen`、`lpc_ren`。默认 exp 在 skills 前；`lpc_xuanming`/`lpc_mingjiao` 是 shen→skills→exp；`lpc_ouyang` 是姓名→出身→叛门→他派→性别→exp；`lpc_ren` 是 permit→max_shen→exp→int→any_min_skills(OR)。
- **inquiry grant gate_order**（另一套）：`lpc_masterd`(teach_pfm 逐字门序；`level_order`+`max-neili` 伪键；`no_family_check=true` ↔ `free:1`)、`lpc_kunlun`、`lpc_duan`、`lpc_emei`、`lpc_meizhuang`、`lpc_jiumozhi_fen/yan`、`lpc_hong`、`lpc_ouyang`(负 `max_shen`；勿与只有 min_shen 的 lpc_kunlun 混用)、`lpc_quanzhen`、`lpc_ren`(贡献先于杀气、内力先于内功、force_deny/skill_level_deny 两档)。
- `teach_pfm` 的 `neili` = `query("max_neili")`（masterd.c:201-205），UCL 写 `max-neili`。详细门序见 `lib/kantele/sect_master.ex`、`lib/kantele/world/loader.ex`、`test/kantele/world/*_test.exs`。

## 当前工作流
- Task #619 按门派顺序回填 UCL；已回填见 `docs/待全量回归清单.zh-CN.md` #1-#19；逐门缺口见 `docs/*教学门控移植计划*.md`。
- 最近完成：欧阳世家（#940-#943，GAP #961-#967）、全真教（#951-#966 + 引擎，GAP #968-#978）、**日月教任我行 ren.c（#19，lpc_ren 引擎 + `characters "ren"` 就地扩展，GAP：NPC score/prepare_skill/message_sort 反置/emote/色号）**。
- **待办**：按 Task #619 顺序推进下一门派（`kungfu/class/` 下尚未回填者，先审计确认）。
- daily log append-only。
