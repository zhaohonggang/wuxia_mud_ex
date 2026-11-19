# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## 项目宪章（最高优先级 · 2026-11-17 用户确立 · 永久生效）
- **完整移植**：LPC 原版 `C:\files\git\mud` → ex（Kantele），非简化重写，零信息丢失（ex ≥ lpc，机制/顺序/阈值/文案/公式只多不少）。
- **缺口主动报告 + 建计划**：发现「lpc 有、ex 无」必须主动报告用户并立即建立移植计划（任务列表 + `docs/*移植计划*.md`）。
- **长期工程禁止简化**：绝不为省时间/省工作量选简化方案；有疑问回 LPC 源码逐条核对。
- **角色**：资深项目经理 + 架构师 + 程序员；工程化推进（审计→计划→实现→回归→归档）。
- **性格**：积极、热心、爱多做工作；遇困难积极耐心解决，不逃避、不偷懒。

## Iron rules
- 无 git commit/push 除非用户明确要求（2026-11-10 已授权「提交推送，然后继续推进」）。
- 改动前 Grep lib/test/docs + LPC 源 `/c/files/git/mud` 确认真缺口，不臆造语义。
- 不要升级 nimble_parsec。

## 验证路径（Windows Git Bash，Docker 不可用）
- `PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH`
- `MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=_build_win13`；`ERL_LIBS=_build_win13/lib`；`MIX_ENV=test`
- `mix compile` / `mix test --seed 831693`（全量约 9-10 min，建议后台重定向日志）
- 基线：~7830 tests / 27 failures（全为 `bcrypt_elixir` NIF 环境性，引擎/命令/技能/世界测试 0 失败）
- 最新全量回归：7960 tests / 27 failures，0 新增回归（2026-11-18，绝情谷批次）

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
- **UCL 数组最后一项不能带尾逗号**（`{ ... }, ]` → `syntax error before: ']'`）；插入新元素到原末项之后时必须先给原末项补逗号，同时删掉新末项的尾逗号。跨字段（如 inquiries/skills）边界的 `]` 由 `first line whose strip()==']'` 定位，插入点务必落在**原末项行之后、']' 之前**。
- **UCL 标识符不能含数字**：`msg1 = "..."` 报 `syntax error before: '"1"'`；改用 `msg_one`（handler 双读 `msg_one`/`msg1`）。
- **loader `parse_teach/1` 只读 character 的 `:teach` map**（loader.ex:607/1098）：character 层直接写 `teach_skills = {...}`（裸键）会被**静默丢弃**，必须包成 `teach = { family = "..." teach_skills = {...} no_teach = [...] }`。新增教学数据一律用 wrapper 格式。
- 编辑被 `git checkout` 丢失时，可从 session transcript jsonl（`C:\Users\honggang\.workbuddy-ai\projects\c-files-git-wuxia_mud_ex\*.jsonl`）的 `function_call` 记录 `arguments` JSON 字段精确还原 old/new_string（bottom-up slice replacement + 单块 anchor count==1 断言，避免全局脚本误伤）。
- `is_player?/1` 认 `"player:"` 前缀；`receive_damage` 别传 killer。
- `zone.items` 缺 `:items` key 时抛 KeyError；改用 `Map.get(zone, :items, %{})`。
- `IO.write` 在 Windows 下对中文抛 `:no_translation`；改用 `File.write!/2` 追加。
- `Path.join/3` 不存在，用 `Path.join([...])`；`File.rm/2` 不存在，用 `File.rm!/1`。
- `String.to_integer/1` 返回裸整数，用 `is_integer()` 保护；`List.to_atom/1` 不接受字符串。

