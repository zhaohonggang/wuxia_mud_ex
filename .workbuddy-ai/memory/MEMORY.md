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
- `character_metadata_backup.sql` 启动时自动生成（gamestart 覆盖最新本地 DB 快照）；**不要还原**，每次 commit 都顺便带上它，以 git 历史保留最新数据（用户 2026-11-23 明确指定，覆盖旧「提交前还原」约定）。

## 验证环境（Windows Git Bash）
- `PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH`；`MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=/c/files/git/wuxia_mud_ex/_build_win13`；`ERL_LIBS=$MIX_BUILD_PATH/lib`；`MIX_ENV=test`；**`ERL_CRASH_DUMP_BYTES=0` 必须**。
- 大测试文件整体跑易 OOM → 用 `mix test path:LINE` 或按 tag 隔离跑。

## 关键约定 / 坑
- UCL：块内赋值换行无逗号；数组末项**无尾逗号**；标识符不能含数字（`msg_one`）。`teach` 必须 wrapper `{family=... teach_skills={...} no_teach={...}}`；`teach_skills` 必须 `{max=N gongxian=0}`（裸数字归零）。
- `no_teach` flat list=仅展示；map/`unlock`=条件解锁（`require_mark_only` 只认 mark）；string=硬拒。`give_item` 负 `cost_gongxian` = LPC `add("gongxian",+N)`。
- inquiries 键 `_`→`-` 归一：`min_levels`/`level_deny`/`level_order`/`improve_skills`/`min_skills`/`min_skills_deny`/`recruit_skill_order`；**`min_skill_levels`（give_item）不归一**。`min_max_neili` 是下界。`no_family_check`/`master_id` 可能加载为字符串 `"true"`。
- **区域文件优先 clone_lib**（`dereference/3` 先查 zone.characters）；`IO.write` 中文 Windows 抛 `:no_translation` → 用 `File.write!/2`；无 `Path.join/3`/`File.rm/2`。
- **字面 `\n` 不换行**，显示文案一律别写。`Stats` 无 `:family`/`:max_neili`（测试用 `Map.put`）；`coagents` 加载为 string-key map；收徒成功文案键 `accept_msg`。
- **`recruit_gate?/3` 成功返回值分两路**：缺省 `permit_first` 返回裸 `:ok`（`accept_msg` 由 `FamilyEvent` 渲染）；自定义门序（lpc_gaibang/lpc_gumu_yang 等）返回 `{:ok, text}`。测试别一律断言 `{:ok, text}`。
- **`betrayed_sect?/betrayed_before?` 读 `meta.env.detach` / `meta.env.betrayer`**（不是 `meta.family`）；`betrayer` map 带门名键先命中离派门，测判师次数用 `%{"times" => 2}`。
- **房间级 UCL 不能写裸 `$n`/`$N`**（`validate_ucl.py` Chars 对非 object_only 文件是 **exit 1 硬失败**；clone_lib.ucl 因 object_only 豁免）。msg_one 写 `{npc}`(=NPC)/`{name}`(=提问者)；`SectMasterGrant.render_msg1/2` 已同时替换 `{npc}/{name}` 与 `$n/$N`。
- **Elixir 同 name/arity 的 `defp` 是「重定义」**（仅告警、后者覆盖前者）→ 危险：新 helper 若与既有同名（如 `below_min_force?/2` 读 `min_force`）会被静默覆盖，务必改唯一名（任我行用 `below_min_force_level?/2`）。
- **`rescue` 是 Elixir 保留字** → 不能作形参/变量名。`loader.parse_rescue/1` 与 `room.maybe_rescue_allies/4` 都必须写 `rescue_cfg`（测试同名局部变量同理）。
- **`Room.NameMatch.matches?/2` 只比 `character.name`（中文名），不查 aliases** → 按别名找 NPC 会恒 false（凌霄城救场一度变空操作）。用 `CombatEvent.ally_matches?/2`（name + `meta.aliases` 小写）。
- **NPC 加载后 `stats.skills` 是 `%{}`**（NPC 技能在独立 `skills` 字段）→ `SectMaster` 的「师父不高于学生」门对 NPC **恒成立**；且同门非嫡传一律被 `Master.prevent_learn?` 拦。测试"通过路径"别指望 `:ok`。
- **收徒无 `apprentice` 块 ≠ 不收徒**：`NpcFamilyEvent.apprentice/2` 只要 `teach.family` 存在就会收。LPC 里只有 `teach`（无 `attempt_apprentice`）的 NPC（如石清）必须显式写 `deny_all = true`。
- **`engage/4` 在 `Kantele.World.Room.CombatEvent`**，不在 `Kantele.World.Room` → 该模块内调 `tell_room` 必须 `Kantele.World.Room.tell_room/2`。

