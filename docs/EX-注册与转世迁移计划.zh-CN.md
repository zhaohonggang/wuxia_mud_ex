# LPC 注册/转世系统迁移到 ExVenture(Kantele) 实施计划

> 目标：**与 LPC 行为越一致越好**（faithful port，不擅自改进/新增 LPC 没有的能力）。
> 前置文档：
> - [`LPC-新用户注册与转世重生机制分析.zh-CN.md`](./LPC-新用户注册与转世重生机制分析.zh-CN.md)（LPC 侧行为基线 + 行号索引）
> - [`EX-注册与转世迁移可行性分析.zh-CN.md`](./EX-注册与转世迁移可行性分析.zh-CN.md)（端口架构 + 难度评估）
> - [`C-PVE27-valid_learn-长尾补全进度.zh-CN.md`](./C-PVE27-valid_learn-长尾补全进度.zh-CN.md)（性格门口径；4 个「包含门」技能与转世强相关）
>
> 系统范围 = **新用户注册** + **转世重生**，含其中 **性格/人格(character)、性别(gender)、属性(str/dex/con/int/per/kar)、出生地(startroom)** 的赋值，**以及承载这些字段的数据库 schema 与数据类型（`Stats` / `PlayerMeta` / `character_metadata`）改动——详见 Phase 0.2 与附录 A「Ex 数据层改动」。**

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
| 0.2 | **数据层改动（DB schema + 数据类型 + 持久化）**：按「数据层改动清单」（下表）落地 migration 与代码。**这是本计划最关键的底层改动**——当前 `PlayerMeta.env` 与 `PlayerMeta.character` 在代码里被标注「运行态，不落盘」，而 LPC 的 gender/born/surname/registered/age/reborn 计数/地府三关标记全部活在 `set()`（即 Ex 的 `meta.env`）里；`Stats` 也缺 `per`/`kar` 字段。若不补持久化，新玩家洗点/投胎/转世结果会在重登后丢失。 | 数据层改动清单 + Ecto migration + `Records.save/apply` 补写 |
| 0.3 | 房间映射 + **出生点持久化**（与 LPC 玩家体验对齐）：将 LPC `BORN_ROOM`/`REGISTER_ROOM`/`START_ROOM` 对应到 Ex 世界具体 room_id。**关键缺口**：当前 `build_character` 对所有登录强制 `room_id = Kantele.World.start_room_id()`（login_controller.ex:158,163），玩家当前房**完全不持久化**，重登恒回全局起始房。需三处改造：① **新玩家进入阎罗殿**：`process_character` 中若 `meta.env[:setup_done] != true`，将 `character.room_id` 设为 BORN_ROOM 等价点（阎罗殿），使 `washto`/`born` 问答物理上发生在阎罗殿（与 LPC 一致）；② **投胎落地+持久化**：`born` 末步将 `character.room_id` 置为选定 `startroom` 并写 `meta.env[:startroom]`（落盘于 `env` 列）；③ **重登回出生地**：返回玩家改用 `env.startroom` 而非全局 `start_room_id()`。注：`spawn_room_id` 字段**仅 NPCConfig 有**（character.ex:399-412），玩家侧不可用。 | 房间常量映射表 + 出生点持久化改造点 |
| 0.4 | 特技存在性核对：列出 LPC `special_skill/*` 12 普通 + 8 转世在 Ex 是否已有实现；缺失项标注为「钩子占位」 | 特技覆盖表 |

#### 0.2.1 数据层改动清单（必须随 Phase 1 前落地）

