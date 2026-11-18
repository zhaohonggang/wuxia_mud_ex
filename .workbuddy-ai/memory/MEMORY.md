# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## 项目宪章（最高优先级 · 2026-11-17 用户确立，详见 AGENTS.md §0）
- **完整移植**：LPC 原版 `C:\files\git\mud` → ex（Kantele），非简化重写。
- **结果标准**：最终 ex 内容 **≥** lpc，零信息丢失（机制/顺序/阈值/文案/公式只多不少）。
- **缺口主动报告 + 建计划**：发现「lpc 有、ex 无」必须主动报告用户并立即建立移植计划（任务列表 + `docs/*移植计划*.md`），禁止沉默略过或用「简化/降级/备注」搪塞。
- **长期工程禁止简化**：绝不为省时间/省工作量选简化方案；有疑问回 LPC 源码逐条核对。
- **角色**：资深项目经理 + 架构师 + 程序员，精通项目设计与编程，工程化推进（审计→计划→实现→回归→归档）。
- **性格**：积极、热心、爱多做工作；遇困难障碍积极耐心解决，不逃避、不偷懒。

## Iron rules
- 无 git commit/push 除非用户明确要求（2026-11-10 已授权「提交推送，然后继续推进」）。
- 改动前 Grep lib/test/docs + LPC 源 `/c/files/git/mud` 确认真缺口，不臆造语义。
- 不要升级 nimble_parsec。

## 阅读约定
- `.workbuddy-ai/memory/YYYY-MM-DD.md` 是按日追加的流水账，中间状态可被本文件「已完成」章节推翻。
- 唯一状态入口 = 本文件「已完成 / 净增量归档」+ `docs/待办对照代码核查.zh-CN.md` §三 / §6.2。

## 验证路径
- Docker 不可用（Windows Git Bash）：`PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH`；`MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=_build_win13`；`ERL_LIBS=_build_win13/lib`；`MIX_ENV=test`。
- `mix compile` / `mix test --seed 831693`（全量约 9-10 min，建议后台重定向日志）。
- 基线：7830 tests / 27 failures / 575.6s（全为 `bcrypt_elixir` NIF 环境性，引擎/命令/技能/世界测试 0 失败）。

## 关键约定 / 坑
- 路由：`parse/2` 裸路由只产 `%{"command"=>...}`；带参命令需 `optional(spaces() |> text(:rest|:target|:category))`。
- CommandProbe：扫描占位标记；白名单 `@whitelist %{}`（0 占位）。新命令回执不得含占位标记。
- daemon：GenServer 持 public ETS，写入直接 `:ets.insert`；`ensure!/0` 补建表；`read_state/0` 表缺失返缺省。
- 人格：字段 `meta.character`（非 personality）；玩家 nil ≡ LPC 0。
- `@static` 白名单 733 唯一 id，与 `.ex` 模块一致（0 缺失 0 extra）。
- suicide：`meta.password` 明文校验 + `Characters.delete_by_name/1`（rescue 降级）。
- 两条死亡管线：正常战斗击杀走 `CombatEvent.die/3`；`smash`/房间 `break` 走 `Feature.Damage.die/2` → `process_death/2`。公共尸体逻辑在 `Kantele.World.Corpse.spawn/1`。
- 物品缓存 key 是 `<zone>:<key>`；动态生成的 `Item.Instance` 要用完整 key。
- UCL 不能有单独一行的 `#`（空注释）。
- UCL 块内赋值必须**换行分隔、不能写逗号**：`teach_skills = { force = { max = 30 gongxian = 2 } }` 会报 `syntax error before: ","`；正确写法是 max/gongxian 各占一行且赋值间无逗号（仅数组元素 `[ {...}, {...} ]` 用逗号）。
- `is_player?/1` 认 `"player:"` 前缀；`receive_damage` 别传 killer。
- `zone.items` 缺 `:items` key 时抛 KeyError；改用 `Map.get(zone, :items, %{})`。
- `IO.write` 在 Windows 下对中文抛 `:no_translation`；改用 `File.write!/2` 追加。
- `Path.join/3` 不存在，用 `Path.join([...])`；`File.rm/2` 不存在，用 `File.rm!/1`。
- `String.to_integer/1` 返回裸整数，用 `is_integer()` 保护；`List.to_atom/1` 不接受字符串。

