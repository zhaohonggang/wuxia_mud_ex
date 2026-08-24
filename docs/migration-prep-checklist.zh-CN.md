# ExVenture/Kantele 迁移准备清单（修订版）+ 战斗系统进度盘点

> 2026-08-23 基于源码实测修订。取代早期分析中的"工程配套"章节。
> 参照物：LPC 源仓库 `C:\files\git\mud`（柳溪镇样板区 `d/minimal_world/`）、本仓库当前实现。

---

## 一、内容迭代机制现状（重要修订）

实测结论：**运行时世界内容不经过数据库**。

```
data/*.ucl ──Loader.load()──> Kalevala 结构体 ──Kickoff──> zone/room/NPC 进程
PostgreSQL 只存账号 + 玩家角色（ExVenture.Users/Characters + character_metadata）
```

游戏内 `reload` = recompile Elixir + 重解析 UCL → 已有 zone/room 进程原地 update、NPC 终止重生、items/help 刷新，**不碰 Ecto**（玩家不掉线不丢档）。改 `.ucl` → `reload` 秒级生效，这就是日常内容迭代通道。

### 残余缺口（原"增量播种"项替换为这两小项）

| # | 缺口 | 证据 |
|---|---|---|
| R1 | **删除型变更无效**：reload 只 start/update，被删的 zone/room/NPC 会继续在内存跑直到整进程重启 | kickoff.ex handle_continue 无 stop 分支 |
| R2 | **admin 世界编辑双轨死路**：ExVenture.Rooms/Zones/StagedChanges + admin room_controller 往 DB 写，但 Loader 只认文件——后台 Publish 不生效 | loader.ex 全程无 Repo 查询 |

处置建议：R1 补一个 diff-stop（对比新旧 id 集合 terminate 多余进程）；R2 迁移期直接禁用 admin 世界编辑入口，避免误以为已发布。

### R1/R2 处置时机（2026-08-24 补充）

两个缺口的"疼点"不在同一时期：

| 阶段 | R1（删除无效） | R2（后台死路） |
|---|---|---|
| 现在（柳溪镇打磨） | 几乎不删东西，零影响；改错重启 driver 即清 | 单人开发不走后台，风险≈0 |
| 转换器联调大世界前 | **必须补**：改名 NPC 新旧并存咬人、删掉的房间仍可走、每次试错需全服重启；且战斗中 NPC 被 terminate 可能留下 enemies 悬挂引用干扰调试 | — |
| 开服/多人协作前 | — | **必须做**：第二个人一旦走 Web 后台 Publish，写库成功但游戏无变化，排查成本高；禁用入口仅需十分钟 |

第四节那批玩法缺口（eff_\*、exp 门、learn 改造、装备多槽位）属**深度缺口不阻塞内容搬运**：exp 门与打坐循环赶在大世界武功数值迁移前，装备多槽位随转换器 Item.Meta 扩展一起做。

---

## 二、迁移前功能准备清单

### Tier 0 —— 硬阻塞（缺一项转换器输出即残废）

| # | 功能 | 状态 | 说明 |
|---|---|---|---|
| 1 | 自定义出口名 | ✅ 已支持 | Loader.parse_exits 对 exit key 无六向限制；minimap 六向仅影响小地图渲染 |
| 2 | 中文命令别名层 | ⬜ 未做 | Router 支持任意 UTF-8 动词；需建 北/南/看/拿/穿/吃/买/给/问 别名表 |
| 3 | Item.Meta 扩展 | 🟨 部分 | damage/skill_type/armor/value 已进 Meta(loader.ex parse_item_meta)；缺 weight/unit/material/food/medicine/秘籍五元组 |
| 4 | 角色持久化 | ✅ 完成 | character_metadata migration + records.ex（combat_exp/potential/skills 等）；**背包+装备均已落盘并登录恢复**（records.ex inventory/equipment 字段） |
| 5 | LPC→UCL 转换器管线 | ⬜ 核心未做 | 词法抽取 set()/heredoc/mapping/array/__DIR__；输出 LF；驱动禁止含 `../` 的加载路径等铁律见 mud 端 README |

### Tier 1 —— 让世界活起来