| 层 | 文件 | 具体改动 |
|---|---|---|
| 数据类型 | `lib/kantele/character/stats.ex` | `defstruct` 增加 `:per`、`:kar`；`@derive {Jason.Encoder, only: [...]}` 增加 `:per`、`:kar`（否则不进房间副本/客户端 JSON）；`new()` 给 `per: 20, kar: 0` 占位（实际由 washto 覆写） |
| 数据类型 | `lib/kantele/character/stats.ex` | `query_per/3` 现有 `Map.get(stats, :per) || 20` 在字段存在后即生效；如需 `kar` 查询则新增 `query_kar/1`（默认 0） |
| 持久化·写 | `lib/kantele/character/records.ex` `save/1` | 存档 map 增加 `per: meta.stats.per`、`kar: meta.stats.kar`、`env: meta.env`、`character: meta.character`；并补写 `gender: meta.env[:gender]`（现有 `gender` 列当前 save 未写，属既有缺口） |
| 持久化·读 | `lib/kantele/character/records.ex` `apply_to_character` | 重建 `Stats` 时补 `per`/`kar`；`meta` 整表恢复 `env`（不再只用 `Map.put_new(:gender, ...)`，改为 `Map.merge` 存档 env，并以 `metadata.gender` 兜底缺省）；补 `character: metadata.character` |
| DB schema | `lib/kantele/character/records.ex` `ExVenture.Characters.Metadata` | `schema` 增列 `field(:env, :map, default: %{})`、`field(:character, :string)`、`field(:per, :integer, default: 20)`、`field(:kar, :integer, default: 0)`；`changeset` 的 `cast` 列表同步增加 `:env, :character, :per, :kar` |
| DB migration | `priv/repo/migrations/*_add_registration_fields.exs` | `alter table(:character_metadata) do add :env, :map, default: %{}; add :character, :string; add :per, :integer, default: 20; add :kar, :integer, default: 0 end` |
| 出生点 | `Kantele.Character` 结构 / `records` | `born` 落点写入 `character.room_id` 并持久化于 `meta.env.startroom`（已落盘）；改 `process_character` 使重登回到 `startroom` 而非全局 `start_room_id()`；注：`spawn_room_id` 仅 NPCConfig 有，玩家不可用 |

> ⚠️ 注意：`meta.env` 是 LPC `set()` 属性的统一仓库。落盘 `env` 一列即一次性解决 gender / born / born_family / surname / registered / age / mud_age / reborn 计数 / `DiZangPass`·`HellZhenPass`·`SkyPass` 三关标记的持久化，远优于逐字段加列。

**验收**：基线清单 + 房间映射 + 特技覆盖表 + **数据层改动清单（migration 通过、`Records.save/apply` 已落盘 env/character/per/kar、重启后属性与出生地不丢失）** 全部就绪。

---

## 2. Phase 1 — 新玩家游戏内问答（对应 `logind.c` 注册流程）

> 难度低–中（~1–2 天）。**完全不碰网页注册页**（账号层本就与角色无关）。

| 步骤 | 内容 | 对应 LPC |
|---|---|---|
| 1.1 | 新增 `SetupController`（或就地扩展 `LoginController`） | `get_gender`/`make_body` |
| 1.2 | 首登判定：用 `meta.env[:setup_done] != true`（或 `meta.env.gender == nil`）区分新/老玩家；判定本身也写入 `meta.env[:setup_done]` | 无直接对应（LPC 每次注册即新角色） |
| 1.3 | 问答①性别：`prompt` m/f → 写 `meta.env[:gender]`（"男性"/"女性"） | logind.c:672-674,703 |
| 1.4 | 问答②属性分配（**核心，须与 LPC 一致**）：在 BORN_ROOM（阎罗殿等价）以 `washto` 等价交互分配 `str/int/con/dex`，**各 10–30、总和必须 =80**；`per` 与 `kar` 随机 `5+random(26)`；校验不通过则要求重输。写入 `meta.stats.str/int/con/dex` 与随机 `meta.stats.per`/`meta.stats.kar`，并置 `meta.env[:washed]=true` | yanluodian.c:100-153（washto） |
| 1.5 | 问答③出生地：以 `born <地名>` 等价交互，从 LPC `born` 映射选 `startroom`/`born`/`born_family`；世家（欧阳/胡/苗/段/慕容）附 `surname`。写入 `meta.env[:born]`/`[:born_family]`/`[:surname]`/`[:registered]=true`/`[:startroom]=选定room_id`（落盘于 `env` 列），并直接置 `character.room_id = 选定 startroom`（玩家无 `spawn_room_id` 字段，见 0.3） | yanluodian.c:155-273（born） |
| 1.6 | **与生俱来特技**：非转世者调用 `born_player` 等价逻辑，按 `meta.character`（此时恒 nil）与属性≥20 过滤，从 Ex 特技池随机赠 1–3 项（缺失项走钩子占位，见 D4）；命中 `strength/intellect/constitution/dexterity` 再 +2 对应属性（写回 `meta.stats`） | updated.c:344-445（born_player） |
| 1.7 | 末步 `Kantele.Character.Records.save(character)` 持久化（经 Phase 0.2 改动，`env`/`character`/`per`/`kar` 一并落盘，含 `env.startroom`），再 `put_controller(CommandController)`；`character.room_id` 已在 1.5 置为选定 startroom（首次落地即该房），`mud_age=0`、`age=14` | `enter_world` + yanluodian.c:262-266 |
| 1.8 | 测试：unit（分配校验 sum=80/范围/per 随机区间）+ 集成（登录→洗点→选出生地→赠特技→落盘→进房） | — |