## 已完成（主要里程碑，免后续重复核查）
- A1/A2/A4 已清零；B1 命令桩 22 个全部真实实现；B2 arch 命令 12 个落地；B3 prepare/scheme/uptime/special/suicide/clone 完整。
- C 跨角色同步/饥饿口渴/门派学徒/门容器/一次性场景/通信中继载具全部落地。
- F4 武功迁移：@static 白名单 733；valid_learn 322/322 全量迁移；R5 动态招式表 33 技能已迁移。
- 拱猪子、死亡→地府→还阳、尸体/NPC 掉落（19/19 quarry NPC）、猎人教 hunting（50 例全绿）全部落地。
- #640 出家门派剃度（峨嵋/血刀/雪山）：`max_shen` 字段解析 + `shen > max_shen` 门控 + `apprentice`/`teach` UCL 块。
- #641 NAME_D 姓名注册表（commit 794f7972）：GenServer+ETS，JSON 持久化，接线 shaolin_kneel 剃度改名 + family_event 辈分晋升改名。
- #642 PKS/MKS/WPK 击杀计数持久化（commit da85c8ba）：DB 列 + 登录恢复 + combat_event 递增 + shaolin_kneel/shaolin_gate 读取 + 迁移文件。
- #643 detach/betrayer 叛门记录落盘（commit 9c8c838f）：meta.env 持久化 + Records.save/apply 恢复。
- #644 清无 gate_order 门控顺序精确对齐（已推送）。
- #695-698 新手拜师门派指南：Section 1/2/5/7/8 全部结案，39 个门派详细配置，文档 commit 88d8520c 已推送。
- Task #619 丐帮 NPC UCL 教学数据回填（第2批）：gaibang_ada（3 sect_master_grant: pichen-jian/ao, guanri-jian/fen, guanri-jian/guan + teach_skills sword/179）、gaibang_bai（apprentice+教学+缠丝擒拿 chansi-shou/qin）、gaibang_lu（apprentice 门控 exp>=150000/shen>=20000/force>=120）、gaibang_ma（apprentice+铁爪锁喉 suohou-gong/suo）、gaibang_peng（apprentice+群魔乱舞 fengmo-zhang/luan）、gaibang_quan（apprentice 仅 permit_recruit）、gaibang_wu（apprentice+乌龙探海 liuhe-zhang/tan + 闪刀诀 liuhe-dao/shan）、gaibang_xi（apprentice+风火轮 fumo-zhang/lun）。gaibang_li 的 2 个绝招（五丁开山/绝命一踢）已先于此对齐。gaibang_jian 仅 青竹令（升袋给物品交互，非技能授予，保留 unimplemented）。全量回归 7941/28（+1 bcrypt 抖动，非回归），定向 137/0。
- #715-#720 拜师门控保真度差异修复（commit 9bbe5038）：min_max_neili 门控、张三丰 min_int=32、陈家洛 min_max_neili=2000、苗人凤移除 miaojia_neigong、宋远桥/俞莲舟 apprentice 块。
- 少林达摩剑四绝 + PFM 六绝/三绝授予（纯 UCL 数据迁移，无引擎改动）。
- #543 严格 LPC 狩猎掉落（commit 148390c8）：hunting.ex 概率门控 + Corpse 直接给击杀者背包；hunting_test 23 例全绿；corpse-drop doc §2.4 已改为 direct-to-killer。
- #724-729 定向测试 + 全量回归 + commit/push：7941 tests / 27 failures，0 新增回归。
- Task #619 丐帮/古墓派/红花会 UCL 教学数据回填：丐帮 c073fc77、古墓派 1a14da4c、红花会 b7bfc2df（chang1/chang2/江/陆菲青/骆冰/石双英/文泰来/杨成协/余鱼同/赵半山 10 NPC）。另 01ce2c60 修复 gaibang/gumu 11 个裸 teach_skills 未包 wrapper（loader 丢弃）的问题。验证 155/0 定向 + 7941/27 全量（0 新增），均已推送。
- Task #736：`SectMaster.inquiry_grant/3` 新增 `min_dex` 门控 + `dex_deny` 文案（对应 hufei.c ask_skill5 飞天神行 dex>=33），4 例新测；sect_master_test 100/0。
- Task #737 关外胡家（hu）3 NPC UCL 回填：程灵素 4 skills（recognize_apprentice 限制）、胡斐 20 skills + apprentice(permit_recruit) + 12 grants（ask_skill1..11，风卷霹雳双键，飞天神行含 min_dex=33/min_max_neili=1000）、胡逸之 14 skills + 横扫千军 grant（accept_ask→teach_pfm，cost=600）。4 个物品问询保留 unimplemented。定向 159/0。
- **已报告缺口**：#738 `recognize_apprentice` 按技能授课门控（cheng.c）；#739 `no_teach` 闭包解锁 `can_learn/hufei/*`（hufei.c 三技能 combat_exp 100000/400000/50000）。迁移计划见 `docs/关外胡家教学门控移植计划.zh-CN.md`。严禁简化。
- Task #740 华山派 8 NPC UCL 回填（成不忧/丛不弃/风清扬/封不平/劳德诺/令狐冲/岳不群/岳夫人）：新增剑宗上限门控 `max_skill_levels`/`max_neili_cap`（顺序先于 min_levels）、收徒三类自定义拒绝文案、`no_teach` map → `no_teach_deny`、`sect_master_teach_skill` 直授 handler、`sect_master_unlock_perform` 破式 handler（潜能 10/random(2)/learned_points）、`GiveItem.min_shen` + 技能键双解析。定向 168/0，全量 7954/27（0 新增）。计划见 `docs/华山派教学门控移植计划.zh-CN.md`。
- **已报告缺口（华山）**：#741 `recognize_apprentice` 按技能门控（feng.c/linghu.c）；#742 `no_teach_deny` 消费端（skills_event.teach/2）；#743 独孤九剑按武器类型破式数组（当前单 perform_id 代理）；#744 `QUEST_D` 历练问询 + `apprentice_available` 收徒上限。严禁简化。
- Task #745 绝情谷 3 NPC UCL 回填（裘千尺/樊一翁/公孙止）：22/20/23 teach skills、5/8/8 grants、公孙止 2 give_item；新增 `reject_master_name` 仇家师父门控、`no_min_shen`（负神上界门派不可套用缺省 min_shen=0）、`min_exp_deny`、`gate_order="lpc_masterd"`（masterd 原顺序）、`level_deny` 逐技能 map、`msg_one` 房间演示文案（UCL 标识符不能含数字，`msg1` 会语法错）、按姓改名（公孙→裘）+ NAME_D。定向 174/0，全量 7960/27（0 新增）。计划见 `docs/绝情谷教学门控移植计划.zh-CN.md`。
- **已报告缺口（绝情谷）**：#747 QUEST_D 历练问询（与 #744 同类）；#748 masterd `maxed` random(4) + `msg2` random(5) 文案；#749 樊一翁 coagents 助战数据。严禁简化。
- Task #763 慕容世家 3 NPC UCL 回填（murongfu/博/长城）：murongfu（3 sect_master_grant: 摘星式/qixing-quan/zhai, 剑转七星/murong-jian/xing, 风雨交加/longcheng-shendao/feng + teach 14 skills + apprentice permit_recruit/no_min_shen/max_shen=0）、murongbo（5 sect_master_grant: 斗转星移/douzhuan-xingyi/yi shen=-60000, 七星指穴/canhe-zhi/zhi shen=-75000, 幽冥剑气/canhe-zhi/you shen=-80000, 金刚剑气/canhe-zhi/jin shen=-95000, 参合剑气/canhe-zhi/canhe shen=-130000 + 1 give_item 琥珀神环/hupohuan max_shen=-50000/min_skill_levels zihui_xinfa=180/master_id=true + teach 38 skills + no_teach 25 skills + apprentice permit_recruit/no_min_shen/max_shen=-36000/min_exp=500000/min_skills douzhuan_xingyi=130/murong_xinfa=120/dodge=200）、longcheng（1 sect_master_grant 风雨交加/longcheng-shendao/fengyu min longcheng_shendao=120 + teach 15 skills, 无 apprentice：LPC“不收徒弟”）。定向 113/0，全量回归 7971/27 (0 新增)，commit 527c1621 已推送 origin/kalevala。所有 gate_order="lpc_kunlun"，keys 均用下划线，无数字标识符，无尾逗号，教学数据均用 teach wrapper 格式。
- Task #764 白驼山 2 NPC UCL 回填（ouyangfeng/欧阳克）：ouyangfeng（3 sect_master_grant: 横行无忌/lingshe-zhangfa/wuji gongxian=500/lingshe_zhangfa>=100, 千蛇出洞/lingshe-zhangfa/qianshe shen=-40000/gongxian=800/lingshe_zhangfa>=120, 千蛇万噬/lingshe-zhangfa/wanshi shen=-120000/gongxian=1000/lingshe_zhangfa>=180 + 2 give_item: 筝谱/clone_lib:zhengpu, 灵蛇杖/baituo:lingshezhang master_id/max_shen=-60000 + teach: guzheng_jifa max=400 + no_teach 21 skills + apprentice permit_recruit/min_exp=200000）、ouyangke（2 give_item: 引路神蛇/神蛇/baituo:shenshe + teach: lingshe_quan max=130 + no_teach 16 skills + apprentice permit_recruit/gender_deny）。定向 113/0，全量回归 7971/27 (0 新增)，commit 4b28b5a8 已推送 origin/kalevala。所有 gate_order="lpc_kunlun"，keys 均用下划线，无数字标识符，无尾逗号，教学数据均用 teach wrapper 格式。
- Task #619 全真派 22 NPC UCL 教学数据回填完成（quanzhen 批次）：wangchuyi（2 grant 缠字诀 quanzhen-jian/chan、定阳针 quanzhen-jian/ding + apprentice min_skills xuanmen_neigong=80/quanzhen_xinfa=80/taoism=80 min_shen=10000 permit_recruit）、wangzhi（apprentice permit_recruit）、yin（3 grant 剑指南山 zhongnan-zhi/zhi、群星璀璨 qixing-jian/xing、三连环 quanzhen-jian/lian + apprentice min_skills xuanmen_neigong=30/quanzhen_xinfa=30/taoism=30 min_shen=3000 permit_recruit）、zhang（apprentice permit_recruit）、zhao（apprentice permit_recruit）、zhou（2 grant 空明若玄 kongming-quan/ruo、空空如也 kongming-quan/kong + teach no_teach xiantian_gong/yijin_duangu/shexing_lifan + apprentice min_exp=400000 min_shen=50000 permit_recruit）。其余 cheng/cui/fang/hao/ji/li/liu/ma/qi/qiu/shen/sun/tan/wang 已前批完成；pi 拒收徒弟无数据（与 LPC 一致）；chen 无 LPC source 已保留缺失。定向 152/0，全量回归 0 新增回归，commit/push 已推送 origin/kalevala。所有 gate_order="lpc_kunlun"，keys 均用下划线，无数字标识符，无尾逗号，教学数据均用 teach wrapper 格式。

