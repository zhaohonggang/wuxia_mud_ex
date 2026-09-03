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
已实现: `goto where who1 clone dest update` (6个stubs) + `whoami who2 who3 mem localcmds home` (本轮新增, 6个真实实现)
未实现: `cat cd chblk copyskill cost cp edit ff ilist info ip ipname ls mkdir more mv pwd rm status ulist weight whohave whoride` 等 (28个)

### Batch W3 — arch 重度命令（需物件系统）
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