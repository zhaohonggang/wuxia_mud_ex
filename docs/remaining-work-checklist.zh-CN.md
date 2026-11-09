# 剩余工作清单（Remaining Work Checklist）

> 记录：2026-09-11 ｜ 分支 `kalevala`
> 来源：全量代码核查 + `docs/kantele-remaining-work.zh-CN.md` + `lpc_example/ex/MIGRATION_PLAN.md` 复核
> 基线：2334 tests / 0 failures（seed 731933/788424）
> 约定：所有规划批次（P0–P5 / M1–K3 / Q1–Q6）已完成；下表为**续做候选**，按优先级分档。

---

## A. 项目级工程缺口（最大 backlog）

| 项 | 说明 | 阻塞 | 参考 |
|----|------|------|------|
| **A1. T1 LPC→UCL 转换器** | 批量把 LPC 世界文件转成 UCL，仓库中不存在任何转换器代码 | 阻塞 A2/A4 | `docs/kantele-remaining-work.zh-CN.md:256` |
| **A2. T2 柳溪镇 34 文件全量对拍** | 将现有柳溪镇数据与 LPC 34 文件逐项比对补齐 | 依赖 A1 | 同上 `:260` |
| **A3. f1 Diff-stop** | reload 终止「旧有而新无」的 zone/房间/NPC，已实现（`cleanup_stale_processes/1` + 角色→房间→zone 终止顺序 + zixu 豁免 + `DynamicSupervisor.terminate_child/2` 正常摘除 + `:global` 注册名清理） | 无 | `lib/kantele/world/kickoff.ex`；测试 `test/kantele/world/kickoff_test.exs` 14/0 |
| **A4. g 终测 / h 大规模分区搬运** | 全流程端到端验收 + 分区级世界搬迁 | 依赖 A1/A2/A3 | 同上 `:277-286` |

### A3 详情（f1 Diff-stop）—— ✅ 已完成

**实现内容**（`lib/kantele/world/kickoff.ex`）：

1. `apply_world/3` 先调用 `ensure_world_infrastructure/0`（兜底启动 `Kalevala.World` DynamicSupervisor 与 `ZoneCache`），再在 `safely/1` 内调用 `cleanup_stale_processes/1`。必须按此顺序：`Kalevala.Cache.keys/1`、`get/1` 直读 ETS 表，表不存在会抛 `ArgumentError`，且清理逻辑若在 `safely/1` 之外会直接击杀加载进程。
2. 角色清理：`DynamicSupervisor.which_children` 遍历各 zone `CharacterSupervisor` 子进程，`char_id != "zixu_daoren"` 且不在新世界集合中的角色发 `:terminate`（Foreman 以 `:normal` 退出，不会被重启）。
3. 房间清理：`stop_room/1` 通过房间状态里的 `supervisor_name` 找到 `RoomSupervisor`，用 `DynamicSupervisor.terminate_child/2` 正常摘除，再 `wait_for_exit/2` + `:global.unregister_name`。
4. Zone 清理：`purge_zone_tree/1` 用 `DynamicSupervisor.terminate_child(Kantele.World, pid)` 正常摘除 ZoneSupervisor，其子进程随之退出；残留 `:global` 名字逐个 kill + 注销；最后 `ZoneCache.delete`。
5. **关键约束**：ZoneSupervisor / Room 都是 `:permanent` 子进程，直接 `Process.exit(pid, :kill)` 会被监督树重启并重新注册 `:global` 名字，甚至触发 DynamicSupervisor 重启强度上限导致整个 supervisor `:shutdown`。必须走 `terminate_child/2`。
6. `start_zone/2` 只在 Zone / RoomSupervisor / ZoneSupervisor 三者都存活时才「原地 update」；任一缺失即 `purge_zone_tree/1` 后重建，避免半死树造成 `already_started` / `:noproc`。
7. 所有 `ZoneCache` 访问经 `safe_zone_keys/get/delete` 包装（ETS 表缺失 / GenServer 退出降级为无旧数据），`safe_get_state/1` 统一返回 `{:ok, state}`。

**测试**：`test/kantele/world/kickoff_test.exs` A3 f1 Diff-stop 三例全部通过（zone 被移除 / 房间被移除 / ZoneCache 条目清理），共 14/0；seed 137275 / 130361 / 1 / 999999 / 42 均 0 失败；与 hand/push/secularize 三个命令套件合跑 56/0（多 seed）。`test/kantele/world` 目录 1957/3，3 个失败（`npc_actions_yitian_test` 的 `:max_neili` KeyError、`mirror_zixu_test` 的 `:rand.uniform(0)`）单独跑同样复现，属既有失败。

