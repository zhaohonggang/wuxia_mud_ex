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
  - **P5-4f 房间 temp 三例已执行**：`hengyang:furong1` 的 `look_net` + `pull`、`hengyang:zigaihole` 的 `look_desk` + `move`、`guanwai:jingxiu` 的 `look_men`（读 `guanwai:xiuxishi` 占用）（详见 §3 P5-4f 执行结果）。
  - **P5-4g 玩家 temp 分支已执行**：`fuzhou:mishi` 的 `look_hua`（3 档 + `marks/辟1`）与 `look_liang`（`marks/辟1` 解锁，按房间 `move` 分支，置 `marks/辟2`）；`jueqing:undertan` 的 `look_kong` 静态回填（详见 §3 P5-4g 执行结果）。
  - **P5-4h 机关状态双键已执行**：`shaolin:putiyuan` 的 `look_hole`（`room_state_tiers`，`status` + `book_count` 双键 3 档）+ `xian` 字序机关 + `get book from hole` 发易筋经 + 8s `close_hole`；顺带为房间引入 UCL `state` 播种（详见 §3 P5-4h 执行结果）。

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
>
> **P5-4f 进度**：`look_net` / `look_desk` 已接入 `room_temp`（房间 temp `marks/拉` / `marks/移`），`look_men` 已接入 `room_occupancy`（目标房 `guanwai:xiuxishi`）。
>
> **P5-4g 进度**：`fuzhou:mishi` 的 `look_hua` 用 `score_tiers`（3 档，最高档置 `marks/辟1`），`look_liang` 用 `player_temp_branch`（`marks/辟1` 门控 + 房间 `move` 分支 + `marks/辟2`）；`jueqing:undertan` 的 `look_kong` 已静态回填。`look_table`（猪圈小游戏）、`look_fen`（对象存在 + 移动）仍待后续；`jump liang` / `move big stone` 等动作仍未接线。
>
> **P5-4h 进度**：`look_hole` 已接入 `room_state_tiers`（`status` + `book_count` 双键 3 档，对应 `shaolin:putiyuan` 的三段 `if`），并补齐同房间的 `xian` / `get` / `close_hole`。`look_table`、`look_fen` 仍待后续。

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

### P5-4f：房间 temp / 占用状态条件闭包

- **房间 temp**：新增 `Room.state`（defstruct 新字段，P7 add-only）与
  `get_state_by_id/2` / `put_state_by_id/3` / `delete_state_by_id/2`，对应 LPC
  `query_temp/set_temp/delete_temp`，仅存活于房间进程、不落库。
- **handler `room_temp`**：按 `key`（如 `marks/拉`）选 `hidden` / `shown`；
  `room_id` 省略取当前房间。**当前房间在房间进程内执行，直接读 `context.data.state`**，
  跨房间才 `Room.get_state_by_id/2`，避免 `:sys.get_state(self())` 死锁。
- **handler `room_occupancy`**：`room_id` 指向目标房间，`shown` = 有人、`hidden` = 无人。
  当前房读 `context.characters`，跨房读 `Room.snapshot/1`；无进程视为无人。
  与 LPC `person_inside` 的差异：快照包含 NPC（近似口径）。
- **动作**：`Furong1.Pull`（`pull net`，置 `marks/拉`）、`Zigaihole.Move`
  （`move desk` / `move 石桌`，切换 `marks/移`），文案与 LPC 一致。
- **数据**：`hengyang:furong1` `item_desc.net`、`hengyang:zigaihole`
  `item_desc.desk`、`guanwai:jingxiu` `item_desc.men`（`room_id = "guanwai:xiuxishi"`）。

#### P5-4f 执行结果（2026-10-19）

- 代码：`Room` 新增 `state` + 3 个公开函数；新增 `RoomTempText`、
  `RoomOccupancyText`；新增 `Pull`、`Move`；注册表补 3 房间 / 2 handler / 2 action。
- 数据：`hengyang.ucl` +14 行、`guanwai.ucl` +8 行；`Loader.parse_room` 归一化出
  `net` / `desk` / `men` 的动态配置。
- 校验：`Elias.parse` 两文件通过；`validate_ucl.py` 两文件全绿；`mix compile` 通过；
  单测 **16/0**（含跨房/当前房 temp、占用快照/当前 context、Pull、Move）；
  `mix format` 新文件通过；`room.ex` 仅新增块，未保留 `mix format` 的既有代码重排。
- 未跑：`mix test`（本机无 Postgres）。

### P5-4g：玩家 temp 解锁 + 房间 temp 分支

- **`look_hua`（`fuzhou:mishi`）**：与 `beijing:aofu_shufang` 同名但不同文案/阈值；
  用 `score_tiers` 3 档（0 / 1000 / 3000），最高档 `set_temp = "marks/辟1"`。
- **`look_liang`**：新增 `PlayerTempBranch`（`kind = "player_temp_branch"`）：
  `gate_temp` 未设置 → `no_access`；否则按当前房间 `room_key` 是否存在选
  `shown` / `hidden`，`hidden` 分支可 `set_temp`（发 `character/effects` 事件）。
- **`look_kong`（`jueqing:undertan`）**：`sort_msg` 仅重排文本，内容为静态字符串，
  按 P5-4c 口径直接回填 `item_desc.kong`（换行折叠为空格）。
- **数据**：`fuzhou:mishi` 新增 `item_desc.hua` + `item_desc.liang`；
  `jueqing:undertan` 新增 `item_desc.kong`。