## 已完成（免后续重复核查）
- A1/A2/A4：已清零；e/g/h 期：用户确认已完成。
- A3/B5 Diff-stop：`kickoff.ex` `cleanup_stale_processes/1` 已真化，`handle_continue(:load)` 走 `safely/1`。
- B1 命令桩（22 个）：全部真实实现，无占位标记。
- B2 W3 arch 命令：12 个已落地；`build` 保留 `not_modeled`。
- B3 prepare/scheme/uptime/special/suicide/clone：全部完整实现。
- C 跨角色同步/饥饿口渴/门派学徒/门容器/一次性场景/通信中继载具：全部落地。
- O2 留言板；O3 门 v1；O4 food/water；O5 gift 先天赋值。
- T1 LPC→UCL 转换器 + 189 `.ucl`；T2 柳溪镇 34 文件对拍；T4 e2e 夹具。
- F4 武功迁移：@static 白名单 733；70 空壳 + 202 无招式已核实；R5 92 真缺口已全部迁移；valid_learn 322/322 全量迁移。
- 拱猪子系统：pig_room/pig_game/pig_table 均实装。
- 死亡→地府→还阳：combat_event.die/3 + revive/2 + niutou AskHandler + death.ucl，测试全绿。
- 尸体/NPC 掉落系统：corpse.ex + drop_a/b/c + power，19/19 quarry NPC 已移植，测试全绿。
- 猎人 NPC 教 hunting：hunter.ex AskHandler + hunting.ex valid_learn/2 + eat_command.ex raw_meat 门控，50 例全绿。
- 三项遗留待办（2026-11-15）：Set Grant as wizard / 世界位置文档 / 位置加到 goto 命令 — 全部结案。
- LPC 式随机鬼魂名字（2026-11-16）：`random_ghost_name/1` + death.ucl 18 NPC `random_name_type = "ghost"`，全量回归 7830 tests / 27 failures，0 新增失败。
- ask 黎生 五丁开山 / 绝命一踢（sect_master_grant）：inquiry_handler 注册 + UCL 配置，99 例测试 0 失败。
- 随机 NPC 名字生成（2026-11-16 已提交推送，commit 1c017236 + fa11948a）：`NameGenerator` 新增 `random_ghost_name/1`、`random_biaoshi_name/1`、`random_biaotou_name/1`；`loader.ex` `parse_character/4` case 匹配 `"ghost"`/`"cn"`/`"biaoshi"`/`"biaotou"`；`death.ucl` 18 HellZhen NPC `ghost`；`gaibang.ucl` 7 丐帮弟子 `cn`；`changan.ucl` 镖师 `biaoshi`、镖头 `biaotou`，总镖头 `万青山` 保留不变。
- AskCommand.find_ask_npc/2 前缀匹配修复（commit 3afb4171）：测试 9/9 全绿，全量 7830 tests / 27 failures（基线一致，0 回归）。
- LPC→UCL 教学数据补全（Tasks #613–#618）：10 个 NPC 的 `teach_skills`/`apprentice` 已回填；`inquiries` 已转为绝招授予；`docs/新手拜师门派指南.zh-CN.md` 已重写（12 个师父条目）。
- 柳溪派 `wangshifu`：无 LPC source 可供 `apprentice` 块数据，保留缺失，非代码缺口，无待办。
- sects.ex 门派原型按 LPC 对齐（commit 1416f7b1）：补全 18 个缺失门派，总数从 21 扩至 39，与 LPC `class_generate_chinese.c` init_family 完全对齐。
- 门派原型详细配置章节（commit 67da804d）：`docs/新手拜师门派指南.zh-CN.md` 新增第6节，列出全部 39 个门派的详细配置（class/scale/skills/maps/preps/carry）。
- #641 NAME_D 姓名注册表（commit 794f7972）：`lib/kantele/world/name_d.ex`（GenServer+ETS，remove_name/map_name/invalid_new_name/change_name/who_is，JSON 持久化），接线 `shaolin_kneel.ex` 剃度改名与 `family_event.ex` 辈分晋升改名，测试 15/0，全量回归 7904/27（0 新增回归）。
- 少林派阶段 A–E（剃度/山门/达摩门槛/辈分晋升链）：`shaolin_promotion` 收礼+斗武事件链、55 名师父 UCL 配置、四级推荐信、字辈改名均已落地，定向 162/0；#652 各字辈晋升专属文案已回填（`shaolin_apprentice_dialogue.ex` + `FamilyEvent` 接线），#653 dao.h generation==0 直收已加 `allow_zero_generation` 到全部 9 个道字辈 NPC，定向 162/0，全量回归 7889/27（0 新增失败）。
- #642 PKS/MKS/WPK 击杀计数持久化（commit da85c8ba，已推送）：`Records.save/1` 从 `meta.combat.temp` 落盘到 `pks/mks/wpk*` DB 列；`Records.apply_to_character/2` 登录时从 DB 恢复到 `combat.temp`；`combat_event.ex enemy_died/2` 杀敌递增 PKS/MKS/WPK + 正邪细分；`shaolin_kneel.ex` 剃度 K_record 从 `combat.temp` 读 PKS+MKS；`shaolin_gate.ex` WPK 门控从 `combat.temp` 读；迁移文件 `20261117000000_add_pks_mks_wpk_to_character_metadata.exs`；单元测试 4 例全绿。Dev 库已手动补列（`ALTER TABLE ... ADD COLUMN` 7 列），测试库已通过 Ecto 迁移。
- #643 detach/betrayer 叛门记录落盘（已推送）：`DetachEvent.detach_result/2` 叛师成功后写入 `meta.env[:detach][门派名] = 1`、`meta.env[:betrayer][门派名] = 1`、`meta.env[:betrayer][:times] += 1`，供 `SectMaster.betrayed_sect?/2` 和 `betrayed_before?/1` 的 `permit_recruit` 门控读取（对齐 LPC shaolin.h `query("detach/<门派>")` / `query("betrayer/<门派>")` / `query("betrayer/times")`）。`Records.save/1` 已落盘 `env` 列，`apply_to_character/2` 已恢复。单元测试 4 例全绿（detach_command_test.exs 共 12 例，0 失败）。

