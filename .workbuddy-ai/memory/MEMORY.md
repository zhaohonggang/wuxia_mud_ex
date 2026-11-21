# Workspace Memory — wuxia_mud_ex（Elixir/Phoenix LPC MUD port）

## 🚨 每次会话首批动作：先读语法参考（用户 2026-11-19 确立 · AGENTS.md §0.5）
- 改 `data/**/*.ucl` → **先读 `docs/UCL语法参考.zh-CN.md`**（Elias 实测语法：token、5 种值、键值规则、数组、字符串/反斜杠、校验提交、错误速查）。
- 改 `lib/**/*.ex` → **先读 `docs/Elixir语法参考.zh-CN.md`**（1.13.4 实测约定：formatter 120 列、Behaviour 守护进程、safe_run/safely、Scheduler、string/atom-key、Enum 累加器陷阱 R20、Windows 中文 IO、错误速查）。
- **权威性**：两份文档均为本仓库实测版，**与 README / 旧文档 / 直觉冲突时一律以它们为准**（例：README 说数组加尾逗号=错；UCL 无浮点；`\n` 在 UCL 字符串合法）。
- 发现文档与实测不符 → 先跑实测确认，**修正文档**（并同步 AGENTS.md §0.5），不在代码里将就。

## 项目宪章（最高优先级 · 永久生效）
- **完整移植** LPC `C:\files\git\mud` → Kantele，非简化重写，零信息丢失（ex ≥ lpc：机制/顺序/阈值/文案/公式只多不少）。
- 发现「lpc 有、ex 无」→ **主动报告 + 立即建计划**（TaskList + `docs/*移植计划*.md`），严禁简化/搪塞。
- 角色：资深项目经理 + 架构师 + 程序员；审计→计划→实现→回归→归档。积极、热心、不逃避。

## 全量回归禁令（2026-11-19 用户确立 · 永久生效 · AGENTS.md §0.4）
- **永远不要自己跑全量回归**（`mix test` 全部 663 文件 / 分 chunk 跑完整套 / 任何变体，含后台异步与脚本包装）。
- 本该跑全量回归的批次 → **改为登记到 `docs/待全量回归清单.zh-CN.md`，然后继续推进下一批**。
- 用户审阅该清单并明确指示后，才执行回归，并把结果回填到对应条目。
- **定向测试不受限**：改动相关的测试文件必须自己跑（验证改动是否正确），不得跳过。

## Iron rules
- **提交前必检查**（AGENTS.md Core Rule #1）：① 改 `lib/**/*.ex` → `mix compile` 必过；② 改 `data/**/*.ucl` → `python scripts/validate_ucl.py <文件>` 必过。`.exs` 不做要求。
- 无 git commit/push 除非用户明确要求（2026-11-10 已授权「提交推送，然后继续推进」）。
- 改动前 Grep lib/test/docs + LPC 源确认真缺口，不臆造语义；不要升级 nimble_parsec。
- `character_metadata_backup.sql` 为启动时自动生成，提交前还原。
- **回填/替换 inquiries 后必做 diff review**：本项目已发生 inquiry 回填把 NPC 的 `combat` 块连带误删、且测试不覆盖战斗属性 → 静默丢失。替换 inquiry 块后要 `git diff | grep '^-'` 确认删除行只动了目标块；NPC 战斗属性改动务必加断言锁定。

## 验证环境（Windows Git Bash，Docker 不可用）
- `PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH`
- `MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=/c/files/git/wuxia_mud_ex/_build_win13`；`ERL_LIBS=$MIX_BUILD_PATH/lib`；`MIX_ENV=test`；**`ERL_CRASH_DUMP_BYTES=0`（必须，见下）**。
- **禁止产生巨型 crash dump**：BEAM 遇 `eheap_alloc` 等不可恢复错误会往 cwd 写 `erl_crash.dump`，内容=全进程堆+全 ETS 快照，实测 13-20 GB，可占满 C 盘（2026-11-19 已发生一次 13.9 GB）。所有 mix 调用前必须 `export ERL_CRASH_DUMP_BYTES=0`；`verify.sh` 已内置。
- **回归执行方式（仅在用户指示后）**：全量 663 文件按 6 chunk 顺序跑；chunk 遇 VM `eheap_alloc` 中止时**只补跑该 chunk**（可再拆 24 文件/组），不要整段重跑。Prior 批次（逍遥/星宿）已确认该中止是环境性，非断言失败。
- `mix compile` / `mix test --seed 831693`；全量 9-10 min，后台重定向日志。基线 27 failures 全为 bcrypt NIF 环境性；最新全量 8007/27（0 新增）。偶发 BEAM heap 中止，重跑可过。

