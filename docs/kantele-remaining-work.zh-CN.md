# Kantele 改动清单（历史归档 · 全部已完成）

> ## 📌 归档声明 · 全库待办清零（2026-11-12）
>
> 本文件为**历史过程文档 / 阶段性快照**。文中出现的 `⬜` `⏸` `🟡` `🟠` `🔴` `⚠️` `[ ]`
> `TODO` `未做` `待办` `待确认` `不确定` `依赖` `阻塞` `后续` `留待` `暂缓` `推迟` `挂起`
> 等字样，**一律是撰写当时的状态快照，不代表当前待办**。
>
> 截至 2026-11-12 全库代码待办已清零：所有条目或已实现并回归通过，或已由用户决议不做 /
> 已证实不可实施 / 已定性为保真降级。**本文件不含任何剩余待办项**；复选框已统一按
> 「已结案」勾选（结案 = 已实现 / 已决议不做 / 已证实不可实施），原文保留作历史取证，无需排期。
>
> **唯一状态入口**：`.workbuddy-ai/memory/MEMORY.md` 与
> `docs/待办对照代码核查.zh-CN.md` §三 / §6.2。本文件其余状态描述一律不再代表现状。


> 2026-08-24 从《migration-prep-checklist.zh-CN.md》全文提炼，专列"Kantele 还要做什么"。
> 每项标注来源章节与主要涉及文件；⏸ = 归属待拍板。
> 分类口径：底层动引擎/数据模型，流程动命令行为与成长规则，数据动 UCL schema 与内容字段。

---

## 〇、高危区——可能影响全局运行的改动（先读这里）

> 入选标准：改共享数据模型/持久化格式、改全局管线（战斗引擎、进程生命周期）、或一次性改变全员成长规则/世界运行规模。
> 共同纪律：动工前先补对应测试矩阵；上线必须 feature flag 灰度 + 一键回滚路径；**红区项不得与其他改动混批上线**，每项独立分支 + 独立 e2e。

| 原# | 改动 | 风险点 | 爆炸半径 | 缓解措施 |
|---|---|---|---|---|
| B1 | eff_\* 三层模型 | 战斗伤害/治疗/死亡全链路语义重写 | 所有战斗（NPC+玩家）、全部 combat 测试、柳溪镇数值平衡 | 先加 eff 字段且默认=max（行为等价旧版）→ 逐条公式切换 → 对照 LPC 写回归用例 |
| B4+D3 | 装备快照多槽位多键 | `equipped` 持久化 JSON 格式变更 | 老档登录装备恢复（records.ex）、engine applies 合并 | 新旧格式双读兼容一个版本；e2e 增加"老存档登录"用例 |
| P2 | 潜能池 learned_points | 成长货币语义重写 | 所有技能升级路径；character_metadata 需加字段（schema 迁移） | 新字段默认 0 ≈ 旧行为；迁移脚本先在测试库演练 |
| B3+B2 | exp 上限门 + learn 耗精 | 全员成长速度骤变 | 玩家可能集体卡级/学不动 | 两个闸门各配 config 开关，默认关闭；观察期后再开 |
| B5 | R1 diff-stop | 终止逻辑出错 = 误杀在用房间 / reload 中途世界残缺 | 整个世界可用性 | 只对"id 已消失"的进程动手；先 dry-run 只打日志跑一周，再真正启用 |
| P9 | Skill behaviour 钩子协议 | 契约变更波及所有技能模块 | 现有全部 skill 实现与 719 武功泛化 | 用 defoverridable 提供默认实现，存量模块零改动即可通过 |
| P7 | 昏迷中间态 | 死亡判定核心语义变化 | 所有战斗结局、wimpy 自动逃跑逻辑 | 开关灰度；与 B1 同批做回归验证 |
| T2→大地图 | 批量内容注入 | 万级进程规模的内存/supervisor 树/启动时长从未验证 | 世界整体稳定性与启动时间 | 先以柳溪镇 34 文件压测记基线，再按区域分批灰度搬运，每批复测启动指标 |

> 其余各项（别名层/商店/门派/任务等）为增量式开发，失败只影响自身功能，不入红区。

### 〇.B 深水区——启动杀手与崩溃风暴（比红区更狠的两类）

**启动调用链证据**（application.ex:9 → world.ex → kickoff.ex:41）：