---

## B. 占位命令（stub，未实现真实逻辑）

### B1. 23 个"XX系统暂未开放"文案 stub

> 均为 `run/2` 渲染占位文案，无事件/逻辑。文件统一位于 `lib/kantele/character/commands/`，占位在第 15 行（个别在 17–23）。

| 命令 | 文件 | 备注 |
|------|------|------|
| answer | `answer_command.ex:15` | **(聊天配对子系统)** forge 议价已真化；非 forge 路径为「回复最后 ask 你的人」+ `quest_gift` Y/N，依赖玩家 `ask` 命令与 quest 临时态 |
| ansuan | `ansuan_command.ex` | 已真化：LPC `ansuan.c` 跨方向暗算门控 + 突袭/暴露/收尾（`ansuan_command_test` 绿） |
| beg | `beg_command.ex` | 已真化：丐帮门禁 + 房间 `no_beg`/`no_fight` 闸门 + `beg/attempt` 跨房间裁定落币（`beg_command` 绿） |
| come | `come_command.ex` + `beast_taming.ex` | 已真化：LPC `come.c` 13 道门（战斗中 / 驭兽术 / 已有 comedby / present / userp / race / 野兽打架或忙 / 无主 / 别人的反扑 / 自己 / living / 精力）+ 扣精 + `comedby` + `set_leader`（`come_command_test` 17/0） |
| hand | `hand_command.ex` | 已真化：LPC `hand.c` 手持门控（背包 present / 重量 20000 / 双手皆占 / 已装备）+ `:handing` 槽位（与 wield/remove 共用），`hand nothing` 收回（`hand_command_test` 绿） |
| liuxi | `liuxi_command.ex` | 已真化：走当前房间 `liuxi` 出口到柳溪镇广场，反向由 `yangzhou` 出口接回 |
| pkd | `pkd_command.ex:15` | **(PK场子系统)** 依赖 `PK_D` 屠人场 daemon（`is_ready` / `query_all_competitor` / `is_pking`），无对应后端 |
| push | `push_command.ex` | 已真化：LPC `push.c` 跨方向推人门控 + qi/neili/force 消耗 + 目标 force>=150 推不动 + 目标 `character/teleport` 瞬移 + busy 收尾（`push_command_test` 绿） |
| release | `release_command.ex` + `beast_state.ex` | 已真化：LPC `release.c` 遍历同房间自己名下的野兽逐条播报放生并清 owner；无可放生时输出「想放生，可是没啥可放的」（`release_command_test` 6/0） |
| remove | `remove_command.ex` + `wield_command.ex` | 已真化：统一 `remove`/`脱` 路由到 `RemoveCommand`，实现 LPC `remove.c` 的 `remove all`、`present()` 与 worn 双重门控；`WieldCommand.remove/2` 保留为共享单件脱卸、`remove_all/1` 处理批量（`remove_command_test` 47/0 子集） |
| secularize | `secularize_command.ex` | 已真化：LPC `cmds/std/secularize.c` 的 `class != "bonze"` 静默、四大僧派禁自由还俗、`pending/secularize` 二次确认 + rumor 频道广播 |
| stab | `stab_command.ex` + `item_use.ex` | 已真化：LPC `stab.c` 无参/背包 `present` 双门 + `do_stab` 经 `ItemActionHandlers` 分发，未注册回落 `notify_fail` 兜底文案（`stab_command_test` 6/0） |
| special | `special_command.ex` + `special_skill.ex` + `special_skills.ex` | 已真化：LPC `special.c` 未出生/无特技提示、`special <特技> [参数]` 经 `SpecialSkills.daemon/1` 调 `perform/3`（busy/未拥有/未注册三道门）、巫师 `special <玩家>` 列他人清单、转世 8 项归「转世」小节（`special_command_test` 14/0） |
| stop | `stop_command.ex` + `beast_taming.ex` | 已真化：LPC `stop.c` 参数 / present / 必须是自己的 / 野兽不忙 + 呼哨 vision + `remove_all_enemy(1)`（`stop_command_test` 7/0） |
| stay | `stay_command.ex` + `beast_taming.ex` | 已真化：LPC `stay.c`（`ting.c`）用 `comedby` 回房间找野兽，owner / 自己 / living / 打架四门 + 清 `comedby` + `set_leader(0)`（`stay_command_test` 11/0） |
| talk | `talk_command.ex` | 已真化：LPC `talk.c` 解析 + 房间 NPC 查找 + `meta.inquiries` 应答（`talk_command_test` 绿） |
| train | `train_command.ex` + `beast_taming.ex` | 已真化：LPC `train.c` 12 道门（驭兽术>=10 / 参数 / present / userp / race / 已有主人 / 别人的 / 自己 / living / 精力 / 随机失败 / 结算）+ `jing` 扣减、驭兽术提升、清敌、`owner` 登记（`train_command_test` 16/0） |
| top | `top_command.ex` + `top_ranking.ex` | 已真化：经验/等级/气血/精力/年龄榜（`top_command_test` 绿）；kill/die 因无计数器返回「未记录」 |
| top2 | `top2_command.ex` + `fame_board.ex` | 已真化：LPC `top2.c` 的 `family`/`league` 声望榜 + 昨日 delta + 同盟限 30 条 + `chinese_number` 尾行（`top2_command_test` 绿） |
| topp | `topp_command.ex` + `fame_board.ex` | 已真化：`topp.c` 与 `top2.c` 源码内容完全相同，共用 `FameBoard`（`topp_command_test` 绿） |
| to | `to_command.ex:15` | **(聊天/邮件子系统)** 多行信息广播路由（`say`/`tell`/`chat`/...）+ 行编辑器 `me->edit` + `neili`/`jing` 消耗 |
| touch | `touch_command.ex` + `item_use.ex` | 已真化：LPC `touch.c` 无参/背包+房间双范围 `present` 三道门（找不到/是人物/物品），`do_touch` 经 `ItemActionHandlers` 分发，未注册回落兜底文案（`touch_command_test` 9/0） |
| vote | `vote_command.ex:15` | **(投票子系统)** 依赖 vote daemon + `chblk`/`unchblk` 动议文件 + 投票权/附议计时，无后端 |