## 关键约定 / 坑
- 路由：`parse/2` 裸路由只产 `%{"command"=>...}`；带参需 `optional(spaces() |> text(:rest|:target|:category))`。CommandProbe 白名单 `@whitelist %{}`，回执不得含占位标记。
- daemon GenServer 持 public ETS，直接 `:ets.insert`；`ensure!/0` 补建表。人格字段 `meta.character`；玩家 nil ≡ LPC 0。
- 两条死亡管线：战斗击杀 `CombatEvent.die/3`；`smash`/房间 `break` → `Feature.Damage.die/2`；公共尸体 `Corpse.spawn/1`。
- 物品缓存 key `<zone>:<key>`；`is_player?/1` 认 `"player:"`；`receive_damage` 别传 killer。
- UCL 语法：块内赋值换行无逗号；数组末项不能带尾逗号；标识符不能含数字（用 `msg_one`）；无单独 `#` 行。**`teach` 必须 wrapper**（`teach = { family=... teach_skills={...} no_teach=[...] }`），裸键被 loader 丢弃。
- `no_teach` flat list 仅展示，map → `no_teach_deny` 硬拒（#742 已接消费端）。
- inquiries 的 `min_levels`/`level_deny` 等 map 键 `_`→`-` 归一，**`min_skill_levels`（give_item）不归一**（loader 保留下划线，GiveItem 双查）；`min_max_neili` 是下界。
- **区域文件优先于 clone_lib**：`dereference/3` 先用 `zone.characters`；同名 NPC 必须改区域文件（wudang 教训）。
- `Elias.parse/1` 对 `value = { ... }` 正常；字段缺失先查区域覆盖，勿盲改语法。
- `teleport_service` 支持 `max_exp`/`max_exp_vision`/`target_vision`；`apprentice.deny_all/deny_msg` 走 NpcFamilyEvent 无条件拒收徒。
- `apprentice` 另支持 `min_per`/`per_deny`、`any_min_skills` OR 门、gate_order `lpc_xiaoyao`（int 先于 exp）/`lpc_wuyazi`（OR→force/dodge→int→exp）、`max_shen_deny` 逐字覆写。
- `IO.write` 中文 Windows 抛 `:no_translation` → 用 `File.write!/2`；`Path.join/3`、`File.rm/2` 不存在。编辑丢失可从 session transcript jsonl 的 `function_call.arguments` 还原。
- **`\n` 显示定论（2026-11-20 三重实测证伪旧说）**：字面 `\n`（`5c 6e`）**原样显示不换行**——`Kalevala.Output.process`+`Jason.encode!` 保持字面、前端 `parseText.js` 只切真 `0x0A`、`CommandView.render("text")` 逐字渲染；`lpc_converter.ex:3410` 的 `String.replace("\\n","\\\\n")` 是 **LPC→UCL 构建期**转换、不在显示期运行。**显示文案一律别写字面 `\n`**（需多句并一行）；clone_lib 历史遗留 120+ 处属旧写法。**已修正 `docs/UCL语法参考.zh-CN.md` §195-210 的陈旧错误说法**。