## 引擎门速查
- **apprentice gate_order**（loader allowlist）：`permit_first`(默认)、`gender_first`、`lpc_xiaoyao`、`lpc_wuyazi`、`lpc_xuanming`、`lpc_mingjiao`、`lpc_ouyang`、`lpc_meizhuang`、`lpc_taohua`、`lpc_wudang`、`lpc_quanzhen`、`lpc_ren`、`lpc_wudu`、`lpc_gaibang`、`lpc_gumu_yang`、`lpc_honghua_chen`、`lpc_honghua_yu`。默认 exp 在 skills 前；`lpc_xuanming`/`lpc_mingjiao` 是 shen→skills→exp；`lpc_ouyang` 是姓名→出身→叛门→他派→性别→exp；`lpc_ren` 是 permit→max_shen→exp→int→any_min_skills(OR)；`lpc_gaibang` 是 permit→exp→shen→beggarlvl→skills→属性→max_neili；`lpc_gumu_yang` 是 permit→str→yunv-xinjing→max_neili；`lpc_honghua_chen` 是 permit→shen→exp→honghua-xinfa→max_neili；`lpc_honghua_yu` 是 permit 后再无条件拒（勿用 `deny_all` 跳过 permit）。
- **收徒总闸**：`apprentice.deny_all = true` + `deny_msg`（loader 解析 → `NpcFamilyEvent.apprentice/2` 直接回 deny_msg）。全派拒收的（雪山剑派/凌霄城）12 个块全写。
- **授艺 recognize 四门**（`teach.recognize`，`SectMaster.recognize_gate/3`）：`require_master_name`（比 `family.master_name`）→ `min_shen` → `allowed_skills` 白名单 → `max_skill_level`，逐条自定义 deny。仅对非嫡传生效。
- **战斗互救**：`meta.rescue { npc_ids, types, vision }` → `room.ex maybe_rescue_allies/4`（`engage/4` 尾部），`types` 默认 `["kill"]`，npc_ids 用 MapSet 按 pid 去重。
- **inquiry grant gate_order**（另一套）：`lpc_masterd`(teach_pfm 逐字门序；`level_order`+`max-neili` 伪键；`no_family_check=true` ↔ `free:1`)、`lpc_kunlun`、`lpc_duan`、`lpc_emei`、`lpc_meizhuang`、`lpc_jiumozhi_fen/yan`、`lpc_hong`、`lpc_ouyang`(负 `max_shen`；勿与只有 min_shen 的 lpc_kunlun 混用)、`lpc_quanzhen`、`lpc_ren`(贡献先于杀气、内力先于内功、force_deny/skill_level_deny 两档)、`lpc_honghua`(已会→同门→技能存在→贡献→侠义→前置绝招→有序等级链)。
- `teach_pfm` 的 `neili` = `query("max_neili")`（masterd.c:201-205），UCL 写 `max-neili`。详细门序见 `lib/kantele/sect_master.ex`、`lib/kantele/world/loader.ex`、`test/kantele/world/*_test.exs`。

