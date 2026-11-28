# Workspace Memory — wuxia_mud_ex

## 宪章（最高优先级）
- LPC `C:\files\git\mud` → Kantele **完整移植**，零信息丢失（机制/顺序/阈值/文案/公式只多不少）。
- 「lpc 有 ex 无」→ 主动报告 + 建 Task + 写 `docs/*移植计划*.md`，严禁简化。

## 全量回归禁令（AGENTS.md §0.4 · 永久）
- **永不自行跑全量回归**。待跑批次 → 登记 `docs/待全量回归清单.zh-CN.md` 后继续下一批；用户明确指示后才跑并回填。
- **定向测试不受限**，改动相关测试必须自己跑。

## Iron rules
- 改 `lib/**/*.ex` → 普通 `mix compile` 必过（`--warnings-as-errors` 因基线告警不要求）；改 `data/**/*.ucl` → `python scripts/validate_ucl.py <文件>` 必过。
- 无 commit/push 除非明确要求。改动前 Grep lib/test/docs + LPC 源确认真缺口。
- 回填 inquiries 后必 `git diff | grep '^-'` 审查；战斗属性改动要加断言。
- `character_metadata_backup.sql` 启动时自动生成（gamestart 覆盖最新本地 DB 快照）；**不要还原**，每次 commit 顺便带上它（用户 2026-11-23 指定）。

## 验证环境（Windows Git Bash）
- `PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH`；`MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=/c/files/git/wuxia_mud_ex/_build_win13`；`ERL_LIBS=$MIX_BUILD_PATH/lib`；`MIX_ENV=test`；**`ERL_CRASH_DUMP_BYTES=0` 必须**。
- 大测试文件易 OOM → 用 `mix test path:LINE` 或按 tag 隔离跑。

## 关键约定 / 坑
- UCL：块内赋值换行无逗号；数组末项**无尾逗号**；标识符不能含数字。`teach` wrapper `{family=... teach_skills={...} no_teach={...}}`；`teach_skills` 必须 `{max=N gongxian=0}`。
- `no_teach` flat list=仅展示；map/`unlock`=条件解锁；string=硬拒。`give_item` 负 `cost_gongxian` = LPC `add("gongxian",+N)`。
- inquiries 键 `_`→`-` 归一：`min_levels`/`level_deny`/`level_order`/`improve_skills`/`min_skills`/`min_skills_deny`/`recruit_skill_order`；**`min_skill_levels`（give_item）不归一**。
- `no_family_check`/`master_id` 可能加载为字符串 `"true"`；`min_max_neili` 是下界。
- 区域文件优先 clone_lib（`dereference/3` 先查 zone.characters）；`IO.write` 中文 Windows 抛 `:no_translation` → 用 `File.write!/2`；无 `Path.join/3`/`File.rm/2`。
- 字面 `\n` 不换行；`Stats` 无 `:family`/`:max_neili`/`:master_id`（均由调用侧补进 stats map）；`coagents` 加载为 string-key map；收徒文案键 `accept_msg`。
- `recruit_gate?/3` 成功：缺省 `permit_first` 返回裸 `:ok`；自定义门序返回 `{:ok, text}`。测试别一律断言 `{:ok, text}`。
- `betrayed_sect?/betrayed_before?` 读 `meta.env.detach`/`meta.env.betrayer`（非 `meta.family`）。
- 房间级 UCL 不能写裸 `$n`/`$N`（validate_ucl.py Chars 对非 object_only 文件 exit 1；clone_lib.ucl object_only 豁免）。msg_one 写 `{npc}`/`{name}`。
- `message_sort` 模板必须原样传给 `MessageSort.run/3`（先替换 `{name}` 会让问询玩家见自己名字而非「你」）。
- Elixir 同 name/arity `defp` 是重定义（后者覆盖前者）→ 新 helper 必须唯一名。
- `rescue` 是保留字 → 形参/变量名须写 `rescue_cfg`。
- `Room.NameMatch.matches?/2` 只比 `character.name`，不查 aliases → 用 `CombatEvent.ally_matches?/2`。
- NPC 加载后 `stats.skills` 是 `%{}` → `SectMaster` 师父不高于学生门对 NPC 恒成立；同门非嫡传一律被 `Master.prevent_learn?` 拦。
- 收徒无 `apprentice` 块 ≠ 不收徒：`NpcFamilyEvent.apprentice/2` 只要 `teach.family` 存在就会收；LPC 仅 `teach` 的 NPC 须显式 `deny_all = true`。
- `engage/4` 在 `Kantele.World.Room.CombatEvent`；该模块内调 `tell_room` 必须 `Kantele.World.Room.tell_room/2`。
- **引擎门速查**：apprentice gate_order=`permit_first`(默认)/`gender_first`/`lpc_xiaoyao`/`lpc_wuyazi`/`lpc_xuanming`/`lpc_mingjiao`/`lpc_ouyang`/`lpc_meizhuang`/`lpc_taohua`/`lpc_wudang`/`lpc_quanzhen`/`lpc_ren`/`lpc_wudu`/`lpc_gaibang`/`lpc_gumu_yang`/`lpc_honghua_chen`/`lpc_honghua_yu`。收徒总闸：`apprentice.deny_all = true` + `deny_msg`（雪山剑派/凌霄城 12 个块全写）。授艺 recognize 四门：`require_master_name`→`min_shen`→`allowed_skills`白名单→`max_skill_level`。战斗互救：`meta.rescue` → `room.ex maybe_rescue_allies/4`。inquiry grant gate_order：`lpc_zhenyuan_tian`(天刀八势 family 三分支)/`lpc_masterd`/`lpc_kunlun`/`lpc_duan_yideng`(一灯双门派+贡献后置)/`lpc_duan`/`lpc_emei`/`lpc_meizhuang`/`lpc_jiumozhi_fen/yan`/`lpc_hong`/`lpc_ouyang`(负 max_shen)/`lpc_quanzhen`/`lpc_ren`/`lpc_honghua`。`teach_pfm` 的 `neili` = `query("max_neili")`，UCL 写 `max-neili`。
- `lpc_kunlun` opt-in 双技能存在门：`presence_skills` 列表 + `presence_deny` map 按序判 `<1`，
  逐字「未学」文案；缺省仍走单一 `skill`，与旧配置零回归（王剑英 #837）。