### B1 续做批次：`remove` + `top2` / `topp`（2026-11-08，未提交）

**`remove` 路由碎片化修正**：原先 `WieldCommand` 注册了带参的 `remove <物品>` / `脱 <物品>`，
`RemoveCommand` 只接裸 `remove` 且是占位文案；`remove all` 被当成物品名、`present()` 与
worn 门控缺失。现 `commands.ex` 把 `remove` / `脱` 用 `optional(spaces + text(:item_name))`
统一交给 `RemoveCommand.run/2`，裸命令回「你要脱掉什么？」，`all` 走
`WieldCommand.remove_all/1`（因 `put_character/2` 只写 `conn.private.update_character`，
批量脱卸必须在 reduce 里显式传递已更新的角色，否则只剩最后一件）。武器 / `:handing`
槽位不属 `remove.c` 范围，保持不变。

**`top2` / `topp` 声望榜**：LPC `cmds/usr/top2.c` 与 `topp.c` 内容逐行相同，Ex 侧收敛成
`Kantele.Character.FameBoard`：

- 数据源 `Kantele.FamilyFame`（新增，移植 `adm/daemons/familyd.c` 的 30 项
  `base_family_fame` 静态表 + `add_family_fame` 钳位 + 跨天 `snapshot/0`）与
  `Kantele.League`（补 `last_fame` 字段、`query_all_last_league_fame/0`、
  `snapshot_last_fame/0`）。两者都新挂进 `ExVenture.Application` 监督树。
- 渲染照抄 LPC：`%2d. %-12s  %-9d(%s%d%s)`、正数 `+`/负数 `-`/零 `0` 的 delta、
  同盟空榜的 `notify_fail`、同盟最多 30 条、`chinese_number()` 尾行。
- 已知差异：去掉 `WHT/HIY/HIR` ANSI 交由输出管线着色；列宽按 CJK 显示列（2 列）
  而非 LPC 的字节数补齐；LPC 的 1800 秒跨天心跳在 Ex 侧暂无定时器，快照需由上层
  主动调用，故未推进前 delta 恒为 0（与 LPC「无昨日数据」一致）。
- `commands.ex` 的 `top2` / `topp` 改为 `optional(spaces + text(:category))`，
  用 `text` 而非 `word` 才能让 `top2 league 多余` 整体落到「你要看什么排行榜？」。