| # | 功能 | 状态 |
|---|---|---|
| 6 | 行为树 timer/chat 节点 | 🟨 有 initial_events(delay) 可凑合，缺独立 chat_chance 随机闲聊节点 |
| 7 | inquiry 问答生成器 | ⬜ 字符串表→tell-match 分支可自动生成；闭包类需新 Action 协议 |
| 8 | 商店系统 | ⬜ list/buy + vendor_goods + 货币余额（Item.Meta.value 已备） |
| 9 | 房间标志位 no_fight/outdoors/water/startroom | ⬜ starting_room_id 单点已有，需多区域与 flags 扩展 |

### Tier 2 —— 系统框架

| # | 功能 | 状态 |
|---|---|---|
| 10 | 师徒/门派框架 | 🟨 learn 命令+师父转发已通（潜能消耗）；缺门派家族树/gongxian 贡献/叛师；learn 语义差异见第四节.4 |
| 11 | 任务框架 | ⬜ Quest schema + accept 钩子 + 奖励服务 + 谣言频道；奖励三件套依赖 score/weiwang（见第四节） |
| 12 | 门 door | ⬜ 建议 v1 降级 features 描述 |
| 13 | 留言板 | ⬜ 决策：暂缓 / Web 化 / 最简 schema |

### 工程配套（修订后）

| # | 项 | 状态 |
|---|---|---|
| 14 | ~~增量播种~~ | ✅ reload 即增量热更（见第一节）；剩 R1/R2 两小补丁 |
| 15 | 柳溪镇 e2e 验收基线 | ✅ 战斗侧已立（scripts/combat_e2e.exs）；其余系统沿用同一夹具 |

---

## 三、战斗系统进度盘点（截至 2026-08-23 22:30）

**结论：按 combat-session-prompt 的验收标准基本交付，P0/P1 完成、P2 大部分完成。**

### 已实现（对照提示词阶段）

| 阶段 | 项 | 证据 |
|---|---|---|
| P0 | Vitals(qi/jing/neili)+死亡重生（NPC 虚空停尸 60s 回出生点） | character.ex、teleport.ex、combat_event.ex die/3 |
| P0 | 心跳模型：每角色 Process.send_after 1s 经 foreman 自投递（选型及理由已记录） | combat-system.zh-CN.md 设计决策表 |
| P0 | 命中管线全公式：valid_power/skill_power/AP-DP-PP/jiali/护甲创伤/伤害封顶，防守方结算制 | combat/engine.ex（rng 可注入，测试确定性） |
| P0 | fight/kill/halt/score + aggressive NPC 开战（brain room-enter→combat-engage） | commands.ex 注册、actions/combat_engage_action.ex |
| P0 | 击杀奖励 exp/potential（简化 winner_reward） | reward_for/1 |
| P1 | Skill behaviour 六契约点 + @actions 招式表数据 | combat/skill.ex、skills/liuxin_jian.ex、liuxi_neigong.ex |
| P1 | perform/exert（含二次施放拒绝、门槛校验）、enable 技能映射 | perform_command.ex、exert_command.ex、enable_command.ex |
| P2 | 角色属性持久化（character_metadata migration） | records.ex |
| P2 | 装备 wield/wear 影响命中管线 | wield_command.ex、world/item.ex meta.damage/armor |
| P2 | learn/practice（潜能消耗、师父校验） | learn_command.ex |

### 柳溪镇内容已先行移植

`data/world/liuxi.ucl`（黑虎 aggressive/野猪/王重九 no_kill 师父/长剑布袍）+ `data/brains/heihu.ucl`。注意这是**战斗子集移植**（8 个 rooms+characters 块），非完整 34 文件对应。

### 测试与验收

- 单元/链路：test/kantele/combat/{engine,flow,perform,skill}_test.exs + character/combat_test.exs + world/loader_combat_test.exs
- e2e：scripts/combat_e2e.exs（登录→装备→拜师→enable/exert/perform→黑虎开战→halt→战死重生→击杀野猪得经验）
- 文档：docs/combat-system.zh-CN.md 含公式对照表与有意简化清单（昏迷阶段省略、hit_ob/valid_damage 钩子未做、毒/jianu/仇杀未移植）

### 尚欠 / 后续建议

