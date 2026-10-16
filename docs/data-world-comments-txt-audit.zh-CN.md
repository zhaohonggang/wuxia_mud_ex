# `data/world/*.comments.txt` 盘点与续做分析

> 生成日期：2026-10-16。基线：`data/world`（72 个 `.comments.txt`）+ `C:\files\git\mud\d`（6976 个 `.c`）。
> 复现脚本：`scripts/analyze_comments_txt.py`、`scripts/audit_ucl_key_loss.py`（输出到 `tmp/`）。
> 所有数字为实测，不是估算。

---

## 0. 结论速览

**用户的判断基本成立，但有三点需要修正：**

| 判断 | 核实结果 |
|------|----------|
| `.comments.txt` 里是「从 `.c` 里还没转换的内容」 | ✅ **成立**，但**混了大量噪声**：35748 条 `#` 行里只有 **11247 条（31.5%）** 是真正的未转换内容，其余是区块溯源标注 |
| 这些内容尚未被处理 | ✅ **成立**，且比现有文档记录的严重得多 |
| 现有文档已经覆盖了这件事 | ❌ **不成立**：`docs/ucl-comment-implementation-plan.zh-CN.md` 的「14483 条注释」**只统计 `.ucl` 内部**，`data-world-converted-ucl-comments.zh-CN.md` §8 更直接断言「mud/d 转换区没有 UNHANDLED 标记」——该断言**只对 `.ucl` 成立**，对 sidecar 完全错误 |
| sidecar 足以指导续做 | ❌ **不成立**：**83.2% 的分支行只有条件、没有 body**；且 `create()` 的 `if/else` 分支里有 **228 个 `set()` key 在任何 `.ucl` 中查无痕迹** |

一句话：**sidecar 是一份「索引」，不是「规格」。** 它告诉你「哪里缺东西」，但不告诉你「缺的东西长什么样」——后者必须回 `C:\files\git\mud` LPC 源（AGENTS.md 指定的权威）。

---

## 1. 核实：`.comments.txt` 到底是什么

### 1.1 生成链路

`scripts/lpc_converter.py` → `_generate_ucl/4`（L3426）→ `comments_content`。只有**三类**内容会写进 sidecar：

```python
# lpc_converter.py L3459-3469
comments_content = ""
if include_comments:
    generic_marker = []                                   # ① generic 文件标记
    if obj_type == "generic":
        generic_marker = [f"# Generic LPC file: {ast.source_path}", "# Requires manual conversion"]
    inherit_parts  = [inherit_comments]  ...              # ② 未能解析的 inherit
    unhandled_text = _generate_unhandled_comments(...)    # ③ UNHANDLED 兜底桶
    extra = "\n\n".join([...])
    if extra != "":
        comments_content = header + extra + "\n"          # header 就是 "# Generated from ..."
```

`_generate_unhandled_comments/1`（L3221）把 `ast.unhandled` 的九个桶渲染成文本：

| 桶 | sidecar 段名 |
|---|---|
| `functions` | `# ==== UNHANDLED FUNCTIONS ====` |
| `globals` | `# ==== UNHANDLED GLOBAL VARIABLES ====` |
| `complex_mappings` | `# ==== COMPLEX MAPPINGS ====` |
| `switch_tables` / `switch_pools` / `switch_statements` | `# ==== SWITCH TABLES / POOLS / STATEMENTS ====` |
| `conditional_branches` | `# ==== CONDITIONAL BRANCHES (<函数名>) ====` |
| `complex_conditionals` | `# ==== COMPLEX CONDITIONALS ====`（`# COMPLEX IF: ...`，保留完整源码） |
| `raw_code_blocks` | `# ==== RAW CODE BLOCKS ====`（`# RAW BLOCK: ...`，保留完整源码） |

### 1.2 两个必须知道的坑

1. **段头在内容之后。** `body = "\n".join(reversed(flat))`（L3299）把整段倒序输出，所以
   `# ==== CONDITIONAL BRANCHES (valid_leave) ====` 出现在**它那几行条件之后**。写解析器时必须
   「先攒行、遇段头再归属」，否则会把条件算到错误的函数上。