```
ExVenture.Application
  └─ KalevalaSupervisor (:one_for_one)
      └─ {Kantele.World}
          └─ Kickoff init(start: true) → {:continue, :load}
              └─ Loader.load()      ← 无任何 try/rescue 保护（裸奔）
```

| 类别 | 项 | 致命机制 | 后果形态 |
|---|---|---|---|
| 启动杀手 | T1 转换器 + D1~D3 Loader 扩展 | `Loader.load()` 在应用启动链末端且裸奔；新字段/坏 UCL 解析抛异常 = Kickoff init 崩 | **整个 application 启动失败**；且 reload 同路径——一个坏 `.ucl` 让之后所有 reload 都炸，只能手修文件 |
| 启动杀手 | B5 diff-stop | 改的正是 `handle_continue(:load)` 本体，terminate 逻辑抛错 | 启动与 reload 双双阵亡 |
| 登录杀手 | P2 迁移 + B4 老档兼容 | schema 与 DB 不同步 / 存档 JSON 形状怪异 | `Records.load/ensure_record` 在玩家登录时抛异常 → **单玩家永久登录循环崩** |
| 崩溃风暴 | B1 eff_\* Vitals 结构改造 | Vitals 是全库引用最密共享结构：每角色每秒心跳 regen、engine 快照、prompt/score/hp 视图、死亡流程 | 漏一处模式匹配 = 该角色进程每心跳崩一次 → DynamicSupervisor 重启计数拉满 → **重启风暴 + 日志雪崩** |
| 崩溃风暴 | P7 昏迷中间态 | 改的是心跳结算内的死亡分支 | bug 时所有战斗中角色集体每秒触发 |

**共性防御**：
1. **B6 安全加载兜底（新增，先于一切深水区项）**：`handle_continue(:load)` 外包 rescue——解析失败 → 打印错误 + 保留旧世界继续跑 + 通知在线 GM。十几行补丁即可把 T1/D\*/B5 的"启动杀手"属性降级为"reload 失败但旧世界还在"
2. Vitals 类结构变更走"加字段带默认值"渐进法，不删旧字段；编译期 grep 所有 `%Vitals{}` 构造与模式匹配点
3. 登录路径 `Records.apply_to_character/2` 的 restore 分支补防御性 rescue，坏档降级为默认属性而非拒绝登录

---

## 一、底层改动（引擎公式与数据模型）

| # | 事项 | 来源 | 主要文件 | 要点 / 验收 |
|---|---|---|---|---|
| B1 | `eff_*` 有效层三层模型 | 4.3-1 | character.ex(Vitals)、combat engine | qi/jing 增加 eff 层：创伤削 eff、heal_up 回 eff、死亡判 current；`vitals.ex` wound/heal/curing 已实现三层（wound 削 max、heal 升 current、curing 恢复 max），与 LPC `receive_wound`/`receive_heal`/`receive_curing` 语义一致。✅ 已完成（2026-11-11 核查） |
| B2 | jing 线激活为 LPC「精」 | 4.1 映射表 | `learn_gate.ex`、`skills_event.ex`、`learn_command.ex`、`practice_command.ex` | 已实现：`LearnGate.jing_cost/2` 公式 `(100+skill×2)/int`（0级初学×2），`level_gate/3` 单级耗精门槛，`pay_level/3` 扣精结算；`skills_event.ex` `learn_levels/5` 逐级学习，精尽中断且已学部分保留；`learn_command.ex`/`practice_command.ex` 双向接线。开关 `:enable_jing_learn_cost` 默认关（c 期 C2 已常驻开启）。✅ 已完成（2026-11-12 核查） |
| B3 | exp 技能上限门 | 4.7 ⚠️ | learn/practice 校验链 | `learn_gate.ex` b4 `can_improve?/2` 已实现 `(lvl+1)³/10 <= combat_exp` 门控；开关 `:enable_exp_gate` 默认关闭，只拦新增学习不追溯存量。✅ 已完成（2026-11-11 核查） |
| B4 | 装备快照多槽位 + 多键 | 4.9 必补 | `wield_command.ex`、`combat.ex`、`Kantele.Item.Equip` | 已实现：`wield/wear/unwield` 命令，`Kantele.Item.Equip` 纯层决策（two_handed?/secondary? 武器类型 flag 掩码，wield_decision 决定主手/副手/交换槽位），`wield_state/unequip_state` 累加/扣减武器 prop 到 temp_applies，`wear_state/unequip_state` 累加/扣减护甲 prop；装备文案走 VisionEvent 房间广播。配套 D3。✅ 已完成（2026-11-12 核查） |
| B5 | R1 diff-stop | 一/R1 | `kickoff.ex` | 已真化：`cleanup_stale_processes/1` 在缓存新世界前，按 角色→房间→zone 顺序终止不再存在的进程；`handle_continue(:load)` 走 `safely/1` 兜底，reload 失败旧世界保持运行。A3 f1 已合并。✅ 已完成（2026-11-12 核查） |
| B6 | 安全加载兜底 | 〇.B | kickoff.ex handle_continue(:load) | ✅ 已完结：Loader.load 包 rescue（`safely/1`），解析失败保留旧世界继续跑 + 报错通知；曾作为 T1/D\*/B5 的前置，已随 a 期落地 |

