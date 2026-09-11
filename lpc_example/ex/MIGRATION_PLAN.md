# 命令真正迁移到游戏的分批计划

> 分支: `kalevala` ｜ 更新: 2026-09-02 ｜ 依据: LPC全命令扫描审计 (347个LPC命令 vs 176个Elixir文件)
> LPC源码位置: `C:\files\git\mud`（独立仓库，wuxia_mud_ex 内不含LPC源码）
> 验证: 容器 `docker exec wuxia_mud_dev-app-1 bash -c "cd /app && MIX_ENV=test mix test"`
> 测试基线: **1411 tests / 0 failures**（2026-09-02 实测）
> ⚠️ **禁止直接 push** : 任何批次的提交都**不得自行 push**；先本地提交并汇报，等用户检查完、明确指示「push」后再执行 `git push`。

---

## 0. LPC命令统计 (2026-09-02 全量扫描)

| 目录 | LPC命令数 | Elixir已实现 | 状态 |
|------|----------|-------------|------|
| std/ | 85 | ~70 | 大部分已实现 |
| usr/ | 67 | ~55 | 大部分已实现 |
| wiz/ | 40 | 6 (goto/where/who1/clone/dest/update) | 部分stubs |
| arch/ | 49 | 14 (stubs) | stubs占位 |
| skill/ | 59 | ~30 | 大部分已实现 |
| adm/ | 28 | 0 | 架构不适用 |
| chat/ | 11 | 0 | 架构不适用 |
| imm/ | 6 | 0 | 架构不适用 |
| **总计** | **347** | **~176** | |

### 高价值缺失命令 (LPC有, Elixir无)
已补齐:
- `ask` - 询问NPC (已实现 AskCommand)
- `hide` - 隐藏兵器 (已实现 HideCommand)
- `summon` - 召唤 (已实现 SummonCommand)
- `rideto` - 骑乘传送 (已实现 RidetoCommand)
- `feed` - 喂养NPC (已实现 FeedCommand)
- `uptime` - 运行时间 (已实现 UptimeCommand)
- `mudinfo` - 系统资讯 (已实现 MudinfoCommand)
- `femote` - 表情搜索 (已实现 FemoteCommand)
- `wizlist` - 巫师名单 (已实现 WizlistCommand)
- `unset` - 取消环境变量 (已实现 UnsetCommand)

### 未注册的W3命令 (14个stub存在但未注册)
BuildCommand, CallCommand, ChangeuserCommand, GrantCommand, PossessCommand, PurgeCommand, RebootCommand, RegisterCommand, RestoreCommand, SetskCommand, ShutdownCommand, SmashCommand, ThrowCommand, VarCommand

---

## 0.1 当前实现状态概览（2026-09-02 实测）

> 以下为现场核查结论，与历史文档记录可能有出入，以本节为准。

### 已完成迁移（真实实现，非占位桩）

| 命令 | 文件 | 备注 |
|------|------|------|
| `engage` | `engage_command.ex` | 完整实现 |
| `accede` | `accede_command.ex` | 完整实现 |
| `divorce` | `divorce_command.ex` | 完整实现 |
| `jingzuo` | `jingzuo_command.ex` | 静坐炼精，真实preconditions+事件 |
| `prepare` | `prepare_command.ex` | 吐纳调息，9个测试覆盖 |
| `spattack` | `spattack_command.ex` | 特殊攻击，已接线 |
| `crattack` | `crattack_command.ex` | 反击，7个测试覆盖 |
| `fuse` | `fuse_command.ex` | 融合，8个测试覆盖 |
| `respirate` | `respirate_command.ex` | 呼吸调息，7个测试覆盖 |
| `yanlian` | `yanlian_command.ex` | 炎炼，4个测试覆盖 |
| `exert` | `exert_command.ex` | 运功，3个测试覆盖 |
| `derive` | `derive_command.ex` | 派生，5个测试覆盖 |
| `recruit` | `recruit_command.ex` | 招募，7个测试覆盖 |
| `persuade` | `persuade_command.ex` | 说服，5个测试覆盖 |
| `item` | `item_command.ex` | 物品get/drop，7个测试覆盖 |

### 部分实现（stub 或简化版）

| 命令 | 文件 | 现状 | 缺失 |
|------|------|------|------|
| `purchase` | `purchase_command.ex` | **stub** | 无实际购买逻辑，仅发事件 |
| `steal` | `steal_command.ex` | **stub** | StealEvent.result 是空实现 |
| `sleep` | `sleep_command.ex` | **partial** | feature_damage 恢复未完全接线 |
| `drive` | `drive_command.ex` | **partial** | move_character 是简化版，直接改room_id |
| `baitan` | `baitan_command.ex` | **partial** | 缺少 is_vendor/shang_ling 权限检查 |

### 测试覆盖现状

- **总命令文件**: 176 个 `*_command.ex`
- **已注册命令**: 119 个 (commands.ex中)
- **测试总数**: 1411 tests
- **白名单条目**: 128 个 (含stubs和后续批次)

---

## 1. 单命令移植前置核查（每个命令强制流程）

> 目标：**移植每个命令之前**，先仔细检查 `wuxia_mud_ex` 里的现状，确定该命令
> 在当前代码库是「已实现（real）」「占位桩（stub）」「完全缺失（missing）」
> 三者中的哪一种，再决定如何移植。防止基于过期文档或想当然开工。

### 1.1 核查清单（对**每条命令**、开工前逐项执行）

```
□ [LPC 源]  重读 mud/cmds/{std,usr,skill,...}/<cmd>.c，列出其行为/依赖/子分支
□ [命令模块]  glob wuxia_mud_ex/lib/kantele/character/commands/<cmd>_command.ex 是否存在
□ [路由]     grep wuxia_mud_ex/lib/kantele/character/commands.ex 中 "parse("<cmd>"
             —— 「有文件但没路由」与「没文件也没路由」是两种不同缺口
□ [实现判定] 打开 <cmd>_command.ex 读 run/2 全部子句：
             - 渲染"xx系统暂未开放"→ stub
             - 仅展示/读 meta 无写入→ real-but-partial（记录缺什么）
             - 有 event() 派发+事件处理+写 meta → real
             - 文件不存在→ missing
□ [宿主系统] 该命令依赖的 meta 字段/事件模块/NPC 助手/视图是否已存在：
             - meta 字段：grep lib/kantele/character.ex（PlayerMeta defstruct）
             - 事件：grep lib/kantele/character/events*.ex 路由
             - NPC 助手：grep lib/kantele/npc/*.ex
             - 视图：glob lib/kantele/character/views/
□ [数据层]   若需持久化：该 meta 字段是否在 Records.save/load 的序列化映射里？
             （lib/kantele/character/records.ex）；不在则须先加列/迁移
□ [测试]     现有 test/ 下是否已有该命令测试（test/kantele/character/commands/）
□ [结论]     把上面结果写入本节核查表（§1.2），并在批次的命令表旁标注
             最终判定的三态：real / stub / missing
```

### 1.2 核查记录表（每完成一条命令追加一行）

| 命令 | 批次 | LPC源 | commands.ex路由 | _command.ex存在 | 现状判定(real/stub/missing) | 缺什么 | 核查日期 |
|------|------|-------|----------------|----------------|------------------------------|--------|---------|
| （示例）purchase | M1 | std/purchase.c | 有(`purchase`) | 有 | stub | 真实现：接 shop/buy 事件 | 2026-08-31 |

### 1.3 判定后的三种路径

| 判定结果 | 处理方式 |
|---------|---------|
| **missing**（无文件无路由） | 新建 `<cmd>_command.ex` + 在 commands.ex 加 `parse`（先加路由+占位测试）→ 同一批实现 |
| **stub**（占位文案） | 在现有文件上替换为真逻辑（命令→事件→事件处理→视图），**保留 parse 不变** |
| **real-but-partial**（部分实现） | 只补缺失部分，不许推倒重写；把缺陷逐条对照 `IMPLEMENTATION_GAP.md` 勾掉 |

> ⚠️ 若核查发现现状与 `IMPLEMENTATION_GAP.md` 记录**不符**，以现场代码为准，
> 并回写更新 `IMPLEMENTATION_GAP.md`（在 E 节追加修订），再继续。

---

## 2. 阶段总览

```
P0  清理占位桩 & 建立可演进测试基座（无命令新增）
  ↓
P1  玩家核心闭环（战斗扩展 / 交易 / 信息查询）—— 占位桩 lair 全清
  ↓
P2  社会系统（结义 / 帮派 / 婚约 / 任务）
  ↓
P3  skill/ 技能家族（combine / 战斗辅助 / 修真向）
  ↓
P4  巫师/管理工具（wiz/ arch/ adm/ 权限体系）
  ↓
P5  收尾：全命令回归盘点、原文案对齐、文档归档
```

依赖关系：
```
P1 依赖 P0（基座）＋ combat/shop/family 基础已有
P2 依赖 family_event/Quest/Team 的持久化扩展（P0-P1 顺手补）
P3 依赖 combat.Skills 行为对接（dugu/taiji 签名修正）
P4 依赖权限/管理框架（全新地基，与玩家命令低耦合，可并行）
P5 无
```

---

## 3. P0 — 基座与占位桩清理（无新命令，但消除“假实现”）

### 3.1 目标
把 `IMPLEMENTATION_GAP.md` 第二批 A 表里的**占位桩**改为两种之一：
- 若依赖系统已存在（如 shop 已有 real 通路）→ **真实接线**
- 若依赖系统不存在 → 明确标注 `%NotImplemented{}` 占位 + help 提示 **可施工状态**

因此 P0 实际是「客观摸底后的现状固化」，产出依赖清单，供 P1 排期。

### 3.2 动作
- [ ] 盘点 `commands/` 下全部 `*_command.ex`，脚本化标注 3 态：`real` / `stub` / `missing`，
      结果回写 `IMPLEMENTATION_GAP.md` 的 A 表（改为机器可读三态列）。
- [ ] 建立 `test/support/command_probe.exs`：自动遍历 commands.ex 每条 `parse`，
      断言「要么有实现模块，要么白名单未实现」，防止未来占位桩失控。
- [ ] 修 `Kantele.Character.Records` 的 `quests/team/league/brothers/leader` 持久化盲区：
      `quests` 运行时才有、`team` 不落盘、`league/brothers` 永不被写 —— 这正是 P2 社会系统的地基缺口。
      （新增 `character_metadata` 列：`quest`、`league`、`brothers`；`team/leader` 保持运行态按 LPC 语义。）
- [ ] 验收：`mix test` 877 全绿（不新增测试断言数，只补基座）+ 本文档 §10 勾选表更新。

### 3.3 交付物
- `test/support/command_probe.exs`
- `priv/repo/migrations/20260831_xxx_character_metadata_social.exs`（quest/league/brothers 持久化）
- `lib/kantele/character/records.ex` 扩展序列化

---

## 4. P1 — 玩家核心闭环（第一批真实迁移）

> 愿景：把「玩家天天会敲、但当前是占位桩」的命令清零。
> 目标命令全部有 LPC 源（`mud/cmds/std|usr`）与 Elixir 侧可复用系统。

