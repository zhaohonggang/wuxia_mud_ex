# Workspace Memory — wuxia_mud_ex（Elixir/Phoenix LPC MUD port）

## 项目宪章（最高优先级 · 永久生效）
- **完整移植** LPC `C:\files\git\mud` → Kantele，非简化重写，零信息丢失（ex ≥ lpc：机制/顺序/阈值/文案/公式只多不少）。
- 发现「lpc 有、ex 无」→ **主动报告 + 立即建计划**（TaskList + `docs/*移植计划*.md`），严禁简化/搪塞。
- 角色：资深项目经理 + 架构师 + 程序员；审计→计划→实现→回归→归档。积极、热心、不逃避。

## Iron rules
- 无 git commit/push 除非用户明确要求（2026-11-10 已授权「提交推送，然后继续推进」）。
- 改动前 Grep lib/test/docs + LPC 源确认真缺口，不臆造语义；不要升级 nimble_parsec。
- `character_metadata_backup.sql` 为启动时自动生成，提交前还原。

## 验证环境（Windows Git Bash，Docker 不可用）
- `PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH`
- `MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=/c/files/git/wuxia_mud_ex/_build_win13`；`ERL_LIBS=$MIX_BUILD_PATH/lib`；`MIX_ENV=test`；**`ERL_CRASH_DUMP_BYTES=0`（必须，见下）**。
- **禁止产生巨型 crash dump**：BEAM 遇 `eheap_alloc` 等不可恢复错误会往 cwd 写 `erl_crash.dump`，内容=全进程堆+全 ETS 快照，实测 13-20 GB，可占满 C 盘（2026-11-19 已发生一次 13.9 GB）。所有 mix 调用前必须 `export ERL_CRASH_DUMP_BYTES=0`；`verify.sh` 已内置。
- **回归只跑一次**：全量 663 文件按 6 chunk 顺序跑；chunk 遇 VM `eheap_alloc` 中止时**只补跑该 chunk**（可再拆 24 文件/组），不要整段重跑。 Prior 批次（逍遥/星宿）已确认该中止是环境性，非断言失败。
- `mix compile` / `mix test --seed 831693`；全量 9-10 min，后台重定向日志。基线 27 failures 全为 bcrypt NIF 环境性；最新全量 8007/27（0 新增）。偶发 BEAM heap 中止，重跑可过。

## 关键约定 / 坑
- 路由：`parse/2` 裸路由只产 `%{"command"=>...}`；带参需 `optional(spaces() |> text(:rest|:target|:category))`。CommandProbe 白名单 `@whitelist %{}`，回执不得含占位标记。
- daemon GenServer 持 public ETS，直接 `:ets.insert`；`ensure!/0` 补建表。人格字段 `meta.character`；玩家 nil ≡ LPC 0。
- 两条死亡管线：战斗击杀 `CombatEvent.die/3`；`smash`/房间 `break` → `Feature.Damage.die/2`；公共尸体 `Corpse.spawn/1`。
- 物品缓存 key `<zone>:<key>`；`is_player?/1` 认 `"player:"`；`receive_damage` 别传 killer。
- UCL 语法：块内赋值换行无逗号；数组末项不能带尾逗号；标识符不能含数字（用 `msg_one`）；无单独 `#` 行。**`teach` 必须 wrapper**（`teach = { family=... teach_skills={...} no_teach=[...] }`），裸键被 loader 丢弃。
- `no_teach` flat list 仅展示，map → `no_teach_deny` 硬拒（#742 已接消费端）。
- inquiries 的 `min_levels`/`level_deny` 等 map 键 `_`→`-` 归一，`min_skill_levels` 不归一；`min_max_neili` 是下界。
- **区域文件优先于 clone_lib**：`dereference/3` 先用 `zone.characters`；同名 NPC 必须改区域文件（wudang 教训）。
- `Elias.parse/1` 对 `value = { ... }` 正常；字段缺失先查区域覆盖，勿盲改语法。
- `teleport_service` 支持 `max_exp`/`max_exp_vision`/`target_vision`；`apprentice.deny_all/deny_msg` 走 NpcFamilyEvent 无条件拒收徒。
- `apprentice` 另支持 `min_per`/`per_deny`、`any_min_skills` OR 门、gate_order `lpc_xiaoyao`（int 先于 exp）/`lpc_wuyazi`（OR→force/dodge→int→exp）、`max_shen_deny` 逐字覆写。
- `sect_master_grant` 的 `lpc_masterd` 支持 `level_order` 有序链（sk1..sk5→force→dodge→neili）与独立 `min_force`（与 min_levels.force 并存，不合并）。
- `IO.write` 中文 Windows 抛 `:no_translation` → 用 `File.write!/2`；`Path.join/3`、`File.rm/2` 不存在。编辑丢失可从 session transcript jsonl 的 `function_call.arguments` 还原。