1. 本机验证一轮 `MIX_ENV=test mix test test/kantele` 与容器内 e2e（本次盘点未代跑）
2. hit_ob/valid_damage 技能钩子协议——大世界 719 武功泛化的前置
3. 昏迷(unconcious)中间态、毒 condition、加力命令(jiali 手动档)
4. NPC 战斗 AI 仅 aggressive 一档；hatred/vendetta 未做
5. 与本文第二节 Tier1/Tier2 合流：中文别名、商店、师徒 gongxian、任务框架

---

## 四、人物属性差距表（2026-08-23 实测补充）

### 4.1 Kantele 侧现状核对

`score` 显示的就是模型全集，无隐藏字段：

| 层 | 字段 | 持久化（character_metadata） |
|---|---|---|
| Vitals | qi/max_qi/base_qi、jing/max_jing/base_jing、neili/max_neili/base_neili | 仅 max_neili |
| Stats | str/dex/con/int、combat_exp/potential、skills{}、mapped{}、performs[] | 全部落盘 |
| Combat 运行态（不显示） | enemies/busy/jiali/temp apply buff/equipped | 不落盘 |
| NPC 专属 | attitude/no_kill/spawn_room_id/apply | UCL 定义 |

`force` 是 skills 表条目（默认 20，score 显示「基本内功」，neili 回复吃其等级加成，王重九可教）——概念与 LPC 一致。

#### 气血三线与 LPC 对应

| Kantele 字段 | 显示 | LPC 对应 | 差异 |
|---|---|---|---|
| `qi / max_qi / base_qi` | 气血 | `qi / eff_qi / max_qi`（气） | 直接对应；战斗唯一承伤线（combat_event.ex 只扣 :qi）；缺 eff 有效层 |
| `jing / max_jing / base_jing` | 精力 | 名承 `jing`（精），显示语义实为 `jingli`（精力） | **当前零消耗**：全代码库无 damage(:jing)/消耗点，仅随 con 回复，纯展示线；LPC 中「精」是 learn/study 燃料（(100+lvl×2)/int）、归零昏迷，「精力 jingli」是独立第四线 |
| `neili / max_neili / base_neili` | 内力 | `neili / max_neili` + jiali 加力档 | 基本对应（perform/exert 扣它）；缺手动加力档与运功疗伤 exert 系列 |

> 结论：learn 不耗精 → 学习无资源约束；若后续补 learn 的 jing 消耗（见 4.4），`jing` 线自然激活为 LPC 语义，无需新增字段。

### 4.2 LPC 端属性全貌（cmds/usr/score.c + hp.c 实测）