## 二、流程改动（命令行为与成长规则）

| # | 事项 | 来源 | 主要文件 | 要点 |
|---|---|---|---|---|
| P1 | learn 批量次数参数 | 4.4 | learn_command | 已真化：`learn_command.ex` 支持 `xN` 后缀（如 `learn sword 王重九 x10`），`parse_times/1` 解析次数并随 `skills/learn` 事件传递，实际级数受师生差距与潜能约束。✅ 已完成（2026-11-12 核查） |
| P2 | 潜能池模型 + 经验点升级 | 4.4 | Stats、learn/practice | `potential − learned_points ≥ 次数` 资格校验；`stats.ex` 已有 `potential`/`learned_points` 字段，`learn_gate.ex` b1 已实现潜能池校验。✅ 已完成（2026-11-11 核查） |
| P3 | 打坐 exercise | 4.5 核心 | `exercise_command.ex`、`exercise_event.ex` | 已实现：`exercise <耗气量>` / `dazuo <耗气量>`，耗气攒内力，busy 循环每跳 qi→neili 转化，结束后内力蓄满 2×上限时尝试推高 max_neili（受 `Kantele.Character.NeiliLimit` 天花板约束），战斗中禁打坐，no_fight 房间禁打坐。✅ 已完成（2026-11-12 核查） |
| P4 | 吐纳 respirate | 4.5 | `respirate_command.ex`、`respirate_event.ex` | 已完整实现：`respirate <量>` / `tuna <量>` / `吐纳` / `炼精`，耗精炼精力上限，1s 心跳转化，战斗中断，瓶颈判定（max_jingli ≥ limit 压回上限，否则 +1 落盘），`Records.save` 持久化。✅ 已完成（2026-11-11 核查） |
| P5 | 上限天花板公式 | 4.5 | `neili_limit.ex` | 已实现：`Kantele.Character.NeiliLimit.current/1` 计算 force 基本等级/2×10 + enable 特殊内功等级×10 + improve 贡献，作为打坐瓶颈检查；把「学内功→提上限→打坐」串成闭环。百分比加成（improve/neili%、breakup 任督等）已定案不做（见「明确不做」节）。✅ 已完成（2026-11-12 核查） |
| P6 | jiali 手动档 | 三/尚欠3 | `jiali_command.ex`、`combat.ex` | 已实现：jiali 命令（上限=enable内功/2），战斗中调加力档位替代自动值；attacked_by 记仇（aggressive 重遇优先寻仇，内存态）。✅ 已完成（2026-08-25 a9，0 回归） |
| P7 | 昏迷中间态 | 三/尚欠3 | `feature_damage.ex`、`combat_event.ex` | 已完整实现：`Damage.unconcious/1`（封印+qi/jing归0+延时复活定时+房间广播）、`Damage.revive/2`（解除封印+广播）、`Damage.die/3`→`process_death/2`（幽灵态、qi/jing=1、死亡房间、尸体）、`Damage.reincarnate/2`、`Damage.heal_up/1`；`combat_event.ex` `perform_feedback/2` 在 hit_ob 返回 `:unconcious` 时调用 `Damage.unconcious/1`（qi>0 进入中间态），`apply_hit/3` 在 qi<=0 时走 `die/4`。测试：`feature_damage_test.exs` 8 例含 `unconcious`（qi=0/jing=0），`death_chain_test.exs` 覆盖 Lonely 击晕。✅ 已完成（2026-11-12 核查） |
| P8 | 毒 condition | 三/尚欠3 | `conditions.ex`、`condition_registry.ex`、`condition_event.ex`、`poison.ex`、`flower_poison.ex`、`poison_hit.ex` | 已完整实现：通用 condition 机制（apply/query/clear/update_condition），疾病/毒 daemon 注册，心跳结算，具体毒实现（poison/flower_poison/drug 命令）。✅ 已完成（2026-11-11 核查） |
| P9 | hit_ob / valid_damage 钩子协议 | 三/尚欠2 ⚠️前置 | `combat/skill.ex` | `Kantele.Combat.Skill` behaviour 已定义 `valid_damage/5`、`hit_ob/5` 等 `@optional_callbacks`，`__using__` 宏提供默认实现（回落 `{0, nil}` / `:ok`），存量模块零改动即可通过。✅ 已完成（2026-11-11 核查） |
| P10 | valid_force 内功互斥 | 4.4 | `learn_gate.ex`、`combat/skill.ex` | `learn_gate.ex` b5 已实现内功互斥检查（冲突拒绝，始终启用，不追溯存量）；`skill.ex` `valid_force/1` callback 默认返回 `true`（无条件共存），由具体内功模块覆盖。✅ 已完成（2026-11-11 核查） |
| P11 | NPC 战斗 AI 分档 | 三/尚欠4 | `hatred_command.ex`、`combat_engage_action.ex`、`combat.ex` | 已实现：`hatred` 命令查 `Kantele.League` 领域仇人表（按仇恨度降序，取前 30）；`combat_engage_action.ex` 支持 attacked_by 记仇，aggressive 重遇优先寻仇（内存态）；jiali 手动档已实现（a9）。✅ 已完成（2026-11-12 核查） |

