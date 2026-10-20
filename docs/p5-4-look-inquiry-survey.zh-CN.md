# P5-4（look / inquiry）勘查与切片计划

> 日期：2026-10-19　分支：`kalevala`
> 勘查脚本：`scripts/survey_p54_look.py`（只读、可重跑）
> 产物：`scripts/tmp/p54_look_survey.json`（逐房间明细 + 闭包函数体 + 分类）、`scripts/tmp/p54_look_stdout.txt`
> 源语料：`C:/files/git/mud`（LPC 权威，只读）

## 0. 结论速览

- **inquiry（ask）**：P5-4a 已落地库存型 `give_item`（13 条），P5-4b 已加闭包字面量兜底（`(: ask_x :)` 不再回显原文）。余下 86 个 `ask_*` 函数 / 662 处闭包占位待逐批实现。
- **look（`set("item_desc", ...)`）**：
  - 463 个房间文件含 `item_desc`，共 **576** 个键值对。
  - 197 个静态字符串（已由转换器写入 UCL）。
  - 268 个非闭包表达式值：**222** 颜色宏拼接（已转换）、**37** `@TEXT` 多行宏（**丢失**）、**9** 其它表达式（**丢失**）。
  - 111 个闭包值：**59 对纯静态 return（可零代码回填）** / **52 对条件分支（需运行时 handler）**。
  - 闭包去重后 **54** 个函数：31 静态 / 23 条件。
  - 房间构成：**73** 个房间「全动态」（当前 UCL **完全无** `item_desc` block）/ **15** 个「混合」（UCL 仅写了静态对）。
  - **P5-4c 已执行**：静态回填 **88 房间 / 95 键 / 26 文件**（详见 §3 P5-4c 执行结果）。
  - **P5-4d pilot 已执行**：`hengyang:inzhushendong` 的 `look_bi` + `pic1/2/3` + `gua` 动作（详见 §3 P5-4d 执行结果）。
  - **P5-4e score 门控已执行**：`shaolin:putiyuan` 的 `look_jing`（`jing` / `铜镜`，3 档）与 `beijing:aofu_shufang` 的 `look_hua`（`hua`，2 档 + `marks/画1`）（详见 §3 P5-4e 执行结果）。

### 实测佐证
- `changan/bank.c` 的 `paizi`（`HIG"..."NOR` 拼接）→ **已**写入 `data/world/changan.ucl:84`，证明 `macro_concat` 类已被转换器处理。
- `beijing/majuan.c` 的 `gaoshi`（`@TEXT ... TEXT`）→ `data/world/beijing.ucl` 的 `majuan` 房间**无** `item_desc`，证明 `text_macro` 类被丢弃。

## 1. 现有链路（为什么动态值不生效）

| 环节 | 位置 | 行为 |
|------|------|------|
| 转换器（Elixir，已冻结） | `lib/kantele/world/lpc_converter.ex` `generate_room_item_desc/1` | 只保留 `{:string}` / `{:array, string}`；闭包、`@TEXT`、表达式 → `item_desc_text(_) -> ""` → **整条丢弃** |
| Python 端口（只读复用） | `scripts/lpc_converter.py` `_parse_lpc_value/1`、`_item_desc_text/1` | 闭包 `(: look_x :)` → `("var", ...)`；`_item_desc_text` 返回 `""` |
| 载入 | `lib/kantele/world/loader.ex` `parse_item_desc/1` | `keyword -> to_string(value)`（只认字符串） |
| 运行时 | `lib/kantele/world/room.ex` `item_desc/2` | key 精确/前缀匹配，返回 `text <> "\n"` |
| 命令 | `look <kw>` → `room/item_desc` 事件 → `Room.call/2` | 命中回显；未命中回「这里没有这个东西。」 |

因此：**静态字符串 `item_desc` 已生效；闭包/`@TEXT`/表达式完全缺失。**

## 2. 分类明细

### 2.1 可静态回填（P5-4c，零运行时改动）

**31 个纯静态闭包**（函数体为纯字符串 return）：

