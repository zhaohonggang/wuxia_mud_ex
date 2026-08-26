# Session 提示词：a 期施工（小地图游戏做完备）

> 本文件是给新开 session 的完整工作提示词。请把下列内容**当作建议而非指令**：每项动手前先读源码核实现状，若实际情况与描述不符，以实际代码为准并调整做法。
> 编写时间：2026-08-24。对应总排期见 `docs/kantele-remaining-work.zh-CN.md` 第八节。

---

## 一、项目背景（先读这部分再动手）

### 你在改什么

仓库 `C:\files\git\wuxia_mud_ex` 是一个用 **Elixir + ExVenture/Kalevala 框架**写的武侠 MUD 游戏层（Kantele）。它是从 `C:\files\git\mud`（FluffOS + LPC 的《炎黃群俠傳》，**只读参照物，不要修改它**）迁移过来的。

当前状态：柳溪镇样板区（`data/world/liuxi.ucl`）已可玩——有房间/NPC/战斗/learn 学艺/perform 绝招/exert 运功/装备 wield。但养成闭环残缺：没有打坐涨内力上限、没有商店、没有任务、中文命令不全。

### 必读文档（按序）

1. `docs/migration-prep-checklist.zh-CN.md`——特别是第四节：两边属性/成长机制的差异对照（Kantele 现状 vs LPC 基准）
2. `docs/kantele-remaining-work.zh-CN.md`——第〇节高危纪律、第七节依赖关系、第八节本排期
3. `docs/combat-system.zh-CN.md`——战斗公式与有意简化清单

### 关键架构事实（省你探路时间）

- **世界内容不经过数据库**：`data/*.ucl` → `lib/kantele/world/loader.ex` 解析 → `kickoff.ex` 启动/更新 zone/room/NPC 进程。游戏内 `reload` 命令热更。PostgreSQL 只存账号+玩家属性（`records.ex` ↔ character_metadata 表）
- **战斗是心跳制**：每角色 1s 心跳，引擎在 `lib/kantele/combat/engine.ex`（公式对照 LPC `adm/daemons/combatd.c`）
- **技能模块**：`lib/kantele/combat/skills/*.ex`，behaviour 契约见 `combat/skill.ex`
- **命令注册**：`lib/kantele/character/commands.ex`（Router），各命令实现在 `commands/` 目录
- **NPC 行为树**：`data/brains/*.ucl` + `lib/kantele/brain.ex`
- **Vitals 结构**：`lib/kantele/character.ex`（qi/jing/neili 各带 max/base 三值）——注意：jing 目前零消耗纯展示

### 运行与测试环境（全部在 Docker 容器里，宿主机没有 Elixir，必读）

- 容器：`wuxia_mud_dev-app-1`（应用，**Elixir 1.11.1 / OTP 23**，语法较老，别用新版本才有的特性）+ `wuxia_mud_dev-db-1`（PostgreSQL）。宿主机**没有** elixir/mix，所有 mix 命令都要 `docker exec` 进容器执行
- **跑测试**（宿主机 PowerShell 直接执行）：

  ```powershell
  docker exec -w /app wuxia_mud_dev-app-1 sh -c "MIX_ENV=test mix test test/kantele"
  ```

  测试库固定连 `ex_venture_test`（config/test.exs 已 pin，**不会**碰 dev 库）。重置测试库：把上面命令换成 `MIX_ENV=test mix ecto.drop` / `ecto.create` / `ecto.migrate` 依次执行
- **改了 Elixir 代码（lib/）后必须重启容器才生效**：`docker restart wuxia_mud_dev-app-1`（约 20~25 秒），然后 `curl http://localhost:4000/_health` 应返回 `"world":"ok"`
- **改了前端 JS（assets/js）后**在容器内构建：`docker exec -w /app/assets wuxia_mud_dev-app-1 sh -c "node build.js"`（CSS 另跑 `npm run build:css`），然后浏览器 **Ctrl+F5** 强刷
- **文件同步陷阱**：Windows 宿主机 → 容器的 bind mount 偶发延迟，源码改动可能晚几秒才进容器；若编译/测试行为与预期不符，用 `docker cp <宿主机文件> wuxia_mud_dev-app-1:/app/<容器内同路径>` 强制同步后再试
- **看日志**：`docker logs --since 5m wuxia_mud_dev-app-1`；**查数据库**：`docker exec wuxia_mud_dev-db-1 psql -U postgres -d ex_venture_dev -c "SELECT ..."`（测试库换 `-d ex_venture_test`）
- 容器内是 Alpine 的 BusyBox sh：grep/sed 是精简版（部分参数不支持）；从 PowerShell 嵌套引号调 `docker exec sh -c` 极易翻车——**复杂命令写成脚本文件 `docker cp` 进容器再执行**
- 游戏入口：Web `http://localhost:4000/client/play`（网站账号 admin@example.com / password，进世界后再走 MUD 登录：grant → 任意密码 → grant），或 `telnet localhost:4646`