## 净增量归档（全部已完结，无待办）
- `docs/` 下 78 份文档 + 根目录 md 已全量扫描，59 份含待办标记的历史文档已加「📌 归档声明 · 全库待办清零」。
- `docs/待对照代码核查.zh-CN.md` §6.2 净增量表、§二、§三已标记 ✅ 已完结。

## 已完成（本轮追加，2026-11-17）
- Task #640 其他出家门派剃度/出家机制移植（峨嵋/血刀/雪山）：commit `f43e77ac` 已推送 `origin kalevala`。
  - `loader.ex parse_apprentice/1` 新增 `max_shen` 字段解析（`int_value/1`）。
  - `sect_master.ex recruit_gate?/3` 新增 `shen > max_shen` 邪气上限门控，支持 `max_shen_deny` 文案覆写；未配置时 `nil` 不拦截。
  - `clone_lib.ucl` 为 `emei_miejue` / `xuedao_laozu` / `xueshan_fawang` 新增 `apprentice` + `teach` UCL 块，严格对齐 LPC `attempt_apprentice`（含峨嵋改名“静”+name[1..1]、血刀/雪山 male+bonze+max_shen）。
  - `sect_master_test.exs` 新增 `max_shen` 上限测试（达标/超限拒绝/未配置不拦），96 tests 0 failures；`loader_meta_test.exs` 41 tests 0 failures；`mix compile` EXIT=0；全量回归 27 个 bcrypt NIF 环境性失败，0 新增失败。
- Task #641 NAME_D 姓名注册表（commit 794f7972，已推送）。
- Task #642 PKS/MKS/WPK 击杀计数持久化（commit da85c8ba，已推送）。
- Task #643 detach/betrayer 叛门记录落盘（commit 9c8c838f，已推送）。
- Task #644 清无 gate_order 门控顺序精确对齐（已推送）。
- Task #695 文档 Section 1 一览表：已结案（15 位师父，含 3 位新 NPC 已回填）。
- Task #696 文档 Section 2 详细条目：已结案（灭绝师太/血刀老祖/金轮法王 3 个条目，含 LPC 检查顺序、教学技能表、不可学列表）。
- Task #697 文档 Section 7 LPC/UCL 对比：已结案（3 位新 NPC 一致性均标 ✅，Section 7.1 字段映射 + 各 NPC 差异说明已写入）。
- Task #698 文档 Section 5/8 统计修正：已结案（apprentice 块 15→13，teach_skills 13→14，门派 13→12，师父条目 14）。
- 文档 `docs/新手拜师门派指南.zh-CN.md` 已 commit `88d8520c` 并推送 `origin/kalevala`。
- 少林移植达摩剑四绝授予（§5.8 绝招支线）：commit `5d9e3b4b` 已推送 `origin/kalevala`。
  - `data/world/clone_lib.ucl` 达摩老祖 inquiries：4 个「unimplemented」占位替换为 `sect_master_grant` 配置（清心剑→luan、乱气剑→qingxin、伤神剑→shang、折元剑→zhe，照 LPC da-mo.c 原版错位保留），门槛 shen>=120000 + damo-jian>=200 + 少林派弟子。
  - 验证：mix compile EXIT=0；loader_meta_test 41/0；sect_master_test 96/0。
