# C-PVE27 `valid_learn` 长尾补全 —— 进度记录

> 记录时间：2026-11-01 22:40（EST） | 分支：`kalevala` | 状态：**结案（剩 2 项卡未建模字段）**
> 本次记录涉及 batch4–batch7，**均未 commit**（铁律：未经用户明确要求不 commit/push）。
> 关联文档：`docs/待办实施计划.zh-CN.md` §C-PVE27、`docs/待办对照代码核查.zh-CN.md` F4 行、`.workbuddy-ai/memory/2026-11-01.md`。

---

## 一、战役目标

把 `lib/kantele/combat/skills/*.ex` 里「LPC 源有 `valid_learn` 而 Elixir 侧缺失/不全」的技能逐个按 LPC 保真补齐，门槛值、文案、短路顺序一律照抄源文件，不做「合理化改写」。

### 口径演进（踩过的坑）

| 阶段 | 口径 | 说明 |
|---|---|---|
| 最初 | 剩余 ~67 | 粗分类器（不区分注释态代码、不区分 `stats` 派生门 vs `character`-only 门） |
| 试点后重算 | **56** | 三类各挑 2–3 个对照 LPC 源试点，推翻原口径 |
| refine 分类器 | **41** | 权威 HIDDEN_A2 = 31（含 batch4 的 6 个）、HIDDEN_A1 = 0、DOOR_MISMATCH = 10 |
| batch6 后 | 21 | 全部卡在 `personality` / `guilty` / `query_condition` 未建模字段 |
| **batch7 后（当前）** | **2** | 性格门全部清空，仅剩 2 个其他未建模字段 |

**教训**：LPC 里被 `/* */` 注释掉的 `query("character")` 门（如 `jinshe-jian.c`）**不是缺口**，分类器必须去块注释；`query_skill("X", 1)`（2 参，raw）与 `query_skill("X")`（1 参，effective）映射到不同的 `Stats` 访问器，不能混。

---

## 二、批次总表

| 批次 | 技能数 | 内容 | 测试 | 提交状态 |
|---|---|---|---|---|
| batch1 | 2 | `linji-zhuang` / `longxiang-gong`（arity-2 `character`/`vitals` 门） | 11/0 | ✅ `7a609e9c` |
| batch2+3 | 16 | 12 个 arity-1 + 4 个 arity-2 | 54/0 | ✅ `4534d108`（已 push） |
| batch4 | 12 | 6 HIDDEN_A1（`Stats.query_*`/`Stats.skill`）+ 6 HIDDEN_A2（`max_neili_of/1` + 持械判定） | 22/0 | ❌ 未 commit |
| batch5 | 16 | 10 武器门 + 6 仅 vitals/skill 门 | 90/0 | ❌ 未 commit |
| batch6 | 2 | `dugu-jiujian`（mark + con<36 + dex<36）、`jiuyang-shengong`（mark + sword/blade<lvl） | 5/0 | ❌ 未 commit |
| **batch7** | **19** | **personality 建模后回填全部性格门** | **76/0** | ❌ 未 commit |
| **合计** | **67** | | — | |

**batch6 的有意 omission（非缺口）**：`qingyun-bian`（须持鞭）、`tiangang-zhi`（须空手）。本仓既有约定——兵器**存在性**门由 practice 流程把关，不写入 `valid_learn`（依据：`qingyun_bian.ex` moduledoc「未建模」段、`bagua_dao.ex:11,146` 同款、`skills_whitelist_batch5_test.exs` 4 例锁定该行为）。初版曾误补，导致 4 例回归，已回退。

---

## 三、batch7 先决：personality 建模决策（已定案）

### 3.1 规范字段 = `meta.character`

三条硬证据：

1. **`lib/kantele/character.ex:12`**（`PlayerMeta` moduledoc）：
   > `character` 人格/天性（LPC `query("character")`，如 "光明磊落"；poison.c valid_learn 门槛；运行态，不落盘）
2. **参考实现 `lib/kantele/combat/skills/poison.ex:36`**：`character.meta.character == "光明磊落"`
3. **`lib/kantele/character/commands/learn_command.ex:32`** 早已把 `conn.character.meta.character` 作为 `student_character` 下发给 `valid_learn/2`，注释即「读人格门（如 poison.c "光明磊落"）」

