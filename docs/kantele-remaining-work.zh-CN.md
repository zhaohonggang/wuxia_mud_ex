# Kantele 待办清单（按改动类型分类）

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
| B1 | `eff_*` 有效层三层模型 | 4.3-1 | character.ex(Vitals)、combat engine | qi/jing 增加 eff 层：创伤削 eff、heal_up 回 eff、死亡判 current；现 wound 直接削 max+base 的近似要替换。⏸补丁时机（现在 vs 大世界武功迁移前） |
| B2 | jing 线激活为 LPC「精」 | 4.1 映射表 | learn/study 命令、regen | 现 `jing` 零消耗纯展示；接上 learn 耗精公式后自然激活，**无需新增字段**。依赖 P1-P2 |
| B3 | exp 技能上限门 | 4.7 ⚠️ | learn/practice 校验链 | 武功类技能 `等级³/10 ≤ combat_exp` 才许升级——养成闭环关键一环。⏸是否并入战斗 session 补丁 |
| B4 | 装备快照多槽位 + 多键 | 4.9 必补 | wield_command、Combat.equip、effective_applies | armor 多部位并行穿戴；weapon_prop/armor_prop 多键（dodge 等）合并进 applies；配套 D3 |
| B5 | R1 diff-stop | 一/R1 | kickoff.ex | reload 时对比新旧 id 集合，terminate 被删的 zone/room/NPC；否则删除型变更靠重启生效 |
| B6 | 安全加载兜底 | 〇.B | kickoff.ex handle_continue(:load) | Loader.load 包 rescue：解析失败保留旧世界继续跑 + 报错通知；**先于 T1/D\*/B5 动工**，拆掉启动杀手引信 |

## 二、流程改动（命令行为与成长规则）

| # | 事项 | 来源 | 主要文件 | 要点 |
|---|---|---|---|---|
| P1 | learn 批量次数参数 | 4.4 | learn_command | `learn <师父> <技能> <次数>` 一条命令连学 |
| P2 | 潜能池模型 + 经验点升级 | 4.4 | Stats、learn/practice | `potential − learned_points ≥ 次数` 资格校验；improve_skill 改经验点累积而非固定 +1 级。⏸归属（建议门派框架阶段） |
| P3 | 打坐 exercise | 4.5 核心 | 新命令 | 耗 qi 攒 neili；`neili ≥ 2×max_neili` 触发上限+1，卡 limit 瓶颈——主养成循环 |
| P4 | 吐纳 respirate | 4.5 | 新命令 | 同款循环涨精力上限；若暂缓独立 jingli 线，可先并入打坐 |
| P5 | 上限天花板公式 | 4.5 | limit 计算模块 | `query_neili_limit` 吃 force 等级（基本/2＋特殊内功）；把「学内功→提上限→打坐」串成闭环 |
| P6 | jiali 手动档 | 三/尚欠3 | 新命令 + engine | 战斗中调加力档位，替代现自动值 |
| P7 | 昏迷中间态 | 三/尚欠3 | combat_event 死亡流程 | 0 < qi 时的 unconscious 阶段 |
| P8 | 毒 condition | 三/尚欠3 | 条件系统 | 中毒持续扣减，随 heartbeat 结算 |
| P9 | hit_ob / valid_damage 钩子协议 | 三/尚欠2 ⚠️前置 | Skill behaviour 扩展 | 大世界 719 武功泛化的硬前置 |
| P10 | valid_force 内功互斥 | 4.4 | learn 校验环节 | 已学 A 内功再学 B 冲突拦截；no_teach 表；叛师 cap 惩罚 |
| P11 | NPC 战斗 AI 分档 | 三/尚欠4 | brains / combat_engage | 现 仅 aggressive 一档；补 hatred/vendetta 仇恨记仇 |

## 三、数据调整（UCL schema 与内容字段）