- `test/kantele/command_probe_test.exs` 白名单已移除这两个文件，退化成占位桩会直接失败。

**验证**（Docker daemon 不可用，改用 Windows 对齐工具链 Erlang/OTP 25 + Elixir 1.13.4）：
`mix compile` exit 0；因 `mix test` 别名强制 `ecto.create/ecto.migrate` 且本机无 Postgres，
改走 `mix run -e` + `ExUnit.run()` 的纯函数测试路径。10 个相关测试文件合跑
**123 tests / 0 failures**，seed `0 / 1 / 42 / 999999` 全部 0 失败。

### B1 续做批次：驯兽五命令 `train` / `come` / `stay` / `stop` / `release`（2026-11-08，未提交）

照 LPC `cmds/std/{train,come,stay,stop,release}.c` 逐条落地门控与文案，收敛成两个共享模块：

- **`Kantele.Character.BeastState`**（新增，挂进 `ExVenture.Application` 监督树）：ETS 表按 NPC id
  存 `owner_id` / `owner_name` / `leader_id` / `attitude` / `ridable` / `enemies` / `busy`。
  原因：`NonPlayerMeta.Trim` 只保留 vitals/stats/guarder/aliases/init，命令侧拿到的是房间快照，
  `Conn.put_character/2` 又只写玩家侧，NPC 的 temp/leader/enemy 状态必须另有落点。
- **`Kantele.Character.BeastTaming`**（新增）：房间 NPC 查找（可 `conn.private[:beast_characters]`
  注入）、`training` 技能 / `int` / `jing` 成本 / 随机成败（可 `[:beast_roll]` 注入）、
  `comedby` 玩家 temp、主人归一、广播（可 `[:beast_broadcast]` 注入）、反扑（可
  `[:beast_retaliate]` 注入）、`NpcAttack.kill_ob/2`、`LearnGate.can_improve?/2` 升级。
- **建模差异（已按 LPC 设计意图归一，非 bug 保留）**：
  ① LPC `race` 由 `inherit/char/{quarry,snake}.c` 的 `set("race","野兽")` 设置，Ex 的
  UCL 转换 / `Loader.parse_character/4` 不输出该字段，故 `beast?/1` 优先读显式 `race`，
  否则回退到 52 项静态注册表（LPC 野兽文件 key + 中文名）；
  ② LPC `train.c` 写 `set_temp("owner", me)` 却在别处按 `me->query("id")` 字符串比较，
  `stay.c` 也把对象型 owner 与 id 字符串比较（新驯服的野兽会被误判成「别人的」并反咬主人），
  Ex 统一用 `owner_id`；
  ③ LPC `message_vision` 用房间广播，Ex 侧通过 `BeastTaming.broadcast/2` + `Room.tell_room/3`。
- **`commands.ex` 路由修正**：这批命令的 `run/2` 需要 `target` 参数，原 `parse/2` 裸路由只产出
  `%{"command" => ...}`；顺带发现 `push` / `hand` / `talk` / `ansuan` 的带参分支此前也是死代码。
  现统一改为 `optional(spaces + text(:rest|:target|:category))`，裸命令与带参共用一条规则；
  `SecularizeCommand.run/2` 的 `%{}` 前置子句同样修正为通配 `_params`。
- **占位桩白名单**：`test/kantele/command_probe_test.exs` 现在只列真实剩余 stub；
  `liuxi_command.ex` 里一句历史注释含「暂未开放」被探针误报，已改写措辞。

**验证**（Windows 对齐工具链 Erlang/OTP 25 + Elixir 1.13.4，纯函数测试路径）：
`mix compile --force` exit 0；新增 `test/support/beast_taming_fixtures.ex` + 6 个测试文件
（`beast_taming_test` 21 / `train` 16 / `come` 17 / `stay` 11 / `stop` 7 / `release` 6），
连同 `command_probe_test` 合跑 **80 tests / 0 failures**；B1 + A3 相关 21 个测试文件合跑
**236 tests / 0 failures**，seed `0 / 1 / 42 / 137275 / 999999` 全部 0 失败。
（纯函数 harness 需手工起 `Kantele.World.Items` / `Kantele.League` / `Kantele.FamilyFame`，
否则 `HandCommandTest` 等会因服务未启动失败，与本次改动无关；`kickoff_test` 还需
`:global` RoomSupervisor，属既有 harness 缺口。）