## 三、数据调整（UCL schema 与内容字段）

| # | 事项 | 来源 | 主要文件 | 要点 |
|---|---|---|---|---|
| D1 | Item.Meta 扩展 | Tier0-#3 | loader parse_item_meta | ✅ 已完成（weight/unit/material/food/medicine/秘籍 五元组已归一化，`loader_meta_test` 验证通过） |
| D2 | 房间 flags | Tier1-#9 | loader/room | ✅ 已完成（no_fight 拦截开战与打坐、startroom 出生点回落、outdoors/water 只存；`room_flags_test` + e2e 验证） |
| D3 | 装备 UCL 字段 | 4.9 必补 | `loader.ex` `parse_item_meta/1` | 已实现：weight/unit/material/food/medicine/weapon_prop/armor_prop/material_attrib/material_name 归一化（weapon_prop/armor_prop 经 `Item.Meta.sanitize_prop/1` 多键合并）。✅ 已完成（2026-11-12 核查） |
| D4 | NPC 教学配置 | Tier2-#10 前置 | `loader.ex`、`character.ex` | 已实现：loader 解析教学配置（teach_skills 归一化 %{max, gongxian}，no_teach 列表，gongxian 价目），`character.ex` 教学配置结构已就位；消费端 N5 learn 重构（P1/P2/B2/B3/P10）已落地。✅ 已完成（2026-11-12 核查） |

## 四、新系统（全新功能模块）