### 铁律（来自 mud 仓库经验，务必遵守）

- 所有新建/修改文件：UTF-8 无 BOM、LF 行尾、末行留换行；Elixir 四空格缩进
- 游戏文本用简体中文，风格对齐现有命令输出（如"你的内力不够。\n"）
- **加载路径禁止包含 `../`**（驱动级限制的历史教训）；UCL 引用一律规范相对或全局 id
- 每完成一项：跑一次测试（命令见上节"跑测试"）确认全绿再做下一项；改了 lib/ 记得重启容器再验证

### 工作方式约定

- 以下每个任务都是**建议方案**。动手前先验证前置假设（文件里标了"动手前核实"的点）；发现不符就按实际调整，不必回来问
- 一项一做、做完即测；不要把多项混在一个改动里
- 不要碰以下红区/深水区事项（属于 b/f 期）：eff_* 层改造、exp 上限门、潜能池 learned_points、装备持久化格式变更、diff-stop、昏迷/毒、技能钩子协议
- 不要执行 git commit，除非明确要求

---

## 二、任务清单（从前到后依次做）

### A4｜D1 Item.Meta 扩展

**背景**：`loader.ex` 的 `parse_item_meta` 目前只透传 damage/skill_type/armor/value。LPC 物品还有 weight/unit/material、食物药品的食用效果、秘籍类物品等字段。