### 3.2 顺带修掉的真 bug

批前 **30 个 `skills/*.ex` + 2 个 `performs/*.ex`** 写的是 `Map.get(meta, :personality)` —— 该键名**根本不存在**，所以 `personality_of/1` 恒返回 `nil`，**这些性格门从未生效过**。

- 修法：字节保真批量替换为 `Map.get(meta, :character)`（脚本 `newline=""` 保 CRLF），共 **32 文件**。
- 核验：0 处残留 `:personality` 键读；34 文件读 `:character`；`mix compile` exit 0。
- **不要动** `Combat.@applies_keys` 里的 `:personality` —— 那是另一个概念（人格魅力/镶嵌属性，对应 LPC `enchased.c`），与本决策无关。

### 3.3 nil 语义（关键判断）

LPC 全库 `set("character", …)` 只有两处：

| 位置 | 值 | 场景 |
|---|---|---|
| `d/register/npc/{hua,li,lu,wei}.c` | 阴险奸诈 / 心狠手辣 / 光明磊落 / 狡黠多变 | NPC 注册 |
| `adm/daemons/updated.c:515` | 国士无双 | **转世** |

玩家侧从未设置 → `nil` ≡ LPC 的 `0`：

- **排除门**（`character == X` 则拒）：`nil` **不拦**（`lonely-sword`、`xixing-dafa`、`poison` 等）
- **包含门**（`character != X && != Y` 则拒）：`nil` **拦**（`xiantian-gong`、`daojian-guizhen`、`sanwu-shou`、`wudoumi-shengong`）→ 这 4 个实为**转世专属**，与 LPC 设计一致

### 3.4 顺带修掉的管线缺口：`marks` 未下发

`skills/learn` 事件此前只下发 `vitals` / `env` / `spouse` / `combat.equipped` / `character`，**没下发 `marks`**，导致 5 个技能的 `Skill.mark?/2` 门（`dugu-jiujian`、`jiuyang-shengong`、`taixuan-gong`、`xixing-dafa`、`wudoumi-shengong`）是**死代码**。

- `learn_command.ex`：新增 `student_marks: conn.character.meta.marks`
- `skills_event.ex`：`student_character.meta` 里新增 `marks: student_marks || %{}`

---

## 四、batch7 明细（19 个性格门）

### 4.1 14 个降龙十八掌子招

源 `valid_learn` **完全同构**（仅自身 id 不同），用参数化生成器 `/c/tmp/gen_batch7_xianglong.py` 一次注入。

`diyang-chufan` / `feilong-zaitian` / `huoyue-zaiyuan` / `jianlong-zaitian` / `kanglong-youhui` / `lishe-dachuan` / `longzhan-yuye` / `lvshuang-bingzhi` / `miyun-buyu` / `shicheng-liulong` / `shuanglong-qushui` / `sunze-youfu` / `turu-qilai` / `yuyue-yuyuan`

门槛顺序（照抄源）：

| # | 条件 | 文案 |
|---|---|---|
| 1 | `Stats.skill("xianglong-zhang") > 0` | 你已经学全十八掌了，不必再单独学习。 |
| 2 | 性格 `阴险奸诈` | 你心中暗想：这武功难练得紧，学它做甚？ |
| 3 | `Stats.query_str < 36` | 你的先天膂力孱弱，难以修炼降龙十八掌。 |
| 4 | `Stats.query_con < 32` | 你的先天根骨孱弱，难以修炼降龙十八掌。 |
| 5 | `Stats.effective("force") < 300` | 你的内功火候不够，难以修炼降龙十八掌。 |
| 6 | `max_neili < 3000` | 你的内力修为不足，难以修炼降龙十八掌。 |
| 7 | `Stats.skill("strike") < 180` | 你的基本掌法火候不够，难以修炼降龙十八掌。 |
| 8 | `strike < 自身等级` | 你的基本掌法水平有限，无法领会更高深的降龙十八掌。 |

### 4.2 其余 5 个