### B1 续做批次：`special` / `stab` / `touch`（2026-11-08，未提交）

照 LPC `cmds/std/{special,stab,touch}.c` 落地门控与文案，复用既有 Ex 基础设施：

- **`special`**（特技）：新增 `special_skill.ex`（`SpecialSkill` behaviour 适配层，兼容
  `name/0`+`perform/3` 与旧 `title/0`+`perform/2(conn, opts)` 两种形状），复用
  `SpecialSkills` 注册表（`daemon/1` 解析 `special <name>` 要调的模块）。逐条落地
  LPC 分支：未出生提示、无特技提示、巫师 `special <玩家>` 列他人清单（在线玩家经
  `conn.private[:special_players]` 注入）、`special <特技> [参数]` 经 `perform/3`
  （busy / 未拥有 / 未注册三道门）、转世 8 项（`guibian`…`tiandao`）归「转世」小节。
  注册表从空库起步，无授予路径时玩家仍见「什么特技都不会」，与 F2 保守语义一致。
- **`stab` / `touch`**（物品交互）：新增共享模块 `item_use.ex`（`find_in_inventory` /
  `find_present` / `dispatch`），把 LPC 的 `do_stab` / `do_touch` 对象方法转到
  `Kantele.World.ItemActionHandlers` 的 handler 注册表（`stab` 单查背包、`touch` 背包+
  房间双范围且命中人物时回「你别乱动X了。」）。未注册 handler 回落 LPC `notify_fail`
  兜底文案——大部分物品今天走此路径（建模缺口见 `item_use.ex` 模块说明）。
- **`commands.ex` 路由修正**：`special` / `stab` / `touch` 改为
  `optional(spaces + text(:rest))`，裸命令与带参共用一条规则。
- **占位桩白名单**：`test/kantele/command_probe_test.exs` 移除 `special_command` /
  `stab_command` / `touch_command`，当前剩余真实 stub 仅 `answer` / `pkd` / `to` /
  `vote` / `clone`（半开）。

**验证**（Windows 对齐工具链，纯函数测试路径）：`mix compile` exit 0；新增
`test/support/interaction_fixtures.ex` + 3 个测试文件（`special` 14 / `stab` 6 /
`touch` 9），连同 `command_probe_test` 共 **29 tests / 0 failures**；B1 + A3 相关
22 个测试文件合跑 **263 tests / 0 failures**，seed `0 / 1 / 42 / 137275 / 999999`
全部 0 失败。

### B1 收尾：自包含占位桩已全部真化（2026-11-08，未提交）

逐一审视 `CommandProbe` 实测剩余 6 个 stub（`answer` `pkd` `to` `vote` `scheme`
`clone`）的 LPC 源与 Elixir 现状，结论是 **B1 范围内「自包含、可独立真化」的占位
命令已全部清零**。剩余 6 个全部依赖尚未建设的后端子系统（或属于未来里程碑），
不属于 B1 的自包含工作：

| 命令 | 里程碑 tag | 现状 | 缺口（需后端/里程碑） |
|------|-----------|------|----------------------|
| `answer` | 聊天配对子系统 | forge 议价已真；非 forge 路径为「回复最后 ask 你的人」+ quest_gift Y/N | 玩家 `ask` 命令 + quest 临时态 |
| `pkd` | PK场子系统 | 纯占位「屠人场暂未开放」 | `PK_D` 屠人场 daemon（无对应实现） |
| `scheme` | 计划执行器子系统 | **show/edit/clear 已真**；仅 `start` 自动执行器 deferred | vitals/busy 自动化执行器 |
| `to` | 聊天/邮件子系统 | 纯占位「to命令暂未开放」 | 多行行编辑器 `me->edit` + neili/jing 消耗 |
| `vote` | 投票子系统 | 纯占位「投票系统暂未开放」 | vote daemon + chblk/unchblk 动议 + 附议计时 |
| `clone` | 巫师命令 | **物品克隆已真**；仅「生物克隆」暂不支持 | Kalevala 无按路径克隆生物的能力 |

- `CommandProbe` 的判定是**纯文本标记**（`暂未开放`/`暂未实现`/`尚未开放`/`系统暂未`）；
  现有 6 个 stub 仅由这些占位文案触发，`test/kantele/command_probe_test.exs` 白名单
  与其严格一致（6 条），无需改动。