- PFM 六绝 + 三绝移植（§5.8 绝招支线）：commit `8d368bf7` 已推送 `origin/kalevala`。
  - `data/world/clone_lib.ucl` 达摩老祖 inquiries：新增 6 绝技（即世即空/金龙疾空/火麒蚀月/震雷乾坤/大金刚神通/易筋通脉），每招 short key + 达摩前缀 key，共 12 条 `sect_master_grant` 条目；门槛严格对齐 LPC da-mo.c accept_ask（lv1/force/neili/gongxian/shen）。
  - `data/world/clone_lib.ucl` 玄慈大师 inquiries：替换 2 条 `unimplemented` 占位，新增 3 绝技（一指点三脉/金刚伏魔诀/赤血连环爪），每招 short key + 玄慈前缀 key，共 7 条 `sect_master_grant` 条目；门槛严格对齐 LPC xuan-ci.c accept_ask。
  - 无引擎代码改动，纯 UCL 数据迁移；门控复用 `SectMaster.inquiry_grant/3`（同门 + 技能等级 + 杀气下限 + 贡献下限 + 内力上限）。
  - 验证：mix compile EXIT=0；sect_master_grant_test + sect_master_test + loader_meta_test 共 137 tests，0 failures。
- Task #715–#720 拜师门控保真度差异修复（commit `9bbe5038`，已推送 `origin/kalevala`）：
  - `loader.ex parse_apprentice/1`：新增 `min_max_neili` 字段解析到 base map（对齐 LPC `query("max_neili")`）。
  - `sect_master.ex recruit_gate?/3`：新增 `min_max_neili` 内力上限门控（`student_max_neili < min_max_neili` 拒绝），补充 `student_max_neili/1` 读取 `meta.vitals.max_neili`。
  - `sect_master.ex student_stats/1` 保持不变（仅 `:shen`/`:combat_exp`）；`student_max_neili/1` 单独读取 `:vitals`。
  - `wudang.ucl` 张三丰：新增 `min_int = 32` + `int_deny`（对齐 LPC `zhang.c` 悟性>=32）。
  - `clone_lib.ucl` 陈家洛：新增 `min_max_neili = 2000` + `max_neili_deny`（对齐 LPC `chen.c` max_neili>=2000）。
  - `zhongzhou.ucl` 苗人凤：移除 `min_skills = { miaojia_neigong = 50 }`（LPC `miao.c` 无 `attempt_apprentice`）。
  - `clone_lib.ucl` 宋远桥：新增完整 `apprentice` 块（shen>=25000, exp>=300000, wudang_xinfa>=100, taoism>=100）。
  - `wudang.ucl` 俞莲舟：新增完整 `apprentice` 块（shen>=20000, exp>=150000, wudang_xinfa>=80, taoism>=80）。
  - 验证：mix compile EXIT=0；loader_meta_test + sect_master_test 共 137 tests，0 failures；全量回归 27 个 bcrypt NIF 环境性失败，0 新增失败。
- Task #695 文档 Section 1 一览表：已结案（15 位师父，含 3 位新 NPC 已回填）。
- Task #696 文档 Section 2 详细条目：已结案（灭绝师太/血刀老祖/金轮法王 3 个条目，含 LPC 检查顺序、教学技能表、不可学列表）。
- Task #697 文档 Section 7 LPC/UCL 对比：已结案（3 位新 NPC 一致性均标 ✅，Section 7.1 字段映射 + 各 NPC 差异说明已写入）。
- Task #698 文档 Section 5/8 统计修正：已结案（apprentice 块 15→13，teach_skills 13→14，门派 13→12，师父条目 14）。
- 文档 `docs/新手拜师门派指南.zh-CN.md` 已 commit `88d8520c` 并推送 `origin/kalevala`。
- 少林移植达摩剑四绝授予（§5.8 绝招支线）：commit `5d9e3b4b` 已推送 `origin/kalevala`。
  - `data/world/clone_lib.ucl` 达摩老祖 inquiries：4 个「unimplemented」占位替换为 `sect_master_grant` 配置（清心剑→luan、乱气剑→qingxin、伤神剑→shang、折元剑→zhe，照 LPC da-mo.c 原版错位保留），门槛 shen>=120000 + damo-jian>=200 + 少林派弟子。
  - 验证：mix compile EXIT=0；loader_meta_test 41/0；sect_master_test 96/0。