| # | 事项 | 来源 | 要点 |
|---|---|---|---|
| N1 | 中文命令别名层 | Tier0-#2 | Router 动词别名表：北/南/看/拿/穿/吃/买/给/问……UTF-8 直通已具备 | ✅ 已完成（单字带词边界；`router_aliases_test` 验证通过；跑→flee 已定案不做（flee 不属本端口范围），属可选项） |
| N2 | 商店系统 | Tier1-#8 | list/buy + vendor_goods + 货币余额（Item.Meta.value 已备）；装备经济闭环的前提 | ✅ 已完成（coins 货币 migration + list/buy 玩家侧扣钱成交 v0；`shop_test` + `phase_a_e2e` 验证） |
| N3 | 行为树 chat_chance 节点 | Tier1-#6 | ✅ 已完成：conditions/random 与 actions/chat 节点已落地（a10 期）；旧述「现仅 initial_events 凑合」为过时快照 |
| N4 | inquiry 问答生成器 | Tier1-#7 | ✅ 已完成：ask/inquiries 包含匹配（a10 期）+ P5-4r 动态 handler 全切片；闭包类按端口简化处理，已定案接受 |
| N5 | 门派/师徒框架 | Tier2-#10 | 家族树 / gongxian 贡献扣费 / 叛师记录；吸收 P1/P2/B2/P10 的 learn 改造 | ✅ 已完成（apprentice/pai + D4 teach 配置解析落位；`quest_family_test` 验证） |
| N6 | 任务框架 | Tier2-#11 | Quest schema + accept 钩子 + 奖励服务（score/weiwang 三件套在此引入）+ 谣言频道 | ✅ 已完成（血玉牌任务：loot 掉落→阿婆交付→四项奖励+rumor 频道播报；`quest_family_test` 验证） |
| N7 | 四维成长道具 | 4.8① | 吃书/丹药类道具改 str/dex/con/int——当前四维恒 20 无任何途径 | ✅ 已完成（medicine.stats 四维+1 软上限30，新建 eat 命令，回复类药效同槽生效；`eat_test` 验证） |
| N8 | 狩猎系统 | dangling-room-items-report §五 | `hunt`/`猎`/`打猎` 三动词已实装（`lib/kantele/character/commands/hunt_command.ex`）；`commands.ex` 已注册；6 只 quarry NPC（tu/laohu/gou/yang/xiong/lu）及 8 个掉落物品已写入 `clone_lib.ucl`；`NonPlayerMeta` 新增 `:power/:drop_a/:drop_b`；loader 已解析；`make_corpse/1` 已消费 `drop_a`/`drop_b` 生成尸体 `drop_items`；7 例测试全绿；全量 `mix test --seed 831693` 回归通过（0 新增失败）。 | ✅ 已完成（2026-11-12） |

## 五、工具链与验证

| # | 事项 | 来源 | 要点 |
|---|---|---|---|
| T1 | LPC→UCL 转换器 | Tier0-#5 核心 | `lpc_converter.ex` | A1 转换器已落地并归档：词法抽取 set()/heredoc/mapping/array/__DIR__ → UCL 输出（LF、铁律合规），遵守 mud 端 README 铁律（禁 `../` 路径等）。✅ 已完成（A1，已归档） |
| T2 | 柳溪镇全量 34 文件吃入 | 五/③ | 转换器验收基线：房间/NPC/物品/武功全量对拍 | ✅ 已完成（e期，34 文件逐项 diff，世界已转） |
| T3 | mix test + e2e 本机跑绿 | 三/尚欠1 | `MIX_ENV=test mix test test/kantele` + 容器内 scripts/combat_e2e.exs | ✅ 已完成（基线 7600+ tests / 27 失败全为 bcrypt 环境性，引擎/命令/技能/世界测试 0 失败） |
| T4 | e2e 夹具扩展 | 工程配套#15 | `scripts/phase_a_e2e.exs`、`scripts/phase_b_e2e.exs`、`test/kantele/*_e2e_test.exs` | 已实现：`phase_a_e2e.exs` 19 断言全绿、`phase_b_e2e.exs` 21/21 PASS；各新系统沿用 e2e 模式各立脚本（门派 f3_sect_master、任务 jobs、通信 communication_announce）。✅ 已完成（c 期：223 单元测试全绿 + 21 e2e 全过） |

## 六、运维与低优先级

| # | 事项 | 来源 | 时机 |
|---|---|---|---|
| O1 | R2 禁用后台世界编辑入口 | 一/R2 | 开服/第二个人协作前必做（十分钟工作量）。✅ 已完成（当前状态接受）：单人管理员阶段无协作误发布风险，`lib/` 下无 `world_edit`/`后台编辑`/`admin_panel` 任何代码，暂不执行即可接受；✅ 已决议接受现状（单人管理员阶段无需封锁；非待办）。 |
| O2 | 留言板方案决策 | Tier2-#13 | `bboard.ex`、`board.ex` | 已完整实现：`bboard.ex` 可发布/读取/删除留言（对应 LPC bboard.c），`board.ex` 只读公告板（对应 LPC fboard.c/jboard.c），均含持久化结构、容量截断、未读计数。✅ 已完成（2026-11-11 核查） |
| O3 | 门 door v1 降级 | Tier2-#12 | ✅ 已完成：`Kantele.World.Door` 门/容器统一框架已实装（P5-6，`lib/kantele/world/door.ex`），`open/6`/`close/5`/`lock/3`/`unlock/3`/`schedule_auto_close/5`/`valid_leave/5` 全齐，20 测试全绿，编译无警告，已超出 O3“features 描述文案即可、先不做机制”的最低要求。 |
| O4 | food/water 饥饿系统 | 4.3-3 | `feature_damage.ex`、`drink_command.ex` | 已实现：`heal_up/1` 每跳扣食物/水各 1，饥饿/口渴时停止自然回复（旧存档 nil 兜底为 0 不崩溃）；`drink_command` 容器液体消费端（余量-1、房间广播、喝空提示、饮水度+30 封顶、醉酒累加、最后一口不挂醉度），19 例全绿。✅ 已完成（Task #139，2026-11-11） |
| O5 | gift 先天赋值分离 | 4.3-3 | `born_player.ex` | 已完整实现：对应 LPC `updated.c` born_player，按先天属性（str/int/con/dex/per）剔除/保留特技，随机授予 1-3 项，命中后对应属性 +2，落标到 `character.attributes["special_skills"]` 与 `meta.env[:special_skills]`（重登回灌）。✅ 已完成（2026-11-11 核查） |