- **决策（用户确认）**：B1 自包含桩工作到此为边界，6 个命令按里程碑保留为占位桩，
  等待对应里程碑建设 PK 场 / vote / 聊天 / 行编辑等后端后再真化。本期**不**对其做
  任何代码改动，仅同步文档与 memory 标注现状。
- 完整测试基线：B1 + A3 相关 22 个测试文件合跑 **263 tests / 0 failures**（seed
  `0 / 1 / 42 / 137275 / 999999`），`mix compile` exit 0。

### B2. 14 个 W3 arch 静默 no-op

> 已注册（`commands.ex:1550-1605`，注释 "14个stubs - 需对象系统"），`run` 直接返回 conn。
> **E5（2026-11-09）已完成**：路由改造 + 全部显式化（非巫师拒绝、巫师明确回执），
> 再真化可落地的 `var`（私有变量）/ `setsk`（自身技能等级），其余 12 个属进程/对象系统
> 管理面、本端口无对应引擎能力 → 显式「未建模」回执并标注 Deferred。详见
> `docs/B5-剩余子系统与引擎改造计划.zh-CN.md` 第 6 节。

| 命令 | 计划处置 |
|------|---------|
| var | E5-2 真化：列/设 `meta.temp` 私有变量 |
| setsk | E5-2 真化：设自身/all 有效技能等级（需 `Stats.put_skill`） |
| build / call / changeuser / grant / possess / purge / reboot / register / restore / shutdown / smash / throw | E5-1 显式「本端口未建模」回执 + Deferred（进程/对象系统管理面，无对应引擎能力） |

### B3. 小占位 / partial

| 命令/系统 | 文件 | 缺口 |
|-----------|------|------|
| clone 生物克隆 | `clone_command.ex:22` | **(巫师命令)** item 可 clone，NPC 不可（Kalevala 无按路径克隆生物的能力） |
| suicide | `suicide_command.ex` | **(2026-11-09 已真化)** `suicide -f <密码>` 校验 `meta.password` 后 `ExVenture.Characters.delete_by_name` 链删角色 + rumor 广播（combat_exp>=1000）；15 秒 halt 倒计时为有意简化 |
| prepare valid_combine | `prepare_command.ex:108-109` | 组合逻辑未实装 |
| closed | `closed_command.ex:9,50` | CLOSE_D 离线修炼缺失 |
| scheme 自动执行 | `scheme_command.ex:38` | **(计划执行器子系统)** show/edit/clear 已真，start 未开（需 vitals/busy 自动化） |
| zixu 心魔幻境 | `world/mirror_daemon/zixu.ex:6,152-156` | 「尚在祭炼之中」占位 |
| uptime | `uptime_command.ex:24` | 手搓占位（无害） |

### B4. 剩余 6 个占位命令依赖的后端子系统（待建，尚未作为独立工作项登记）

> 2026-11-09 更新：原列 6 个占位命令（`pkd`/`vote`/`answer`/`to`/`scheme`/`clone`）依赖的后端子系统
> 已全部随 E1–E5 真化（PK 场 daemon、投票 daemon、ask/answer 配对、行编辑器、计划执行器、生物克隆均已落地），
> 故本节仅作历史归档。当前真正未建模的命令是 B2 的 12 个 W3 命令（进程/对象系统管理面，需 W3 对象引擎）。
> 原表保留以备回溯：

| 子系统 | 依赖它的命令 | LPC 源 | 当前 Elixir 状态 | 是否已在他处登记 |
|--------|------------|--------|----------------|------------------|
| PK 场 daemon（`PK_D`） | `pkd` | `adm/daemons/pkd.c` + `cmds/usr/pkd.c` | 无对应实现；`sign.ex`(pk:entry) 已落「无赛事」态文案 | ✅ 顺带提及：`npc-private-actions-survey.zh-CN.md:222`（「PK_D 建模」依赖）、`session-prompts-npc-actions-continuation.zh-CN.md:36,240`（`sign.ex` PK_D 未建模） |
| 投票 daemon | `vote` | `cmds/std/vote.c` + `cmds/std/vote/{chblk,unchblk}.c` | 无对应实现 | ❌ 无 |
| 聊天 ask/answer 配对 | `answer`（非 forge 路径） | `cmds/std/answer.c` + 玩家 `ask` 命令 | 仅 forge 议价分支；缺玩家 `ask` 命令 + `ask_you` 临时态 | ❌ 无 |
| 多行行编辑器（`me->edit`）+ 频道重分发 | `to` | `cmds/std/to.c` | 纯占位 | ❌ 无 |
| 计划自动执行器（vitals/busy 自动化） | `scheme start` | `cmds/usr/scheme.c` REPEAT/LOOP | show/edit/clear 已真，`start` 未开 | ❌ 无 |
| 生物克隆（按路径 `new(file)`） | `clone`（生物部分） | `cmds/wiz/clone.c` | 物品克隆已真，生物克隆不支持 | ❌ 无 |

