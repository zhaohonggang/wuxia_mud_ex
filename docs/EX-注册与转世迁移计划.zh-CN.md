# LPC 注册/转世系统迁移到 ExVenture(Kantele) 实施计划

> 目标：**与 LPC 行为越一致越好**（faithful port，不擅自改进/新增 LPC 没有的能力）。
> 前置文档：
> - [`LPC-新用户注册与转世重生机制分析.zh-CN.md`](./LPC-新用户注册与转世重生机制分析.zh-CN.md)（LPC 侧行为基线 + 行号索引）
> - [`EX-注册与转世迁移可行性分析.zh-CN.md`](./EX-注册与转世迁移可行性分析.zh-CN.md)（端口架构 + 难度评估）
> - [`C-PVE27-valid_learn-长尾补全进度.zh-CN.md`](./C-PVE27-valid_learn-长尾补全进度.zh-CN.md)（性格门口径；4 个「包含门」技能与转世强相关）
>
> 系统范围 = **新用户注册** + **转世重生**，含其中 **性格/人格(character)、性别(gender)、属性(str/dex/con/int/per)、出生地(startroom)** 的赋值。

---

## 0. 一致性原则（贯穿全程）

1. **照搬 LPC 数值与分支**，不因「更现代」而改：
   - 新玩家属性**非固定**：`logind.c` 仅给临时初值 `str=dex=con=int=14, per=20`（logind.c:698-702），**真正分配在「阎罗殿」(`BORN_ROOM`) 经 `washto` 指令完成**——`str/int/con/dex` 各 10–30、总和必须 =80（yanluodian.c:112-129），`per` 与 `kar`（福缘）随机 `5+random(26)`（yanluodian.c:139-140）；转世后该分配机制不变。
   - 新玩家出生地经 `born <地名>` 选择（yanluodian.c:155-273），从固定 `born` 映射取 `startroom`/`born`/`born_family`，世家（欧阳/胡/苗/段/慕容）附 `surname` 与 `startroom`；非转世者走 `UPDATE_D->born_player` 随机赠 1–3 项「与生俱来」特技（updated.c:344-445，按 `character` 与属性≥20 过滤，部分特技再 +2 对应属性）。
   - 转世设 `character="国士无双"`（updated.c:515）、清记录清单、`age=14`、`max_qi/max_jing=100`、`reborn/count+1`、随机 `reborn.{str,con,int,dex}+1`、赠 1 普通+1 转世特技。
2. **不新增 LPC 没有的能力**：LPC 中**普通玩家无任何设定 `character` 的入口**（仅 NPC 注册 + 转世设），故 Ex 也不应为普通玩家提供「自选天性」——保持 `meta.character` 恒 nil 直至转世。这是「一致」而非「缺口」。
3. **出生地**沿用 LPC 的 `BORN_ROOM`（新玩家）语义，而非单一 `start_room_id` 兜底。
4. 一切以**可逐项比对**为目标：每个 Phase 末产出「LPC 行为 vs Ex 行为」对照表。

---

## 1. Phase 0 — 准备与对齐（约 0.5 天）

| 步骤 | 内容 | 产出 |
|---|---|---|
| 0.1 | 锁定 LPC 行为基线：通读两份前置分析文档，列出「必须一致」清单（属性初值、gender 取值、character 取值集合、转世清记录清单、特技集合、startroom 规则） | `一致性基线清单`（附本文档附录 A） |
| 0.2 | 数据模型核对：确认 `PlayerMeta.character` / `meta.env.gender` / `Stats` / `Vitals` / 角色 `room_id` 在 Ex 的落点与**持久化**（重点：DB schema 是否存 `character`；若 `Records.save` 未落盘该字段需补列） | 核对报告 + 必要的 schema migration |
| 0.3 | 房间映射：将 LPC `BORN_ROOM`/`REGISTER_ROOM`/`START_ROOM` 对应到 Ex 世界中的具体 room_id（新玩家 → BORN_ROOM 等价点） | 房间常量映射表 |
| 0.4 | 特技存在性核对：列出 LPC `special_skill/*` 12 普通 + 8 转世在 Ex 是否已有实现；缺失项标注为「钩子占位」 | 特技覆盖表 |