| 组 | 属性 | 说明 |
|---|---|---|
| 气血三层 | `qi / eff_qi / max_qi`、`jing / eff_jing / max_jing` | **当前/有效/上限**：创伤削 eff、治疗回 eff、heal_up 修 eff |
| 额外资源线 | `jingli / max_jingli`（精神力，与"精"是两条线）、`jiali` 加力档、`craze` 狂怒值 | Kantele 的 `jing` 字段名承「精」但显示为精力且零消耗（见 4.1 映射表） |
| 生存 | `food / water`（容量上限） | 无饥饿系统则无沉浸压力 |
| 先天/成长 | 四维 + **gift 先天赋值分离**（score 中 `[20]` 括号染色即对比 gift）、`magic_points` 灵慧 | Kantele 四维无先天/后天 |
| 江湖数值 | combat_exp、potential、**score 阅历、weiwang 威望、gongxian 门派贡献、shen 正邪** | 后四者任务/门派前置 |
| 战绩/生死 | MKS/PKS/WPK 杀生统计、dietimes/last_die 死亡记录 | 未迁移 |
| 境界系统 | breakup 任督、animaout 元婴、death 生死玄关、reborn 转世、opinion 大宗师评价 | 高阶玩法，远期 |
| 身份社交 | age/birthday/gender、born_family、family 师门树、couple、balance 存款、rmb 充值 | 社交经济层 |
| 技能/状态 | skills + skill_mapped + prepare + can_perform flags、temp apply/*、conditions、money | 部分已有 |

### 4.3 差距结论与优先级

1. **结构缺口（影响公式正确性）**：`eff_*` 有效层——LPC 创伤削有效值、回复修有效值；Kantele 现 wound 直接削 max+base 近似。→ *待拍板：现在给战斗 session 发补丁提示词，还是大世界武功迁移前再动？*
2. **Tier2 前置数值**：`gongxian/score/weiwang/shen` 必须随门派/任务框架补齐（拜师学绝招扣 gongxian、正邪限制拜师、任务奖励三件套）
3. **中优先级**：food/water 饥饿系统、gift 先天分离
4. **明确砍掉（远期）**：rmb 充值、sex 经历、skybook 丹药、婚姻存款、转世境界

### 4.4 learn/成长机制差异（learn force 王重九 ×10 实测）

| 维度 | LPC（cmds/skill/learn.c） | Kantele（learn_command.ex） |
|---|---|---|
| 批量学习 | `learn <人> <技能> <次数>` 一条命令×N | 无次数参数，需手动重复 |
| 直接消耗 | **jing**：`(100+lvl×2)/悟性`，首学双倍；耗尽可运功续学（force/regenerate） | 不耗气血精力 |
| 潜能语义 | **池子计数器**：`potential - learned_points ≥ 次数` 资格校验，每次记 1 点 | 直接扣货币：2 点/级 |
| 成长粒度 | improve_skill(+4~random) 经验点累积升级 | 每次 learn 恰好 +1 级 |
| 内功特有 | **valid_force 互斥**：已学 A 再学 B 冲突拦截；no_teach 表；叛师次数惩罚（cap−2×次） | 无互斥/叛师概念 |

处置建议：批量次数参数、jing 消耗公式、潜能池模型归入门派框架阶段（Tier2-#10）；valid_force 互斥随内功数量增多前实现。*待拍板：是否并入战斗 session 补丁范围。*

### 4.5 三条上限的成长路径（LPC 实测，clone/user/user.c）

三条线机制完全不对称：

**内力 `max_neili`——"天花板+打磨"体系 ✅**

天花板 `query_neili_limit()`（user.c:387）：

```
force 基本内功等级/2 × 10
＋最高一门特殊内功 (基本/2＋等级)×10 ＋ 该内功 query_neili_improve 贡献
×(1 + improve/neili%)        ← 百分比加成，次数上限受 con 约束
＋40%（breakup 任督二脉）＋转世特技/僧侣门派等杂项
```

| 爬升路径 | 机制 |
|---|---|
| `exercise/dazuo 打坐`（cmds/skill/exercise.c:111） | 耗气攒内力；**neili ≥ 2×max_neili 时 max_neili+1**，直到瓶颈 |
| `closed 闭关`（cmds/skill/closed.c:141） | 每 864s 一周期，4% 概率 improve_neili(+1)，上限 con 次 |
| 丹药 | dimai.c 类直接 improve_neili(100~200) |
| 境界 | breakup 任督 +40% |

**精力 `max_jingli`——同款结构 ✅**

天花板 = `magic_points/30 + int×30` ×(1+improve/jingli%) ＋ animaout 元婴 +40% ＋ 特殊内功 query_jingli_improve。爬升：`respirate/吐纳`（同打坐判定）、闭关、玉露丹类。

**气血 `max_qi / max_jing`——没有常规成长路径 ⚠️**

玩家侧全库无公式化增长；出生/转世固定 100（updated.c:556），唯一变动是个别物品（如蛇胆膏 +10 max_jing）。战力膨胀全在内力/精力/技能层。

#### 对 Kantele 的迁移含义

Kantele 的固定 base_qi 与 LPC 现状意外吻合，真正要补的是养成闭环：

1. **打坐/吐纳循环**（资源≥2×上限 → 上限+1，卡 query_*_limit 瓶颈）——核心成长循环
2. **limit 公式**吃 force 技能等级 → 把 learn force 与打坐串成「学内功→提上限→打坐涨内力」闭环
3. 闭关挂机、丹药、境界加成（breakup/animaout）属远期

### 4.6 战斗力来源与成长杠杆（2026-08-24 实测，adm/daemons/combatd.c）

#### 公式链

```
命中对抗 A/(A+B) 制（combatd.c:348 skill_power）:
  power = 技能等级³/10 + valid_power(combat_exp)
  攻击侧 power = power / 30 × str     （:402）
  防御侧 power = power / 30 × dex     （:408）
  ※ 四维是全局乘数：str 14→28 攻击力翻倍

伤害结算（do_attack）:
  damage += damage × str/50           （>30/>60 阶梯更陡，:1215-1219）
  jiali 加力：每刀耗 neili，bonus = jiali×damage/200（对方内功更高衰减到 /300）
  特殊内功 hit_ob 钩子可追加内伤；护甲创伤削 eff_qi
```

成长闭环：`打怪/任务 → combat_exp ─┬→ 解锁技能上限（等级³/10 ≤ exp）
                                  └→ 直接进 AP/DP`；`learn/practice 升技能（立方涨 power）→ 打更强的怪`；int 是练级速度加速器（learn 耗精 ÷int）。

#### 杠杆排序

| 排名 | 项 | 理由 |
|---|---|---|
| 🥇 | 武功技能等级 | 三次方增长（100→200级=8倍），被 exp 卡顶 |
| 🥈 | str 臂力 | 唯一双乘数属性（AP 乘数+伤害乘数），输出之王 |
| 🥉 | dex 身法 | 防御乘数，闪避/招架全靠它 |
| 4 | force 内功等级 | jiali 上限、hit_ob 内伤、打坐天花板三线挂钩 |
| 5 | con 根骨 | 回复速度 + improve_neili 次数上限（续航） |
| 6 | int 悟性 | 不直接加战力，决定练级速度 |

结论：优先堆技能等级（基本内功+主战武功+招架轻功均衡）；exp 过 200 万边际收益骤降，别裸刷经验。此结论两端通用（Kantele P0 已实现同款公式族）。

### 4.7 combat_exp 实战经验用途 + Kantele 缺口

| # | 用途 | 证据 | 公式/门槛 |
|---|---|---|---|
| 🥇 | 技能等级硬上限 | feature/skill.c:278 | `等级³/10 ≤ exp` 才能升级——exp 不够潜能再多也学不动 |
| 🥈 | 战斗公式直接加成 | combatd.c:398 | valid_power 进 AP/DP，200万后 ÷10、300万后再 ÷20 |
| 3 | 学习/研习门槛 | study.c:68、derive.c:29、jingzuo.c:55 | 读书需书籍 exp 要求；顿悟 3 万；静坐转化率 exp/10万 |
| 4 | 偷袭/暗算成功率 | ansuan.c:183、touxi.c:72 | random(我方exp) vs 对方exp/2 |
| 5 | 系统门槛/保护 | rideto 80万、scheme 5万、giftd 分档、新手<150免罚、PK 十级奖惩阶梯 | combatd.c:1974-1995 |
| 6 | 排行/社交 | brothers.c、league.c 按 exp 排序 | 江湖地位标尺 |

三条"经验"辨析：**combat_exp** 只增长不消费、解锁一切上限；**potential** 是 learn/practice 资格池（`potential - learned_points ≥ 次数`）；**experience 体会**是独立兑换线（user.c:590 有独立 limit）。

> ⚠️ **Kantele 缺口**：learn/practice 校验链（师父等级→valid_learn→气血→potential≥2）**未实现 exp 技能上限门（等级³/10 ≤ combat_exp）**——当前柳心剑可无视实战积累直接学到师父等级，养成闭环断一环。engine 侧 valid_power 已实现（见第三节 P0）。*待拍板：exp gate 是否并入战斗 session 补丁范围。*

### 4.8 Kantele 现有成长手段盘点（2026-08-24）

当前可用（7 条）：

| # | 手段 | 机制 | 效果 |
|---|---|---|---|
| 1 | `learn <技能> 王重九` | potential −2/级 | 技能等级立方进 skill_power，唯一主成长线 |
| 2 | `practice liuxin-jian` | qi 55 + neili 38 + potential 2/级 | 剑法专用刷级通道（liuxi-neigong 为 nil"只能用学"，learn_command.ex） |
| 3 | 击杀奖励循环 | exp=受害者/10(min5)、potential=exp/2(min2)（combat_event.ex:527 reward_for） | 唯一资源再生回路 |
| 4 | 装备 wield/wear | 长剑 damage 22 / 布袍 armor 2；场景另有 damage 35 / armor 20 高阶件 | 直接加减伤害管线 |
| 5 | `enable force liuxi-neigong` | 映射内功 | 解锁 exert/perform 加成基数 |
| 6 | `exert powerup` | 耗 neili 上临时 buff | 战斗中临时 apply |
| 7 | `perform liuxin-jian.liu` 柳浪闻莺 | 剑法 60 级自动领悟 | 爆发技 |

对照 4.6 杠杆表的断点：

| LPC 杠杆 | Kantele 现状 |
|---|---|
| 🥇 技能等级 | ✅ 有（learn/practice），缺 exp 上限门（见 4.7） |
| 🥈 str 双乘数 | ❌ 四维固定 20，全游戏无改变途径——乘数恒 ×20/30 |
| force 三线挂钩 | 🟨 有映射/exert，但 max_neili 固定恢复向 base，无打坐涨上限 |
| con 续航 | ❌ 固定值 |
| 装备经济 | ❌ 无 buy/list 商店，装备只能捡场景摆放 |

现版本最优养成路线：`杀野猪攒潜能 → learn 双技能顶满王重九(30级) → practice 柳心剑冲60领悟绝招 → 换高阶装备 → 战力封顶`。

**结论：闭环 = 一条技能线 + 一层装备，到顶即内容荒。** 优先补三件事（对应 4.3/4.5/4.7 已记缺口）：① 四维成长途径（先做吃书/丹药类道具即可）、② 打坐涨 max_neili 循环、③ exp 技能门。

### 4.9 装备系统对照（2026-08-24，LPC feature/equip.c 全读）

#### Kantele 现状：管线已通 ✅

- 四命令齐全：`wield/wear/unwield/remove`（wield_command.ex）
- 两槽位：武器 ×1（name/skill_type/damage）+ 护甲 ×1（name/armor），快照存 meta.combat.equipped
- 引擎三消费点接通：skill_type→attack_skill（engine.ex:64，空手 unarmed、"pin"→sword）；weapon damage 进伤害；armor → 受击方 `damage − random(armor)`（engine.ex:266）；持械与否影响招架 delta
- **持久化完整**：inventory + equipment 落盘 character_metadata 并登录恢复（records.ex:107-108, 217-224）——Tier0-#4 的"背包待确认"已解决

#### 与 LPC 差距表

| 维度 | LPC | Kantele |
|---|---|---|
| 武器类别 | 15 类独立 inherit（sword/blade/club/staff/whip/bow/axe/fork/hammer/pin/qin/xiao/zheng/dagger/throwing）各 set skill_type | 仅 skill_type 字段透传，无类别差异 |
| 武器属性键 | weapon_prop/{damage, dodge, …} 多键累加进 temp("apply") | 仅 damage 一个数 |
| 双手/副手 | TWO_HANDED/SECONDARY flag、空手 handing、主副手自动切换（equip.c:92-132） | ❌ |
| 护甲部位 | armor_type 多部位并行（body/head/boots/hands…）独立穿戴叠加 | 单 armor 槽 |
| 多属性护甲 | armor_prop/{armor, dodge, …} | 仅 armor 一个数 |
| 重量惩罚 | weight≥3000 自动 dodge −weight/3000（equip.c:8-11） | ❌ |
| 属性需求 | need mapping（"装备需要 臂力X"） | ❌ 无校验 |
| 耐久度 | consistence<1 禁用；命中 reduce_consistence（equip.c:18,199） | ❌ |
| 性别限制 | female_only（wear.c:75） | ❌ |

#### 迁移优先级

1. **必补**：多护甲部位 + weapon_prop/armor_prop 多键——否则大世界 72 区的靴子头盔与带 dodge 惩罚的重甲全废
2. **应补**：双手/副手 flag、need 校验、重量惩罚
3. **可缓**：耐久度、性别限制（不影响搬运，属运营细节）

---

## 五、建议下一步顺序

```
① 跑一遍 mix test + e2e 确认绿 → ② R1/R2 两个 reload 小补丁
→ ③ 转换器（Tier0-5）吃下柳溪镇全量 34 文件 → ④ 中文别名层
→ ⑤ 商店 + 房间flags → ⑥ 门派贡献/任务框架 → ⑦ 大地图分区批量搬运
```