- 注：B1 收尾里原写的里程碑 tag `(M3)`/`(M4)`/`(W2)` 已更正——它们与
  `lpc_example/ex/MIGRATION_PLAN.md` 中 M3（探测/信息类）、M4（疾患/生活技能）、W2
  （常用 wiz 命令）的定义**不符**，此处改用描述性子系统名（见 B1 表与 B1 收尾表的
  「里程碑 tag」列）。

---

## C. 社区 / 杂项 TODO

| 项 | 文件 | 说明 |
|----|------|------|
| brothers 跨角色同步 | `brothers_command.ex` / `ex_venture/characters.ex` / `world/room.ex` / `events/brothers_event.ex` | 断义时：持久化移除对方名单（`ExVenture.Characters.remove_brother/2`，离线亦可，LPC UPDATE_D 等价）+ rumor 广播 + 同房间在场兄弟内存同步（`brothers/break`→`brothers/broken`） |
| 饥饿系统不完整 | `feature_damage.ex:430-500` | heartbeat 扣减有，`eat` 仅展示（`eat_command.ex:8`） |

---

## D. 已记录的技术债（有意推迟 / v2）

| 项 | 来源 | 说明 |
|----|------|------|
| Q2 v2：疾病/光线/雪原封路 | `MIGRATION_PLAN.md:754` | event_noon 疾病、room light、季节封路 = stretch |
| Q1-T3：真·clone 动态目标 | `MIGRATION_PLAN.md:733-737` | 运行时 clone 需 Chei/Pawning |
| Q1-T3：search/explore 入位校验 | 同上 | 依赖房间人员查询 + 入位判断 |
| Q1-T3：count>1 逐件交付 | 同上 | |
| P-Adm 未开始（历史行） | `MIGRATION_PLAN.md:445` | §13 已全 ✅，属陈旧标注 |
| §3.2 P0 四个 `[ ]` | `MIGRATION_PLAN.md:172-179` | 与 §10 `P0 [x]` 冲突，stale |

---

## 建议优先级

1. ✅ **A3 (f1 Diff-stop)** — 已完成：热更终止不再存在的 zone/房间/角色，防止僵尸进程堆积。测试 `test/kantele/world/kickoff_test.exs` 14/0。
2. ✅ **B1 `suicide`** — 已完成（2026-11-09）：`suicide -f <密码>` 校验 `meta.password` 后链删角色 + rumor 广播（combat_exp>=1000）；15 秒 halt 倒计时为有意简化。
3. ✅ **C brothers 跨角色同步** — 已完成（2026-11-09）：断义 `brothers out <name>` 现同步对方持久化名单（`ExVenture.Characters.remove_brother/2`，离线亦可，对应 LPC `UPDATE_D->clear_user_data`）+ rumor 广播 + 同房间在场兄弟内存同步（房间 `brothers/break` 转发 `brothers/broken`）。`brothers_command_test.exs` + `brothers_event_test.exs` 9/0。
4. **B1 自包含 stub — 已全部真化（见上方 B1 收尾）** — `push`/`hand`/`secularize`/`remove`/`top2`/`topp`/`train`/`come`/`stay`/`stop`/`release`/`talk`/`ansuan`/`top`/`special`/`stab`/`touch`（含 `answer` 的 forge 议价分支）均已按 LPC 真实实现；**原「剩余 6 个」占位命令（`answer`/`pkd`/`to`/`vote`/`scheme`/`clone`）亦已于 2026-11-09 随 E1–E5 全部真化**，其依赖的后端子系统（PK 场、投票、ask/answer、行编辑器、计划执行器、生物克隆）均已落地。真正未建模的仅剩 B2 的 12 个 W3 命令。
5. **A1/A2/A4** — 大工程，需立项排期（T1 转换器投入最大）

> 按仓库约定：本清单仅记录与查阅，开工任意项前先更新"当前状态"，每批验收以 `MIX_ENV=test mix test --seed 731933/788424` 全绿为准。