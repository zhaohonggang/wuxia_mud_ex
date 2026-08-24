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

---

## 二、迁移前功能准备清单

### Tier 0 —— 硬阻塞（缺一项转换器输出即残废）

| # | 功能 | 状态 | 说明 |
|---|---|---|---|
| 1 | 自定义出口名 | ✅ 已支持 | Loader.parse_exits 对 exit key 无六向限制；minimap 六向仅影响小地图渲染 |
| 2 | 中文命令别名层 | ⬜ 未做 | Router 支持任意 UTF-8 动词；需建 北/南/看/拿/穿/吃/买/给/问 别名表 |
| 3 | Item.Meta 扩展 | 🟨 部分 | damage/skill_type/armor/value 已进 Meta(loader.ex parse_item_meta)；缺 weight/unit/material/food/medicine/秘籍五元组 |
| 4 | 角色持久化 | ✅ 基础完成 | character_metadata migration + records.ex（combat_exp/potential/skills 等）；背包持久化待确认 |
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

### 4.2 LPC 端属性全貌（cmds/usr/score.c + hp.c 实测）

| 组 | 属性 | 说明 |
|---|---|---|
| 气血三层 | `qi / eff_qi / max_qi`、`jing / eff_jing / max_jing` | **当前/有效/上限**：创伤削 eff、治疗回 eff、heal_up 修 eff |
| 额外资源线 | `jingli / max_jingli`（精神力，与"精"是两条线）、`jiali` 加力档、`craze` 狂怒值 | Kantele 已把 jing 当精力用，语义偏移 |
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

---

## 五、建议下一步顺序

```
① 跑一遍 mix test + e2e 确认绿 → ② R1/R2 两个 reload 小补丁
→ ③ 转换器（Tier0-5）吃下柳溪镇全量 34 文件 → ④ 中文别名层
→ ⑤ 商店 + 房间flags → ⑥ 门派贡献/任务框架 → ⑦ 大地图分区批量搬运
```
