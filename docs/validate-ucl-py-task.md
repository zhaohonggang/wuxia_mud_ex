你是本仓库的新会话实现者。任务：把 Elixir 的 UCL 校验器 `scripts/validate_ucl.exs` 移植为纯 Python 的 `scripts/validate_ucl.py`，并用已备好的回归 fixture 验证正确性。

以下背景全部由上一会话**实测**确认，直接当作事实使用，不要重新论证，也不要试图"复刻"这些缺陷。

## 背景事实

1. 仓库根：`C:\files\git\wuxia_mud_ex`。容器 `wuxia_mud_dev-app-1` 的 `/app` 是它的 bind mount。
2. **`scripts/validate_ucl.exs` 目前完全不可用，不能作为 oracle。** 它的 `check_syntax/1` 写成
   `case Elias.parse(content) do {:ok, _} -> ...; {:error, err} -> ... end`，
   但 `deps/elias/lib/elias.ex` 的 `parse/1` 成功时返回**裸 map**，失败时 `Elias.Parser.parse_tokens/1` 直接**抛异常**。
   实测：对任何文件（包括完全合法的文件）都抛 `** (CaseClauseError) no case clause matching: %{zones: %{...}, ...}` 并中止。
3. 另两个已实测确认的缺陷：
   - `check_chars/1` 的 `~r/^\s*}\s*}/m` 与 `~r/,\s*}/m` 中 `\s` 会匹配换行。真实转换器产物里 `item_desc` 的 ` }` 紧跟 rooms 块的 `    }`（两个只含 `}` 的相邻行），会被**误判**为 "double closing brace"。
   - `check_encoding/1` 只检查 `FF FE`（UTF-16LE BOM），**不检查 UTF-8 BOM**（`EF BB BF`），导致带 UTF-8 BOM 的文件被判为通过。
4. 其他实测结论：
   - Elias 对 CRLF 文件解析**成功**。
   - Elias 对非法 UTF-8 文件抛出 `invalid encoding starting at <<255, 254, 10>>`。
   - `Elias.parse/1` 成功返回 `%{zones: %{...}, rooms: %{...}, room_exits: %{...}}` 形式的 map。

## 任务边界（硬约束）

- 只允许**新增** `scripts/validate_ucl.py`。
- 禁止修改：`scripts/validate_ucl.exs`、`test/fixtures/validate_ucl/**`、`data/world/**`、`data/world_backup/**`、任何 Elixir 源码、`mix.exs`、既有文档。
- 纯标准库实现，不新增任何依赖。
- 不要 `git add`，不要 `git commit`。
- 语义按**修正后**的行为实现（下节规格）。**不要**复刻上述 3 个缺陷。

## CLI 契约

`python scripts\validate_ucl.py <file.ucl>`

- 无参数或参数多于 1 个 → 向 stderr 打印用法，exit 2。
- 文件不存在或不可读 → stderr 打印 `❌ IO: cannot read <path>`，exit 1。
- 5 项检查全部通过 → stdout 打印 `✅ All checks passed: <命令行传入的路径字符串>`，exit 0。
- 任意检查失败 → stdout 按固定顺序每项打印一行 `❌ <Check>: <detail>`，`<Check>` 为 `Encoding` / `Syntax` / `Structure` / `Integrity` / `Chars`，exit 1。
- 5 项检查**全部执行**，任何一项失败都**不得**短路。
- 任何输入都**不得**抛未捕获异常或打印 traceback（包括非法 UTF-8、截断文件）。

## 5 项检查的规格

### 1. Encoding
读原始字节。任一违反即 fail，detail 指明违反哪条：
- 不能以合法 UTF-8 解码 → `not valid UTF-8`
- 以 `EF BB BF` 开头 → `UTF-8 BOM not allowed`
- 以 `FF FE` 开头 → `UTF-16LE BOM not allowed`
- 含任意 `0x0D` 字节 → `CR found, LF-only required`