| # | 事项 | 来源 | 主要文件 | 要点 |
|---|---|---|---|---|
| D1 | Item.Meta 扩展 | Tier0-#3 | loader parse_item_meta | 补 weight/unit/material/food/medicine/秘籍五元组（damage/armor/value 已备） |
| D2 | 房间 flags | Tier1-#9 | loader/room | no_fight / outdoors / water / startroom 多区域支持 |
| D3 | 装备 UCL 字段 | 4.9 必补 | loader 物品解析 | weapon_prop/armor_prop 多键、need 属性需求、双手/副手 flag（消费端=B4） |
| D4 | NPC 教学配置 | Tier2-#10 前置 | NPC ucl 块 | teach_skills 清单 / no_teach 表 / gongxian 价目（消费端=N5） |

## 四、新系统（全新功能模块）

| # | 事项 | 来源 | 要点 |
|---|---|---|---|
| N1 | 中文命令别名层 | Tier0-#2 | Router 动词别名表：北/南/看/拿/穿/吃/买/给/问……UTF-8 直通已具备，缺表 |
| N2 | 商店系统 | Tier1-#8 | list/buy + vendor_goods + 货币余额（Item.Meta.value 已备）；装备经济闭环的前提 |
| N3 | 行为树 chat_chance 节点 | Tier1-#6 | 独立随机闲聊节点（现仅 initial_events 凑合） |
| N4 | inquiry 问答生成器 | Tier1-#7 | 字符串表→tell-match 分支可自动生成；闭包类需新 Action 协议 |
| N5 | 门派/师徒框架 | Tier2-#10 | 家族树 / gongxian 贡献扣费 / 叛师记录；吸收 P1/P2/B2/P10 的 learn 改造 |
| N6 | 任务框架 | Tier2-#11 | Quest schema + accept 钩子 + 奖励服务（score/weiwang 三件套在此引入）+ 谣言频道 |
| N7 | 四维成长道具 | 4.8① | 吃书/丹药类道具改 str/dex/con/int——当前四维恒 20 无任何途径 |

## 五、工具链与验证

| # | 事项 | 来源 | 要点 |
|---|---|---|---|
| T1 | LPC→UCL 转换器 | Tier0-#5 核心 | 词法抽取 set()/heredoc/mapping/array/__DIR__；输出 LF；遵守 mud 端 README 铁律（禁 `../` 路径等） |
| T2 | 柳溪镇全量 34 文件吃入 | 五/③ | 转换器验收基线：房间/NPC/物品/武功全量对拍 |
| T3 | mix test + e2e 本机跑绿 | 三/尚欠1 | `MIX_ENV=test mix test test/kantele` + 容器内 scripts/combat_e2e.exs |
| T4 | e2e 夹具扩展 | 工程配套#15 | 商店/门派等新系统沿用 combat_e2e.exs 模式各立脚本 |

## 六、运维与低优先级

| # | 事项 | 来源 | 时机 |
|---|---|---|---|
| O1 | R2 禁用后台世界编辑入口 | 一/R2 | 开服/第二个人协作前必做（十分钟工作量）。⏸已挂起：单人管理员阶段暂不执行，已从 a 期移出 |
| O2 | 留言板方案决策 | Tier2-#13 | 暂缓 / Web 化 / 最简 schema 三选一 |
| O3 | 门 door v1 降级 | Tier2-#12 | features 描述文案即可，先不做机制 |
| O4 | food/water 饥饿系统 | 4.3-3 | 中优先级，影响沉浸感不阻塞搬运 |
| O5 | gift 先天赋值分离 | 4.3-3 | 中优先级，score/hp 显示对比用 |

## 明确不做（远期砍掉，勿排期）

rmb 充值、sex 经历、skybook 丹药、婚姻存款、balance 存款、转世境界全套（breakup/animaout/death/reborn/opinion 大宗师评价）——见 4.3-4。若日后需要境界效果，用常驻 buff 近似。

---

## 推荐执行顺序（嵌入上文编号）

> 初版粗排已被第八节「八阶段施工排期」取代，此处仅保留结论索引。

三个 ⏸ 待拍板项汇总：B1 补丁时机、B3 归属（战斗 session or 此清单）、P2 归属（建议门派阶段）。

红区约束：第〇节所列 8 项在执行顺序中到达时，须先过"独立分支 + 测试矩阵 + 灰度开关 + 回滚预案"评审，再合入；B1/P7/P9 建议集中在「大世界武功迁移前」同一窗口处理，避免引擎语义多次翻烧饼。

---