## 待办（当前）
任务列表为唯一权威状态入口（TaskList，732 项，634 completed / 98 pending）。主要待开始类项：

- **Task #1**：提交 P0 产物（R1 阻塞项）：5 个只读脚本 + 4 份文档入 git，确保工作树干净。工作树已 clean（commit 148390c8），仅 `.workbuddy-ai/memory/2026-11-18.md` 为未跟踪待提交工作日志。
- **Task #544-561**：衡阳猎人教学链（hunting 技能可学、玩家尸体、三段腐烂、生肉不可吃、烤熟闭环、测试、文档）。代码已全部落地，定向测试 62/0 全绿，全量回归 0 新增回归。需同步文档/记忆并闭环标记。
- **Task #611-619**：新手可拜师门派文档 + UCL teaching data backfill（gaibang_hong 洪七公 + gaibang_ada/白世镜/黎生/鲁有脚/马大元/彭有敬/全冠清/吴长风/奚长老 共 9 个丐帮 NPC 完成，commit c073fc77；gaibang_jian 仅 青竹令 升袋交互非技能授予保留；gaibang_li 的 2 个绝招已对齐。gumu 古墓派 4 个 NPC 完成：gumu_li 李莫愁（apprentice+7 sect_master_grant+teach_skills，commit 1a14da4c）、gumu_lin 林朝英（apprentice+3 sect_master_grant+teach_skills）、gumu_longnv 小龙女（apprentice+5 sect_master_grant+teach_skills，玉蜂针保留unimplemented）、gumu_yang 杨过（apprentice+4 sect_master_grant cost_gongxian=0+teach_skills）。其余门派 NPC 待回填）。UCL 块内赋值不可用逗号：min_skills = { force = 160, strike = 120 } 报 syntax error，需改为多行块形式。
- **Task #620-624**：少林派剃度机制移植计划 + audits（部分已完结）。
- **Task #703-721**：遗留保真度差异修复（部分已完结，见 TaskList #722-723）。

### 已保留缺失（非代码缺口，无需实现）
- 柳溪派 王重九：无 LPC source，`apprentice` 块无法回填（非代码缺口，保留缺失）。

## 已归档
- `docs/` 下 78 份文档 + 根目录 md 已全量扫描；59 份含待办标记的历史文档已加「📌 归档声明 · 全库待办清零」。
- `docs/待对照代码核查.zh-CN.md` §6.2 净增量表、§二、§三已标记 ✅ 已完结。
- 历史重复条目已合并，MEMORY.md 保持精简。