2. **sidecar 不进运行时。** `Kantele.World.Loader` 只读 `.ucl`（`loader.ex` L85：
   `load_folder(&1, ".ucl", merge)`）。sidecar 是纯人读的旁路文件，删掉不影响游戏 —— 但也因此
   **删掉就永久丢失唯一的索引**。

---

## 2. 实测规模

### 2.1 总量

```
文件数                : 72 个（data/world）；另有 data/world_backup/test.comments.txt
空文件                : 2 个（special、xuanminggu —— 无任何未转换内容）
含 payload 的区       : 69 / 72
'#' 行总数            : 35748
  ├─ 溯源/结构噪声    : ~24501（68.5%）
  └─ 真实未转换内容    : 11247（31.5%）
```

### 2.2 分类明细（全库，含 test 区）

| 类别 | 条数 | 说明 |
|------|-----:|------|
| `if/else → action` 条件分支行 | **8525** | 主体。其中 **7096（83.2%）只有条件、action 为空** |
| `# UNHANDLED FUNCTION: <名>` | **2136** | **643 个不同函数名** |
| `# COMPLEX IF: ...` | 135 | 保留完整 LPC 源码 ✅ |
| `# SWITCH POOL:` | 132 | 保留完整源码 ✅ |
| `# SWITCH: ...` | 27 | 保留完整源码 ✅ |
| `# SWITCH TABLE (expr:)` + 行 | 5 + 89 | 结构化表格 ✅ |
| `# RAW BLOCK:` | 38 | 保留完整源码 ✅ |
| `# COMPLEX MAPPING:` | 34 | 保留完整源码 ✅ |
| `# Generic LPC file:` / `Requires manual conversion` | 126 | 120 属 test 区；**真实 3 个**：`death/heisenlin.c`、`heimuya/insert.c`、`huashan/tsr_room_dugu-jiujian.c` |
| `# inherit X;`（未解析继承） | 1202 | 多为 `F_MASTER` 等基类标记 |
| 区块溯源 `# Generated from` / `# Zone:` | 2801 + 2801 | 纯噪声 |
| 段分隔线 `# ====` / 段头 | 7767 + 2589 + … | 纯噪声 |

### 2.3 条件分支归属哪个函数（去掉 test 区，7666 条可归属）

| 函数 | 行数 | 有 action | 仅条件 |
|------|-----:|----------:|-------:|
| `create` | **2619** | 3 | 2616 |
| `valid_leave` | 472 | 62 | 410 |
| `init` | 367 | 68 | 299 |
| `greeting` | 184 | 39 | 145 |
| `do_effect` | 184 | 89 | 95 |
| `accept_object` | 167 | 107 | 60 |
| `do_move` | 164 | 47 | 117 |
| `do_think` | 148 | 13 | 135 |
| `do_jump` / `do_climb` / `do_du` / `recognize_apprentice` | 69 / 68 / 66 / 64 | | |
| `do_serve` / `do_canwu` / `do_eat` / `ask_me` / `do_break` / `do_push` / `do_open` | 62 / 61 / 56 / 51 / 49 / 48 / 46 | | |

> **关键**：`valid_leave` 只占 **6.2%**。也就是说现有文档做的 183 条「阻挡条件」，
> 覆盖的是条件分支总量的**十六分之一**。

### 2.4 函数名分类（去掉 test 区，2136 行 / 643 名）

| 类别 | 行数 | 名数 | 备注 |
|------|-----:|-----:|------|
| `do_*` 自定义动词 | 646 | 215 | 与 `lib/kantele/character/commands/`（已有 **204 个**命令模块）高度重叠 |
| 其它/一次性 | 459 | 246 | `check_trigger`、`relay_emote`、`xiqu1..7`、`create_wine/water/food`、`on_board`、`begin/working/halt_working`… |
| 战斗回调 | 259 | 12 | `accept_fight/kill/hit/ansuan`、`unconcious`、`die`、`owner_is_killed`、`fight_ob` |
| look/inquiry/描述 | 185 | 86 | `look_gaoshi`、`ask_me`、`look_duilian`… |
| 生命周期/无操作 | 130 | 7 | `setup`、`reset`、`long`、`name`、`is_container`、`is_chat_room`、`query_autoload` |
| 技能/perform | 108 | 2 | `perform`、`exert` |
| 学徒/门派 | 52 | 2 | `recognize_apprentice`、`attempt_apprentice` |
| 门/容器 | 40 | 2 | `close`、`close_passage` |
| 状态/flag | 23 | 15 | `set_*/query_*` 包装 |
| 物品/食物 | 13 | 1 | `finish_eat` |