## 七、依赖关系（谁卡谁）

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
| a3 | ~~O1 禁用后台世界编辑入口~~ | ⏸ **已挂起另行安排**：当前单人管理员，无协作误发布风险 |
| a4 | D1 Item.Meta 扩展 | ✅ weight/unit/material/food/medicine/秘籍 Book 五元组（loader_meta_test） |
| a5 | D2 房间 flags | ✅ no_fight 拦截开战与打坐、startroom 出生点回落逻辑、outdoors/water 只存（room_flags_test + e2e） |
| a6 | P5 limit 公式 → P3 打坐 → P4 吐纳 | ✅ NeiliLimit.current（query_current_neili_limit 语义）+ exercise/dazuo 循环+瓶颈判定+落盘；吐纳按建议留占位未做（exercise_test） |
| a7 | N7 四维成长道具 | ✅ medicine.stats 四维+1（软上限30）+ 新建 eat 命令；回复类药效同槽生效（eat_test） |
| a8 | N1 中文别名层 | ✅ 北南西东上看拿捡穿脱吃喝杀(掉)学练打坐买问；单字带词边界（router_aliases_test）；跑→flee 因 flee 玩家命令不存在未做 |
| a9 | P6 jiali 手动档 / P11 NPC 仇恨 | ✅ jiali 命令（上限=enable内功/2）+ attacked_by 记仇（aggressive 重遇优先寻仇，内存态）（jiali_test/hatred_test） |
| a10 | N2 商店 / N3 闲聊节点 / N4 问答生成器 | ✅ coins 货币(migration)+list/buy（玩家侧扣钱成交的 v0 简化）+ conditions/random 与 actions/chat 节点 + ask/inquiries 包含匹配（shop_test + phase_a_e2e） |
| a11 | Stats 扩展四字段 + N5 门派 v0 + N6 任务 v0 | ✅ score/weiwang/gongxian/shen/family migration + apprentice/pai + D4 teach 配置解析落位 + 血玉牌任务（loot 掉落→阿婆交付→四项奖励+rumor 频道播报）（quest_family_test） |
| a12 | O4 / O5 / O2 / O3 | ❌ 放弃（允许项）：本期未投入 |

T4 e2e 夹具随各系统落地同步扩展。✅ scripts/phase_a_e2e.exs（19 断言全绿）＋ combat_e2e.exs 回归通过（death-respawn 为 flaky 项）。

### b 期——危险但非"启动杀手"，T1 前就位（红区纪律生效）

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

### e 期——小规模验证（不搬运）

- T2 柳溪镇全量 34 文件对拍：房间/NPC/物品/武功逐项 diff
- 顺带记录性能基线：进程数/内存/启动时长（供 f、h 对照）
- 此期删除型变更仍靠重启兜底（B5 尚未上线），34 文件规模可接受

### f 期——深水区集中窗口（搬运前必做，独立分支逐一灰度）

| 序 | 项 | 备注 |
|---|---|---|
| f1 | B5 R1 diff-stop | 先 dry-run 只打日志观察，再真启用；启用后即刻验证 reload 删除变更 |
| f2 | B1 eff_\* 三层模型 | 先加字段默认=max 保持旧行为 → 逐公式切换 → LPC 回归用例 |
| f3 | P7 昏迷中间态 / P8 毒条件系统 | 与 B1 同批回归（同压心跳结算路径） |
| f4 | P9 Skill behaviour 钩子协议 | defoverridable 默认实现，存量模块零改动通过 |

**为什么放这里**：四类全部压在启动路径/心跳路径上（见〇.B）；放在转换器验证之后、大搬运之前，既不拖累 d/e 迭代速度，又卡死 h 的正确性前置。B1 不先定 Vitals 形状，P7/P8 必返工（链D）。

### g 期——最终小地图全面测试

- 全量 e2e 回归：战斗/养成/商店/门派/任务/装备/learn 包
- 存档往返测试（含 b 期新字段的旧档升级）
- reload 删除型变更验证（B5 已上线）
- 重启恢复演练 + f 期后性能指标复核

### h 期——大规模分区搬运

按区域分批循环：`转换 → 对拍 → 灰度加载 → 启动指标复测`；每批独立可回滚；武功数值迁移在 f4 钩子协议就位后进行。