## 当前工作流
- Task #619 按门派顺序回填 UCL；已回填门派（有 Task #619 提交 + plan doc，共 39 门派，全部完成）：丐帮/中原苗家/五毒教/侠客岛/全真教/关外胡家/凌霄城/华山/古墓派/唐门/商家堡/大理段氏/大轮寺/少林派/峨眉派/嵩山派/恒山派/慕容世家/日月教/桃花岛/武当派/灵鹫宫/玄冥谷/神龙教/红花会/绝情谷/血刀派/逍遥派/铁掌帮/镇远镖局/云龙(天地会)/星宿派/昆仑派/明教/欧阳世家(75c1bdd1)/大宗师ultra(7880db7e+540b4d0e)/地狱地藏王(register.ucl)/天龙寺/梅庄。见 git log `Task #619` / `feat(sects)` 系列提交；逐门缺口见 `docs/*教学门控移植计划*.md`。
- 逍遥派（Task #804）：9 个 NPC（fanbail/fengas/goudu/kanggl/shiqingl/suxingh/wulingj/wuyazi/xuemuh）的 teach + apprentice + sect_master_grant 均已回填至 `data/world/clone_lib.ucl`，已 commit `7649f464`；UCL 校验通过、`mix compile` 清白、`sect_master_test.exs` 121 测试 0 失败。UCL 数据层已完毕，不再需要重复实现。逍遥派 #805 铁八卦/布阵箱、#806 论语书、#809 coagents、#810 guarder/permit_pass 均已实现并验证（未提交，见日志）；剩余 engine GAP（非 UCL 数据）：无（#807 神仙环、#808 珍珑 pass_zhenlong 均已完成，见 2026-11-25.md）。
- **GAP 状态**：#1032（loader 不解析 `combat.jiali`）与 **#1040（NPC 顶层 `skills=[]` 解析）均已实现关闭**；#1040 实测 1,341 块/11,160 条 set_skill，`npc_stats/3` + `parse_npc_skills/1` 并入 Stats.skills/mapped，零 UCL 改动，全量登记 #28。**#1041 十八罗汉大阵已完成**（状态机+协调器+问询处理器+UCL 回填+33 测试全过，已 commit 369fbedd 并 push）。**#1042 渡厄物主遍历 give_item + accept_object、#1045 道果 follow + 道象2/清乐 give_item 门均已实现**（commit 548650d2/b94b39fe + #1082-#1086，见日志）。**昆仑 #756/#757/#758 均已实现**（#756 npc_item_grant handler + kunlun_liangji accept + 18 测试；#757 班淑娴/西华子 guarder + coagents + 9 测试；#758 动态敬称接入 greeting、何足道 alias 30% greeting、8 NPC 战斗闲聊 + 47 测试；plan doc 已同步；**已提交（commit 0a752b55，已 push）**）。两处可接受近似：#756 物主遍历用计数/背包近似、#758 何足道一拍延迟用即时广播。**#742 经复核已实现**（`sect_master.ex:61` 消费 no_teach_deny）。**逍遥 #805/#806/#809/#810 均已实现**（npc_item_grant fallback/random 初值、苏星河 guarder 自定义门+qingcaop in 方向、coagents 回填；`xiaoyao_guarder_test` 11/11、`xiaoyao_item_grant_test` 11/11、`guarded_exit_runtime_test` 32/32；**已提交（commit 0a752b55，已 push）**）。**#807 神仙环 owner traversal、#808 珍珑 pass_zhenlong 均已完成（2026-11-25，已 commit 0a752b55 并 push）**。
- **give_item 前缀坑**：handler 自动给 `family_deny`/`already` 前缀「大侠」，**不加**到 `min_skill_deny`。
- **共享别名坑**：道相(dao_xiang)与道象2(dao_xiang2) 共享别名 "daoxiang chanshi" → 测试须用块 id 别名（`"shaolin_dao_xiang2"`）精确定位。
- **待办**：Task #619 **无剩余门派**——全部 39 门派已回填并验证通过。此前记录的「剩余 4 个」（地狱地藏王、大宗师ultra、天地会、欧阳世家）经审计均已提交并通过测试，见上文已更正。雪山剑派无独立 plan doc（仅剃度/守卫提交），是否纳入 Task #619 需用户确认。无 commit/push 除非明确要求（届时带上 `character_metadata_backup.sql`）。
- daily log append-only。
- 2026-11-25：GAP #798 大轮寺剃度/kneel 流程已完成并 push（commit 95867f3a）：新增 XueshanTonsure 问询处理器 + XueshanKneel NPC 动作，4 房间注册，clone_lib.ucl 4 名 NPC inquiries 回填，23 测试全过，validate_ucl + mix compile 干净。见 2026-11-25.md 第 9 条。
- 2026-11-25：GAP #796/#797 已完成并 push（commit 18d700c6）：XueshanMidao 私有密语 + XueshanLun 全部门序/持有者分支，zhihuan_owner 扩展到 xueshan_lun，clone_lib.ucl 3 个 GAP 占位转真实配置；21 定向 + 59 邻近回归全过，validate/compile/format 通过；全量登记待回归清单 #30。见 2026-11-25.md 第 10 条。