## 引擎能力速查（sect_master / loader / handler）
- `inquiry_grant_lpc`（sect_master.ex:727）门序：perform_id nil → same_family(family_deny) → perform_known(maxed) → max_shen(neg,max_shen_deny) → min_shen(pos,shen_deny) → gongxian(gongxian_deny) → skill exists(skill_deny) → level_order(ordered_level_deny)/meets_levels(level_deny_text) → below_min_force(force_deny) → below_min_dodge(dodge_deny) → above_neili_cap → below_max_neili(max_neili_deny) → below_min_dex(dex_deny) → ok。
- `below_min_force?` 读 `min_force`（int，`skill_level_of(force)`）；`below_min_dodge?` 读 `min_dodge`；`below_max_neili?` 读 `min_max_neili`（`max_neili` 下界）；`first_failing_lpc_level` 仅当有 `level_order` 时生效。
- `recruit_gate?/3` gate_order 已实现：`"permit_first"`(默认)、`"gender_first"`、`"lpc_xiaoyao"`、`"lpc_wuyazi"`、`"lpc_xuanming"`、`"lpc_meizhuang"`、`"lpc_masterd"`（#745）。**songshan 复用 `lpc_masterd`（衡山派先例），零引擎改动。**
- `lpc_masterd`（inquiry）＝masterd.c teach_pfm 逐字门序（family→maxed→max_shen→min_shen→gongxian→skill→level_order/levels→force→dodge→neili→dex）。
- `SectMaster.teachable?` 支持 `teach.no_teach` map 形态带 `unlock`（先判 `can_learn/<family>/<skill>` mark 或 `combat_exp>min_exp` → `{:unlock,...}`）。
- `parse_apprentice`（loader.ex:1206）支持全部门控字段（max_shen/min_shen/min_exp/recruit_skill_order/permit_recruit/no_min_shen/min_skills_deny 等）；`parse_inquiries`(832)/`normalize_inquiry_field`(876) 归一 min_levels/level_deny/level_order/improve_skills/max_skill_levels/min_skill_deny。
- GiveItem handler 字段：item/match/unique/family/master_id/max_shen(neg)/min_shen/min_combat_exp/max_skill_levels/min_skill_levels(双下划线查)/min_gongxian/max_neili/perform_id/cost_gongxian + max_shen_deny/min_skill_deny/family_deny/master_deny 逐字覆写。
- `attach_npc_applies`(loader.ex:1679) 读 combat.apply；`chat_msg_combat`(624)/`chat_chance_combat`(625)。

## 里程碑（已完成，免重复核查）
- A1/A2/A4、B1(22 命令桩)/B2(12 arch)/B3、C 类同步全清零。F4：@static 白名单 733、valid_learn 322/322、R5 动态招式 33 技能。
- #640-644：剃度、NAME_D(794f7972)、PKS/MKS/WPK(da85c8ba)、detach/betrayer(9c8c838f)、清无 gate_order。#695-698 门派指南 39 配置(88d8520c)。#543 严格狩猎掉落(148390c8)。#724-729 全量 7941/27。
- **Task #619 已回填**（详见 daily log）：丐帮、古墓、红花会、关外胡家(#737)、华山(#740)、绝情谷(#745)、慕容(527c1621)、白驼(4b28b5a8)、全真、日月、昆仑(#750-#755)、少林(ca37e867)、武当(7d0de3f1)、血刀(986b0e8d)、大轮寺 13 grant(1e869000)、侠客岛(#799/a714e488)、逍遥派 9 NPC + 11 grant(#804/7649f464)、星宿派 7 NPC + 9 grant(#811)、**玄冥谷(xuanming,4233847d)、天地会(yunlong)/镇远镖局(zhenyuan) 8 NPC（待回归清单 #2）、大理段氏(duan) 14 NPC + 14 grant + 11 apprentice（待回归清单 #3）、峨眉派(emei) 24 NPC + 11 grant + 20 apprentice + daoming teach（待回归清单 #4；docs/峨眉派教学门控移植计划.zh-CN.md）、恒山派(henshan) 5 NPC + 10 grant + 5 apprentice + 3 no_teach（待回归清单 #5）、梅庄(meizhuang) 5 NPC + 10 grant + 5 apprentice + 4 riyue + 黄钟公 1 no_teach（待回归清单 #6）、中原苗家(miao) 5 NPC + 条件 no_teach 解锁 + born_family 收徒门 + carry/chat/apply（待回归清单 #7）、**嵩山派(songshan) 4 NPC + 13 grant + 残阳宝剑 give_item + lee 双类两处回填（待回归清单 #8）**。
- 引擎扩展历史：#736 `min_dex`/`dex_deny`；#740 剑宗上限门控 + 直授/破式；#745 `reject_master_name`/`no_min_shen`/`lpc_masterd`；天地会 `lpc_kunlun`（min_shen/min_perform_skill）；段氏 `lpc_duan`；峨眉 `lpc_emei`；恒山 `recruit_skill_order`；梅庄 `lpc_meizhuang`+`riyue_grant`+`meizhuang_riyue`；苗家 `required_born_family`/`born_family_deny`+no_teach unlock map+`combat_event.notify_coagents`。
- 其他历史批次：拱猪子、死亡→地府→还阳、19/19 quarry NPC 掉落、猎人教 hunting。