**验收**：基线清单 + 房间映射 + 特技覆盖表就绪；`meta.character` 持久化路径确认（必要时先补 migration）。

---

## 2. Phase 1 — 新玩家游戏内问答（对应 `logind.c` 注册流程）

> 难度低–中（~1–2 天）。**完全不碰网页注册页**（账号层本就与角色无关）。

| 步骤 | 内容 | 对应 LPC |
|---|---|---|
| 1.1 | 新增 `SetupController`（或就地扩展 `LoginController`） | `get_gender`/`make_body` |
| 1.2 | 首登判定：用 `meta.env.gender == nil` 或新增 `meta.setup_done` 标志区分新/老玩家 | 无直接对应（LPC 每次注册即新角色） |
| 1.3 | 问答①性别：`prompt` m/f → 写 `meta.env.gender`（"男性"/"女性"） | logind.c:672-674,703 |
| 1.4 | 问答②属性分配（**核心，须与 LPC 一致**）：在 BORN_ROOM（阎罗殿等价）以 `washto` 等价交互分配 `str/int/con/dex`，**各 10–30、总和必须 =80**；`per` 与 `kar` 随机 `5+random(26)`；校验不通过则要求重输 | yanluodian.c:100-153（washto） |
| 1.5 | 问答③出生地：以 `born <地名>` 等价交互，从 LPC `born` 映射选 `startroom`/`born`/`born_family`；世家（欧阳/胡/苗/段/慕容）附 `surname`+对应 `startroom` | yanluodian.c:155-273（born） |
| 1.6 | **与生俱来特技**：非转世者调用 `born_player` 等价逻辑，按 `meta.character`（此时恒 nil）与属性≥20 过滤，从 Ex 特技池随机赠 1–3 项（缺失项走钩子占位，见 D4）；命中 `strength/intellect/constitution/dexterity` 再 +2 对应属性 | updated.c:344-445（born_player） |
| 1.7 | 末步 `Kantele.Character.Records.save(character)` 持久化，再 `put_controller(CommandController)`；初始 `room_id = startroom`，`mud_age=0`、`age=14`、`registered=1` | `enter_world` + yanluodian.c:262-266 |
| 1.8 | 测试：unit（分配校验 sum=80/范围/per 随机区间）+ 集成（登录→洗点→选出生地→赠特技→落盘→进房） | — |

**验收**：新玩家登录后游戏内流程设性别 → `washto` 点数池（str/int/con/dex 各10–30且和=80，per/kar 随机） → `born` 选出生地+世家姓氏 → `born_player` 赠 1–3 与生俱来特技，全部落盘；初始 room = BORN_ROOM 等价；老玩家跳过问答直接进游戏；全程网页注册页零改动。

---

## 3. Phase 2 — 转世重生（对应 `updated.c` 的 `zhuan_player`）

> 难度中–高（~3–5 天）。逐项机械翻译 LPC，重点在「清记录」覆盖面。