- **未接线**：`jump liang`（`do_jump`）与 `move big stone`（`do_move`）仍未实现，
  因此 `room_key = "move"` 分支在实机中暂不可达，仅 handler/测试可验证；
  `look_fen` 的剑对象存在性同理留待动作批次。

#### P5-4g 执行结果（2026-10-19）

- 代码：新增 `PlayerTempBranch`；`ItemDescHandlers` 注册 `fuzhou:mishi`
  （`score_tiers` + `player_temp_branch`）。
- 数据：`fuzhou.ucl` +19 行、`jueqing.ucl` +1 行；`Loader.parse_room` 归一化出
  `hua` / `liang` / `kong`。
- 校验：`Elias.parse` 两文件通过；`validate_ucl.py` 两文件全绿；`mix compile` 通过；
  单测 **19/0**（+3：未解锁 / 解锁置 `marks/辟2` / 房间 `move` 已置）。
- 未跑：`mix test`（本机无 Postgres）。

### P5-4h：机关状态双键分支 + 房间 state 播种（少林菩提院）

`d/shaolin/putiyuan.c` 是第一个「`item_desc` + 房间动作 + 定时回调 + 发物」四件套
齐全的谜题，也是第一个**覆盖全局命令**的移植。

- **`look_hole`**：新增 `RoomStateTiers`（`kind = "room_state_tiers"`）。与
  `room_temp` 的「有/无」两分支不同，这里由 **`status`（0/1/2/4）+ `book_count`
  （1/0）两个键**共同决定三段文案。`tiers` 按顺序取第一个 `match` 全命中的层级，
  无 `match` 的层级是兜底项（须放最后）；`match` 要求房间 state 同名键**精确相等**，
  缺键不算命中。
- **`status` / `book_count` 是房间属性，不是房间 temp**：源文件 `create()` 里是
  `set("status", 0)` / `set("book_count", 1)`（`set/query`），此前调研记为「房间
  temp」不准确。落地方式：UCL 新增 `state = { status = 0  book_count = 1 }`，
  `Loader.parse_room/4` 增加 `parse_room_state/1` 播种到 `Room.state`（缺省 `%{}`，
  未回填的房间行为不变）。
- **`xian <字> [序号]`**：字序机关。`一` 是重置键；`梦`（status 1→2）、`如 3`
  （2→3，`如` 在偈中出现三次故必须带序号且只有第三个有效）、`是`（3→4）。
  任何一步错误都把 `status` 归零；`status == 4` 时再掀任意字会把铜镜按回去。
- **`get book from hole`**：四种写法（`book|jing` × `from|in`）才接管，其余输入
  一律 `:not_handled` 交回全局 `GetCommand` —— 对应 LPC 的三处 `return 0`。
- **8 秒 `close_hole`**：**没有**用 `Room.set_timer/3`（它把
  `{:room_timer, ...}` 投给 `self()`，而房间进程没有对应 `handle_info/2`，
  详见该函数的说明），改用 `:timer.apply_after/4` 回调 `Xian.close_hole/1`，
  回调体只用按 room_id 的运行时原语：`Room.put_state_by_id/3` + `Room.tell_room/2`。
- **发物**：`give_item/3` 从 `NpcActions.Helpers` 下移到 `RoomActions.Helpers`
  （房间动作也要发物），NPC 侧保留薄委托，历史调用点零改动。

#### P5-4h 执行结果（2026-10-20）

- 代码：新增 `RoomStateTiers`、`RoomActions.Shaolin.Putiyuan.Xian`、
  `RoomActions.Shaolin.Putiyuan.Get`；`ItemDescHandlers` / `RoomActionHandlers`
  各注册 `shaolin:putiyuan`；`Loader` 增 `parse_room_state/1`；
  `RoomActions.Helpers` 增 `give_item/3`、`give_items/4`。
- 数据：`shaolin.ucl` 的 `rooms "putiyuan"` 增 `state` 块与 `item_desc.hole`
  （3 档）。
- 校验（容器内，权威）：新增单测 **22/0**；全量套件见
  `docs/data-world-comments-progress.zh-CN.md` 的 M9 行。
- **与 LPC 的唯一差异**：LPC 在 `load_object(MIJI)` **之前**就把 `book_count`
  置 0，物品定义缺失时书永久消失、谜题不可再解；本实现先 `Items.get/1` 校验定义
  存在，缺失时只报「系统出现故障」而不改 `book_count`。世界数据正常时两者等价。
- **顺带发现（未修）**：`RoomActions.Helpers.broadcast_vision/4` 传的
  `&__MODULE__.publish_error/1` 与实际定义的 `publish_error/2` 不匹配，
  编译期即有 warning；真正走到错误分支时会 `UndefinedFunctionError`。
  与 P5-4h 无关，单独记账。

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
3. ~~score 门控~~ ✅ 已完成（P5-4e：`look_jing` / `look_hua`；`show_hua` P5-4c 已静态回填）。
   ~~房间 temp 首批~~ ✅ 已完成（P5-4f：`look_net` / `look_desk` / `look_men`）。
   ~~玩家 temp 分支~~ ✅ 已完成（P5-4g：`look_hua` / `look_liang` / 静态 `look_kong`）。
4. ~~机关状态双键 + 房间 state 播种~~ ✅ 已完成（P5-4h：`look_hole` / `xian` /
   `get book from hole` / 8s `close_hole`，`shaolin:putiyuan`；见上）。
   `look_fen`（对象存在性 + 移动）与 `look_table`（猪圈小游戏）仍暂缓；之后
   daemon/helper，最后补 9 个表达式值。
5. inquiry 侧继续：`ask_skill1..10`（≈247 处）/ 86 个 `ask_*` 函数，按门派分批。