## 已报告缺口（必须建计划，严禁简化）
- 关外胡家 #738/#739；华山 #741/#742(已实现)/#743/#744；绝情谷 #747/#748/#749。
- 日月：任我行 `ren.c` 有 ask_skill1~5 + no_teach 但无 UCL 块（待建任务）。
- 武当/血刀/大轮寺/侠客岛/逍遥/星宿：见 `docs/{武当派,血刀派,大轮寺,侠客岛,逍遥派,星宿派}教学门控移植计划.zh-CN.md`，缺口 #789-#816。
- 关外胡家/华山/绝情谷/日月计划见 `docs/{关外胡家,华山派,绝情谷,日月教}教学门控移植计划.zh-CN.md`。
- 天地会 #830/#831；镇远镖局 #832-#837。见 `docs/{天地会,镇远镖局}教学门控移植计划.zh-CN.md`。
- 大理段氏 #843-#846（#843 born_family 硬门已于苗家批 #879 落地）。见 `docs/大理段氏教学门控移植计划.zh-CN.md`。
- 峨眉派 #852-#857。见 `docs/峨眉派教学门控移植计划.zh-CN.md`。
- 恒山派 #863-#867。见 `docs/恒山派教学门控移植计划.zh-CN.md`。
- 梅庄 #873-#877。见 `docs/梅庄教学门控移植计划.zh-CN.md`。
- 中原苗家 #884-#887。见 `docs/中原苗家教学门控移植计划.zh-CN.md`。
- 嵩山派 #892-#896（QUEST_D 历练 / 残阳剑 owner 遍历 / guarder / coagents startroom / 乐厚双 LPC 类 yao.c≡yue.c + 未放置块 combat_exp 偏差）。见 `docs/嵩山派教学门控移植计划.zh-CN.md`。

## 语法参考
- 见本文件顶部「🚨 每次会话首批动作」+ AGENTS.md §0.5。两份实测文档：`docs/UCL语法参考.zh-CN.md`、`docs/Elixir语法参考.zh-CN.md`。

## 当前工作流
- Task #619 按门派顺序回填 UCL 教学数据；状态以 TaskList 为唯一权威。**玄冥谷(xuanming) + 天地会(yunlong)/镇远镖局(zhenyuan) + 大理段氏(duan) + 峨眉派(emei) + 恒山派(henshan) + 梅庄(meizhuang) + 中原苗家(miao) + 嵩山派(songshan) 批已完成**（待回归清单 #1-#8，均未跑全量）。**下一门：tangmen（唐门，Task #897 已建）** —— 字母序 songshan 之后；初查 LPC tangrou.c 有 create_family+attempt_apprentice，ex clone_lib `tangmen_tangrou` 无 teach/apprentice，缺口明确。
- **嵩山批关键决策**：衡山派（Hengshan, clone_lib.ucl:18901+）已用 `gate_order="lpc_masterd"` 实现与 songshan 逐字相同的 permit_recruit + teach_pfm 模式 → songshan **零引擎改动**，直接复用 `lpc_masterd`。已回填 songshan.ucl +512/−0、clone_lib.ucl 纯插入 92；6 定向测试全绿。
- **乐厚双类陷阱（GAP #896）**：LPC `yao.c`≡`yue.c`（仅 aliases 不同）；luyanpubu 房间实际引用 `clone_lib.ucl:characters "songshan_yue"`，不是 songshan.ucl 的 `characters "yao"`。**两处都要回填**才能生效。§0.5 之外的「区域文件优先」惯例在此不适用（key 不同）。
- 注意：本批对 `sect_master.ex`/`loader.ex`/`inquiry_sect_masters_test.exs` 做过 `mix format`（HEAD 原未格式化），旧文档测试行号全部失效。各批测试 describe 位置：梅庄 :3932；苗人凤 :175/:262。
- 已保留缺失（非缺口）：柳溪 王重九无 LPC source；gaibang_jian 青竹令为升袋交互非技能授予。
- 归档：docs/ 100 份，59 份历史待办加「📌 归档声明」。daily log append-only，超 30 天蒸馏到本文件。