| 步骤 | 内容 | 对应 LPC |
|---|---|---|
| 2.1 | 新增 `reborn` 触发（地藏王 `ask_zhuan` 等价）+ 执行 `zhuan_player` 等价。**前置条件须与 LPC 一致（四项齐备方可进入六道轮回→zhuan_player）**：① 大宗师（`combat_exp≥800000000` 且 `ultrap`，dizangwang.c:123-129 注释硬门槛）；② 十八层地狱 `HellZhenPass`（dizangwang.c:138）；③ 十二重天 `SkyPass`（取来精元丹，dizangwang.c:145,243）；④ 击败地藏王得 `DiZangPass`（dizangwang.c:210）。 | dizangwang.c:117-271（地府考验全流程） |
| 2.2 | 无性→男性 | updated.c:458-459 |
| 2.3 | **清记录**：按 LPC `delete` 清单逐子系统映射——`couple/sex/brothers/bunch/league/family/class/detach/betrayer/born_family/combat/animaout/breakup/can_learn/can_make/env/gift/opinion(s)/out_family/quest/map/rumor/schedule/skybook/.../DiZangPass/HellZhenPass/SkyPass/over_quest/tattoo/can_learned/mirror_task/death/can_perform/learned_literate/static/mark` | updated.c:462-527 |
| 2.4 | **设 `meta.character = "国士无双"`**（并确认 `Records.save` 已落盘该字段，Phase 0.2） | updated.c:515 |
| 2.5 | 数值重置：gongxian/score/weiwang/experience/learned_experience=0；max_neili/neili/jiali=0；max_jingli/jingli/jiajing=0；shen=0；combat_exp/learned_points/potential/magic_*=0；max_qi=100,max_jing=100；mud_age=0,age=14,birthday=time() | updated.c:530-565 |
| 2.6 | 删全部武功（`delete_skill` 全量） | updated.c:567-577 |
| 2.7 | `reborn/count += 1`、`reborn/point += 1`；随机 `reborn.{str,con,int,dex} +1`（各 50%） | updated.c:579-602 |
| 2.8 | 赠特技：1 普通技能（12 选 1，排除已拥有）+ 1 转世特技（8 选 1，按 `int`/`dex` 条件过滤，固定「神眼」），缺失特技走「钩子占位」（Phase 0.4） | updated.c:608-682 |
| 2.9 | 落盘 + 回到世界（room 重置到重生点） | `reincarnate`/`reset_action` |
| 2.10 | **解锁验证**：转世后 `meta.character="国士无双"` 应使 4 个「包含门」技能（先天功/刀剑归真/三无三不手/五斗米神功）的 `valid_learn` 放行（见 C-PVE27 文档） | — |
| 2.11 | 测试：转世全流程 + 4 包含门技能转世后变可学 | — |

**验收**：执行转世后 `character=国士无双`、数值/技能清零、`reborn/count+1`、随机属性加成、赠特技、回世界；4 包含门技能变为可学；与 LPC 清记录清单逐项一致。

---

## 4. Phase 3 — 一致性校验与回归

| 步骤 | 内容 |
|---|---|
| 3.1 | 产出「LPC 行为 vs Ex 行为」对照表（附录 B）：性别取值、属性初值、character 取值集合、birthplace、转世清记录范围、特技集合、age/HP 重置值 |
| 3.2 | 全量回归 `mix test`：确保不影响 batch1–7 的 valid_learn 成果（基线 6933/105，零新增失败） |
| 3.3 | 文档更新：两份分析文档补「已迁移」状态；`C-PVE27-valid_learn-长尾补全进度.zh-CN.md` 补「转世已落地 → 4 包含门技能已可学，真实缺口再减」；本计划移至「已完成」 |

---

## 5. 关键决策点（需用户拍板）

- **D1 属性分配**：✅ 采用 LPC 真实机制——`washto` 式点数池：`str/int/con/dex` 各 10–30、**总和必须=80**，`per`/`kar` 随机 `5+random(26)`（忠实移植，非固定 14/14/14/14/20）。`logind.c` 的 14/20 仅是转世前临时默认值，不算分配。
- **D2 转世前置条件**：✅ 一次性对接 LPC 全部前置——**大宗师 + 十八层地狱(HellZhenPass) + 十二重天(SkyPass 取精元丹) + 击败地藏王(DiZangPass)**（dizangwang.c:117-271）。不采用简化触发；机制本体与前置在同一 Phase 内完成。
- **D3 普通玩家人格**：默认**不实现**（与 LPC 一致）✅；若产品想加「自选天性」，单独立项（属新增特性，非迁移）。
- **D4 缺失特技**：转世赠「钩子占位」特技（记录意图但不实际给效果）✅；或仅赠 Ex 已实现的特技子集。

---

## 6. 风险

| 风险 | 缓解 |
|---|---|
| 转世清记录覆盖面（40+ 类，易漏） | 附录 A 清单逐条映射 + 对照表（3.1） |
| `meta.character` 持久化缺口 | Phase 0.2 先确认/补 schema migration |
| 首登/老玩家判定误伤 | `meta.env.gender == nil` 或 `setup_done` 标志；Phase 1.7 测试覆盖 |
| 与现有 valid_learn 性格门交互 | Phase 2.10 专门验证 4 包含门转世后可学 |
| 特技在 Ex 缺实现 | Phase 0.4 覆盖表 + Phase 2.8 钩子占位 |

---

## 7. 验收总标准