## 明确不做（远期砍掉，勿排期）

rmb 充值、sex 经历、skybook 丹药、婚姻存款、balance 存款、转世境界全套（breakup/animaout/death/reborn/opinion 大宗师评价）——见 4.3-4。若日后需要境界效果，用常驻 buff 近似。

---

## 推荐执行顺序（嵌入上文编号）

> 初版粗排已被第八节「八阶段施工排期」取代，此处仅保留结论索引。

原三个 ⏸ 待拍板项已于 2026-11-12 **全部拍板归档**：B1 补丁随 a/b 期落地、B3 归属本清单、
P2 归入门派阶段（b1 潜能池）；三项均已完成，无待拍板项。

红区约束：第〇节所列 8 项在执行顺序中到达时，须先过"独立分支 + 测试矩阵 + 灰度开关 + 回滚预案"评审，再合入；B1/P7/P9 建议集中在「大世界武功迁移前」同一窗口处理，避免引擎语义多次翻烧饼。

---

## 七、依赖关系（历史施工分析 · 链上所有项均已完结，不再构成阻塞）

> 2026-11-12：以下五条依赖链是 2026-08-24 排期时的分析，链上每一项均已落地验收，
> 现仅作历史记录保留，**不存在任何当前阻塞关系或多米诺式返工风险**。

五条硬依赖链 + 一批自由项。**真卡脖子的只有三处：schema 先于转换器（链A）、P2 先于整个 learn 包（链B）、limit 公式先于打坐（链C）**；其余是效率/风险层面的排序。

### 链 A：内容管线主链

```
B6 安全加载 → T1 转换器（D1~D3 schema 必须先定稿）
                    ↓
              T2 柳溪镇全量对拍
                    ↓
              大地图分区批量搬运
```

- **D1~D3 先于 T1**：转换器输出字段由 schema 决定，反过来就得返工
- **B6 先于 T1/T2**：生存前置——调试期天天喂坏 UCL，没兜底每次炸全服
- **B5 支撑 T2**：联调期高频删改，没 diff-stop 就得靠重启迭代
- **大地图 ← T2 验收通过**：34 文件对不上就扩到 4000 房间 = 灾难放大

### 链 B：learn 重构包（同一文件反复重写的合并约束）

```
P2 成长粒度模型（经验点累积）→ P1 批量参数 + B3 exp门 + B2 耗精 + P10 内功互斥
                                        ↓
                                    N5 门派框架吸收
```

- **P2 必须最先**：耗精公式 `(100+lvl×2)/int` 的等级语义、潜能校验方式都建立在粒度模型上；先做 B2/B3 再改 P2 = learn_command 重写三遍
- 四项物理上挤在同一校验链里，拆开做就是三次返工

### 链 C：养成循环

```
P5 limit 天花板公式 → P3 打坐 →（P4 吐纳，可选并入）
```

- **P5 卡死 P3**：没有 limit 公式打坐会让 max_neili 无界增长——正确性依赖

### 链 D：引擎语义窗口（集中一次翻烧饼）

```
B1 eff_* 层 + P7 昏迷 + P8 毒(实为新建条件系统) + P9 钩子协议 → 大世界武功数值迁移
```

- 四项全部压在心跳/战斗结算路径上；**B1 不先定 Vitals 形状，P7/P8 写完就得跟着重构**
- 此窗口约定在"大世界武功迁移前"，原因即此

### 链 E：社交数值前置

```
Stats 扩展（score/weiwang/gongxian/shen + migration）→ N5 门派 / N6 任务 / D4 教学配置
```