- PFM 六绝 + 三绝移植（§5.8 绝招支线）：commit `8d368bf7` 已推送 `origin/kalevala`。
  - `data/world/clone_lib.ucl` 达摩老祖 inquiries：新增 6 绝技（即世即空/金龙疾空/火麒蚀月/震雷乾坤/大金刚神通/易筋通脉），每招 short key + 达摩前缀 key，共 12 条 `sect_master_grant` 条目；门槛严格对齐 LPC da-mo.c accept_ask（lv1/force/neili/gongxian/shen）。
  - `data/world/clone_lib.ucl` 玄慈大师 inquiries：替换 2 条 `unimplemented` 占位，新增 3 绝技（一指点三脉/金刚伏魔诀/赤血连环爪），每招 short key + 玄慈前缀 key，共 7 条 `sect_master_grant` 条目；门槛严格对齐 LPC xuan-ci.c accept_ask。
  - 无引擎代码改动，纯 UCL 数据迁移；门控复用 `SectMaster.inquiry_grant/3`（同门 + 技能等级 + 杀气下限 + 贡献下限 + 内力上限）。
  - 验证：mix compile EXIT=0；sect_master_grant_test + sect_master_test + loader_meta_test 共 137 tests，0 failures。

## 已完成（本轮追加，2026-11-18）
- Task #543 严格 LPC 狩猎掉落（commit `148390c8`，已推送 `origin/kalevala`）：`hunting.ex` 概率门控（`drop_a` >10, `drop_b` >30+random(4)>2, `drop_c` >60+random(5)>3，互斥，skill≤11 永不掉）；`Corpse.spawn/1` → `notify_hunting_drops/2` → `hunting/drops` 事件 → `CombatEvent.hunting_drops/2` → 直接放入击杀者背包（不落地、不入尸体）；`test/kantele/world/hunting_test.exs` 23 例全绿；`docs/corpse-drop-system.zh-CN.md` §2.4 已改为 direct-to-killer。
- Task #724 `#724`：新建 `test/kantele/world/hunting_test.exs`，23 例覆盖 `Hunting.roll/3`，全绿 0 失败。
- Task #725 `#725`：修正 `docs/corpse-drop-system.zh-CN.md` §2.4，替换陈旧“方案 A”地面掉落描述，改为 direct-to-killer 管道。
- Task #726/#729 `#729`：全量回归 7941 tests / 27 failures（全为预存在 `bcrypt_elixir` NIF 环境性，0 新增回归），提交并推送 commit `148390c8` 到 `origin/kalevala`，工作树干净。

## 待办（当前）

### 进行中
- Task #1 提交 P0 产物（R1 阻塞项）：5 个只读脚本 + 4 份文档入 git，确保工作树干净。当前工作树已 clean（commit `148390c8`），仅 `.workbuddy-ai/memory/2026-11-18.md` 为未跟踪待提交工作日志。

### 待开始
- Task #544–561 衡阳猎人教学链：hunting 技能可学、玩家尸体、三段腐烂、生肉不可吃、烤熟闭环、测试、文档。
- Task #641 LPC NAME_D 姓名注册表（remove_name/map_name + 重名校验）。
- Task #644 清无 gate_order 门控顺序对齐。
- Task #697 文档 Section 7：补充三个新 NPC 的 LPC/UCL 对比。
- Task #703–721 遗留保真度差异修复（部分已完结，见 TaskList）。
- Task #611–619 新手可拜师门派文档 + UCL teaching data backfill（部分已完结）。
- Task #620–624 少林派剃度机制移植计划 + audits（部分已完结）。

### 已保留缺失（非代码缺口，无需实现）
- 柳溪派 王重九 无 LPC source，`apprentice` 块无法回填（非代码缺口，保留缺失）。