### 2.5 逐区 payload 排行（前 20）

| 区 | payload | 源文件 | 函数名 | 条件行 |
|----|--------:|-------:|-------:|-------:|
| city | 1418 | 180 | 125 | 1036 |
| ~~test~~ | ~~1286~~ | 117 | 91 | 859 | ← 测试靶场，排除 |
| beijing | 683 | 194 | 45 | 556 |
| death | 680 | 205 | 75 | 509 |
| shaolin | 454 | 151 | 56 | 369 |
| changan | 349 | 116 | 49 | 265 |
| huashan | 346 | 57 | 66 | 250 |
| tulong | 330 | 59 | 42 | 205 |
| hengyang | 314 | 69 | 37 | 248 |
| xiakedao | 306 | 57 | 30 | 238 |
| wudu | 233 | 69 | 32 | 171 |
| mingjiao | 221 | 101 | 28 | 174 |
| jingzhou | 217 | 75 | 17 | 182 |
| wuguan | 191 | 27 | 23 | 161 |
| guanwai | 181 | 36 | 28 | 141 |
| kaifeng | 177 | 51 | 16 | 148 |
| baituo / tiezhang / xiyu / hangzhou | 159 / 157 / 148 / 138 | | | |

**payload = 0 的区**：`hengshan`（只有 10 条 `# inherit F_MASTER;`）、`special`、`xuanminggu`。

---

## 3. 需要更正的现有文档

| 文档 | 原话 | 问题 |
|------|------|------|
| `docs/data-world-converted-ucl-comments.zh-CN.md` §8 | 「除 `global.ucl` 外，mud/d 转换区**没有** `UNHANDLED FUNCTION` / `Requires manual conversion` / `Generic LPC file` 等『未转换』标记」 | **对 sidecar 完全错误**：sidecar 里有 **2136 条 `UNHANDLED FUNCTION`**、3 个真实 generic 文件。该文档开头的口径就是「统计 `data/world/*.ucl` 中…」，**从未扫过 sidecar** |
| `docs/ucl-comment-implementation-plan.zh-CN.md` §0 | 「71 个转换区共 **14483** 条注释」，三类「做」= `vendor_goods` 464 + `阻挡条件` 183 + `skipped` 96 | 这三类**全部在 `.ucl` 内部**。sidecar 的 **11247 行 payload 从未被盘点、从未进过排期** |
| `docs/ucl-comment-todo.zh-CN.md` §10 | 「`skipped` 注释：299 → 7」「`vendor_goods` 注释：清零」 | 同样是 `.ucl` 口径。容易让人误以为「注释都清完了」 |

> **建议**：在三份文档顶部各加一句范围声明，并把本文作为 sidecar 的唯一入口，
> 避免「第二份真相源」问题（该仓库已经因为重复真相源踩过坑，见 `ucl-conversion-todo.zh-CN.md` 开头）。

---

## 4. 更严重的发现：sidecar 本身也记不全

### 4.1 `create()` 的 `if/else` 分支把非标准字段丢了

以 `d/item/obj/butian.c`（补天石）为例，源码：

```c
void create()
{
    set_name(HIM "补天石" NOR, ({"magic stone", "butian shi", "shi"}));
    set_weight(6000);
    if (clonep())
        set_default_object(__FILE__);
    else {
        set("long", "传说这是女娲补天剩下的五彩石，不知是真是假。\n");
        set("unit", "块");
        set("value", 10000);
        set("item_origin", 1);            // ← 丢
        set("material_attrib", "magic stone");  // ← 丢
        set("material_name", HIM "神铁" NOR);   // ← 丢
        set("can_make", "all");           // ← 丢
        set("not_make", ({ "战衣", "腰带" }));   // ← 丢
        set("power_point", 100);          // ← 丢
    }
}
```

`data/world/item.ucl` 里只有 `name/aliases/description/value/weight/unit`；
`item_origin`、`material_attrib`、`material_name`、`can_make`、`not_make`、`power_point`
**在整份 `item.ucl` 里查无痕迹**。而 sidecar 里对这个文件只留下两行：