- `lpc_duan_yideng` 门序：`allowed_families` 双门派同门（未配置回退 `same_family?/2`）→
  `presence_skills` 两道技能门 → shen → force → max_neili → gongxian → 后天等级链
  （#845，一灯 ask_skill2 原序，贡献门在 max_neili 之后）。
- 收徒出生门：`required_born_family`/`born_family_deny` 在 `recruit_gate?/3` 中位于
  `betrayer/times` 之后、`other_family` 之前（duan.h/hu.h/miao.h/murong.h 原序）；未配置恒不命中。
  `lpc_ouyang` 有专属门序，不受这次前移影响（#843）。
- `give_item` 新 opt-in 字段：`master_before_gates` 只前移师父门、**不再关闭 gate 链**（#1188 已修）；
  `npc_say` 走 PubSub 广播 LPC `command("say")`，`silent_success` 抑制缺省私聊
  （两者均缺省关闭，#844 脉经启用）。`npc_say` 断言看 `conn.private.channel_changes`。
- `improve_skills` 数组每项 = 一次 `Stats.improve_skill/2`（+1 级）；LPC 重复
  `improve_skill(skill,1500000)` 必须用重复数组元素保留次数，不可折叠去重（#846）。
- `lpc_emei` 授艺 opt-in `require_master_id = true`（UCL 裸 true 加载为 `"true"`，引擎两种
  都吃）：门序=同门→直传弟子→技能存在→贡献→等级链→shen；调用侧须把
  `meta.family.master_id` 并入 player stats、`data.npc_id` 并入 npc stats，比较
  `master_id == npc_id`，文案键 `master_id_deny`（#852 风陵两招）。
- 峨眉剃度（`kind = "emei_tonsure"` / `NpcActions.EmeiKneel`，#853）：九名师太共用
  `tobebonze.h`；问询门序同门→已出家→女性，成功时 `npc_say` 广播 + 私发返回值两段输出；
  kneel 须按房间+NPC 身份过滤（共用别名「shitai」不参与匹配），法名=`灵/文/心/妙`+
  `purename`（缺省 `name`）首字，写 `marks.old_name`、`class=bonze`、`K_record=PKS+MKS`、
  `shen_record=旧 shen`、`shen=0`。

## 当前工作流
- Task #619 **已全部完成**（39 门派全部回填并验证）。无剩余门派。无 commit/push 除非明确要求（带上 `character_metadata_backup.sql`）。
- **GAP 已提交/推送**：#1032、#1040、#1041、#1042、#1045、昆仑 #756/#757/#758、#742、逍遥 #805/#806/#809/#810、#807 神仙环、#808 珍珑 pass_zhenlong、#798 大轮寺（95867f3a）、#796/#797 大轮寺（18d700c6）；**本次 8fa6baf6 追加**：门派批次 #1–#26（玄冥谷→少林）及其 GAP（#31–#54 侠客岛/星宿/特殊类均已随提交包含）。
- **27–54 批次全部验证通过**：2026-11-28 按顺序逐个运行定向测试，28 个批次全部 0 失败；第 51 批（峨眉 #854 静风给物）测试 setup 缺陷已修复（补充 `setup_all` 预加载 `emei:tianxiang_gao`/`emei:ruanjian` 到 `Kantele.World.Items` ETS 缓存），重跑后 11/0 通过。
- **GAP 已实现未提交**：（全部已随 8fa6baf6 提交推送，27–54 状态已在清单中标记 `✅ 已实现 · ⏳ 待全量回归授权`，当前无未提交 GAP）
- 待办：恒山 #863–#867 已完成并随 8fa6baf6 提交推送；无剩余门派。
- 坑：`give_item` 的 `owner_check` 等 UCL 布尔加载为字符串 `"true"` → 消费端须 `in [true, "true"]`；`gate_denial` 签名已改为 `/4`（多带 data 供 owner 快照）。
- 无 DB 跑纯函数测试：`mix run --no-start /tmp/<runner>.exs`（Code.require_file 指定测试文件）；涉及 `Items.get` 须先 `Kantele.World.Items.start_link(name: ...)` 并灌 `world.items`。
