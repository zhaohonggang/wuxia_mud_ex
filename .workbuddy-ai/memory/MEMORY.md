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
- 最新全量回归：7941 tests / 27 failures，0 新增回归（2026-11-18）

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

## 待办（当前）
任务列表为唯一权威状态入口（TaskList，732 项，634 completed / 98 pending）。主要待开始类项：

- **Task #1**：提交 P0 产物（R1 阻塞项）：5 个只读脚本 + 4 份文档入 git，确保工作树干净。工作树已 clean（commit 148390c8），仅 `.workbuddy-ai/memory/2026-11-18.md` 为未跟踪待提交工作日志。
- **Task #544-561**：衡阳猎人教学链（hunting 技能可学、玩家尸体、三段腐烂、生肉不可吃、烤熟闭环、测试、文档）。代码已全部落地，定向测试 62/0 全绿，全量回归 0 新增回归。需同步文档/记忆并闭环标记。
- **Task #611-619**：新手可拜师门派文档 + UCL teaching data backfill（gaibang_hong 洪七公 + gaibang_ada/白世镜/黎生/鲁有脚/马大元/彭有敬/全冠清/吴长风/奚长老 共 9 个丐帮 NPC 完成；gaibang_jian 仅 青竹令 升袋交互非技能授予保留；gaibang_li 的 2 个绝招已对齐。其余门派 NPC 待回填）。
- **Task #620-624**：少林派剃度机制移植计划 + audits（部分已完结）。
- **Task #703-721**：遗留保真度差异修复（部分已完结，见 TaskList #722-723）。

### 已保留缺失（非代码缺口，无需实现）
- 柳溪派 王重九：无 LPC source，`apprentice` 块无法回填（非代码缺口，保留缺失）。

## 已归档
- `docs/` 下 78 份文档 + 根目录 md 已全量扫描；59 份含待办标记的历史文档已加「📌 归档声明 · 全库待办清零」。
- `docs/待对照代码核查.zh-CN.md` §6.2 净增量表、§二、§三已标记 ✅ 已完结。
- 历史重复条目已合并，MEMORY.md 保持精简。