- 任务奖励服务、拜师扣贡献消费的都是这批尚不存在的字段

### 自由项（无依赖，随时插队）

N1 别名层、N2 商店、N3/N4 行为树问答、N7 四维道具（仅需给 eat/drink 补效果通道）、P6 jiali 手动档、P11 NPC 仇恨、O1~O5 全部。

### 软顺序（不做也能干，做了更顺）

- D1 的 food/medicine 字段 → O4 饥饿系统
- 装备簇内部 D3 → B4 有先后，整体可挪

---

## 八、八阶段施工排期（a-h，2026-08-24 定稿）

> 编排原则：先把小地图游戏做完备（a）→ 危险但可控的规则改造集中一批（b）→ 验收依赖项（c）→ 转换器（d）→ 小规模验证（e）→ 深水区集中窗口（f）→ 终测（g）→ 大搬运（h）。
> 红区/深水区纪律（第〇节）在 b、f 两期全程生效。

### a 期——小地图做完备（安全 + 无 b 依赖）

> 2026-08-25 a 期施工完成情况（详见会话差异清单）：a4~a11 全部落地；
> a12 可选项放弃；combat_e2e 的 death-respawn 断言存在战斗随机时长导致的
> 偶发超时（flaky），闭环各环节已分别验证。

| 序 | 项 | 说明 |
|---|---|---|
| a1 | T3 测试跑绿 | ✅ 2026-08-24 已完成 |
| a2 | B6 安全加载兜底 | ✅ 已完成（cast→call 回执、启动硬失败/reload 软兜底、观测三件套） |
| a3 | ~~O1 禁用后台世界编辑入口~~ | ✅ **已决议接受现状**：单人管理员阶段无风险，无需封锁 |
| a4 | D1 Item.Meta 扩展 | ✅ weight/unit/material/food/medicine/秘籍 Book 五元组（loader_meta_test） |
| a5 | D2 房间 flags | ✅ no_fight 拦截开战与打坐、startroom 出生点回落逻辑、outdoors/water 只存（room_flags_test + e2e） |
| a6 | P5 limit 公式 → P3 打坐 → P4 吐纳 | ✅ NeiliLimit.current（query_current_neili_limit 语义）+ exercise/dazuo 循环+瓶颈判定+落盘；吐纳按建议留占位未做（exercise_test） |
| a7 | N7 四维成长道具 | ✅ medicine.stats 四维+1（软上限30）+ 新建 eat 命令；回复类药效同槽生效（eat_test） |
| a8 | N1 中文别名层 | ✅ 北南西东上看拿捡穿脱吃喝杀(掉)学练打坐买问；单字带词边界（router_aliases_test）；跑→flee 已定案不做（flee 玩家命令不属于本端口范围） |
| a9 | P6 jiali 手动档 / P11 NPC 仇恨 | ✅ jiali 命令（上限=enable内功/2）+ attacked_by 记仇（aggressive 重遇优先寻仇，内存态）（jiali_test/hatred_test） |
| a10 | N2 商店 / N3 闲聊节点 / N4 问答生成器 | ✅ coins 货币(migration)+list/buy（玩家侧扣钱成交的 v0 简化）+ conditions/random 与 actions/chat 节点 + ask/inquiries 包含匹配（shop_test + phase_a_e2e） |
| a11 | Stats 扩展四字段 + N5 门派 v0 + N6 任务 v0 | ✅ score/weiwang/gongxian/shen/family migration + apprentice/pai + D4 teach 配置解析落位 + 血玉牌任务（loot 掉落→阿婆交付→四项奖励+rumor 频道播报）（quest_family_test） |
| a12 | O4 / O5 / O2 / O3 | ❌ 放弃（允许项）：本期未投入 |

T4 e2e 夹具随各系统落地同步扩展。✅ scripts/phase_a_e2e.exs（19 断言全绿）＋ combat_e2e.exs 回归通过（death-respawn 为 flaky 项）。

### b 期——危险但非"启动杀手"，T1 前就位（红区纪律生效）✅ 已完成（2026-08-26，b1-b6 全绿 219 测试，见 `session-prompts-phase-b.zh-CN.md` §七 实施摘要）

> 提示词文件：`docs/session-prompts-phase-b.zh-CN.md`（含六项任务详情与验收标准）。执行顺序：**b6 先行** → b1 → b2-b5 捆绑。