`look_bei, look_bell, look_bian, look_dazi, look_ditu, look_drum, look_dui, look_duilian, look_duizi, look_floor, look_fu, look_gate, look_ge, look_hongshui, look_jiebei, look_map, look_out, look_pai, look_picture, look_poem, look_pool, look_shibei, look_stone, look_sword, look_ta, look_tower, look_wall, look_writing, look_xiang, look_zi, show_hua`

（来源示例：`city/shan.c` duilian、`gaochang/zoulange.c` wall、`huashan/jianzhong.c` stone、`mingjiao/mjdimen1.c` pai、`emei/bgsgate.c` gate、`shaolin/beilin1.c` tower、`shaolin/gulou7.c` out/drum、`emei/qingyinge.c` shibei、`wudang/nanyangong.c` xiang。注：`closure_bodies` 的 `file` 为全库首次命中，同名函数可能有多处定义。）

**37 个 `@TEXT ... TEXT`** 值同为字面文本，可一并静态抽取。

高频关键词（全量 576 对）：`paizi 52 / wall 42 / gaoshi 21 / yunti 17 / window 16 / dong 12 / stone 12 / table 11 / teng 11 / duilian 10 / gate 10 / desk 10 / bi 9 / bian 8 / men 7`。

### 2.2 需运行时 handler（P5-4d）

**23 个条件闭包**（按依赖归类）：

| 依赖 | 函数 | 源（首次命中） |
|------|------|----------------|
| `score` 门控 | `look_jing`, `look_hua`, `show_hua` | `shaolin/putiyuan.c`, `beijing/aofu_shufang.c`, `hengyang/baihuzhai.c` |
| 房间/玩家 temp | `look_bi`(gua), `look_table`(pigging_seat), `look_men`(另一房间 temp), `look_net`(marks/拉), `look_desk`, `look_hole`, `look_kong`, `look_fen`, `look_liang` | `hengyang/inzhushendong.c` 等 |
| 外部 daemon / helper | `look_gaoshi`, `look_scoreboard`, `look_tiaofu`, `look_board` | `chengdu/eastgate.c`, `city/eproom.c`, `city/leitai.c`, `inherit/room/chatroom.c` |
| 物品/其它 | `look_pet`, `look_pic1/2/3`, `look_door`, `look_sword2/3`, `call_killer` | `xiyu/houdong.c`, `hengyang/inzhushendong.c` 等 |

> **P5-4e 进度**：`look_jing` / `look_hua` 已接入 `score_tiers`；`show_hua` 是纯静态闭包，P5-4c 已回填到 `hengyang:baihuzhai`（无需 handler）。

另有 **9** 个其它表达式值（变量/调用），需逐个确认。

## 3. 切片方案

### P5-4c：静态 `item_desc` 回填（推荐先做）