**验收**：新玩家登录后游戏内流程设性别 → `washto` 点数池（str/int/con/dex 各10–30且和=80，per/kar 随机） → `born` 选出生地+世家姓氏 → `born_player` 赠 1–3 与生俱来特技，全部落盘；初始 room = BORN_ROOM 等价；老玩家跳过问答直接进游戏；全程网页注册页零改动。

---

## 3. Phase 2 — 转世重生（对应 `updated.c` 的 `zhuan_player`）

> 难度中–高（~3–5 天）。逐项机械翻译 LPC，重点在「清记录」覆盖面。

| 步骤 | 内容 | 对应 LPC |
|---|---|---|
| 2.1 | 新增 `reborn` 触发（地藏王 `ask_zhuan` 等价）+ 执行 `zhuan_player` 等价。**前置条件须与 LPC 一致（四项齐备方可进入六道轮回→zhuan_player）**，判定全部走 `meta.env`：① 大宗师 = 需**新定义** `ultrap` 判定（Ex 暂无此概念；按 `combat_exp≥800000000` + 境界/title 标志实现，dizangwang.c:123-129）；② 十八层地狱 `meta.env[:HellZhenPass]`（dizangwang.c:138）；③ 十二重天 `meta.env[:SkyPass]`（取来精元丹，dizangwang.c:145,243）；④ 击败地藏王置 `meta.env[:DiZangPass]=1`（dizangwang.c:210）。 | dizangwang.c:117-271（地府考验全流程） |
| 2.2 | 无性→男性（写 `meta.env[:gender]="男性"`；Ex 性别存 `meta.env`，与 1.3 同源） | updated.c:458-459 |
| 2.3 | **清记录**：按 LPC `delete` 清单逐子系统映射（含 `meta.env` 中的 `DiZangPass`/`HellZhenPass`/`SkyPass`/`over_quest`/`tattoo`/`mark`/`can_learn`/`can_perform`/`learned_literate`/`static` 等键），以及 `meta.family`/`league`/`brothers`/`spouse`/`quest`/`bag`/`marks`/`schedule` 等存档字段 | updated.c:462-527 |
| 2.4 | **设 `meta.character = "国士无双"`**（经 Phase 0.2 的 `character` 列落盘，重登后不丢失） | updated.c:515 |
| 2.5 | 数值重置：gongxian/score/weiwang/experience/learned_experience=0；max_neili/neili/jiali=0；max_jingli/jingli/jiajing=0；shen=0；combat_exp/learned_points/potential/magic_*=0；max_qi=100,max_jing=100；`meta.env[:mud_age]=0`、`meta.env[:age]=14`、`birthday=time()` | updated.c:530-565 |
| 2.6 | 删全部武功（`delete_skill` 全量） | updated.c:567-577 |
| 2.7 | `meta.env[:reborn_count] += 1`、`meta.env[:reborn_point] += 1`；随机 `meta.stats.reborn.{str,con,int,dex} +1`（各 50%，写回 `Stats.reborn` map，已参与 `query_str/int/con/dex` 派生） | updated.c:579-602 |
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
- **D2 转世前置条件**：✅ 一次性对接 LPC 全部前置——**大宗师 + 十八层地狱(HellZhenPass) + 十二重天(SkyPass 取精元丹) + 击败地藏王(DiZangPass)**（dizangwang.c:117-271）。不采用简化触发；机制本体与前置在同一 Phase 内完成。**注意**：Ex 暂无 `ultrap`/「大宗师」概念，须在 Phase 2.1 先定义其判定（`combat_exp≥800M` + 境界/title 标志，存 `meta.env` 或单独标志），再接四前置。
- **D3 普通玩家人格**：默认**不实现**（与 LPC 一致）✅；若产品想加「自选天性」，单独立项（属新增特性，非迁移）。
- **D4 缺失特技**：转世赠「钩子占位」特技（记录意图但不实际给效果）✅；或仅赠 Ex 已实现的特技子集。