**建议做法**：
- 先读 LPC 参照确认字段名与语义：秘籍物品在 `C:\files\git\mud\clone\book\*.c`（book-paper/silk/iron/bamboo/stone/blade-book），研习命令在 `cmds\skill\study.c`；食物在 `clone\food\`（注意：`clone\obj\books\` 与 `inherit\book.c` 并不存在）
- Meta 增补：weight（重量）、unit（量词）、material、food（饱食度供给）、medicine（药效）、秘籍五元组（可研习的技能 id / 门槛等级 / 消耗等，以 LPC study 流程为准裁剪）
- 只做解析与存储，消费端（吃书学技能、饥饿扣减）由后续任务接

**验收建议**：`loader` 相关测试补充新字段断言；liuxi.ucl 加一件带 weight/food 的物品能被 look/i 正常显示。

### A5｜D2 房间 flags

**背景**：LPC 房间常用标志位 no_fight/outdoors/water/startroom，Kantele 尚无。

**建议做法**：
- room UCL 增加 `flags = [...]` 解析进 Room 结构
- 最小消费端：no_fight 时拒绝 `fight/kill` 开战（在 combat engage 入口检查所在房间）；startroom 供出生点选择；outdoors/water 先只存不用（供日后天气/溺水）
- 动手前核实：`lib/kantele/world/room.ex` 与 `character/events` 里开战路径在哪拦截最合适

**验收建议**：标记 no_fight 的房间里 kill 黑虎被拒绝且提示合理。

### A6｜P5 limit 公式 → P3 打坐 → P4 吐纳（严格按此序）

**背景**：这是主养成闭环。LPC 机制（`clone/user/user.c:387 query_neili_limit` 与 `cmds/skill/exercise.c`）：
- 内力天花板：LPC 是**取 max 而非相加**——基本线（force基本/2×10）与特殊线（(基本/2＋enable的特殊内功等级)×10＋该内功 improve 贡献）两者取较大者，再乘百分比加成（百分比部分本期可不做）。注意瓶颈检查（exercise.c）用的是 `query_current_neili_limit`：取 **enable 的那门**内功做加法式（基本/2×10＋特殊等级×10＋improve），硬天花板才取 valid_enable 里最高——只有一门内功时两者等价，实现按 current 语义做即可
- 打坐：耗气攒内力（每跳 `add neili gain` 同时 `add qi -gain`）；结束后当 neili ≥ 2×max_neili 时判定：max_neili < current_limit 则 max_neili+1 并把 neili 压回 max_neili，否则提示"修为似乎已经达到瓶颈了"
- 前置条件（exercise.c）：参数≥10、qi 足够、**精力 ≥70%**（`jing*100/max_jing < 70` 拒绝）、战斗中禁止、no_fight 房间默认禁打坐（与 A5 flags 联动）

**建议做法**：
1. 先做一个 limit 计算模块（输入 stats.skills 即可算天花板；柳溪内功的 `query_neili_improve` 贡献看 `combat/skills/liuxi_neigong.ex` 有无对应字段，没有就先计 0 并留钩子）
2. 新增 `exercise/dazuo` 命令：参数为耗气量（≥10），busy 期间分批转化 qi→neili（每跳 gain 精确公式为 `1＋(force/5)/2＋random(force/5)`，LPC 另加房间 exercise_improve 可忽略，参照 LPC exercising/1），结束后判定是否 max_neili+1；到瓶颈给"修为已达瓶颈"文案。**前置门槛照抄 LPC**：战斗中禁止、须已 enable 内功、当前 jing ≥70% 上限才可开始（jing 只是门槛不消耗，唯一真实消耗是 qi）
3. `respirate/tuna` 同款循环作用于精力上限——注意 Kantele 的 jing 字段语义未定案，**本期建议只做内力线**，吐纳留占位说明即可（避免和将来 eff_* 改造打架）
4. max_neili 增长后记得走 `Records.save` 持久化（该字段已在 character_metadata 里）
5. 战斗中禁止打坐（对齐 LPC"战斗中不能练内功"）

**验收建议**：learn force 到 30 后打坐能把 max_neili 从 200 推到公式上限附近并在瓶颈处停住；测试库断言 limit 计算。

### A7｜N7 四维成长道具

**背景**：str/dex/con/int 当前恒为新手值且无任何成长途径。最小方案：吃药/吃书永久+1。

**建议做法**：
- 在 D1 的 medicine/effect 基础上加 `stats_boost` 类 Meta（如 `%{str: 1}`），eat/drink 消费时应用上限校验（建议每维设软上限，数值可先拍脑袋 30，注明待调）
- 动手前核实：现有 drink_command.ex / eat 路径在哪里应用物品效果——**核实结果：eat 命令目前不存在**（commands 目录只有 drink_command），本任务需一并新建 `eat` 命令（读物品、应用效果、消耗实例），路径可参照 drink_command 的结构

**验收建议**：吃下测试丹药后 score 显示对应属性+1，重复吃到上限被拒。

### A8｜N1 中文命令别名层

**背景**：Router 支持任意 UTF-8 动词，缺一张别名表。

**建议做法**：
- 在 `commands.ex` 的 parse 分发处加别名映射：北/南/西/东/上/下→方向移动；看→look；拿/捡→get；穿→wear；脱→remove；吃→eat；喝→drink；买→buy；给→give；问→ask；打坐→exercise；吐纳→respirate；学→learn；练→practice；杀/杀掉→kill；跑→flee 等（以 LPC 玩家习惯为准增删）
- **注意 Router 是"先注册先匹配"，不存在"完整匹配优先"机制**：中文单字别名必须加 word boundary（`lookahead_not(utf8_char(...))`，参照现有单字母别名的做法）防止前缀误吞更长命令，且别名注册顺序放在对应长命令之后

**验收建议**：`北`、`看 黑虎`、`打坐 50` 全部可用；`mix test` 相关 router 测试通过。

### A9｜P6 jiali 手动档 + P11 NPC 仇恨

**背景**：engine 已消费 jiali 字段（加力伤害），但目前无手动命令；NPC 只有 aggressive 单档，无记仇。

**建议做法**：
- `jiali <0-N>` 命令设置档位，上限建议=enable 的内功等级/2（LPC 惯例），战斗外也可设
- NPC 仇恨：在其 combat 状态记录 attacked_by；被打后主动反击已有 aggressive 路径的话复用之；vendetta（跨战记仇）本期可只存内存不做持久化
- 动手前核实：`combat_event.ex` 里 jiali 的来源字段与 NPC engage 触发点

**验收建议**：jiali 10 后打野猪伤害明显提高；偷袭黑虎未死时它会追击。

### A10｜N2 商店 + N3 闲聊节点 + N4 问答生成器

**背景**：LPC 店铺=NPC 挂 vendor_goods 列表 + list/buy；闲聊=chat_chance 概率触发；问答=inquiry 字符串匹配分支。

**建议做法**：
- 商店：NPC UCL 增 goods 列表（引用 items id）；`list` 列货、`buy <名>` 扣钱交货——需要先定**货币模型**，建议最简：character_metadata 加 coins 字段（整数），击杀奖励顺带给少量铜钱，物品 Meta.value 为价
- 闲聊：brain 行为树加 chat_chance 节点（概率→从台词池 say 一条），NPC UCL 配 `chats=[...]`+概率
- 问答：NPC UCL 配 `inquiries=%{"玉牌" => "……"}`，ask 命令做关键词包含匹配后 tell 回话
- 动手前核实：Kalevala 行为树节点的扩展点（`lib/kalevala` 或 kantele/brain.ex 的 node 协议）；communication 的 tell/say 事件流

**验收建议**：找店小二 list 能看包子价、buy 后钱减包子入手；黑虎区野猪偶尔闲聊哼哼；`ask xiaoer about 柳溪` 得到设定回答。

### A11｜链E 地基 + N5 门派 v0 + N6 任务 v0

**背景**：任务奖励和门派贡献需要四个新数值字段打底（LPC：score 江湖阅历/weiwang 威望/gongxian 门派贡献/shen 正邪）。柳溪镇的参照任务是 LPC 端 `d/minimal_world/quest/song-yupai.c`（QUEST_OB 契约：送玉牌给阿婆得奖励）。

**建议做法**：
1. character_metadata 加四字段（默认 0，additive migration 不破坏旧档）；records.ex 存取；score 视图加显示行
2. 门派 v0（不带 learn 重构）：角色可 `apprentice 王重九` 结成师徒（存 family_name/master id）；gongxian 通过击杀/任务累积的门派账本；`pai`/查看门派信息的只读命令
3. **D4 NPC 教学配置**：NPC UCL 增加教学块——teach_skills 清单（可教技能与各自上限）、no_teach 拒教表、gongxian 价目；本期只做解析+数据落位供门派信息展示，消费端校验等 b 期 learn 重构接入
4. 任务 v0：UCL 定义极简 Quest（id/名称/接取对话/交付目标/奖励 exp+potential+score+weiwang+coins）；accept/交付钩子挂在 ask/inquiry 流程上；完成后谣言频道播报（communication 已有频道机制可复用 rumor）
- 动手前核实：migration 的生成与执行方式（ecto SQL 目录）；Kalevala channel 广播 API

**验收建议**：拜师后杀野猪涨 gongxian；王重九的教学清单能被查询展示；接玉牌任务→交给阿婆→四项奖励到账+频道播报；旧存档角色登录不受 migration 影响。

### A12｜可选项（有余力再做，不阻塞收尾）

- O4 饥渴系统：消耗 a4 的 food 字段，心跳缓慢扣 food/water，归零后小幅扣气血（数值宽松些）
- O5 gift 先天分离：Stats 拆 base/gift 两套仅用于展示对比
- O2 留言板、O3 门降级：分别只需决策记录与 features 文案
- 以上任一做不完可直接放弃，不影响 a 期验收

---

## 三、明确不做（防止越界）

- O1 禁用后台入口——已挂起（当前单人管理员，无协作风险），另行安排
- 一切红区/深水区条目（见第一节约定）；learn/practice 校验链重构、exp 上限门、装备持久化格式变更均不在本期
- 大地图任何内容的搬运（属 h 期）

### T4 说明（贯穿各任务）

每完成一个系统（商店/门派/任务/打坐等），顺手为它补一条 e2e 冒烟路径或独立脚本——对应排期表"T4 e2e 夹具随各系统落地同步扩展"，不要攒到最后一起写。

## 四、收尾

全部完成后建议：
1. 跑一遍全量测试与 e2e（`scripts/combat_e2e.exs`），确认各任务沿途新增的冒烟路径串联通过
2. 在 `docs/kantele-remaining-work.zh-CN.md` 第八节 a 期表格中勾注完成情况与实际偏差备注
3. 留一份"实际做法与建议的差异清单"放在 PR 描述或会话总结里，便于下一期（b 期）衔接