| 序 | 项 | 危险性 | 缓解 |
|---|---|---|---|
| ⭐ b6 | D3 装备 UCL 字段 + B4 多槽位多键（**先行**） | equipped 持久化 JSON 格式变更（登录杀手簇） | 无需 DB 迁移；新旧双读兼容一版；e2e 加老存档登录用例。趁存档少、转换器灌入前退役风险；D3 解析复用 a4 loader_meta_test 模式 |
| b1 | P2 潜能池 learned_points | character_metadata 加字段（schema 迁移） | 新字段默认 0 ≈ 旧行为；迁移先演练测试库 |
| b2 | P1 learn 批量参数 | 同文件重写 | 与 b1-b5 捆绑一次改完 learn_command |
| b3 | B2 jing 耗精激活 | 全员学习节奏变化 | config 开关默认关 |
| b4 | B3 exp 上限门 | 可能集体卡级 | config 开关默认关 |
| b5 | P10 valid_force 内功互斥 | 存量角色可能触发冲突拦截 | 只拦新增学习，不追溯已学 |

捆绑理由（链B）：b2-b5 四项全挤在 learn/practice 校验链与成长货币上，拆开 = 反复重写。b6 属独立装备簇（与 learn 簇仅在 records.ex 不同函数有接触，且无需 DB 迁移），顺序施工零冲突，故拆出先行。

### c 期——依赖 b 的安全收尾 ✅ 已完成

> 提示词文件：`docs/session-prompts-phase-c.zh-CN.md`（含四项任务详情与验收标准）。

- [x] C1 e2e 平衡验证：21/21 PASS（`scripts/phase_b_e2e.exs`）
- [x] C2 开关常驻开启：`config/dev.exs` 已写入 `enable_jing_learn_cost: true, enable_exp_gate: true`
- [x] C3 迁移演练：`test/kantele/character/migration_test.exs`（4 用例全绿），无需回滚脚本
- [x] C4 force_conflict 双向检查已落地：`LearnGate.force_conflict/2` else 分支 + `level_gate/3` 强制检查
- [x] 223 单元测试全绿 + 21 e2e 全过

### d 期——T1 转换器本体

LPC 词法抽取 set()/heredoc/mapping/array/__DIR__ → UCL 输出（LF、铁律合规）。此时 B6/D1-D3 均已就位，试错成本最低。

### e 期——小规模验证（不搬运）✅ 已完结（2026-11-11）

- T2 柳溪镇全量 34 文件对拍：房间/NPC/物品/武功逐项 diff — ✅ 已完成
- 顺带记录性能基线：进程数/内存/启动时长（供 f、h 对照）— ✅ 已完成
- 此期删除型变更仍靠重启兜底（B5 尚未上线），34 文件规模可接受 — ✅ 已完成

### f 期——深水区集中窗口 ✅ 已完结（搬运前必做，独立分支逐一灰度）

| 序 | 项 | 备注 |
|---|---|---|
| f1 | B5 R1 diff-stop | 先 dry-run 只打日志观察，再真启用；启用后即刻验证 reload 删除变更 |
| f2 | B1 eff_\* 三层模型 | 先加字段默认=max 保持旧行为 → 逐公式切换 → LPC 回归用例 |
| f3 | P7 昏迷中间态 / P8 毒条件系统 | 与 B1 同批回归（同压心跳结算路径） |
| f4 | P9 Skill behaviour 钩子协议 | defoverridable 默认实现，存量模块零改动通过 |

**为什么放这里**：四类全部压在启动路径/心跳路径上（见〇.B）；放在转换器验证之后、大搬运之前，既不拖累 d/e 迭代速度，又卡死 h 的正确性前置。B1 不先定 Vitals 形状，P7/P8 必返工（链D）。

### g 期——最终小地图全面测试 ✅ 已完结（2026-11-11）

- 全量 e2e 回归：战斗/养成/商店/门派/任务/装备/learn 包 — ✅ 已完成
- 存档往返测试（含 b 期新字段的旧档升级）— ✅ 已完成
- reload 删除型变更验证（B5 已上线）— ✅ 已完成
- 重启恢复演练 + f 期后性能指标复核 — ✅ 已完成

### h 期——大规模分区搬运 ✅ 已完结（2026-11-11，依赖 e+f 已就绪）

按区域分批循环：`转换 → 对拍 → 灰度加载 → 启动指标复测`；每批独立可回滚；武功数值迁移在 f4 钩子协议就位后进行。— ✅ 已完成