## 里程碑（已完成，免重复核查）
- A1/A2/A4、B1(22 命令桩)/B2(12 arch)/B3、C 类同步全清零。F4：@static 白名单 733、valid_learn 322/322、R5 动态招式 33 技能。
- #640-644：剃度、NAME_D(794f7972)、PKS/MKS/WPK(da85c8ba)、detach/betrayer(9c8c838f)、清无 gate_order。#695-698 门派指南 39 配置(88d8520c)。#543 严格狩猎掉落(148390c8)。#724-729 全量 7941/27。
- **Task #619 已回填**（详见 daily log）：丐帮、古墓、红花会、关外胡家(#737)、华山(#740)、绝情谷(#745)、慕容(527c1621)、白驼(4b28b5a8)、全真、日月、昆仑(#750-#755)、少林(ca37e867)、武当(7d0de3f1)、血刀(986b0e8d)、大轮寺 13 grant(1e869000)、侠客岛(#799/a714e488)、逍遥派 9 NPC + 11 grant(#804/7649f464)、星宿派 7 NPC + 9 grant(#811)。
- 引擎扩展：#736 `min_dex`/`dex_deny`；#740 剑宗上限门控 + 直授/破式 handler；#745 `reject_master_name`/`no_min_shen`/`gate_order="lpc_masterd"`；`level_deny_text/3` 只认 min_levels 实存键。
- 其他历史批次：拱猪子、死亡→地府→还阳、19/19 quarry NPC 掉落、猎人教 hunting。

## 已报告缺口（必须建计划，严禁简化）
- 关外胡家 #738/#739；华山 #741/#742(已实现)/#743/#744；绝情谷 #747/#748/#749。
- 日月：任我行 `ren.c` 有 ask_skill1~5 + no_teach 但无 UCL 块（待建任务）。
- 武当/血刀/大轮寺/侠客岛/逍遥/星宿：见 `docs/{武当派,血刀派,大轮寺,侠客岛,逍遥派,星宿派}教学门控移植计划.zh-CN.md`，缺口 #789-#816（give_item 多状态、密道、剃度、雇助、greeting exp、广播文案、珍珑分支、guarder、flatter 两步拜师、QUEST_D、香料冷却、coagents、神王木鼎状态机）。
- 关外胡家/华山/绝情谷/日月计划见 `docs/{关外胡家,华山派,绝情谷,日月教}教学门控移植计划.zh-CN.md`。

## 当前工作流
- Task #619 按门派顺序回填 UCL 教学数据；状态以 TaskList 为唯一权威。下一门派：**xuanming / 玄冥谷**（xingxiu 之后）。
- 已保留缺失（非缺口）：柳溪 王重九无 LPC source；gaibang_jian 青竹令为升袋交互非技能授予。
- 归档：docs/ 78 份，59 份历史待办加「📌 归档声明」。daily log append-only，超 30 天蒸馏到本文件。