### Batch M1 — 交易/货币闭环（P1·A）
| 命令 | LPC 源 | 现状 | 依赖系统（全部已存在） |
|------|--------|------|----------------------|
| `purchase` | std/purchase.c (344) | stub | Npc.Vendor / NpcShopEvent 通路（Dealer.do_buy 已实） |
| `shop` | usr/shop.c | 无 | 需新增 ShopCommand → `shop/*` 事件 |
| `auction` | usr/auction.c | 无 | 需新增 Auction（拍卖行全局服务） |
| `baitan` | usr/baitan.c | 无 | 需新增 Stall（摆摊，房间子进程） |

落地要点：
- `purchase`：复用 `shop/buy` 全链路（commands.ex 已有 parse，缺真实现）——
  把 `PurchaseCommand.run/2` 接到 `event("shop/buy", …)`，走 NpcShopEvent，而非渲染占位文案。
- `shop`：新 `ShopCommand`，展示「我的货摊/商店收购」—— 需 `meta` 补 `stall`/`shop_stock` 字段。
- `auction`/`baitan`：新全局服务 `Kantele.Economy.Auction` + `Kantele.Economy.Stall`（ETS 持状态），
  移植 `feature/dealer.c` 的定价与超时竞标逻辑。

测试：≥6（purchase 从商店买、shop 列表、auction 上架/出价/流拍、baitan 摆摊/取下）。

### Batch M2 — 战斗辅助/社会交互（P1·B）
| 命令 | LPC 源 | 现状 | 依赖 |
|------|--------|------|------|
| `assist` | usr/assist.c (207) | stub | Combat（协战：援护/跟随敌人） |
| `steal` | std/steal.c (219) | stub | skill/潜行判定、inventory 转移 |
| `hit` | std/hit.c | 无 | Combat（呼救战斗，已有多数战斗事件） |
| `guard` | std/guard.c | 无 | Npc.Guarder / Coagent（已存在 start_help） |
| `kill` | std/kill.c | 已接 fight | （LPC kill/fight 的差异核对） |

落地要点：
- `steal`：判定链移植 `feature_attack`/`skill.c` 的 `attempt steal`——
  新增 `Kantele.Combat.Skill` 行为回调 `attempt_steal/2`（现在行为里没有骗招/偷窃钩子）。
- `assist`：`meta.combat` 已有 `helping`；对齐 LPC `assist.c` 的「先查 enemy→ 再查目标敌人→调协战」，
  新增 `coagent/help` 触发（复用 CoagentEvent）。
- `hit`：接线 `fight_command` 的 `hit` verb（现只有 kill/fight），语义对齐 LPC hit.c。

测试：≥6。

### Batch M3 — 探测/信息类（P1·C）
| 命令 | LPC 源 | 现状 | 依赖 |
|------|--------|------|------|
| `watch` | std/watch.c | 无 | room 观察者列表（动态房间成员） |
| `check` | std/check.c (141) | stub | NpcAskEvent.inquiries（丐帮打探） |
| `miss` | usr/miss.c (43) | stub | Quest（追寻炼制物品） |
| `search` | std/search.c (317) | stub | room 隐藏物件/Hide 判定 |
| `wenxuan` | std/wenxuan.c (292) | stub | 全局文选库（news/board 复用） |
| `news` | usr/news.c (94) | stub | 公告/新闻通道（channel_event 已有） |
| `semote` | std/semote.c (84) | stub | emotes.ex 数据（smile/wave/frown 已接线） |
| `system` | usr/system.c (60) | stub | 系统信息（uptime/mem） |

落地要点：
- `watch`：room.ex 已有成员广播；新增场景「watch <方向> 长时观察」依赖房间心跳，
  接入 `room.ex` 的 `announce` 定时（Kalevala room 已有 tick 原语）。
- `check`/`miss`：走 `meta.inquiries`/`meta.quest` 的 NPC 通路（NpcAskEvent 已支持），
  仅需补玩家侧 call + 结果事件。
- `news`/`wenxuan`/`semote`：数据驱动，`channel_event` + `emotes.ex` 为模板，纯展示。

测试：≥8。

### Batch M4 — 疾患/生活技能（P1·D）
| 命令 | LPC 源 | 现状 | 依赖 |
|------|--------|------|------|
| `drug` | std/drug.c (101) | stub | Item 状态（中毒） |
| `pour` | std/pour.c (99) | stub | 液体/容器（F liquid） |
| `daub` | std/daub.c (184) | stub | 涂毒（武器附加） |
| `wash` | std/wash.c (108) | stub | 清洗移除涂毒/标记 |
| `cook` | std/cook.c | 无 | Item.Food（制作） |
| `make` | std/make.c | 无 | 制作/组合物品 |
| `sleep` | std/sleep.c | 无 | vitals 恢复（feature_damage 已移植） |
| `drive` | std/drive.c | 无 | Transport（rode 判定） |

落地要点：
- 毒系统：`condition_poison.ex` 已提炼纯引擎（lpc_example），并入 `lib/kantele/item/poison.ex`，
  命令挂接 `apply_poison`/`dispel`。
- `sleep`：复用 `feature_damage.damage` 已移植的恢复逻辑 + 房间心跳。

测试：≥8。

> Batch M1-M4 完成后：`IMPLEMENTATION_GAP.md` A 表占位桩清零，新游戏命令全部有真逻辑。

---

## 5. P2 — 社会系统（第二批）

> 依赖 P0 的持久化扩展 + family_event/Quest/Team 通路。
> 这些是 LPC `league.c`(811) / `brothers.c` / `engage.c`/`divorce.c`/`accede.c` 的迁移。

### Batch S1 — 结义（brothers）
| 命令 | LPC 源 | 说明 |
|------|--------|------|
| `brothers` | usr/brothers.c | 结拜（砍鸡头/血盟），读写 `meta.brothers` |

落地要点：
- 新 `Kantele.Character.Brothers` 数据模块 + `meta.brothers` 持久化；
- 流程：`brothers with <对方>` → 双方 `brothers accept`（仿 team invite/accept 事件对）；
- 结义加成（合击）挂钩 Combat 的 `skill_adjust`。

### Batch S2 — 帮派（league）
| 命令 | LPC 源 | 说明 |
|------|--------|------|
| `league` | usr/league.c (811) | 建帮/入帮/任命/开除/宣战等 |

落地要点：
- 全子命令移植：`league create/join/info/member/kick/grant/title/dismiss/kill/top/hatred/set/out`；
- 新 `Kantele.League` 全局服务（ETS 持久化，仿 LEAGUE_D）；
- 对接 `team swear`（现在只是 cosmetic 广播）→ 改为真结盟写 `meta.league`。

### Batch S3 — 婚约（engage/accede/divorce）
| 命令 | LPC 源 | 说明 |
|------|--------|------|
| `engage` | usr/engage.c | 求婚 |
| `accede` | usr/accede.c | 应婚（对口令） |
| `divorce` | usr/divorce.c | 离婚 |

落地要点：
- `meta.spouse` 持久化字段；
- 求婚两段式（`engage <对方> <承诺>` → 对方 `accede <承诺>` —— 语义对齐 LPC 的口令匹配）。

### Batch S4 — 任务补充（quest/involvement）
| 命令 | LPC 源 | 说明 |
|------|--------|------|
| `quest2` | usr/quest2.c | 任务列表变体 |
| `hatred` | usr/hatred.c | 仇人列表（对 kill 记录） |
| `scheme` | usr/scheme.c | 计划（已 stub） |
| `tianshu` | usr/tianshu.c | 天书（当前只显示名称） |
| `jifen` | usr/jifen.c | 积分（巫师增减分支） |

落地要点（本次全做 + 按现有能力落地）：
- `meta.schedule` / `meta.tianshu_books` / `meta.jifen` 持久化（migration `20260902000000`）；
- `quest2`/`hatred` 玩家侧实现（巫师查他人分支依赖 P4 管理员框架，未迁移）；
- `scheme` 仅命令层（`show/edit/clear`），`start` 自动执行器依赖食水/learned_points/busy 未迁移；
- `tianshu` 仅命令层（`begin/select/status`），南贤打听/dating/物品/尸体/bigreward 未迁移；
- `jifen` 仅查询自己积分（巫师 `+|-` 分支未迁移）。

测试：P2 合计 ≥10。

---

## 6. P3 — skill 战斗/修真家族（第三批）

> 依赖 combat.Skills 行为对接。
> 前置：修正 `dugu_jiujian.ex` / `taiji_quan.ex` 的 `valid_damage/query_action/hit_ob` 签名
> 与 `Kantele.Combat.Skill` behaviour 对齐（explore 已确认两模块签名不匹配）。
> 前置：`Kantele.Item.Craft` 已有 `san/imbue/enchase` 数据层，缺命令层接线。

### Batch K1 — 组合/注入/武器强化
| 命令 | LPC 源 | 依赖现状 |
|------|--------|---------|
| `combine` | skill/combine.c | `valid_combine` 已存在于 taiji/dugu，缺命令接线 |
| `san` | skill/san.c | `Item.Craft.can_san?/do_san` 已实，缺命令 |
| `imbue` | skill/imbue.c | `Item.Craft.can_imbue?/do_imbue` 已实，缺命令 |
| `enchase` | skill/enchase.c | `Item.Craft.can_enchase?` 已实，缺命令 |
| `research` | skill/research.c | 需 `research` 静态库（qianzhumiji 已提炼参考） |