```
  # else  →  
  # if (clonep())  →  
# ==== CONDITIONAL BRANCHES (create) ====
```

**action 是空的** —— 因为 `_BRANCH_ACTION`（L94）只匹配
`command|say|tell_object|message_vision|write`，`set(...)` 调用不在其中。
所以 `create` 名下那 **2619 行**分支里，绝大多数**既没进 `.ucl`，也没在 sidecar 里留下 body**。

### 4.2 全库 `set()` key 对账：202 个 key 真正丢失

> **口径修正（2026-10-16）**：本节初版用「字面子串」判定存在性，得到 228 个。
> 但部分 key 只是**换了 UCL 字段名**（`chat_msg` → `chats`）或**在 Elixir 里实现**。
> 经 `scripts/triage_lost_keys.py` 三分类后，真正无归属的是
> **202 个 distinct / 3150 次**（A 别名 1 个 / B 引擎已有 40 个 / C 真丢失 202 个）。下文以此为准。

`scripts/audit_ucl_key_loss.py` 扫 6976 个 `.c` 的 `set("key"`，与全部 `.ucl` 做
「别名感知」的存在性对账（`exits→room_exits`、`objects→characters` 等）：

```
corpus .c 文件        : 6976
distinct set() key    : 433
在任何 .ucl 无痕迹    : 228 个 distinct / 4565 次   ← 字面子串口径（偏保守）
经三分类后真正丢失    : 202 个 distinct / 3150 次   ← scripts/triage_lost_keys.py
```

**真·无操作**（可安全登记免除）：

| key | 次数 | 说明 |
|-----|-----:|------|
| `no_clean_up` | 1805 | 房间重置提示，引擎生命周期已覆盖 |
| `valid_startroom` | 68 | 出生点校验 |
| `no_map` / `no_shown` / `no_user` | 6 / 4 / 4 | 显示开关 |

**真·内容丢失**（必须补）：

| key | 次数 | 影响 |
|-----|-----:|------|
| `wield_msg` / `unwield_msg` / `wear_msg` / `remove_msg` / `unequip_msg` | 295/217/89/63/37 | **装备/卸下文案全丢** |
| `chat_msg` / `chat_msg_combat` / `chat_chance_combat` | 146/132/129 | NPC 闲聊与战斗喊话 |
| `sleep_room` / `no_sleep_room` | 127/90 | 客栈/禁睡房 flag |
| `max_liquid` / `liquid` / `base_unit` / `base_value` | 74/74/72/69 | 容器/酒水系统 |
| `armor_prop/personality` | 69 | 防具属性 |
| `female_only` / `no_steal` / `no_beg` / `no_get_from` | 60/55/39/14 | 权限 flag |
| `eff_qi` / `eff_jing` | 37/19 | 有效气血/精神 |
| `can_make` / `not_make` / `power_point` / `item_origin` | 16/8/20/16 | **打造系统** |
| `room_owner` / `room_name` / `room_position` / `room_owner_id` | 29/29/29/24 | 玩家自建房 |
| `for_family` / `coagents` / `hellzhen` / `jiaji` | 35/30/18/21 | 门派/特殊玩法 |

> **结论**：现有文档「已完成」清单里的
> `P0b 补建缺失物品`、`转换区物品 meta 回填（685 个物品）`（`c7c5fd9`）确实做了不少，
> 但**没有做 key 级对账**，所以这批字段一直没人发现。这是**纯数据、零运行时风险**的一块。

---

## 5. 如何继续：分层路线

### 步骤 0（前置，一次性）—— 把 sidecar 变成机器可读清单

**问题**：sidecar 是纯文本，没有 id、没有去重、没有优先级、没有源文件行号，**无法排期、无法验收、无法防回归**。

**做法**：转换器的 `ast.unhandled` **本来就是结构化 dict**。加一个只读的 manifest 导出
（新脚本 `scripts/emit_unhandled_manifest.py`，**不重新生成 `.ucl`**，只跑 `_parse_lpc` 取 AST）：

```
每条记录 = {
  zone, source_path, object_id, object_type,
  kind: "function" | "cond_branch" | "complex_if" | "switch" | "raw_block" | "complex_mapping",
  fn_name, condition, action,        # cond_branch 才有
  lpc_line,                          # 回源定位用
}
```