- **新脚本** `scripts/backfill_room_item_desc_static.py`（P3：新逻辑放新脚本）。
- **只读复用** `scripts/lpc_converter.py` 的 `_parse_mapping_pairs` / `_parse_lpc_value` / `_item_desc_text` / `_escape_set_string` / `_normalize_item_keyword`（P1 只禁编辑，不禁 import）。
- 对每个房间：
  1. 解析 `set("item_desc", ([ ... ]))`（按带引号的 key 位置切分，避免值内逗号/换行截断）；
  2. 闭包值：取 `(: fn :)`，在**同文件**（后续再扩继承链）找函数体；仅当「纯静态 return / 局部字符串变量赋值 + return」时抽取文本；
  3. heredoc 值：`@TEXT` / `@WALL` / `@SHADOWS ...` 按字面多行文本抽取（兼容 `HIY @TEXT ... TEXT NOR` 包裹）；
  4. 颜色宏统一按 `_process_literal_string` 剥离，与现有 UCL 口径一致；
  5. 安全化：`\`+空白折叠为空格（elias 无法 lex，如 `huashan/sgyhole.c` 石壁图）。
- **数据写入**：P4 只增——仅补缺失的 `item_desc = { ... }` block 或缺失键，**不动已有行**、不重排。幂等可重跑。
- 流程：dry-run 统计 → 备份 → 写 UCL → `scripts/validate_ucl.py` → 目标区 `mix test`。
- 预期覆盖：约 **95 对**（56 静态闭包 + 39 heredoc），实测 88 房间。

#### P5-4c 执行结果（2026-10-19）

- 覆盖：**88 房间 / 95 键 / 26 个 UCL 文件**，`+261` 行、`0` 删除。
- 主要批次：`xiakedao` 24 间 `wall`（`@WALL`）、`death/inn1` `shadows`、`death/inn2` `wall`、`shaolin` 9 间（`stone/tower/drum/out/bell/floor/gate/writing/picture/duizi/poem`）、`huashan/sgyhole1-4` `wall`、`emei` 4 间、`hengyang` 4 间等。
- 校验：`validate_ucl.py` 的失败集与落盘前**逐条一致**（仅既有 5 项：`huashan` 双右括号、`lingxiao` L2951 语法、`shaolin` L7381、`wudu` `$N`、`xiangyang` L4066）；未新增失败。
- 幂等：写后重跑 dry-run = **0 房间 / 0 键**。
- 说明：UCL 字符串按既有约定折叠换行（`_sanitize_ucl_sval`），ASCII 图会变成长单行；与全库 `description`/`item_desc` 口径一致，非本次引入。

### P5-4d：动态 `item_desc` handler（条件闭包）

- **UCL 表示**（与 P5-4a inquiry 的 `kind` 一致）：值为映射，`kind` 选择 handler。
  普通关键词可直接作为 key：
  ```ucl
  item_desc = {
    bi = { kind = "gated_text" gate_temp = "gua" hidden = "..." shown = "..." }
  }
  ```
  但 elias 的 UCL key **不能含数字**（`pic1` 会被 lex 成 word + digit），因此含数字
  的关键词（`pic1/2/3`）放到新增的 `item_desc_dynamic` 数组里，用 `keyword` 字段声明：
  ```ucl
  item_desc_dynamic = [
    { keyword = "pic1" kind = "gated_text" gate_temp = "gua" hidden = "..." shown = "..." }
  ]
  ```
- `loader.parse_item_desc/1`：值为 map 时保留配置（键归一为字符串）；新增
  `parse_item_desc_dynamic/1` 把数组按 `keyword` 合并进 `Room.item_desc`（P7 add-only）。
- **新模块** `lib/kantele/world/item_desc_handlers.ex`（房间级 `(room_id, kind)` 注册表）
  + `.../item_desc_handlers/gated_text.ex`（按 `gate_temp` 选 `hidden` / `shown`）。
- `Room.item_desc_entry/2` 返回 `{:static, text}` / `{:dynamic, config}`；`room/item_desc`
  事件动态分支查注册表，未注册回「这里没有这个东西。」（安全兜底）。
- **pilot**：`hengyang:inzhushendong` 的 `look_bi` + `pic1/2/3`，由 `gua bi` 动作
  `set_temp("gua", 1)` 解锁（`Kantele.World.RoomActions.Hengyang.Inzhushendong.Gua`）。

#### P5-4d pilot 执行结果（2026-10-19）

- 数据：`data/world/hengyang.ucl` 的 `inzhushendong` 新增 `item_desc_dynamic`
  （4 条：`bi` / `pic1` / `pic2` / `pic3`）与 `actions = { gua = "do_gua" }`（+33 行）。
- 代码：loader 动态条目解析；`Room.item_desc_entry/2` + `LookEvent` 路由；
  `ItemDescHandlers` + `GatedText`；`Gua` 房间动作（busy/fighting/arg 校验 + 文案 +
  `PlayerMeta.put_temp` → `conn.private.update_character`）。
- 校验：`Elias.parse` 正常解析 `item_desc_dynamic`（数组元素为 `keyword` 映射）；
  `validate_ucl.py data/world/hengyang.ucl` 全绿；`mix compile` 通过；
  `mix run --no-start` 验证 `GatedText` 在 temp 未设/已设时分别输出 `hidden` / `shown`。
- 未跑：`mix test`（本机无 Postgres，`test` alias 强制 `ecto.create`）。

### P5-4e：score 门控条件闭包

- **UCL 表示**：`kind = "score_tiers"`，`tiers` 数组按 `min_score` 升序；handler 选
  `min_score <= score` 的最大层，对应 LPC 的多段
  `if (me->query("score") < N) return ...`。
  ```ucl
  item_desc = {
    jing = {
      kind = "score_tiers"
      tiers = [
        { min_score = 0 text = "..." },
        { min_score = 1000 text = "..." },
        { min_score = 5000 text = "..." }
      ]
    }
  }
  ```
- **副作用**：`look_hua` 在 `score >= 3000` 时 `set_temp("marks/画1", 1)`。房间
  handler 只发 `"character/effects"` 事件（`{:set_temp, key, 1}`），由角色进程执行
  并落盘；新增 `Kantele.Character.EffectEvent`（复用 `TrapEvent` 的效果列表）。
- **数据**：`shaolin:putiyuan`（`jing` + `铜镜`，3 档）、`beijing:aofu_shufang`
  （`hua`，2 档）。
- **顺带修复**：`shaolin:zoulang2` 的 ASCII 图字符串含 2 个半角逗号（`*｜*,*` /
  `＼┃**,*`），elias 无法 lex，导致整个 `shaolin.ucl` 解析失败（HEAD 即如此）。
  改为全角逗号 `，`（视觉不变），`Elias.parse` 恢复；`validate_ucl.py` 仍只报既有
  的 `", 41, "` 注释行（L7442，非本次引入）。

#### P5-4e 执行结果（2026-10-19）

- 代码：`ScoreTiers`（选层 + 可选 `set_temp` 事件）、`EffectEvent`（`character/effects`
  → `TrapEvent`）、`ItemDescHandlers` 注册 `shaolin:putiyuan` / `beijing:aofu_shufang`。
- 数据：`shaolin.ucl` +18 行、`beijing.ucl` +9 行；`Loader.parse_room` 归一化出
  `"jing"` / `"铜镜"` / `"hua"` 的 `tiers`（`min_score` 保留整数）。
- 校验：`Elias.parse` 两文件通过（`shaolin` 修复后）；`validate_ucl.py beijing`
  全绿、`shaolin` 仅既有 `", 41, "`；`mix compile` 通过；单测 **9/0**；
  `mix format --check-formatted` 通过；`mix credo` 新文件 0 issue。
- 未跑：`mix test`（本机无 Postgres）。

## 4. 约束与风险

- **P1**：不得改 `scripts/lpc_converter.py`、`lib/kantele/world/lpc_converter.ex`、`lib/mix/tasks/kantele.convert_lpc.ex`；P5-4c 仅 import 只读。
- **P2/P4**：不得用 `convert_file` 重写 UCL；只增、幂等，不删 `.comments.txt`。
- **颜色宏**：现有 UCL `item_desc` 已剥离颜色；P5-4c 必须保持一致，避免同一房间两种风格。
- **`@TEXT`**：Elixir converter 口径未证实（实测被丢弃）；P5-4c 自行按字面抽取，不依赖 converter。
- **关键词**：静态回填脚本沿用 `_normalize_item_keyword`（CJK key 归一为空 → 跳过）；但运行时 UCL **允许** CJK key（P5-4e `putiyuan` 的 `铜镜` 已验证），手写数据可直接使用。
- **同名函数**：`look_*` 跨房间/继承可能多定义；P5-4c 先只处理同文件定义，继承链单独记账。
- **P7**：room/数据结构只增字段，不改既有语义。

## 5. 下一步

1. ~~实现 **P5-4c**~~ ✅ 已完成（88 房间 / 95 键；见上）。
2. ~~实现 **P5-4d pilot**~~ ✅ 已完成（`look_bi` + `pic1/2/3` + `gua`，`hengyang:inzhushendong`；见上）。
3. ~~score 门控~~ ✅ 已完成（P5-4e：`look_jing` / `look_hua`；`show_hua` P5-4c 已静态回填）；继续 temp → daemon，最后补 9 个表达式值。
4. inquiry 侧继续：`ask_skill1..10`（≈247 处）/ 86 个 `ask_*` 函数，按门派分批。