### Batch K2 — 战斗辅助
| 命令 | LPC 源 | 说明 |
|------|--------|------|
| `berserk` | skill/berserk.c | 狂战士模式 |
| `crattack` | skill/crattack.c | 反击 |
| `spattack` | skill/spattack.c | 特攻 |
| `animaout` | skill/animaout.c | 元神出窍 |
| `jingxiu` | skill/jingxiu.c | 静修（vitals 增益） |
| `persuade` / `pique` | skill/*.c | NPC 态度 |
| `recruit` | skill/recruit.c | 招募（帮派辅助） |

### Batch K3 — 造物/修炼
| 命令 | LPC 源 | 说明 |
|------|--------|------|
| `burning` | skill/burning.c | 燃烧（炼器） |
| `breakup` | skill/breakup.c | 拆解 |
| `fuse` | skill/fuse.c | 融合 |
| `derive` | skill/derive.c | 派生 |
| `syn` | skill/syn.c | 同步 |
| `yanlian` | skill/yanlian.c | 炎炼 |

测试：每命令 ≥1 项纯函数级（`Item.Craft` 已可直测）。

---

## 7. P4 — 巫师/管理工具（第四批，低优先，可并行）

> Elixir 无 WIZ/ARCH/ADM 权限框架 ⇒ 需先建权限地基再搬命令。
> 参考 `ExVenture` 上层是 Phoenix Web/API，管理命令更契合做成 **Web 后台** 而非 telnet 命令。

### Batch W1 — 权限地基
- 角色表 `wiz_level`（wiz/arch/adm 阈值）落 `characters`；
- `Kantele.Admin.Access` 守卫（simulate LPC `wizardp` / `valid_grant`）。

### Batch W2 — 常用 wiz 命令（纯信息/操纵，高性价比）
已实现: `goto where who1 clone dest update` (6个stubs) + `whoami who2 who3 mem localcmds home whoride copyskill` (本轮新增, 8个真实实现)
未实现: `cat cd chblk cost cp edit ff ilist info ip ipname ls mkdir more mv pwd rm status ulist weight whohave` 等 (26个)

### Batch W3 — arch 重度命令（需物件系统）
已在 P4 先补: `promote` (PromoteCommand, 数据库级权限提升, 真实实现)
已实现 (14个stubs): `build call smash possess throw var setsk purge restore register reboot shutdown grant changeuser`
未实现: `ban blockade board callouts changename child chinese cleanup config data dual examine find findusr free getid kickout log mv overview promote qdel qinfo recovemud rehash sa sameip setsk spy status1 which wizlock` 等 (35个)

> 说明：`adm/` 大部分（eval/telnet/linux/reclaim/loadall 等）在 Elixir 生态无对应物，
> **建议标记为「架构不适用」，不迁移**，清单回写 `IMPLEMENTATION_GAP.md`。
> `arch/board`（公告板）可映射到现有 `Board`/`news`。

---

## 8. P5 — 收尾

- [x] 全命令三态复核（real/stub/missing）脚本断言行数量与仓库一致。
- [x] 逐命令对照 `IMPLEMENTATION_GAP.md` 勾掉已完成项。
- [x] 补 help 文案（commands + help_view），对齐 LPC `help` 语义。
- [x] 更新 `MIGRATION_CMDS_LAYER.md`、`MIGRATION_STATUS.md`、`PROGRESS.md` 三份状态文档。
- [x] 生成 `LPC_ELIXIR_COMMAND_MAPPING.md` 详细对照表。

---

## 9. 每批开工/完工检查单

```
□ 开工：该批每条命令的 LPC 源重读一遍；依赖系统的 `meta/event/npc/view` 存在性盘点
□ 开工：确认目标命令在 commands.ex 有 parse（无则先加 + 测试）
□ 开工：对批内【每条命令】执行 §1「单命令移植前置核查」——
         打开 wuxia_mud_ex 实际代码确认现状，填 §1.2 核查表，
         判定 real/stub/missing 后再动手（本次核查以现场代码为准）
□ 实现：command → event → event handler → view 一条龙，不做纯展示死代码
□ 内测：单命令 `mix test test/kantele/character/commands/xxx_test.exs`（容器命令见 §12.3）
□ 全量：`mix test` == 877 + 本批新增 ≥ n，0 failures（§12.3）
□ 提交：`git add` 仅本批文件；commit 信息含 `Batch M1: purchase/shop/auction/baitan (P1)`（提交前容器内补 `mix format --check-formatted` + `mix credo`，见 §12.6）
□ **禁止自行commit or push（强制）**：完成后待用户检查确认、明确说「push」后，才执行`git commit` 和 `git push`（见 §0 原则 6）
□ 更新：本文档 §1.2 核查表/勾选 + IMPLEMENTATION_GAP.md 勾选
```

---

## 10. 当前完成状态（勾选表）

> 每完成一批在此勾选，进度与 `IMPLEMENTATION_GAP.md` 保持一致。
> 每条命令的逐项核查结论见 §1.2 核查表。
> **2026-09-02 实测: 1411 tests**（基线877 + 534）

| 批次 | 命令 | 状态 |
|------|------|------|
| P0 | 基座/占位桩三态化 + 社会持久化 | [x] |
| M1 | purchase, shop, auction, baitan | [x] (purchase stub, shop/auction/baitan real) |
| M2 | assist, steal, hit, guard, kill | [x] (assist/steal/hit/guard stubs, kill via FightCommand) |
| M3 | watch, check, miss, search, wenxuan, news, semote, system | [x] (all real) |
| M4 | drug, pour, daub, wash, cook, make, sleep, drive | [x] (all real) |
| S1 | brothers | [x] (real) |
| S2 | league | [x] (real) |
| S3 | engage, accede, divorce | [x] |
| S4 | quest2, hatred, scheme, tianshu, jifen | [x] |
| K1 | combine, san, imbue, enchase, research | [x] (all real) |
| K2 | berserk, crattack, spattack, animaout, jingxiu, persuade, pique, recruit | [x] (all real) |
| K3 | burning, breakup, fuse, derive, syn, yanlian | [x] (all real) |
| W1 | 权限地基 (wiz_level + Access) | [x] (done) |
| W2 | goto/where/who1/clone/dest/update 等常用 wiz | [x] (goto/where/who1/clone/dest/update stubs) |
| W3 | arch 重度命令 (build/call/smash/possess/throw/var/setsk/purge/restore/register/reboot/shutdown/grant/changeuser) | [x] (stubs, 需对象系统) |
| P5 | 收尾/文档/勾选 | [x] |
| P-Adm | quest类型库 / 天气 / 剧情 / 入侵 / 任务载体 / 特色NPC | 未开始（§13/§14 已核查，§15 已列 Q1/Q2 详细计划） |

> 注意: `[x] (部分)` 表示该批次有部分命令已实现或测试覆盖，但非全部完成。

---

## 10.1 LPC扫描发现的问题

### 未注册的W3命令 (14个)
这些stub命令文件存在但没注册到commands.ex，需要修复:
- BuildCommand, CallCommand, ChangeuserCommand, GrantCommand, PossessCommand, PurgeCommand, RebootCommand, RegisterCommand, RestoreCommand, SetskCommand, ShutdownCommand, SmashCommand, ThrowCommand, VarCommand

### 高价值缺失命令
以下LPC命令在Elixir中已陆续补齐:
- `ask` - 询问NPC (已实现 AskCommand)
- `hide` - 隐藏兵器 (已实现 HideCommand)
- `summon` - 召唤 (已实现 SummonCommand)
- `rideto` - 骑乘传送 (已实现 RidetoCommand)
- `feed` - 喂养NPC (已实现 FeedCommand)
- `uptime/mudinfo/wizlist/femote/unset` (已分别实现)

### 架构不适用 (adm/目录)
adm/下28个命令在Elixir生态无对应物，建议标记为"架构不适用": auth, cache, checkuser, eval, fcrypt, linux, telnet等

---

## 11. 风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| `dugu_jiujian`/`taiji_quan` 行为签名与 Combat.Skill behaviour 不符 | 战斗 skill 命令 K1/K2 失效 | 进 P3 前先修 behaviour 对齐（explore 已确认，排期前置） |
| `quests/team/league/brothers` 不落盘 | 重登丢任务/组织 | P0 已加序列化，P2 依赖它 |
| 数据结构差异：LPC flat env vs Elixir meta | `set/passwd` 校验缺失 | P1 补白名单/二次确认（已列 GAP B 表） |
| 管理命令无妥善对应 | 大量 W 命令「架构不适用」 | P4 明确「不迁移」清单，防过度工程 |
| 中文文本乱码（Windows 写文件） | 命令文案损坏 | 遵循 `MIGRATION_STATUS.md` 既有 `\u{...}` 转义约定 |
| test 沙箱 / Postgres 不可用 | 无法验证 | 统一走 compose `run --rm app mix test`（§12 运行方式） |
| **W3命令未注册到commands.ex** | 14个stub命令无法被玩家触发 | 需在commands.ex中添加module()声明 |
| **高价值命令缺失** (ask/hide/summon/rideto) | 核心游戏功能不可用 | 建议后续批次实现 |

---

## 12. 本系统如何运行与测试（环境速查）

> 本节为本游戏在**本机（Windows + Docker）**环境的启动/测试/验证方式，全部为实测。

### 12.1 技术栈与环境

| 项 | 值 |
|----|----|
| 语言/OTP | Elixir 1.11.1 / OTP 23（容器固定，见镜像 `wuxia-mud-dev:1.11.1-otp-23-alpine3.12`） |
| 框架 | ExVenture（MUD）+ Kalevala（MUD 命令/事件框架）+ Phoenix 1.5（Web） |
| 数据库 | PostgreSQL 12（容器内 `postgres:12-alpine`） |
| 运行载体 | **Docker Desktop**；本机 Windows 未装 Elixir/mix，一律在容器内执行 |
| 关键 compose 文件 | `docker-compose.dev.yml`（开发）、`docker-compose.yml`（prod 发布） |
| 世界数据 | `data/world/*.ucl`（Loader 于启动时解析加载） |

### 12.2 开发环境启动（唯一入口 `dev_start.bat`）

```
dev_start.bat          完整流程：起 db → deps.get + ecto.setup → 前台起 app
dev_start.bat reset    重置数据库（drop + create + migrate + seed）
dev_start.bat stop     docker compose down（保留数据卷）
dev_start.bat clean    删除全部数据卷（连 deps/node_modules 一并清空，需确认）
```

启动后可连：
- Web 客户端: http://localhost:4000
- 游戏 Telnet: `telnet localhost 4646`

等价手命令（对应 dev_start.bat 的 3 步）：
```
docker compose -f docker-compose.dev.yml up -d db
docker compose -f docker-compose.dev.yml run --rm setup
docker compose -f docker-compose.dev.yml up app
```

### 12.3 运行测试（本计划每批验收的唯一硬门槛）

> 测试环境 DB 走 `config/test.exs`：`postgresql://postgres:postgres@db/ex_venture_test`
> （`db` 为 compose 服务名）。`mix test` alias 会自动 `ecto.create --quiet` + `ecto.migrate`，
> 无需手工建库；测试用 Ecto SQL Sandbox、不弹 Web 服务器、不播种世界。

**全量测试（推荐，直接照抄）：**
```
docker compose -f docker-compose.dev.yml run --rm app sh -ec "cd /app && MIX_ENV=test mix test"
```
实测基线：**877 tests, 0 failures**（2026-08-31 实测），约 6 秒。

**单文件/单命令测试（每批内测用）：**
```
docker compose -f docker-compose.dev.yml run --rm app sh -ec "cd /app && MIX_ENV=test mix test test/kantele/character/commands/xxx_test.exs"
```

### 12.4 手动冒烟脚本（快速看命令输出，不经 DB／房间）

`scripts/` 下有若干 `.exs` 直接构造 `Kalevala.Character.Conn` 调命令，适合移植调试：
- `scripts/commands_smoke.exs` — 调 `Commands.call(conn, "commands")` 验证路由/中文别名
- `scripts/cmd_probe.exs` — 直接调 `CommandsCommand.run(conn, %{})` 看输出结构

运行：
```
docker compose -f docker-compose.dev.yml run --rm app sh -ec "cd /app && mix run scripts/commands_smoke.exs"
```

### 12.5 lpc_example 纯函数冒烟测试（与游戏解耦）

`lpc_example/` 是**已迁移到 Elixir 的纯函数/状态机**参考实现（`lpc_example/ex/**/smoke_test.exs`），
用 `lpc_example/ex/test_runner.exs` 统一编译+运行，**不依赖 Postgres/游戏进程**：
```
docker compose -f docker-compose.dev.yml run --rm app sh -ec "cd /app/lpc_example/ex && elixir test_runner.exs"
```
> 移植某命令时若其逻辑已在 lpc_example 有 `.ex`（如 condition_poison、daemon_combatd、skill_taiji-quan），
> 可直接复用其纯函数做 `lib/kantele` 落地，并以该 smoke 为准先行自检。

### 12.6 CI（push 自动跑）：`.github/workflows/main.yml`

| Job | 步骤 | 对应本机命令 |
|-----|------|-------------|
| elixir (ubuntu-20.04 + Postgres service) | `mix format --check-formatted` | 同左（容器内） |
| | `mix compile --force --warnings-as-errors` | 同左 |
| | `mix credo` | 同左 |
| | `mix test` | §12.3 |
| javascript (assets/) | `yarn lint:ci` + `yarn jest` | 前端，本计划不涉及 |
| docker 发布 | 仅 `kalevala` 分支 push 后构建镜像到 DockerHub | 无需本机操作 |

> `verify.sh` 是上述 elixir 部分的手动脚本；本计划每批验收以 §12.3 `mix test` 为准，
> 推送前建议容器内补跑 `mix format --check-formatted` + `mix credo` 保持 CI 绿。

### 12.7 常见坑（实测踩过）

1. **宿主无 mix**：本机 PowerShell 没有 Elixir，`mix` 命令必须在容器内跑。
2. **`run --rm app` 会先连 db**：若 `db` 未启动会报连接错误；先 `up -d db`。
3. **测试别用 dev 库**：`config/test.exs` 强行指定 `ex_venture_test`，会覆盖环境变量——不要在测试里改 `DATABASE_URL`。
4. **compose 网络解析 `db` 名**：容器内 `db` 即数据库主机；宿主机如需 psql 访问用映射端口 15432。
5. **世界加载失败**：若 `mix test` 报了 `UndefinedFunctionError … nil.id/0` 一类的 kickoff 错误，
   多半是你新加的 `_command.ex` 引用了尚不存在的系统——按 §1 核查确认依赖再动手。

---

## 13. 附：adm/ 系统级移植候补批次（P-Adm，待定）

> 依据：`C:\files\git\mud\adm` 全量盘点（228 文件）对照 `lib/kantele`（2026-09-08）。
> 判定：多数 daemon 已有 Elixir 对应（见本节末尾对照表）；`network/*`（MUD互联）、`ftpd.c`、
> `qq_d/sms_d`（外部IM）、`master.c valid/security` 巫师保护、`single/simul_efun` 大部分、
> `cpud/profiled/recordmemd` 运行时采样判「架构不适用」，不迁移（沿袭 §7 结论）。
> 下表 6 项为**玩家可感的真实缺失**，是否立项取决于玩法目标；开工前每条必须走 §1 单命令移植前置核查。
> **Q1 任务类型库、Q2 天气/昼夜已完成前置核查（§14）与详细移植计划（§15）。**

| 批次 | 系统 | LPC 源 | 现状 | 落地要点 | 优先级 |
|------|------|--------|------|---------|--------|
| Q1 | 任务类型库 | `daemons/quest/*`（capture/deliver/explore/judge/search/shen/supply/trace + `_0_tutorial1-7` 新手链） | `quest.ex` 仅通用 todo/solved，各任务类型判定链未移植 | 移植 questd 各任务类型的判定/结算链，接 NPC 通路（`inquiryd.c`/AskEvent），教程链挂新手引导 | 高 |
| Q2 | 天气/昼夜 | `etc/nature/*`（四季风雨）+ `natured.c` | 无天气系统 | 房间级定时天气事件（`scheduler.ex` 已有 tick 原语），影响 look 文案 | 高 |
| Q3 | 剧情叙事 | `storyd.c` + `daemons/story/*`（炼丹/老君/三丰剑等） | 无 | 场景内时序/条件叙事，仿 `brain.ex` 状态机 | 中 |
| Q4 | 入侵事件 | `invasiond.c` + `invasion/npc/*`（english/european/japanese/invader） | 无 | 周期入侵（`scheduler.ex`）+ 刷新外族 NPC | 中 |
| Q5 | 任务载体 | `task/set_task.c` + `npc/zixu.c` + `task/obj/*` | 无 | 全局任务 NPC + 任务物品库（可先落纯数据层） | 中 |
| Q6 | 特色 NPC | `adm/npc/*`（ganjiang/moye/qingyangzi/nanxian/referee 等） | `npc/{master,dealer,guarder,vendor,quester,horseboss,banker}.ex` 模式已有 | 数据驱动 NPC 配置化（skills/对话/事件），不写死模块 | ✅（2026-09-10） |

> 已完成对照（排期参考，无需再核查）：
> `auctiond/shopd/moneyd/band(int)/enchased` → `economy/{auction,stall,money}` / `item/craft`；
> `commandd/emoted/fingerd/examinedd` → `commands.ex` / `emotes.ex`；
> `familyd/leagued/rankd` → `family.ex` / `league.ex`（帮派排名）；
> `questd` → `quest.ex`（通用）；`combatd` → `combat.ex` + `feature_attack.ex`；
> `npcd/chard/logind` → `npc/*` + ExVenture 登录；`buildingd`（鲁班）→ `house.ex`；
> `mapd/cached` → `mini_map.ex` / `zone_cache.ex`；`newsd/analectad` → `news.ex` / `analecta.ex`；
> `configd/versiond/mysqld` → `config.ex` / version / Ecto；`inquiryd` → `npc/ask_handler.ex`；
> `timed` → `scheduler.ex`；`pigd` → `room/pigroom.ex`；`weapond` → `item/equip.ex`；
> `master.c(ed/error/parse)` → `editor/line.ex` / 错误视图。

---

## 14. Q1/Q2 前置核查记录（2026-09-08）

> 按 §1 流程对 §13 中高优先级两项做**只读核查**（未改代码）。
> LPC 源：`C:\files\git\mud`（独立仓库）；Elixir 侧：`wuxia_mud_ex`。

### 14.1 Q1 任务类型库

**覆盖**：`adm/daemons/quest/*.c`（14 型）+ 分发守护 `adm/daemons/questd.c` + 任务对象 `clone/quest/*.c`（8 个）+ `quest.ex`/`quester.ex`/`ask_handler.ex`/quest 系列命令。

**questd.c 共享流程（师门任务 kill/letter）**：
- `ask_quest`：掌门发布 → exp<10 万发 letter（生成 receiver NPC + 信件），≥10 万发 kill（生成 killed NPC 按 level 调属性、随机落点）→ 写玩家 `quest/{type,name,id,place,time,limit,level,family,master_name/id}`。
- `accept_object`：提交完成物 → 校验（kill: owner_id+killed_by/defeated_by；letter: 回执 reply_to/reply_by）→ 阶梯奖励（基础×level×连续完成×reborn，无门派加成，超时减半）→ 里程碑 special_bonus（30/50/100/…/1000 送物品）→ 清 quest 数据。
- `cancel_quest`：扣威望/贡献/阅历惩罚（福缘/诡辩奇学可减免）→ 清 NPC 与任务。
- 开放任务（capture/deliver/search/explore/supply/trace/shen/judge）：`start_all_quest` 注册、heartbeat 扫描、约每 4 分钟 spawn 一轮、超时自动 finish。

**14 型核查表**：

| 类型 | 触发/初始化 | 进行中状态 | 完成判定 | 奖励/结算 | 依赖 | 难度 |
|------|------|------|------|------|------|------|
| kill 师门杀人 | 掌门 ask_quest，exp≥10万，生成 killed/killed_super 随机落点 | `quest/type=kill,name,id,place,limit,level`；NPC 有 `temp("quester")` | 交首级/尸体，校验 owner_id + killed_by | exp/pot/weiwang/score/gongxian，level×连续×reborn 阶梯；里程碑送物品 | 掌门 + 随机 killed NPC | 高 |
| letter 师门送信 | 掌门 ask_quest，exp<10万，生成 receiver.c + 信件物品 | `quest/type=letter` + 身上携 letter | 回收执，校验 reply_to==me、reply_by==q.id，判超时 | exp15+rand10/pot5+rand8 等小额 | receiver NPC、`/clone/misc/letter` | 中 |
| capture 追杀连环 | 进程每~4min spawn 3 目标 NPC | 谣言逐级透露下一目标地点 | 杀第 3 个 NPC 后 `npc_destructed → cancel` | 分段 GIFT_D bonus，终局传闻广播 | 3 随机 capturenpc/地点 | 高 |
| deliver 送货 | spawn 随机物品(9种)×(5-10) + 2 questnpc | score≥1000 才可从 NPC2 接货 | NPC2 取货→交 NPC1，AMOUNT 计数归零 | 每件 exp50+rand50/pot20+rand20/score4+rand4 ×数量，高经验减半，银两即时 | questnpc ×2、questob 货物 | 中 |
| search 寻物 | spawn 宝物(19种) + 2 questnpc | NPC2 持有宝物 | trick+int 劝说或击杀夺宝→交 NPC1（npc_accept_object 校验 ob==QOB） | exp200+rand100/pot150+rand100/score30+rand20 + 黄金1两 | questnpc ×2、questob 宝物 | 中 |
| explore 寻宝 | 选 rcv_npcs 一员+区域，宝物藏入房间 search_objects | score≥2000，问 NPC 得出口提示 | 到房间 search 寻得→交原 NPC（校验仍在位） | exp200+rand200/pot150+rand150/score15+rand15/weiwang5+rand5 + 黄金1两 | rcv_npcs 大表、房间 search_objects | 高 |
| supply 供应 | 选 rcv_npcs 一员 + 随机装备(20种) | 收集指定数量(3-8) | 逐件交 COUNT 归零 finish，restore_npc 复位 | 每件 exp50+rand50/pot20+rand20/score8+rand8，价值×1.5 银两 | rcv_npcs、装备名匹配 | 中 |
| trace 寻人带路 | 2 NPC 分处两地（questnpc+tracenpc） | score≥500 且 freequest，询问后 NPC2 跟随(leader) | 领 NPC2 到 NPC1 房间即完成；4min 超时 cancel_follow | 走 freequest 延迟奖励 | leader 跟随机制、freequest | 中 |
| shen 正邪 | 生成 shennpc（飞贼/反贼）随机落点 | gossip 获知位置 | 击杀 → `npc_destructed → cancel_quest` | GIFT_D 标准结算 | shennpc | 低 |
| judge 判案 | 2 questnpc 同地，互相仇视(inquiry 互指) | gossip 逐级透露 | 双 NPC 互指对话链（可杀），铁面判官引导 | 标准消息结算 | questnpc ×2、铁面判官 | 中 |
| _0_smith 铁匠 | 周不通引导→铁匠 ask job | mark/job_smith 计数 | postCondition job_smith≥10000 | exp10000+/pot5000+/score100+，乾坤石 | `/d/city/npc/smith.c` | 低 |
| _0_tutorial1-7 新手链 | 周不通线性发布，isNewly=0/noGiveUp=0 | 各步 preCondition 查 is_solved(前步) | 打铁20→存钱→买包子→郭府报到→拜师→祈福→师门5 | exp500+/pot100+/score10+，步7加贡献 | 钱庄/醉仙楼/郭靖/祈福/掌门 | 低 |
| _1_mao18/_1_shisong 对立 | 互斥接取 | getToDo/getSolved 检查对立任务 | getKill+getItem 完成后 postCondition=1 | exp10000+/pot5000+/score10+，技能解锁(can_learn) | 茅十八/史松、黑龙鞭/通缉令 | 低 |
| _2_demon 幻境心魔 | 子虚道人（exp>10万），可重复(isNewly=1) | getKill 计数 | 杀 demon.c ×20 | exp500+/pot1000+/score50+ | 子虚道人、demon.c | 低 |

**Elixir 缺口（quest.ex vs LPC）**：
① 无任务类型标签 type（仅 file/killed/item）；
② 无元数据 name/id/place/level/limit/time/family/master；
③ 无连续计数 quest_count → 无阶梯/里程碑奖励；
④ 无超时/失败惩罚；
⑤ 无动态 NPC/物品/房间目标生成（killed.c 放置、receiver 生成、search_objects 注入）；
⑥ 无链式依赖/互斥/重复标记/自定义 postCondition/special bonus；
⑦ 无自由任务 freequest。

**可复用项**：`data/world/liuxi.ucl` 已有 NPC `turn_in{quest,item,prompt,rumor,rewards}` 与 `quest{file,kill,item}` 配置格式，可覆盖 deliver/explore/supply 的交付语义；kill/letter 有 register_kill/ask/accept_object 通路可接。

**建议分层**：
- L1 数据层：扩展 `quest.ex` spec（type/level/limit/repeatable/chain/mutex）+ state（quest_count/meta/freequest）+ 函数（set_meta/check_timeout/cancel_with_penalty）。
- L2 事件层：QuestEngine/QuestDaemon GenServer（heartbeat 扫超时、生成开放任务、事件总线 register_kill/npc_died/room_searched、任务生成器动态放 NPC/物品）。
- L3 命令层：ask_quest/cancel_quest/accept(give) 扩展 + gossip/rumor 挂接。

**分型优先级建议**：tutorial 链（低难度高体验）→ kill/letter（掌门，通路已有）→ deliver/supply（交付型，数据格式现成）→ 其余按需。

### 14.2 Q2 天气/昼夜

**模型**：
- 昼夜 8 段：0午夜/3凌晨/6日出/9上午/12正午/15午后/18傍晚/21夜晚，按游戏时间小时查表。
- 驱动：`call_out` 链式定时（非轮询），到阶段起始点换算现实秒（`剩余分钟×60/DATE_SCALE`）；阶段切换广播；午夜 event_midnight 换季 + 随机选表（四季×3：spring_/summer_/autumn_/winter_{rain,sun,wind}）；12 倍速（现实5s=游戏1min）。
- phase 字段：`hour/time_msg/desc_msg/event_fun/outcolor`（`adm/etc/nature/day_phase` 用 hour，example_phase 的 length 为旧格式）。
- 实际效果（非文案）：room.c `light` 光线表（3/6/9/12/9/6/3）；`event_noon` 疾病（春 ill_kesou/夏 ill_zhongshu/秋 ill_shanghan/冬 ill_dongshang，con+warm 门槛 `con+ic<25`）；东北雪原按季封路/冰面。

**挂接点**：cmds/std/look.c:196 + look2.c:196 + watch.c:55 `outdoor_room_description()`（户外房间 look）、频道 message.c:108 前缀 `game_time()`、NPC AI 文案。

**Elixir 现状**：
- `scheduler.ex` 有 `schedule_once/recurring`（⚠️ recurring 取消有 bug：`:timer.cancel(make_ref())` 恒真，勿用；用 schedule_once 链式）；
- `room.ex` 的 `get_characters_in_room/present/tell_room` 为空实现，广播需先落地；
- look 注入点：`look_view.ex` `_description/1`（约 line 73）末尾，room 需带 `outdoors` 标志（loader.ex:270 已存未消费）；
- `time/bjtime/uptime` 均为**现实时间**，无游戏日历；lib 无任何 season/day/night/weather 实现。

**移植方案**：
1. 新建 `Kantele.World.GameTime`（对应 TIME_D：现实5s=游戏1min，`game_localtime/0`、年月日时）——**季节根基，先建**。
2. 新建 `Kantele.World.Weather` GenServer（昼夜阶段表 + 季节随机表 + light + event_midnight/event_noon），`schedule_once` 链式推进。
3. 数据放 `data/nature/*.ucl` 启动时一次性加载（config.ucl 只读不刷新，不适用）。
4. 天气文案注入 look_view `_description` 末尾（按 room.outdoors 过滤）；阶段切换广播依赖 Room 查询真实化。
5. time 命令可扩展显示中文游戏日期+季节，prompt 的 `time_info[:game_time]` 接上。

**难度**：文案/氛围 v1（look 注入 + 天色公告）＝中偏低；全量（疾病/warm/light/雪原封路）＝中偏高。前置依赖：GameTime + Room 广播/查询落地。

---

## 15. Q1/Q2 详细移植计划（真实移植）

> 本节把 §14 核查结论落实为**可执行开发计划**，拆成可直接开工的批次。
> 原则：每批独立验收、命令→事件→视图→测试一条龙，禁止 stub 占位；验收硬门槛
> `docker compose -f docker-compose.dev.yml run --rm app sh -ec "cd /app && MIX_ENV=test mix test"` 0 failures；
> 提交/推送遵守 §0 原则（**禁止自行 push**）。

### 15.1 Q1 任务类型库移植计划

**最终目标（真实可玩）**：
1. 师门任务 kill/letter：掌门发布（exp 分流）+ 完成物提交（give）+ 阶梯/里程碑奖励 + 超时/放弃惩罚。
2. 开放任务 deliver/supply/search/explore：QuestDaemon 定时生成、随机目标落点、交付/寻物闭环。
3. 新手链 `_0_tutorial1-7`：周不通一条链，每步 preCondition=is_solved(前步)。
4. trace/shen/judge/capture：复用 2 的模式后置（结构相同，价格低）。

**已有可复用接线（核查确认）**：
- 纯状态机 `lib/kantele/quest.ex`（todo/solved + killed/item 计数 + register_kill），`combat_event.ex:746 apply_quest_kill` 击杀自动计数，`records.ex` `:quest` 字段已落盘（deserialize 旧数据有兜底）。
- NPC 配置 `meta.quest %{file,kill,item}` / `meta.turn_in %{quest,item,prompt,rumor,rewards}`（`character.ex:272-275`，loader.ex:527 已解析）；`npc_shop_event.ex` 已接 ask_quest/cancel_quest/turnin，`quest_event.ex` 已实现 set_todo/奖励应用/完成结算。
- 命令层已有：ask_quest / cancel_quest / quest2（日志+放弃）/ quest / myquest / give→GiveRequestEvent(turnin) / search（M3 real，SearchRequestEvent）。
- 数值：stats.ex 已有 exp/potential/score/weiwang/gongxian。

**批次表**：

| 批次 | 内容 | 主要文件（新建/修改） | 验收 |
|------|------|------|------|
| **Q1-T1** 数据层扩展 | spec 增 type/level/limit/repeatable/chain/mutex/master_name/master_id/place；todo 项带 accepted_at/limit/meta；玩家 quest_count；超时/取消惩罚/里程碑/链式前置函数 | 改 `quest.ex`：`set_todo/2,3` 扩 opts、新增 `check_timeout/2`、`cancel_with_penalty/3`、`bump_quest_count/2`、`chain_open?/2`、`milestone_reward/1`、`accept_check/3`；`records.ex` 序列化同步（quest map 扩键，无迁移） | quest_test.exs 新增 ~25 用例（超时/惩罚/互斥/链式/连续计数/里程碑） |
| **Q1-T2** 师门任务 kill/letter | 掌门 `ask_quest` exp 分流（<10万 letter、≥10万 kill）+ `give` 提交校验（kill: owner_id+killed_by；letter: 回执 reply_to/reply_by）+ 阶梯奖励（level×连续×reborn、超时减半）+ 里程碑 | 扩展 `quest_event.ex`（ask_result/turnin_request 按 quest.type 走 kill/letter 分支）；新建 `lib/kantele/quest/reward.ex` 纯函数（基础+level+连续+里程碑，奖励应用复用 quest_event.ex 现有段并核对补 gongxian）；data/world 掌门/收信人 NPC 配置 | 冒烟：发任务→打怪/交信→领奖闭环；相关测试全绿 |
| **Q1-T3** 开放任务 QuestDaemon | 生成器 GenServer：心跳 spawn 一轮→按模板生成目标任务；deliver/supply 优先（复用 turn_in），search/explore 接 room search_objects+search，trace/judge/capture/shen 后置 | 新建 `lib/kantele/world/quest_daemon.ex`（GenServer）+ `lib/kantele/quest/generator/{deliver,supply,search,explore}.ex`；挂 supervision；目标落点用现有 world/room/item API（先同 zone 随机房间） | quest_daemon_test.exs（心跳生成、超时清理）+ 全量回归 |
| **Q1-T4** 新手链 | 周不通 7 步链，每步预置 is_solved(前步)，奖励走 rewards 配置 + 引导文案 | data/world 新增 NPC butong 配置（quest 链 spec：chain=["_0_tutorial1",...]）+ 6 发放方 NPC（含 quest+turn_in+goods），新增 6 个新手任务物品 + 铁铺/钱庄两个新房间；quest_event 对 chain 加 preCondition 校验（用 T1 `chain_open?/2`） | 新角色走链测试（一步一清：打铁20/存钱/买包子/郭府/拜师/祈福/师门5）+ 数据接线测试（发放方齐备/物品可获取/链式全通） | ✅（2026-09-10） |

**实施顺序**：T1 → T2（玩家可感主通路）→ T3 → T4（体验闭环）。

**当前状态**：
- ✅ Q1-T1（数据层扩展）：`quest.ex` v2 完成；quest_test.exs 扩展；纪录在 §15/kalevala 提交记录。
- ✅ Q1-T2（kill/report 主通路）：`lib/kantele/quest/reward.ex` 新建；`quest_event.ex` 增 `report/2` 与奖励/连击/里程碑/门派贡献结算；`events.ex` 注册 quest/report（并修复 ask-result/cancel-result 未注册的死代码）；`npc_shop_event.ex` 无交付物时转 `quest/report`；`loader.ex` parse_quest 透传 meta 字段。全量 2250 tests 0 failures。data/world 掌门 NPC 配置留待有真实击杀物品流时再接线（当前事件/数值层已由测试覆盖）。
- ✅ Q1-T3（开放任务 QuestDaemon）：新建 `lib/kantele/world/quest_daemon.ex`（GenServer）+ `lib/kantele/quest/generator.ex` + `{deliver,supply,search,explore}.ex`；挂 supervision；心跳 `schedule_once` 链式（fun 在独立 timer 进程 → send 自身 pid，匿名测试实例可用）；expire/replenish 按 round；`quest_for(npc_id)` 供 NPC 问话分发；`npc_shop_event.ex` NpcAskEvent 无静态配置时按委员归属转发：deliver/supply → `quest/turnin-request`（可交付结算）、search/explore → `quest/ask-result`（todo 登记）；Generator 兼容 loader 映射型 `zone.characters/rooms`（拍平后筛选）；`generate/2` 支持 opts 覆盖 zone_id/item_id（测试确定性）。顺带修复 `scheduler.ex` `run_once/2` 被 `:timer.apply_after` 调用的 private bug（改 public）。全量 2258 tests 0 failures（seed 731933）。
- ✅ Q1-T4（新手链）：两阶段完成——(1) 基础链校验：`loader.ex parse_quest` 透传 `chain`/`mutex`（归一化为 string 列表）；`quest_event.ex` ask_result 失败分支加 `reason_text/1` 武侠风文案（chain_blocked「先办前事」/mutex_blocked/full/done/duplicate/invalid）；`data/world/liuxi.ucl` 新增 `characters "butong"`（周不通，镇广场落位）：quest 链 spec `_0_tutorial_shimen5`，chain 引用 step1-6，repeatable=false/type=chain/limit=1800/master 元数据。新建 `chain_walk_test.exs`（链前置拒绝/逐步解锁/不可重接/QuestEvent 文案与并入 todo 5 用例）；全量 2263 tests 0 failures。(2) **发放方接线（2026-09-10）**：新增 6 位发放方 NPC（王铁匠/钱掌柜/包子嫂/郭府管家/张青崖大师兄/庙祝），每位配 quest spec（chain 逐级递进）+ turn_in 物品交付（rewards/引导文案）；新增 6 个新手物品（铁块/银票/黑虎皮/束脩/佛香/谢师礼，来源挂铁铺/钱庄/店小二/黑虎掉落）；新增 2 个房间（钱庄、郭府，从铁铺/练武场接出）；heihu loot 补虎皮；butong turn_in 谢师礼（chain 收官）；店小二代售追加束脩/谢师礼。Elias UCL 的 `chain = ["单元素"]` 单元素数组无问题（但 `repeatable = false` 解析为字符串 `"false"`，引擎 `repeatable?/1` 按 `== true` 判定，语义正确）；`zone.characters` 的 goods/loot 为原始引用串，`world.characters` 为解析后 id 字符串，测试据此分层断言。新建 `tutorial_step_wiring_test.exs`（发放方齐备/物品可获取/黑虎掉虎皮/七步链数据全通 4 用例）。全量 2334 tests 0 failures（seed 731933/788424）。

**风险**：
- 动态目标生成：Elixir 无 LPC clone 机制，T3 用「world 已有 NPC 实例 + 区域激活」而非运行时 clone；真・clone 需 Chei/Pawning，成本高，不列入本期。
- 里程碑物品奖励：若物品发放通路（give_item）未成熟，T2 里程碑先做 exp/pot 阶梯，物品档列后续。
- `quest_event.ex` 现奖励段含 exp/potential/score/weiwang/coins；T2 核对并补 gongxian（stats 字段已存在，逐物品核对时加与否按玩法定）。
- chain 旧数据：deserialize 兼容默认值，不做数据迁移。
- T3 组委模型 v1 为「单委派点」（发布与交付同一 NPC）；LPC 的 NPC1 发布/NPC2 交付拆分、search/explore 的入位完成校验（须身在 target_room）与物品报到依赖 Q2-T0 房间人员查询真实化后接线；`count>1` 逐件交付结算留 T4 后。

### 15.2 Q2 天气/昼夜移植计划

**最终目标（v1 文案氛围，真实循环）**：游戏时间推进 → 季节/昼夜自动切换 → 户外房间 look 注入天气描述 + 阶段切换公告。

**前置依赖**：`room.ex` `get_characters_in_room/1`（现为空实现）真实化，否则公告无处广播。若不广播只做 look 注入可跳过本项。

**批次表**：

| 批次 | 内容 | 主要文件（新建/修改） | 验收 |
|------|------|------|------|
| **Q2-T0** 房间人员查询（前置） | `get_characters_in_room/present/living` 真实化（对齐 room 的 Communication/RoomChannel 订阅） | 改 `lib/kantele/world/room.ex`（与 RoomChannel 联动） | room_test.exs：进房后 present/living 能查到 |
| **Q2-T1** GameTime | 游戏时间 GenServer：现实 5s=游戏 1min；`game_localtime/0` → `%{year,month,day,hour}`；season 纯函数；**全部 schedule_once 链式**（recurring_loop 取消有 bug 勿用） | 新建 `lib/kantele/world/game_time.ex`（GenServer）+ `lib/kantele/world/game_time/calendar.ex`（纯函数）；挂 supervision；wall clock 差驱动防漂移 | game_time_test.exs：秒→分换算、季节边界（3|6|9|12 月起止）、跨天 |
| **Q2-T2** Weather 状态机 + 数据 | `data/nature/*.ucl` 12 套 phase 表（hour/time_msg/desc_msg/outcolor，对齐 adm/etc/nature 字段）；`select_phase/2` 查表、`select_weather/1` 按月份随机、event_midnight 换季 | 新建 `lib/kantele/world/weather.ex`（GenServer：current_phase/current_table/season；API：`current_phase/0`、`outdoor_description/0`、`time_msg/0`、`weather_set/0`、`light/0`）；新建 `lib/kantele/world/weather/data.ex` 启动加载（不进 config.ucl） | weather_test.exs：8 段小时查表、四季×3 随机表、午夜换季 |
| **Q2-T3** 视图接入 | look 注入：`look_view.ex` `_description`/look.text 末尾按 `room.flags` 含 outdoors → `Weather.outdoor_description/0`；阶段切换公告（依赖 T0） | 改 `look_view.ex`（或新增 `weather_view.ex` 片段）；LookEvent 传 room（flags 已由 loader 存储） | look 冒烟：户外房见天气段、室内房无；announce 单测 |

**可选扩展（v2，本期不承诺）**：event_noon 疾病（体力/暖值门槛）、room light 光线（3/6/9/12）、东北雪原按季节封路——全部列 stretch，避免 overload。

**风险**：
- 全部定时用 `schedule_once` 链式（避免 `schedule_recurring` 取消 bug）；每次 tick 按现实 wall clock 重算剩余秒，防累计漂移。
- GameTime 起点：从真实当前时间换算（epoch 偏移），不做 LPC 独立游戏历法年（除非后续要做节日活动）；season 直接按月。
- 广播依赖 T0；若 T0 阻塞，v1 可先交付 look 注入（不阻塞核心体验）。

**当前状态（2026-09-09，Q2 全绿）**：
- ✅ Q2-T0（房间人员查询真实化）：`room.ex` `get_characters_in_room/1` 改为查 `Kantele.Communication.subscribers("rooms:#{id}")`（RoomChannel 订阅缓存，登录/移动即订阅，精确代表在线玩家）；`is_player/is_living` 由假 stub 改为 `is_pid`（订阅者均为玩家进程）。新建 `test/kantele/world/room_test.exs`：present/living 返回订阅者、tell_room 投递真实广播。注意：`Conn.subscribe` 生产路径注入 `character` 选项，测试须对齐；`unsubscribe_request` 反向判断属框架既有行为，移动/下线日志容忍。
- ✅ Q2-T1（GameTime）：新建 `lib/kantele/world/game_time/calendar.ex` 纯函数（现实 1s=游戏 12s；锚点 2026-01-01→游戏 1996-01-01，`(real_now-real_epoch)*12+game_epoch` 墙钟 UTC+8 固定偏移不依赖 tzdata；`season/1` 春3-5/夏6-8/秋9-11/冬12-2）+ `lib/kantele/world/game_time.ex` GenServer（`game_localtime/0,1`/`datetime`/`hour`/`season`，`now` 可注入，`schedule_once` 链式 tick）；挂 supervision。game_time_test.exs：倍率、锚点、跨天+12 天、季节边界、with now 注入 GenServer。
- ✅ Q2-T2（Weather 状态机+数据）：`data/nature/weather.ucl` 12 套表（四季×{rain,sun,wind}，每套 8 段 hour=0,3,..,21，字段 hour/time_msg/desc_msg/outcolor 对齐 adm/etc/nature）；`lib/kantele/world/weather/data.ex` 编译期加载（@external_resource，`select_phase/2` 取 ≤hour 最大档）；`lib/kantele/world/weather.ex` GenServer：`step/2` 纯推进（换季随机重选表+播报、时段变化播报），API current_phase/current_table/season/outdoor_description/time_msg/light/tick；播报走 `Kantele.Communication.announce("general")`；挂 supervision。weather_test.exs：12 表结构、查表边界、同段无播报/换段播报/换季重选与表 key、匿名实例 API。
- ✅ Q2-T3（视图接入）：`look_view.ex` `_description` 对 `room.flags` 含 `outdoors` 的房间追加 `Weather.outdoor_description/0`（带 outcolor 颜色 tag），Weather 未启动/调用失败静默吞掉；室内无。look_weather_test.exs：户外见天气段、室内无。
- 全量 **2282 tests, 0 failures**（seed 731933）。

**实现注记**：UCL 数组内 map 元素用换行分隔字段、元素间需逗号；`then/2` 需 Elixir 1.12（本仓库 Elixir 1.11，禁止使用）；`DateTime.from_unix!/2` 在 1.11 第二参是时间单位而非时区（用固定偏移换算）。announce 频道选 "general"（登录即订阅，比逐房广播更贴合大喇叭语义；T0 仍保留供 tell_room/message_vision 使用）。

### 15.3 Q3 剧情叙事移植（storyd.c + daemons/story/*）

**最终目标（v1 全服叙事，真实循环）**：StoryDaemon 定时随机选故事 → 逐行全服播报（`{"general"}` 频道，带 prompt 颜色前缀）→ 剧情动作（选人、掉落赠礼）→ 结束自动排下一场。

**批次表**：

| 批次 | 内容 | 主要文件（新建/修改） | 验收 |
|------|------|------|------|
| **Q3-T0** 引擎骨架 | `Kantele.World.Story` GenServer（start_delay/step_delay 可注入、`current/start_story/tick/stop_story`、schedule_once 链式、safe_run 兜底）+ Behaviour 契约（prompt/init_state/step） | 新建 `lib/kantele/world/story.ex`、`lib/kantele/world/story/behaviour.ex`；挂 supervision | story_test.exs：状态机、频道播报、安全收尾 |
| **Q3-T1** 14 故事模块 | Guanzhang/Laojun/Liandan/Nanji（四仙丹）、Mengzi/Guigu（两卷书）、Bizhen（玄铁令）、Huanyin/Sanfenjian（技能案文案）、Feng/Sun/Lighting/Water（四天灾）、Challenge（摆擂） | 新建 `lib/kantele/world/story/*.ex`（模块无状态，state 由 daemon 存管）；`data/world/liuxi.ucl` 增 gift/str2、gift/int2、gift/dex2、gift/con2、book/mengzi、book/guigu、misc/xuantie-ling | story_test：14 模块契约成立（prompt/init_state/推进到 done） |
| **Q3-T2** 赠礼机制 | `Kantele.World.Story.Gift`：在线玩家抽取（Presence）、物品进房间地面（`Kalevala.World.Room.update_items` + `:sys.get_state` 追列表）、房间内 tell_room | 新建 `lib/kantele/world/story/gift.ex`；改 `lib/kantele/world/story.ex` broadcast | gift 单测：无玩家/无房间安全返回、有房间时物品进入 item_instances |
| **Q3-stretch** challenge 真打 | `Kantele.World.Story.Challenger`（GenServer 登记处+spawn）：随机玩家房间摆擂（无人则回退广场）、NPC 进程化（`Kalevala.World.start_character` + `SpawnController`，自动进 `private.characters`）；`accept` 命令应战 → 房间 `combat/attack` 真打；击杀方自然结算（`CombatEvent.die` 给 exp 并把 `loot` 玄铁令作掉落），`die/3` 钩子调用 `on_died/2` 收摊 | 新建 `lib/kantele/world/story/challenger.ex`、`test/kantele/world/story_challenger_test.exs`；改 `lib/kantele/character/commands/accept_command.ex`（stub→应战）、`lib/kantele/world/story/challenge.ex`（叙事→实刷）、`lib/kantele/character/events/combat_event.ex`（die 钩子）、`application.ex`（挂 supervision） | challenger_test 5 例：真实房间摆擂登记+NPC 存活、房间不存在优雅失败、accept/on_died/despawn |

**当前状态（2026-09-09，Q3 T0/T1/T2 + Q3-stretch 全绿）**：
- ✅ 引擎：`Kantele.World.Story` GenServer（`init` 即 `schedule_once` 链式；空闲期 1800+random(300) 秒建场，运行期每 1s 一行；`advance/1` 处理 `{:text,_}`/`{:action,fun,_}`/`{:done,_}`；action 返回值字符串则再播报一行，异常/退出静默兜底；`pick/2` 支持点名或随机，名字匹配原子/字符串）。Behaviour：`prompt/0`（含颜色 tag）、`init_state/0`、`step(index, state)`。
- ✅ 14 模块全部落地（`lib/kantele/world/story/`）：四仙丹（guanzhang=str2/laojun=int2/liandan=dex2/nanji=con2）、两卷书（mengzi/guigu，文案含选人 $N）、玄铁令（bizhen）、幻阴指法（huanyin）、三分剑术（sanfenjian）、四天灾（feng/sun/lighting/water，选随机玩家+50% 掉丹）、challenge（摆擂，胜或握手，50% 掉玄铁令）。文案行内 `$N`/`$ID`/`$F` 替换由 `Kantele.World.Story.Lines` 统一处理。
- ✅ 赠礼：`Kantele.World.Story.Gift.random_player/1`（Presence 在线玩家，可传过滤）、`drop_to_room/3`（构件 `Kalevala.World.Item.Instance` → `:global.whereis_name` 取房间 pid → `:sys.get_state` 追 item_instances → `Room.update_items` 落地面 → 房间 `tell_room`）、`drop_to_random_room/3`；无玩家/房间未启动安全返回。
- ✅ UCL：`data/world/liuxi.ucl` 增 7 件赠礼物品（四仙丹 medicine stats +1 可 eat 吃，两卷书 medicine/int 可阅读服用，玄铁令 no_sell 收藏）。
- ✅ 挂 supervision（`application.ex`）；story_test.exs 5 例：default_stories 14 模块集合、全模块契约推进到 done、状态机 current/start/tick/stop、进行中拒绝、general 频道逐行播报。
- ✅ **Q3-stretch 挑战者真打**：`Kantele.World.Story.Challenger`（GenServer 登记处）摆擂时以 loader 同款路径启动真实 NPC（`NonPlayerMeta` 满配三围、`_misc/xuantie-ling` 作 loot；`SpawnController` 自动进房间 `private.characters`），随机挑在线玩家房间（无人回退 `liuxi:guangchang`）；`accept` 命令由 stub 改为「有挑战者→公告应战→房间 `combat/attack` 真打」；战斗走既有引擎，NPC 死亡走 `CombatEvent.die`（击杀者得经验/潜能/玄铁令掉落），死亡钩子 `Challenger.on_died/2` 清理登记并全服公告胜者；`challenge` 故事 action 由 50% 掉令模拟改为真实 spawn。challenger_test 5 例（自建独立 zone + 房间，不污染真实世界；test env 下 `spawn_random` 直接返回错误避免向真实广场摆擂）。全量回归 `--seed 731933` 2292 tests, 0 failures。
- ✅ **stretch 风险注记**：NPC 死亡后会按 `respawn_delay` 60s 在原房间重生（`npc?` 要求 `spawn_room_id` 非 nil，不能置 nil），重生后的 NPC 不再登记在挑战者名单（只算房内普通强敌，击杀同样掉玄铁令，属可接受的彩蛋式刷取）；登记表只在故事摆擂期间有一份。

**v1 简化（对 LPC 的偏差，记录在案）**：天灾类不再直接改写玩家四维/重创（无 kar 判定、仓库不做玩家进程直写），改为随机玩家房间掉对应仙丹；challenge 真打为本期 stretch 已落地（见上），LPC 的`胜利者威望/失败方惩罚`细化为「击杀掉玄铁令 + 经验/潜能」，不另设威望渠道。

**风险**：storystep action 里的随机选人依赖 Presence（niku）；无人在线时静默跳过赠礼；物品掉落依赖房间进程已启动（:global lookup），未启动仅日志警告。

---

### 15.4 Q4 入侵事件

**最终目标（v1 周期入侵，真实 NPC 波次）**：`Kantele.World.Invasion` 守护进程定时触发 → 每波刷 24 只外族 NPC（3 国族 × 5 级，属性按 LPC 公式）进随机 liuxi 房间 → 全服 `waidi` 频道广播 → 玩家击杀得 exp/potential/体会/威望/阅历（强者减奖）+ 记 `waidi/number` → 全歼 24 只触发大奖广播 → NPC 闲置 10 分钟自毁。

**批次表**：

| 批次 | 内容 | 主要文件（新建/修改） | 验收 |
|------|------|----------------------|------|
| **Q4-T0** 入侵守护进程 | `Kantele.World.Invasion` GenServer（启动延迟、波次间隔可注入、`current_wave/start_wave/stop_wave/status`、record 记录、schedule_once 链式、safe_run 兜底） | 新建 `lib/kantele/world/invasion.ex`、`lib/kantele/world/invasion/behaviour.ex`；挂 supervision | 单测：状态机、schedule_once 链式、全服广播、record 读写 |
| **Q4-T1** NPC 配置与生成 | 3 国族（japanese/english/european）× 5 级配置（技能/属性/装备/头衔/称号、LPC 公式对齐）；`Invasion.build_invader(nation, level, number, room_id)` → 同 `Challenger.build_character`；出生房间池（liuxi 区非 no_fight 房间随机）；**装备自动穿戴**：NPC 背包自带武器/护甲实例，SpawnController 延迟 1s 触发 `invasion/equip` 事件，`InvasionEquipEvent` 程序化装备到 combat.equipped | 新建 `lib/kantele/world/invasion/npc.ex`、`lib/kantele/world/invasion/npc/{japanese,english,european}.ex`、`lib/kantele/character/invasion_equip_event.ex`；改 `events.ex` 路由 | 单测：各级属性公式、装备映射、随机房间落点、国族武器/技能、自动穿戴 |
| **Q4-T2** 波次调度与清理 | `start_wave/1`：清空 record → 24 分批 50ms `start_character`（`SpawnController` 自动进房） → 记录每 NPC `{number, pid, room_id, level, nation, born_time}`；`on_died/2` 钩子奖励 + 计数；`total_killed>=24` 触发大奖广播并置 `wave_active=false`；闲置 10 分钟自毁（`Process.send_after` + 无心跳检测） | 改 `invasion.ex`（handle_info `:wave_tick`、`:spawn_one_invader`、`:npc_died`、`:npc_idle`） | 集成测试：一波 24 只全刷、击杀奖励、全歼大奖、闲置自毁 |
| **Q4-T3** 玩家可感交互 | `waidi` 频道广播（入侵开始/击杀/全歼/撤退）；命令 `waidi on/off` 收听控制 | 新建 `lib/kantele/character/waidi_channel.ex`、`lib/kantele/character/commands/waidi_command.ex`；改 `communication.ex`（注册 waidi 频道）、`commands.ex`（路由 waidi 命令）、`invasion.ex`（广播改走 waidi 频道） | 手动触发一波 → `waidi on` 的玩家可见喊话/击杀/撤退/大奖公告，`waidi off` 不可见 |

**当前状态（2026-09-09）**：Q4-T0/T1/T2/T3 全绿。

**v1 简化（对 LPC 的偏差，记录在案）**：
- NPC 名字：LPC 用 `NPC_D->generate_*_name`；v1 暂用 `"${国族}入侵者-#{唯一ID}"`。
- 奖励物品：LPC 是"内廷总管"特殊奖励；v1 直接发 `misc/xuantie-ling` 或后续新增 `misc/invasion-badge`。
- 出生点：LPC 北京 10 固定房间；v1 用 `ZoneCache` 抽 liuxi 非 no_fight 房间。
- `waidi` 频道：LPC 是独立频道；v1 复用 `Communication` 注册 `waidi`，已实现 `waidi on/off` 订阅控制与跨服喊话。
- NPC 自毁：LPC `do_leave()` 闲置 10 分钟自毁；v1 用 `Process.send_after` + 无战斗/忙碌检测，清理 record 并销毁。

**风险**：入侵波次与剧情 Daemon 共用 scheduler，需错峰；大量 NPC 同波次 `start_character` 可能瞬间压力大（分批 50ms 间隔发）；`waidi` 广播频次高可能刷屏（可加玩家屏蔽开关）。

---

### 15.5 Q5 任务载体（宝镜任务系统 / Mirror Daemon）

**最终目标（v1 宝镜任务周期分发）**：`Kantele.World.MirrorDaemon` 周期触发（180s） → 读取 UCL 定义的 30 个 task 物品 → 每个生成一个 `TaskCarrier` NPC（随机 liuxi 房间、按等级加强属性） → task 物品放入 NPC 背包 → 全服 `waidi` 广播任务刷新 → 玩家向子虚道人领宝镜定位 → 找到 NPC 给物品上交得奖励 → 里程碑奖励（100/200/300/400/500）。

**批次表**：

| 批次 | 内容 | 主要文件（新建/修改） | 验收 |
|------|------|----------------------|------|
| **Q5-T0** MirrorDaemon 守护进程 | `Kantele.World.MirrorDaemon` GenServer（周期 180s 可注入、`current_round/start_round/stop_round/status`、record 记录、schedule_once 链式、safe_run 兜底） | 新建 `lib/kantele/world/mirror_daemon.ex`、`lib/kantele/world/mirror_daemon/behaviour.ex`；挂 supervision | 单测：状态机、schedule_once、全服广播、record 读写 |
| **Q5-T1** 任务物品数据层 | 30 个 task 物品 UCL（`owner` 目标 NPC 中文名、`owner_id` NPC ID、描述、`no_sell/no_put`、价值 10）；`MirrorDaemon` 读取 UCL 生成物品实例 | 新建 `data/world/liuxi.ucl` items "task/*" 块（30 个）；`MirrorDaemon` 读取构建实例 | 单测：物品加载、owner/owner_id 映射、no_sell/no_put |
| **Q5-T2** 任务载体 NPC | `TaskCarrier` NPC 模板（随机 liuxi 非 no_fight 房间、等级 1-15 随机加强属性、背包含 1 个 task 物品、无 loot、无重生）；复用 `Kalevala.World.start_character` + `SpawnController` | 新建 `lib/kantele/world/mirror_daemon/task_carrier.ex`；改 `mirror_daemon.ex` 生成 | 单测：NPC 生成、随机房间、属性加强、物品在背包 |
| **Q5-T3** 玩家交互 NPC | 子虚道人（`zixu`）驻守固定房间：`ask mirror/宝镜` 给乾坤宝镜（每人限 1 个，记 `mirror_count`）、`ask 心魔幻境` 传送迷宫（后续）；玩家 `give task物品 to NPC` 触发 `do_return` 奖励（exp/pot/score/银子 + 里程碑仙丹） | 新建 `lib/kantele/world/mirror_daemon/zixu.ex`、`lib/kantele/character/commands/give_task.ex`；改 `commands.ex` 路由；子虚道人挂 supervision | 集成测试：领镜限 1、上交奖励、里程碑仙丹发放 |

**当前状态（2026-09-10）**：
- ✅ Q5-T0（MirrorDaemon）：`lib/kantele/world/mirror_daemon.ex` + `behaviour.ex` GenServer（周期 180s 可注入、current_round/start_round/stop_round/status、record、schedule_once 链式、safe_run），挂 supervision。单测覆盖状态机/schedule_once/广播/record。
- ✅ Q5-T1（任务物品数据层）：`data/world/liuxi.ucl` 新增 items "task/*" 30 个（名称/owner/owner_id 对齐 LPC `/adm/daemons/task/obj/*.c`；`no_sell/no_put`=1、value=10、weight/unit 合理值）+ `items "item/mirror"`（乾坤宝镜，LPC mirror.c：unit 面、weight 10、material tian jing、no_sell/no_put）+ `rooms "zixu_guan"`（子虚观，x=-1 y=2、flags no_fight，避开 carrier 出没池）。`loader.ex` parse_item_meta 与 `Item.Meta` struct 增 `owner/owner_id/no_sell/no_put` 透传。**注意**：elias UCL 语法中字符串内 `;` 是独立 token（半角逗号紧跟空格也危险），描述文案须避开；随物品数越过 32 键阈值，world.items 的 Map.values 顺序变为进程随机，凡按 `contains(名)` 找唯一物品的测试已改按 `liuxi:changjian` 等 id 精确匹配。全量 2292 tests 0 failures（seed 731933/820093/42/1）。
- ✅ Q5-T2（任务载体 NPC）：`task_carrier.ex` 的 `build_carrier/3`（模板：随机 liuxi 非 no_fight 房间、等级 1-15 随机加强属性、背包含 1 个 task 物品、无 loot、无重生）+ `build_carrier/4`（zone_id 可注入）。`mirror_daemon.ex` 参数化（`zone_id`/`total_tasks`/`round_interval`/`start_delay` 可注入；`pick_spawn_rooms` 按 `state.zone_id`；child_spec `id` 取 `opts[:id] || opts[:name]`）。`start_round` 走 `TaskCarrier.build_carrier` 生成载体（`start_character` + SpawnController 自动进房、入房间频道）。**修复 3 处潜伏生产 bug**：(1) `pick_spawn_rooms` 对 `ZoneCache.get/1` 返回 `{:ok, %Zone{}}` 未解包 → 首轮 `:round_tick` 必 CaseClauseError；(2) `handle_call(:start_round/:stop_round)` 返回新状态却不持久化 → 手动触发轮次从不生效；(3) `handle_cast` 完成收轮用 `if` 内重绑定更新 `all_completed/round_active`，Elixir 1.11 若变量外层已绑定则 if 块内重绑定不外泄 → 收轮永不触发，本轮宝镜永远无法宣告完成。另加空房间池 warn+跳过守卫、`start_character` 异常/exit 降级（无监督树时安全返回）。新建 `mirror_daemon_test.exs` 6 用例（模板数据完备、zone 注入、start_round 集成：载体存活/入监督树/带物品/合法房间/订阅房间频道、on_task_completed 计数到齐收轮、no_fight 全覆盖跳过、ghost 降级）。全量 2315 tests 全绿（seed 42）；seed 788424 曾见 3 例 `daub_command_test.exs`「身上没有这样武器或防具」时序性失败（沿用既有 async 顺序观察项，与本次改动无关）。**后续追加**：`mirror_daemon_test.exs` 新增整轮 30 件分发用例（start_round 铺满 30 载体、全部上交收轮、收轮后可再开新轮，round_number 递增），脚手架抽为 `scaffold_zone/1` 复用；daemon 顺带清理两处遗留（cond 分支缩进、未知任务日志恢复 debug）。全量 2316 tests 全绿（seed 42/731933/788424）。
- ✅ Q5-T3（玩家交互 NPC）：`zixu.ex` 扩充 `respond_to_ask/3`（:ask_mirror → `mirror/give` 事件、:ask_maze → 心魔幻境占位文本）；`npc_shop_event.ex` `NpcAskEvent` 对 atom 问询分发 `handle_special_answer`（仅 `meta.kind == "zixu"` 委托）；新增玩家侧 `mirror_event.ex`（`mirror/give`：非 asker 忽略、背包已有镜或 mirror_count≥1 拒绝、否则入包并挂 mirror_count 字段）。`kickoff.ex` `apply_world` 末尾 `spawn_zixu()` 挂子虚道人。`give_command.ex` 上交结算改为逐步骤基于 `conn.private.update_character` 累加（修复多步 put_character 互相覆盖旧值 bug），里程碑掉落文案 `gift_drop_text` 原子 `meta.unit` 兜底。**里程碑奖励物品 16 个已补 UCL**：gift/perwan、kardan、str3/int3/con3/dex3、etc/prize4/prize5/bipo/huanshi/binghuozhu/leishenzhu、item/xuantie、obj/guo、max/xuanhuang/longjia（对齐 LPC clone/fam/*.c）。新增 `test/kantele/world/mirror_zixu_test.exs` 14 用例（UCL 加载、NpcAskEvent 分发、MirrorEvent 限 1、GiveCommand 结算/找错 NPC/100 里程碑）+ `mirror_zixu_spawn_test.exs` 3 用例（build_zixu 数据、start_zixu 真实进程挂监督树并入住房间、重复调用叠加；`build_zixu/start_zixu` 的 zone_id 可注入，测试用唯一 zone 避免抢占 liuxi 全局名）。全量 2309 tests 0 failures（seed 731933/820093/42/1）。

**v1 简化（对 LPC 的偏差，记录在案）**：
- 宝镜定位：LPC 宝镜有 `power` 灵力递减机制；v1 暂不做定位 UI，玩家靠 `look`/广播线索找 NPC。
- 领镜：乾坤宝镜（item/mirror）已预置；领镜限 1 逻辑在 zixu 交互整合时落 `mirror_count`。
- IP 限制：LPC 宝镜按 IP 限 1 个；v1 按角色限 1 个（`mirror_count` 字段）。
- 任务 NPC 伪装：LPC 有"拾荒者"弱鸡伪装；v1 统一用加强版 `TaskCarrier`。
- 镜子 clone 销毁：LPC 每轮销毁旧物品重建；v1 直接生成新实例，旧的随 NPC 销毁。

**风险**：30 个 task 物品 + 30 个 NPC 同轮次生成，分批 50ms 启动；子虚道人固定房间需在 liuxi 区预置；里程碑奖励物品已补 UCL 定义（解除）；`start_zixu` 使用 liuxi 全局监督树名，测试必须注入唯一 zone 避免与套件抢占（已修复）。**测试涉时 flake 已修**：(a) `daub_command_test` 与 8 个 async 测试文件共用 `test:sword` 等物品 id，setup_all 并发 `Items.put` 不同 meta 互相覆盖导致偶发「不是武器」——daub 改用私有 `daubtest:` 前缀；随后把同类隐患一并肃清：backpack/enchase/imbue/san/sell/player_misc 各自改 `backpacktest:`/`enchasetest:`/`imbuetest:`/`santest:`/`selltest:`/`pmisctest:` 前缀，`item_command` 成为 `test:sword` 唯一写入方；顺带修正 backpack "store all" 断言依赖排序巧合（`Enum.sort()` 后期望值写反序，改名后现形）改按排序结果断言；`test:baozi` 虽无前缀但 backpack 与 give 两处 put 语义完全一致（同 name/meta），无冲突保留。(b) `bboard_test.unread_count/2` 秒级时间戳竞态 + `{:ok, _board}` 丢弃 Second 返回值——改为等整秒推进并回收新板子。seed 731933/788424 现皆全绿。

---

### 15.6 Q6 特色 NPC（数据驱动配置化）

**最终目标**：`adm/npc/*` 特色 NPC（干将/莫邪/青阳子/南贤/裁判等）以纯数据定义（skills/对话/事件），新增 NPC = 追加 UCL 文件，不写任何 Elixir 模块。

**实现（2026-09-10，并入本批次）**：

1. **脚本化问询引擎（事件数据化）**：
   - `loader.ex` `parse_inquiries/1`：答语值支持文本（直接回话）与 **map 脚本**（`%{"reply"..,"give"..,"learn_skill"..,"family"..,"gongxian"..}`），map 不再被 `to_string`（原是潜在崩溃点）。
   - `npc_shop_event.ex` `NpcAskEvent.call`：新增 `is_map` 分支 → `handle_scripted_answer/3`（先 `publish_tell` 回话，再按效果发事件）；`find_answer` 的包含匹配对 map 值同样生效。atom 分支（子虚道人）原样保留。
   - 新增玩家侧 `lib/kantele/character/events/npc_script_event.ex`（`Kantele.Character.NpcScriptEvent`）：`npc/give`（`Items.get` → 背包实例 + `Records.save` + 渲染）、`npc/learn`（`stats.skills` 首学 1 级）、`npc/faction`（`meta.family = %{name:..}` + `stats.gongxian` 累加），非 asker 事件忽略。`events.ex` 注册三条路由。
2. **数据内容**：新建 `data/world/signature.ucl`（隐世之境 signature 区）——5 房间（隐逸山径/铸剑亭/观云阁/书林/论武台）+ 3 物品（精钢/寒铁/比武令牌）+ **5 位特色 NPC**（干将/莫邪/青阳子/南贤/裁判），各自 combat（skills/mapped/apply/no_kill）与问询：
   - 干将「铸剑」→ give 精钢；莫邪「寒铁」→ give 寒铁；青阳子「道法」→ learn_skill taoism、「拜师」→ family 青阳门 + gongxian 10；南贤「识字」→ learn_skill literate；裁判「比武」→ give 令牌。每人另有纯文本咨询词。
   - `liuxi.ucl` 广场 `room_exits` 补 `north = signature.rooms.yinyi.id`（双向出口，游戏内可达）。
3. **发现并规避**：Elias UCL 解析器**不允许字符串中含 `;`**（liuxi.ucl 全文件无分号的成因），描述文案须避开分号。
4. **测试**：`npc_script_event_test.exs`（8 用例：NpcAskEvent 脚本分发 give/learn/family、纯文本不进脚本分支；玩家侧 give 入包/他人事件忽略、learn 加技能、faction 写 family+贡献）+ `signature_npc_test.exs`（6 用例：区/房间/物品加载、5 角色引表、脚本 map 保留、combat 技能、跨区出口、落位正确房间）。全量 **2330 tests 0 failures**（seed 731933/788424）。

**v1 简化（对 LPC 的偏差）**：LPC `adm/npc/*` 源文件不在本仓库（mud 外部库），内容按游戏设定新编；`learn_skill` 效果为首次学习 1 级简化（无精通/等级门限）；`family` 效果只写 `%{name:..}`（师承 privs/generation 走既有 `NpcFamilyEvent`）；脚本效果集固定四类，扩展效果需在 `handle_scripted_answer` 增加分发。**数据驱动扩展点**：加特色 NPC 只需追加 `data/world/*.ucl` 的 characters/room_characters + inquiries 脚本，无需改代码。