产出 `tmp/unhandled_manifest.json`，然后把条目**编号**（如 `city#0042`）写回 sidecar 的注释行，
从此每个待做项都有稳定 id。本文已附的两个脚本可作为起点。

### 步骤 1 —— 函数名分诊（Tier 0 / 1 / 2）

**Tier 0 · 免除**（不改代码，只登记抑制清单 `scripts/unhandled_suppressions.json`，必须写理由）：

- `setup`(37) `reset`(34) `create` `init` `long`(19) `name`(11) `is_container`(17) `is_chat_room`(11) `query_autoload`(13)
- `no_clean_up`(1805) `valid_startroom`(68) `no_map` `no_shown` `no_user`
- ⚠️ **例外**：`long` / `name` 若依赖 `query()`/`query_temp()` 动态生成，**不属于免除**，归 Tier 2。

**Tier 1 · 引擎已有命令，只缺「逐对象覆盖」通道**（收益最大的一层）

- `lib/kantele/character/commands/` 已有 **204 个命令模块**（`move`/`push`/`open`/`ride`/`study`/`eat`/`drink`/`look`/`push`…）。
- 缺的是 LPC `add_action(verb, fn)` 的**逐对象注册 + 分发**：
  - 现状：`Kantele.World.Room.add_action/2` + `resolve_verb/4`（`room.ex` L272-302）**只有房间级**，
    且只存进 `dynamic_exits[:verbs]`，**没有 UCL 数据入口，NPC / 物品级完全不支持**。
- **建议**：定义通用 UCL 字段

  ```ucl
  actions = [
    { verb = "turn"  handler = "Kantele.World.Actions.AofuTurn" }
    { verb = "xian"  handler = "Kantele.World.Actions.AofuXian" }
  ]
  ```

  loader 读入后注册到房间/NPC/物品；`Kalevala.Verb` 路由时**先查对象级 handler、再落到全局命令**。
- **覆盖**：`do_*` 646 行 / 215 名里的大部分（`do_move` 53、`do_climb` 33、`do_eat` 28、`do_jump` 26、
  `do_open` 19、`do_push`/`do_enter` 16、`do_think` 15、`do_serve` 14、`do_break` 13、`do_get` 12…）。

**Tier 2 · 需要新子系统**（按条数 × 复用面排序）

| 子系统 | 代表函数 | 条数 / 名数 | 复用面 | 备注 |
|--------|----------|------------:|--------|------|
| 战斗回调 | `accept_fight/kill/hit/ansuan`、`unconcious`、`die`、`owner_is_killed` | 259 / 12 | 跨区高 | 转换器已有 `ast.engage` 抽取，但只在模式匹配时命中 —— 应**加宽抽取规则**而不是逐条手写 |
| look / inquiry | `look_*`、`ask_me`、`item_desc` 闭包 `(: look_hua :)` | 185 / 86 | 跨区高 | 与 `xiangyang` 铁匠 inquiry 6 条（`ucl-comment-todo` §6 E）同类，可一并做 |
| 学徒 / 门派 | `recognize_apprentice`、`attempt_apprentice` | 52 / 2 | 门派区 | 名数少但行数多，单点收益高 |
| 门 / 容器 | `close`、`close_passage`、`do_open/knock/break` | 40 / 2 | 中 | 需要**有状态出口** |
| 移动动词 | `do_climb`、`do_jump`、`do_tiao`、`do_cross`、`do_swim` | 含在 `do_*` 内 | 高 | 与 Tier 1 通道共用 |
| 物品 / 食物 / 酒水 | `do_eat`、`finish_eat`、`do_serve`、`create_wine/water/food` | 13+ | 中 | |
| 一次性场景 | 赌场（`city/bet`、`changan/duchang`）、`xiqu1..7`、棋房 `do_play`、`look_gaoshi`、`relay_emote`、`on_board`、`begin/working/halt_working` | 459 / 246 | 低 | **逐房写 Elixir 模块按 room id 绑定**（沿用既有棋房/拱猪先例），不要硬塞进数据 |

### 步骤 2 —— 先做「纯数据、零运行时风险」的一块

**202 个真丢失 key（3150 次）** 是最划算的（其中 `no_clean_up` 一个就占 1805 次、属噪音）：