---

## 6. 风险

| 风险 | 缓解 |
|---|---|
| **`meta.env` / `meta.character` 当前「不落盘」（致命缺口）** | Phase 0.2 + 0.2.1 已并入 `env`/`character` 列迁移与 `Records.save/apply` 补写；迁移前先用「重启后属性/出生地不丢失」集成测试锁死 |
| `Stats` 缺 `per`/`kar` 字段导致洗点结果无法落盘/下发 | Phase 0.2.1：`stats.ex` 补 `:per`/`:kar` + Jason 编码 + `save/apply` 补写 + DB 加列 |
| 转世清记录覆盖面（40+ 类，易漏） | 附录 A 清单逐条映射 + 对照表（3.1） |
| **LPC `ultrap`(大宗师) 在 Ex 无对应概念** | Phase 2.1 先定义「大宗师」判定（`combat_exp≥800M` + 境界/title 标志，存 `meta.env` 或单独标志），再接四前置 |
| 出生点/`spawn_room_id` 落盘与重登回出生地 | Phase 0.3 确认并写入 `spawn_room_id`，验证房间 state 持久化 |
| 首登/老玩家判定误伤 | `meta.env[:setup_done] != true` 判定；Phase 1.7 测试覆盖 |
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
- **Ex 数据层改动（实现前提，否则重登即丢）**：① `Stats` 增 `per`/`kar` 字段并纳入 `@derive Jason.Encoder`；② `character_metadata` 增 `env`(map)/`character`(string)/`per`/`kar` 四列；③ `Records.save/1` 补写 `env`/`character`/`per`/`kar`，`apply_to_character` 补恢复；④ `born` 落点写入 `spawn_room_id`（出生/复活点）。当前 `meta.env` 与 `meta.character` 在代码里标注「不落盘」，是最大缺口。
- **Ex 需新定义 `ultrap`(大宗师) 判定**：LPC 无直接对应概念；按 `combat_exp≥800000000` + 境界/title 标志实现，结果存 `meta.env`（如 `meta.env[:ultrap]`）供 `reborn` 前置读取。
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
| 属性 per/kar 落盘 | `per`/`kar` 随 dbase 落盘 | `Stats.per`/`Stats.kar` + DB `per`/`kar` 列 + `save/apply` 补写 | ⬜ |
| `meta.env` 持久化 | 全部 `set()` 属性（gender/born/surname/registered/age/reborn 计数/三关标记）随 dbase 落盘 | `env`(map) 列 + `save/apply` 整表落盘 | ⬜ |
| `meta.character` 持久化 | 国士无双随 dbase 落盘 | `character`(string) 列 + `save/apply` 落盘 | ⬜ |
| 出生点 | `startroom` 落为登录/复活点 | 选出生地置 `character.room_id`，持久化于 `meta.env.startroom`；改 `process_character` 重登回 `startroom` 而非全局 `start_room_id()`（`spawn_room_id` 仅 NPC 有，玩家不可用） | ⬜ |
| 大宗师(ultrap) | LPC 境界判定(combat_exp≥800M 且 ultrap) | Ex 需新定义（combat_exp 阈值 + 境界/title 标志） | ⬜ |
| 转世前置 | 大宗师+十八层地狱+十二重天+击败地藏王 | 同四项齐备（均经 `meta.env` 读取/写入） | ⬜ |
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