### 2. Syntax
自写**最小 UCL 递归下降解析器**。不需要覆盖完整 UCL，只需覆盖 `scripts/lpc_converter.py` 真实产物的语法子集：
- 顶层 `name "value" { ... }` 与 `name { ... }` 块；
- 块内 `key = value`；
- **内联嵌套对象 `key = { ... }`（递归）**——必须支持，否则 fixture 02 的 `item_desc = { ... }` 会解析失败；
- 数组 `[ ... ]`，可为空、可跨多行、元素可为 `{ k = v }`；
- 标量：双引号字符串（支持 `\"` 转义）、数字、裸标识符（含 `rooms.damen.id` 这类带点的引用）、`[]`、`{}`；
- 注释 `#` 到行尾；闭合花括号可与值粘连在行尾，如 `north = rooms.a.id  }`。

要求：必须接受全部 `*_ok_*` fixture；必须拒绝 `10`、`11`、`12`、`40`、`52`。失败 detail 必须含 1-based 行号。
注意：不要因为"顶层只有一个 zones 块"就假定其余内容合法，解析器要真正逐 token 消费。

### 3. Structure
全文 multiline 搜索三个模式，缺哪个就在 detail 里列出哪个：
`^\s*zones\s+"\w+"`、`^\s*rooms\s+"\w+"`、`^\s*room_exits\s+"\w+"`

### 4. Integrity
- `rooms_count` = `^\s*rooms\s+"(\w+)"` 的匹配数；`room_exits_count` = `^\s*room_exits\s+"(\w+)"` 的匹配数。
- 通过条件：两者相等 **且** `rooms_count > 0`。
- detail 形如 `rooms(N) != room_exits(M)` 或 `no rooms defined`。

### 5. Chars
三条子规则。**这里必须用 `[ \t]`，不能用 `\s`**：
- `^[ \t]*}[ \t]*}` → `double closing brace`
- `,[ \t]*}` → `trailing comma before }`
- 全文 `"` 字节总数为奇数 → `unpaired double quote`

## 验收标准

`test/fixtures/validate_ucl/expected.json` 是权威对照表（已实测）。逐条比对：**退出码必须完全一致，`failing_checks` 集合必须完全一致**——多报和漏报都算失败。

摘要（exit / failing_checks）：
```
01_ok_minimal.ucl                   0 / []
02_ok_nested_consecutive_braces.ucl 0 / []           # 旧 check_chars 误报，必须放行
03_ok_comments_with_quotes.ucl      0 / []
10_bad_syntax_unclosed.ucl          1 / [syntax]
11_bad_syntax_double_quote.ucl      1 / [syntax]     # lpc_converter 引号 bug 回归
12_bad_syntax_unbalanced_quote.ucl  1 / [syntax, chars]
20_bad_structure_no_zone.ucl        1 / [structure]
21_bad_structure_no_exits.ucl       1 / [structure, integrity]
22_bad_integrity_zero_rooms.ucl     1 / [structure, integrity]
30_bad_integrity_mismatch.ucl       1 / [integrity]
40_bad_chars_double_close.ucl       1 / [syntax, chars]
50_bad_encoding_crlf.ucl            1 / [encoding]
51_bad_encoding_bom.ucl             1 / [encoding]    # 旧 check_encoding 漏报，必须拦下
52_bad_encoding_invalid_utf8.ucl    1 / [encoding, syntax]
```

## 验证步骤

1. 写一个临时 harness 遍历 `test/fixtures/validate_ucl/*.ucl`，用 `subprocess` 调用 `python scripts\validate_ucl.py <path>`，把 exit code 与 stdout 中的 `❌ <Check>:` 解析成集合，与 `expected.json` 逐条比对。全部一致才算通过。
2. 真实产物回归，以下三份必须 exit 0 并打印成功行：
   - `data\world\test.ucl`
   - `data\world_backup\test_before.ucl`
   - `data\world_backup\test_after.ucl`
3. 反向验证：把 `.exs` 那 3 个缺陷的判定逻辑（`\s` 版 chars、只查 `FF FE` 的 encoding）在内存里单独实现一份做对照，证明差异**恰好**落在 `02`、`11`、`51` 三例上。
4. 汇报时给出逐 fixture 对照表和三份真实产物的结果，并说明每个用例对应的检查项。完成后停止，不要 commit。