1. 新玩家：登录后**游戏内流程**（性别 → `washto` 点数池分配 str/int/con/dex 和=80、per/kar 随机 → `born` 选出生地+世家姓氏 → `born_player` 赠 1–3 与生俱来特技），落盘，初始 room = BORN_ROOM 等价；网页注册页未改动。
2. 转世：执行后 `character=国士无双`、数值/技能清零、`reborn/count+1`、随机属性加成、赠特技、回世界；**4 个包含门技能变为可学**。
3. 附录 B 对照表全部通过（与 LPC 行为一致）。
4. `mix test` 全量无新增失败。

---

## 附录 A — LPC 必须一致清单（Phase 0.1 产出，草稿）

- 新玩家属性分配（**非固定**）：`logind.c` 临时初值 `str=dex=con=int=14, per=20`；**真正分配 = `washto` 点数池**：`str/int/con/dex` 各 10–30、总和=80，`per`/`kar` 随机 `5+random(26)`（yanluodian.c:100-153）
- 新玩家出生地：`born` 映射选 `startroom`+`born`+`born_family`，世家（欧阳/胡/苗/段/慕容）附 `surname` 与对应 `startroom`（yanluodian.c:12-39,155-273）
- 新玩家与生俱来特技：`born_player` 从特技池随机赠 1–3 项，按 `character`（新玩家恒 nil）与属性≥20 过滤，命中 `strength/intellect/constitution/dexterity/youth/clever` 再 +2 对应属性（updated.c:344-445）
- gender 取值：`"男性"` / `"女性"`（转世：`"无性"→"男性"`）
- character 取值集合：`"阴险奸诈"|"心狠手辣"|"光明磊落"|"狡黠多变"|"国士无双"`（玩家侧恒 nil，除非转世）
- 转世前置（四项齐备）：大宗师（`combat_exp≥800000000` 且 `ultrap`） + 十八层地狱 `HellZhenPass` + 十二重天 `SkyPass`（取精元丹） + 击败地藏王 `DiZangPass`（dizangwang.c:117-271）
- 转世清记录清单：见 updated.c:462-527（40+ 项）
- 转世数值重置：`max_qi=max_jing=100`、`age=14`、各类经验/内力/精力清零
- 转世随机加成：reborn.{str,con,int,dex} 各 50% +1
- 转世特技：普通 12 选 1 + 转世 8 选 1（按 int/dex 过滤）+ 固定「神眼」
- 出生地：新玩家 → BORN_ROOM 等价（阎罗殿）

## 附录 B — LPC vs Ex 行为对照表（Phase 3.1 产出，骨架）

| 维度 | LPC 行为 | Ex 目标行为 | 一致？ |
|---|---|---|---|
| 新玩家性别 | m/f 选，存 `gender` | SetupController 问答 → `meta.env.gender` | ⬜ |
| 新玩家属性分配 | washto 池：str/int/con/dex 各10–30且和=80，per/kar随机5–30 | 同（点数池校验一致） | ⬜ |
| 新玩家出生地 | born 映射选 startroom+姓氏 | 同映射 | ⬜ |
| 新玩家与生俱来特技 | born_player 随机1–3项(按character/属性≥20过滤) | 同（缺项钩子占位） | ⬜ |
| 新玩家 birthplace | BORN_ROOM(阎罗殿) | BORN_ROOM 等价 room_id | ⬜ |
| 转世前置 | 大宗师+十八层地狱+十二重天+击败地藏王 | 同四项齐备 | ⬜ |
| 转世 character | 设「国士无双」 | 同，且持久化 | ⬜ |
| 转世清记录 | 40+ 项 delete | 同清单映射 | ⬜ |
| 转世数值重置 | HP=100/age=14/清零 | 同 | ⬜ |
| 转世属性加成 | reborn.* 随机+1 | 同 | ⬜ |
| 转世特技 | 1 普通+1 转世+神眼 | 同（缺项钩子占位） | ⬜ |
| 4 包含门技能 | 转世后可学 | 转世后可学 | ⬜ |

---

*参照：`LPC-新用户注册与转世重生机制分析.zh-CN.md`（LPC 侧）、
`EX-注册与转世迁移可行性分析.zh-CN.md`（端口架构与难度）、
`C-PVE27-valid_learn-长尾补全进度.zh-CN.md`（valid_learn 性格门口径）。*