| 技能 | 迁移内容 | 备注 |
|---|---|---|
| `lonely-sword` | `query_int`<34 → 心狠手辣 / 阴险奸诈 / 光明磊落 → `sword < 自身` | 首门「须持剑」按约定**不写入**（moduledoc 已注明） |
| `daojian-guizhen` | 性格须「光明磊落」∨「国士无双」作**首门** | 原 moduledoc 写「未建模、未迁移」，已改 |
| `sanwu-shou` | 性格须「心狠手辣」∨「国士无双」作**首门**（先于持鞭门） | 同上 |
| `xixing-dafa` | 性格「光明磊落」则拒作**首门** | 同上 |
| `wudoumi-shengong` | 补末门 `can_perform/wudoumi-shengong/gui` mark + `unarmed < 自身` | 依赖 3.4 的 marks 管线 |

### 4.3 覆盖率复核

脚本（去行注释 + 去块注释后扫 LPC `valid_learn` 体）：

> 全库 **49** 个技能带有效性格门，**49/49 已迁移**（30 个原有但被键名 bug 废掉 + 本批 19 个回填）
>
> 唯一「未迁移」命中 `jinshe-jian` 是误报——其 LPC 性格门在 `/* */` 注释里。

---

## 五、测试与回归

| 项目 | 结果 |
|---|---|
| 新增 `test/kantele/combat/skills_valid_learn_batch7_test.exs` | **32 例 / 12 个 describe** |
| 改动既有测试 | `skills_daojian_guizhen_test.exs`（17 例）、`skills_sanwu_shou_test.exs`（13 例）、`skills_xixing_dafa_test.exs`（14 例） |
| 4 文件合跑 | **76 tests / 0 failures** |
| 全量 `mix test` | **6933 tests / 105 failures** |
| batch6 基线 | 6890 tests / 115 failures |
| 增量 | +43 测试（本批新增 42）、失败数 115 → 105 |
| 新增失败 | **0** |

**105 例既有失败的原因抽检**（均与本批无关）：

1. `Kantele.Combat.Skills.ForceRegenerate` 模块缺失 → `LearnTimesTest`、`SkillsValidLearnBatch2Test`、`PerformExertTest` 等
2. 测试传裸 map 而 `Stats.query_*` 只接受 `%Stats{}` 结构体 → `SkillsSouguTest`、`SkillsPhantomForceTest`（xiantian-gong）等
3. 期望与实现不符（`chongling-jian` 空手期望被拦，实现只拦「错械」）

### 测试写法踩坑

- `stats/1` 复用 batch6 的分流：派生属性（str/int/dex/con/per）进 struct 字段，其余进 `:skills`，**未给出的技能 = 0**（不是 `Stats.new()` 的默认值）
- 测 `query_str` 门必须让拳脚技能为 **0**（否则 `max(拳脚)/10` 加成会顶过 36）
- 测 `query_con` 门必须让 `force` 为 **0**（否则 `force/10` 加成会顶过 32）
- `defp char(opts \\ [])` —— 漏默认值会导致无参调用编译报 `undefined function char/0`

---

## 六、剩余缺口与后续

### 6.1 剩余 2 项（卡未建模字段，非可独立编码）

| 技能 | 卡点 |
|---|---|
| `hunyuan-yiqi` | LPC `query("guilty")` 未建模 |
| `qiankun-danuoyi` | LPC `query_condition()` 未建模 |

### 6.2 若要放开 4 个「包含门」技能

`xiantian-gong` / `daojian-guizhen` / `sanwu-shou` / `wudoumi-shengong` 当前对全体玩家不可学（`meta.character` = nil → 包含门拒）。这是 LPC 原设计（转世专属），但要真正可玩需两步：

1. 实现**玩家侧人格赋值入口**（LPC 对应 `adm/daemons/updated.c:515` 转世设「国士无双」）
2. 让 `meta.character` **落盘**（当前 moduledoc 标注「运行态，不落盘」）

### 6.3 结论

> **C-PVE27 `valid_learn` 长尾补全结案。** 可建模门槛已全部 LPC 保真迁移；余项均依赖尚未建模的字段或尚未实现的转世系统。
