# UCL 语法参考（Elias 解析器 · 本仓库实测版）

> 面向「以后接手本项目的 AI」的硬约束参考。目的：写 / 改 `data/world/*.ucl`
> 时不再犯语法错误。
>
> **本文所有规则均以本机实测为准**（Elixir 1.13.4 / `deps/elias` 0.2.8，
> 用 `mix run -e 'Elias.parse(...)'` 逐条验证）。凡与直觉或旧文档冲突，
> **以本文为准**。每条规则后标注「实测」或「源码」。
>
> 权威解析器源码：
> - 词法：`deps/elias/src/elias_lexer.xrl`（leex）
> - 语法：`deps/elias/src/elias_parser.yrl`（yecc）
> - 入口：`deps/elias/lib/elias.ex`（`Elias.parse/1`，成功返回**裸 map**，失败**抛异常**）
>
> 校验器：`python scripts/validate_ucl.py <file>`（提交前必跑，见 AGENTS.md Core Rule #1）。

---

## 0. 一句话总览

UCL 是「`块名 "键" { 键 = 值 ... }`」的嵌套配置。**词法极简**（只有 ~20 种 token），
**没有** C/Python 那套运算符与表达式。写 UCL 只需记住：

1. **键（key）= 纯字母/下划线的 ASCII 标识符，绝不能含数字、连字符、中文。**
2. **值只有 5 种**：整数、双引号字符串、裸词（bare word，含点号引用）、数组 `[...]`、内联对象 `{...}`。
3. **块内成员靠「换行」分隔**（不是逗号）。**数组元素靠「逗号」分隔**（不是换行）。
4. **字符串里不能出现 `;` `[` `]`；`\` 只能接普通字符或引号**（`\n` 合法且是换行约定）。
5. **数组最后一个元素不能带尾随逗号**（实测报错）。

---

## 1. 词法（lexer）：有哪些 token

源码 `elias_lexer.xrl` 定义的全部 token（`Word` 正则最关键）：

```
ArrayClose   = ]          ArrayOpen   = [
BackSlash    = \          BracketClose= }        BracketOpen= {
Colon        = :          Comma       = ,        Dash        = -
Digit        = [0-9]+     DoubleQuote = "        Equals      = =
ForwardSlash = /          NewLine     = (\n|\n\r|\r)
Pound        = #          SemiColon   = ;        SingleQuote = '
Space        = \s+        Star        = *        CommentOpen = /*
CommentClose = */         Word = [^0-9{}\*\/#\n\[\]=\s'":;\\-]+
```

**`Word` 的排除集**（决定什么字符不能出现在「裸词 / 键」里）：
`0-9 { } * / # 换行 [ ] = 空格 ' " : ; \ -`

逐个推导出的硬约束：

| 不能出现在裸词/键里的字符 | 原因 | 后果 |
|---|---|---|
| `0-9` | 数字是独立 `digit` token | 键含数字 → 无法闭合赋值（**实测 `a1 = 5` 报错**；值侧数字正常） |
| `-` | 是独立 `dash` token | 键含 `-` 报错（**实测 `a-b = 1` 报错**） |
| `*` | 独立 `star` token | 裸词含 `*` 会被切断 |
| `/` | 独立 `forward_slash` token | **裸值含 `/` 报错**（实测 `a = tie-zhang/lei` 报错；必须写成字符串 `"tie-zhang/lei"`） |
| `#` | 注释起始 `pound` | 行内 `#` 之后全是注释 |
| `[` `]` | 独立括号 token | 裸词含 `[]` 报错 |
| `=` | 独立 `equals` | 裸词含 `=` 报错 |
| `'` | 独立 `single_quote` | 裸值用单引号 → 报错（**实测 `a = 'hi'` 报错**） |
| `"` | 独立 `double_quote` | 裸词含 `"` 报错 |
| `:` | 独立 `colon` | 裸词含 `:` 报错 |
| `;` | 独立 `semi_colon` | **字符串里出现 `;` 也会报错**（实测 `a = "x;y"` 报错） |
| `\` | 独立 `back_slash` | 字符串里 `\` 只能接「普通字符」或 `"`（合法：`\n` `\"`；非法：`\\` `\ ` `\]` `\#` `\;`，见 §6） |
| `空格` | 独立 `space` | 裸词不能含空格（这是分词依据） |

> **推论：`Word` 允许的字符 = 除上面全部之外的可见 ASCII + 所有 ≥126 的字节（含中文）。**
> 所以 **裸词里可以有中文**（`a = 玄冥谷` 合法），但 **键不行**（见 §3 的键规则——键实际走的是同一条 `Word` 规则，所以键也不能含中文/数字/连字符）。

**实测确认可出现在裸词里的字符**：`@ ? . _ ( ) , :`（`:`,`)` 等只在特定上下文）、以及中文。
例：`a = x@y` → `%{a: "x@y"}`；`a = x?y` → `%{a: "x?y"}`；`a = xuanming-zhang` → `%{a: "xuanming-zhang"}`（`-` 在**值**位置合法，因为 `value -> value_sub`，`value_sub` 显式包含 `dash`）。

---

## 2. 值的 5 种形态（实测）

| 写法 | 解析结果 | 说明 |
|---|---|---|
| `a = 5` | `%{a: 5}` | 整数 |
| `a = -5` | `%{a: -5}` | 负整数（`word equality dash digit`） |
| `a = 007` | `%{a: 7}` | 前导零被吃掉 |
| `a = 5.5` | ❌ 报错 | **没有浮点数！** 小数会解析失败 |
| `a = "hi"` | `%{a: "hi"}` | 双引号字符串 |
| `a = ""` | `%{a: ""}` | 空字符串合法 |
| `a = rooms.x.id` | `%{a: "rooms.x.id"}` | **裸词 → 字符串**（loader 后续按引用解析） |
| `a = xiyu.rooms.shamo10.id` | `%{a: "xiyu.rooms.shamo10.id"}` | 跨区引用也是裸词字符串 |
| `a = true` | `%{a: "true"}` | ⚠️ 是**字符串** `"true"`，不是布尔 |
| `a = [1, 2]` | `%{a: [1, 2]}` | 数组 |
| `a = []` | `%{a: []}` | 空数组 |
| `a = { b = 1 c = 2 }` | `%{a: %{b: 1, c: 2}}` | 内联对象（块成员换行或空格分隔均可） |
| `a = {}` | `%{a: %{}}` | 空对象 |

**关键坑**：

- **没有浮点**：`5.5` 报错。需要小数时（极少）另想编码（如字符串）。
- **`true`/`false`/`nil` 都是普通裸词 → 字符串**。loader 里布尔字段（如 `permit_recruit = true`）
  靠 `to_bool/1` 把 `"true"` 字符串转布尔（见 `loader.ex`），**不是** UCL 原生布尔。
- **负数只能在「值」位、且不能进数组**：`a = -5` 可以，`a = { b = -5 }` 可以，
  但 **`a = [-1]` / `a = [1, -2]` 报错**（数组的 `array_value` 只接 `digit`，不接 `dash digit`）。
  需要在数组里放负数 → 改用对象或字符串。
- **裸值含 `/` 必须加引号**：`perform_id = tie-zhang/lei` ❌；`perform_id = "tie-zhang/lei"` ✅。

---

## 3. 键（key / 块名）的规则

- **键必须是「纯字母 + 下划线」的 ASCII 标识符，不能含数字、连字符、中文。**
  - 合法：`name`、`min_levels`、`x`、`item_desc`、`msg_one`
  - 非法（实测报错）：`a1`（含数字）、`hole6`（含数字）、`a-b`（含连字符）、`乾`（中文）
- **值侧不受此限**：`rooms.lockroom6.id`、`xuanming-zhang` 作为**值**都正常。
- 这条是「键」与「值」最容易被混淆的区别：**键严、值宽。**

> 历史背景：huashan 的方向名 `hole1..hole6`、shaolin 的八卦方向名 `乾/巽/...`
> 都因为「键含数字/中文」被 elias 拒绝，见 `docs/ucl-conversion-issues.zh-CN.md` 问题 3/4。

---

## 4. 块（block）与「章节」

顶层与嵌套都用花括号：

```ucl
zones "liuxi" {          # 章节：section_name + 可选的 keys + block
  name = "柳溪镇"
}

rooms "guangchang" {     # 另一个章节
  name = "镇广场"
  x = 0 y = 1 z = 0      # 同一行多个成员靠空格分隔也合法（实测）
}
```

- **块成员（assignment）靠换行分隔**（`assignments -> assignment assignments`）。
  同一行写多个成员靠空格分隔也**能解析**（实测 `a = 1 b = 2` → `%{a: 1, b: 2}`），
  但**约定每行一个**，便于 `validate_ucl` 报行号与人工审阅。
- **块成员之间不能有逗号**。写了逗号（`,`）在块内 → 报错。
- **闭合括号可与值粘连**：`north = rooms.a.id  }` 合法（`block_end -> bracket_close`）。
- **单文件顶层可以有多个块**（实测 `zones...rooms...` 两个块 → 合并成一个 map）。

### 4.1 引用（reference）

`rooms.guangchang.id` 这类「点号引用」在 UCL 里**只是裸词字符串**，由 loader 的
`dereference/3` 解析为 `"zone:key"` 形式的 id：

- 同区引用：`rooms.<roomkey>.id` → `"<zone>:<roomkey>"`
- 跨区引用：`<zone>.rooms.<roomkey>.id` → `"<zone>:<roomkey>"`
- 物品：`items.<itemkey>.id` → `"<zone>:<itemkey>"`
- 角色：`characters.<id>.id` → `"<zone>:<id>"`
- **区域文件优先于 clone_lib**：同名 NPC/房间以区域文件（`data/world/<zone>.ucl`）为准，
  clone_lib 仅作后备（`dereference/3` 先查 `zone.characters`）。

> 引用写成字符串 `"rooms.x.id"` 与裸词 `rooms.x.id` 等价（loader 照样解引用），
> 但**约定写裸词**（转换器产物即如此）。

---

## 5. 数组（array）

```ucl
verbs = [
  "get",
  "drop"
]
```

- **元素之间必须用逗号**（`array_inner -> array_value comma array_inner`）。
  换行**不能**代替逗号（实测 `a = [1 2 3]` 报错；`a = [1, 2]` 通过）。
- **最后一个元素不能带尾随逗号**（实测 `a = [1, 2, 3,]` 报错、`["x","y",]` 报错）。
  ⚠️ 这与 README 旧表述「建议加尾随逗号」**矛盾**——**以实测为准：不要加尾随逗号。**
- **数组元素可以是对象**：`[{ id = items.x.id }, { id = items.y.id }]`（实测通过）。
- **数组元素不能是负数**：`[-1]` 报错。
- 空数组：`[]` 或 `[ ]`（实测都通过）。

> `validate_ucl.py` 的 Chars 检查会把「`,` 紧跟 `}`」和「尾随逗号」抓出来，
> 就是为了兜住这一类错误。

---

## 6. 字符串

字符串是**双引号**包裹的内容。词法上 `words` 规则对反斜杠有两条产生式
（`elias_parser.yrl`）：

```
words -> word words
       | back_slash quotes words      # \" 转义引号
       | back_slash word words        # \ 后接普通 word 字符
       | quotes | ... 
```

由此得到**反斜杠的唯一合法用法**：`\` 后面必须紧跟一个「word 字符」或 `"`。

- **`\"` → 合法**，表示转义后的引号（实测 `a = "x\"y"` → `%{a: "x\"y"}`）。
- **`\n`（反斜杠 + 字母 n）→ 合法**，并且是**本仓库表达换行的约定写法**。
  - clone_lib 有 120+ 处 `learned = "...\n"`、`msg_one = "...\n"` 之类（原始字节 `5c 6e`）。
  - 解析后保留为**字面 2 字符** `\` `n`（Elias 不做 C 式转义解释），
    到显示层再被转成真换行（转换器 `lpc_converter.ex` 有 `String.replace("\\n", "\n")`；
    前端 `assets/js/kalevala/parseText.js` 按真实 `\n` 切行）。
  - 同理合法：`\t`、`\r`、`\,`、`\y`、`\(` 等——**只要 `\` 后面是普通字符就行**。
- **非法**（实测报错）：
  - `\\`（双反斜杠）→ 报错（`back_slash` 后面只能跟 word 或 `"`，`\` 不在 `Word` 里）
  - `\ `（反斜杠 + 空格）→ 报错
  - `\]`、`\#`、`\;` → 报错（`]`/`#`/`;` 不是 `Word` 字符）
- **字符串内真实换行**（直接按回车）→ 报错（`NewLine` 会终结 assignment）。
- **不能出现**：`;`、`[`、`]`（实测 `a = "x;y"`、`a = "x[y]"`、`a = "x]y"` 全报错）。
- **可以出现**：`,` `:` `{` `}` `=` `#` `'` `*` `/` `(` `)` `.` `@` `?` 空格 中文
  （实测逐一通过）。注意 `{` `}` 在**字符串内**是普通字符（只有块位置才是括号）。

> **一句话：`\` 只能接普通字符或引号；`\n` 是本仓库换行的标准写法，可放心用；`
> `\\`、`\ `、`\]`、`\#`、`\;` 才是禁忌。** 若拿不准，先 `Elias.parse/1` 验证再落盘。

---

## 7. 注释

- **行注释**：`#` 到行尾（`comments -> pound single_comments newline`）。
  - `# 这是注释`
  - 行内尾注释：`x = 5  # 说明`（`#` 之后是注释）
- **块注释**：`/* ... */`（`CommentOpen ... CommentClose`）。可跨行（实测 `/* multi\nline */` 通过）。
- **没有** `//` 行注释（`//` 会被词成两个 `forward_slash` → 报错，实测 `a = 1 // c` 报错）。
- 注释可出现在几乎任何 token 之间（`whitespace` / `assignments` 规则里都含 `comments`）。

---

## 8. 顶层块名与字段（本仓库 loader 实际消费）

### 8.1 顶层块（每个 `.ucl` 文件）

| 块 | 语法 | 必填 | 说明 |
|---|---|---|---|
| `zones` | `zones "<id>" { name = "..." }` | **是** | 每个文件必须有且仅有一个（loader 取 `Map.keys(zone_data.zones)` 的唯一个） |
| `rooms` | `rooms "<key>" { ... }` | 视区而定 | 房间定义；纯物件区（tangmen）可无 |
| `room_exits` | `room_exits "<key>" { ... }` | 视区而定 | 出口；房间数应与 room_exits 数相等 |
| `room_characters` | `room_characters "<roomkey>" { ... }` | 否 | 房间内 NPC 落位 |
| `room_items` | `room_items "<roomkey>" { ... }` | 否 | 房间地面物品 |
| `characters` | `characters "<id>" { ... }` | 否 | NPC 定义（通常在 clone_lib.ucl 集中定义） |
| `items` | `items "<key>" { ... }` | 否 | 物品定义 |

> 纯物件区（`tangmen` / `clone_lib` 的 items 集合）只有 `zones` + `items/characters`、
> **无 `rooms`/`room_exits`**，这是**合法**的（`Elias.parse` 接受，loader 也加载）。
> `validate_ucl.py` 对这类「object-only zone」做窄化豁免（见 §10）。

### 8.2 `characters "<id>" { ... }` 常用字段（实测 loader 消费）

```
characters "xuanming_bai" {
  name = "百损道人"
  aliases = ["xuanming_bai", "baisun", "daoren"]   # 数组
  description = "..."
  gender = "男性"
  age = 72
  combat = { ... }              # 属性块
  skills = [ { skill = "force" level = 320 }, ... ]
  carry = [ { id = items.baipao.id } ]
  inquiries = [ { key = "..." value = "..." }, ... ]   # 数组形态（也支持 map 形态）
  teach = { family = "..." teach_skills = { ... } no_teach = [ ... ] }
  apprentice = { ... }
  ...
}
```

- **`teach` 必须是 wrapper**：`teach = { family=... teach_skills={...} no_teach=[...] }`。
  **裸键（直接 `teach_skills = {...}` 不套 `teach`）会被 loader 丢弃。**
- `skills` 数组元素：`{ skill = "force" level = 320 }`（带等级）或 `{ type = "strike" skill = "..." }`（类型声明）。
- `inquiries` 两种形态都支持：数组 `[{ key=... value=... }, ...]` 或 map `inquiry名 = 值`。

### 8.3 `items "<key>" { ... }` 常用字段

```
items "tiekuai" {
  name = "铁块 Iron Lump"
  aliases = ["tiekuai"]
  description = "..."
  verbs = ["get", "drop"]        # 数组
  messages = { wield = "{npc}..." }   # 可选
  meta = { value = 10 weight = 20 unit = "块" material = "iron" }
}
```

### 8.4 `rooms "<key>" { ... }` 常用字段

```
rooms "guangchang" {
  name = "镇广场"
  description = "..."
  x = 0 y = 1 z = 0
  flags = ["outdoors"]
  item_desc = { 门 = "..." }          # 或 item_desc_dynamic = [ ... ]
  actions = { think = "do_think" }
  valid_leave = [ { direction = "north" message = "..." } ]
  state = { status = 0 }              # 初始 temp
  ...
}
```

### 8.5 引用 id 的最终形态

- 房间 id = `"<zone>:<roomkey>"`（如 `liuxi:guangchang`）
- 物品 id = `"<zone>:<itemkey>"`；任务物品 `"liuxi:task/xxx"`
- 角色 id = `"<zone>:<id>"`
- 引用字段（`room_id = rooms.x.id`、`{ id = items.y.id }`）最终都变成上述字符串。

---

## 9. 本仓库的「真实约定」汇总（写 UCL 时照做）

1. **一个文件一个 `zones`**，`zones` 的 key 必须等于文件名（`liuxi.ucl` → `zones "liuxi"`）。
2. **每行一个 `key = value`**（便于报行号；不要一行塞多个成员，虽然能解析）。
3. **块内成员不写逗号**；**数组元素必须写逗号**，且**末元素不带尾随逗号**。
4. **键只写 `[A-Za-z_][A-Za-z_]*`**；含数字/连字符/中文的键一律换成合法标识符（如 `msg_one`、`msg_two`）。
5. **值里的 `/` 一定加引号**（`"tie-zhang/lei"`、`"liuxi:task/xxx"`）。
6. **布尔用 `true`/`false`**（loader 会转），但要意识到它是字符串 `"true"`。
7. **引用写裸词** `rooms.x.id` / `items.y.id` / `characters.z.id`，或跨区 `<zone>.rooms.x.id`。
8. **`teach` 必须 wrapper**；`no_teach` 是 flat list（map 形态会走 `no_teach_deny` 硬拒）。
9. **字符串里不要写 `;` `[` `]`**；反斜杠 `\` 只能接普通字符或引号（`\n` 是换行约定，合法）。
10. **不要写浮点数**（不支持）。
11. **不要加尾随逗号**（实测报错，别信旧 README）。

---

## 10. 校验与提交（提交前必做）

```bash
python scripts/validate_ucl.py data/world/<zone>.ucl
```

- 通过 → `✅ All checks passed`，exit 0。
- 失败 → 逐行 `❌ <Check>: <detail>`，exit 1。
- 5 项检查：`Encoding`（UTF-8、无 BOM、无 CR）、`Syntax`（递归下降）、
  `Structure`（zones/rooms/room_exits）、`Integrity`（rooms 数 == room_exits 数且 >0）、
  `Chars`（双花括号、尾逗号、奇数引号、`$N`/`$n` 泄漏、`[]` 在串内、重复出口键、
  Python repr、LPC 表达式泄漏、elias 无法分词的三类）。
- **object-only 区（无 rooms）豁免** Structure/Integrity 的「必须>0」与 Chars 的
  `double brace`/`$N`/`$n` 三条（它们描述的是转换器输出布局，对标准库会误报）。
  见 `test/fixtures/validate_ucl/47_ok_object_only_zone.ucl` 与 `48_ok_object_only_chars_exempt.ucl`。
- 真值表：`test/fixtures/validate_ucl/expected.json`（22 个案例，改动校验器后必须全 MATCH）。

---

## 11. 常见错误速查（都已在本仓库真实发生过）

| 你写的 | 现象 | 正确写法 |
|---|---|---|
| `a1 = 5` / `hole6 = ...` | `syntax error before: ...` | 键去掉数字：`a_one`、`hole_six` |
| `a-b = 1` | 报错 | `a_b = 1` |
| `perform_id = tie-zhang/lei` | 报错 | `perform_id = "tie-zhang/lei"` |
| `a = 5.5` | 报错（无浮点） | 用整数或字符串 |
| `a = [-1]` / `[1, -2]` | 报错 | 负数不放数组 |
| `a = [1, 2, 3,]` | 报错（尾逗号） | `a = [1, 2, 3]` |
| `a = [1 2 3]` | 报错（缺逗号） | `a = [1, 2, 3]` |
| `a = "x;y"` | 报错（串内 `;`） | 去掉 `;` 或改写 |
| `a = "x[y]"` | 报错（串内 `[]`） | 去掉 `[]` 或改写成 `( )` |
| `a = "x\\y"`（双反斜杠） | 报错（`\` 后不能接 `\`） | 单写 `\y` 或改写 |
| `a = "x\ y"`（反斜杠+空格） | 报错（`\` 后不能接空格） | 去掉空格或反斜杠 |
| `a = 'hi'` | 报错（单引号） | `a = "hi"` |
| `a = 1 // c` | 报错（无 `//`） | `a = 1 # c` |
| `teach_skills = {...}`（裸键） | 被 loader 丢弃 | `teach = { family=... teach_skills={...} }` |
| 中文键 `乾 = ...` | 报错 | 换合法 ASCII 键 |

---

## 12. 自测片段（改完语法记得跑）

```bash
# 单文件语法验证（权威）
python scripts/validate_ucl.py data/world/<zone>.ucl

# 直接问 Elias（最底层，报错会抛异常）
mix run -e 'File.read!("data/world/<zone>.ucl") |> Elias.parse() |> IO.inspect(label: "ok")'

# 全库扫描（应 77/77 通过）
for f in data/world/*.ucl; do python scripts/validate_ucl.py "$f" >/dev/null 2>&1 || echo "FAIL $f"; done
```

> 记住：**改完 UCL，先 `validate_ucl.py`，再谈提交**。Elias 报错时容器会整体启动失败
> （`Kantele.World.Kickoff terminating`），全服皆挂——所以宁可多跑一次校验。