- 做法：一次性 Python **直接读 `.ucl` 写 `.ucl`**（不跑转换器，符合「转换器已收尾」的约定），
  把 key 补进 `meta = { ... }`。与既有 `scripts/item_meta_backfill.py`（`c7c5fd9`，685 物品）同法。
- 优先级：装备文案（701）> NPC 闲聊（407）> 房间 flag（217）> 容器/酒水（≈220）> 权限 flag（168）> 打造（60）。
- ⚠️ **注意 `create()` 的 `if (clonep()) ... else ...` 必须区分**：
  `clonep()` 分支是「克隆体覆盖」，`else` 是「原型定义」，**不能无脑合并**。
- 无需任何新运行时 → 不动战斗、不动移动，风险最低。

### 步骤 3 —— 运行时子系统

顺序建议：**Tier 1 actions 通道 → 战斗回调 → look/inquiry → 门/容器 → 移动动词 → 门派 → 一次性场景**。
每个子系统单独提交（沿用 checklist「完成即 commit + 记录」风格）。

### 步骤 4 —— 验收与防回归

1. **基线冻结**：把 `tmp/unhandled_manifest.json` / `tmp/ucl_key_loss.json` 的当前数字写进文档，
   加断言脚本；数字**只能降不能升**。
2. **抑制清单**：Tier 0 + 确认免除项，每条带理由（对应 `ucl-comment-implementation-plan` §3.1 的
   「不允许留成待办黑洞」原则）。
3. **可达性**：`scripts/world_reachability.py` 不降（实测 4190/4409，95.0%）。
4. **测试**：`MIX_ENV=test mix test --seed 12345` 保持绿。
5. **不要删 sidecar**：它是唯一索引；AGENTS.md「Never discard information」同样适用。

---

## 6. 风险与硬约束

1. **sidecar ≠ 规格**。83.2% 的分支行没有 body。续做时**必须回 `C:\files\git\mud` LPC 源**
   （AGENTS.md 明确指定为「the definitive reference」），不能只看 sidecar。
2. **Tier 1 的 actions 通道是新的执行路径**。NPC / 物品级 handler 会与现有 204 个全局命令冲突 →
   必须先定**覆盖优先级规则**（对象级 > 全局）+ 灰度。
3. **战斗回调改动面最大**。漏实现是「少行为」，误实现是「改平衡」，必须逐条验证。
   参考 `ucl-comment-todo.zh-CN.md` §9.3 的教训：三道「失败即放行」守卫能让缺陷**隐身**，
   所以涉及新执行路径时要主动加日志/断言，别依赖「不报错就是对的」。
4. **别用 `key` 定位房间**。全库 432 个 key 重名（`majiu` 22 个区、`kedian` 19 个）——
   跨区世界里定位对象**必须用 `id`**（见 `ucl-comment-todo.zh-CN.md` §51 第 6 条）。
5. **elias 词法限制**（写 UCL 字符串时）：嵌套 `\"` 会提前截断 → 一律用单引号；
   「逗号后带空格 / 逗号后紧跟数字」会提前截断；`\` 转义不要原样保留。

---

## 附录 A. 复现命令

```bash
# sidecar 分类盘点（输出 tmp/comments_inventory.json）
python scripts/analyze_comments_txt.py data/world

# LPC set() key 丢失对账（输出 tmp/ucl_key_loss.json）
python scripts/audit_ucl_key_loss.py
```

两个脚本都只在**宿主机**跑（容器内无 Python），且**只读**，不修改 `data/world`。

## 附录 B. 与既有文档的关系

| 文档 | 覆盖范围 | 状态 |
|------|----------|------|
| `docs/data-world-converted-ucl-comments.zh-CN.md` | **`.ucl` 内部**注释（14483 条） | 已完成，但 §8 的结论需按本文 §3 更正 |
| `docs/ucl-comment-implementation-plan.zh-CN.md` | `.ucl` 内 3 类（743 条） | 除 E 外已完成 |
| `docs/ucl-comment-todo.zh-CN.md` | `.ucl` 内剩余（B–G） | 进行中 |
| **本文** | **`.comments.txt` sidecar（11247 行 payload）+ `set()` key 丢失（202 个）** | **新增，此前从未盘点** |
| `docs/data-world-comments-continuation-plan.zh-CN.md` | **续做执行计划**（P0–P6、脚本清单、安全协议） | **新增** |
