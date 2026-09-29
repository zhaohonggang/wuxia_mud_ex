# 任务：将 assign_room_coords.exs 移植为 Python

> 用法：把本文件全文复制到新的 session，作为任务提示词。
> 前提已验证：Elixir 版对 `test_before.ucl` + `damen` 的产出与 `test_after.ucl` 逐字节一致
> （已跑过 `cmp`，结果 IDENTICAL）。

## 任务

把 `scripts/assign_room_coords.exs`（Elixir，804 行）逐行移植为 Python 脚本
`scripts/assign_room_coords.py`。要求是**逐字节一致**，不是"行为大致相同"。

## 验收标准（唯一硬标准）

```
python scripts/assign_room_coords.py data/world_backup/test_before.ucl damen --output <输出文件>
```

产出必须与 `data/world_backup/test_after.ucl` **逐字节相同**（`git diff --no-index` 无输出）。

- `test_before.ucl`：py 转换器输出、未赋坐标（1607 行 / 55554 字节）
- `test_after.ucl`：赋坐标后（1677 行 / 56903 字节），中心房 `damen`
- `data/world_backup/` 下其他文件（test_1/2/3、test_bak、test_assigned、test_no_coords.bak、
  test_zero、test.ucl、test.comments.txt）是历史迭代产物，**忽略、不要修改**。

## 参考实现与风格

`scripts/lpc_converter.py`（2608 行）是 `lib/kantele/world/lpc_converter.ex` 的既有 Python 移植，
已做到与 Elixir 输出逐字节一致。移植手法可参照：

- 用注释标注"模拟 Erlang term 顺序"的排序函数（例：`# Elixir small maps iterate in Erlang term order (bytewise-sorted keys)`）
- `("string", v)` / `("mapping", pairs)` 这类 tagged tuple 模拟 Elixir 结构
- heredoc / 换行拼接的逐字节对齐

命名与代码结构风格跟它保持一致。

## 必须原样复刻的行为（不要"顺手修正"）

目标是保真，包括 .exs 里的缺陷。

1. **`build_exits_block` 的重复右花括号缺陷**（`scripts/assign_room_coords.exs:681` 附近）：

   ```elixir
   non_exit_lines = Enum.filter(content, fn line -> parse_exit_row(line) == nil end)
   ```

   这一步把源块里独立的 `}`（匹配 `^[ \t]*\}[ \t]*$`）也当作"非出口行"保留，随后
   `non_exit_lines ++ exit_lines ++ [closing_brace]` 又追加一个 `}`。因此对只有 `room_id`
   的空 `room_exits` 块（无出口的房间），产出是：

   ```
     room_exits "liandan_lin" {
       room_id = rooms.liandan_lin.id
     }
       up = rooms.liandan_lin1.id
       down = rooms.yujia.id
     }
   ```

   这是真实存在、并已被 `test_after.ucl` 固化的行为，Python 版必须照抄。

2. **重复定义的死代码**：`replace_or_insert/2`（609 与 730）、`exists?/2`（642 与 763）、
   `current_coord/1`（439/459/460）。编译期 warning（"clauses with the same name and arity
   should be grouped together"、"this clause cannot match because a previous clause ... always
   matches"）是既有的；运行时生效的是**第一个**定义。Python 只需实现实际被调用的那份，但要能判断哪份是活的。

3. `@skip_dirs ~w()` 是空列表。`@dirs` 中 `"enter"/"out"/"in"/"go_in"` 为 `{0,0,0}`，
   `"climb"` 等同 `up`，其余为常规方向向量。

4. 不带 `--output` 时 `File.write!(path, new_content)` **原地覆盖输入文件**（`:82-84`）；
   `--dry-run` 把新内容打到 stdout。CLI 用 `OptionParser.parse(args, strict: false)`。

5. `report/4` 的四行 stdout（含对齐空格）也要一致：

   ```
   zone: test_before.ucl  rooms: 34
   anchor rooms (kept non-zero): 0
   rooms assigned new coords:    33
   start room: damen -> (0,0,0)
   ```

   注意 `Path.basename(path)`，以及 `assigned_coord in [nil, current]`（`in` 用 `==` 语义）。

## Elixir → Python 语义陷阱（逐个确认，不要凭直觉）

- `String.split(content, "\n")` 再 `Enum.join(lines, "\n")`：文件末尾若有换行会多出一个空字符串
  元素，round-trip 必须原样还原。
- `File.read!` / `File.write!` 未指定编码 → 按原始字节处理。Python 端用
  `encoding="utf-8", newline=""` 精确控制，禁止任何换行转换。
- **Map 遍历顺序**：≤32 键的小 map 按 term order（键排序）迭代，超过 32 键退化为哈希序。
  `Map.keys/1`、`Enum.reduce(map, ...)` 的顺序会影响输出，必须复刻。先实测 `fields` /
  `exits_map` / `assigned` 各有多少键，必要时显式排序。
- `String.replace/3` 传 Regex 时替换**全部**匹配；传 String 时只替换第一个。
- `Enum.uniq` 保序去重；`List.duplicate/2`。
- `cond` 从上到下取第一个真分支；`if` 作为表达式返回值。
- 正则：Elixir 用 PCRE，Python `re` 基本兼容，注意 `~r/^[ \t]*rooms "([^"]+)"[ \t]*\{/` 的 `\{`。
- 坐标全用整数。

## 环境注意（Windows PowerShell 5.1）

- **不支持 `&&`**，用 `;` 或分多次调用。
- PowerShell 的 `>` 重定向写 UTF-16，**不要**用它生成中间文件。比对文件用
  `git diff --no-index a b`（git 可用）或 Python。
- 跑 Elixir 参考实现需要容器在运行：`docker start wuxia_mud_dev-app-1`，然后

  ```
  docker exec -w /app wuxia_mud_dev-app-1 mix run --no-start scripts/assign_room_coords.exs <in> damen --output /tmp/ref.ucl
  ```

  - `--no-start` 必须加，否则会启动整个应用、加载 world、抢 4646 端口，产生噪声。
  - `/app` 是宿主工作区 `C:\files\git\wuxia_mud_ex` 的 bind mount，文件互通。
  - `mix run` 每次重新编译脚本，那些 warning 是既有的，不是你引入的。
  - 用完 `docker exec wuxia_mud_dev-app-1 rm -f /tmp/ref.ucl` 清理。

- 宿主已有 Python 3.13：`python scripts\assign_room_coords.py ...`

## 约束

- 只新增/修改 `scripts/assign_room_coords.py`。**不要**改 `assign_room_coords.exs`，
  不要手改 `test_before.ucl` / `test_after.ucl`（验收基准），不要 commit。
- 遵守 `docs/zone-conversion-sop.zh-CN.md`："只改脚本，不改生成产物"。
- 纯 Python 实现，运行时不得依赖 Elixir / mix / 容器。优先只用标准库
  （re / argparse / pathlib）；若确需第三方库，先说明理由。

## 交付

1. `scripts/assign_room_coords.py`，CLI 与 .exs 一致：
   `<zone.ucl> <start_room_id> [--dry-run|--output <file>]`
2. 贴出验证结果（无输出即通过）：

   ```
   python scripts\assign_room_coords.py data\world_backup\test_before.ucl damen --output %TEMP%\py_out.ucl
   git diff --no-index data\world_backup\test_after.ucl %TEMP%\py_out.ucl
   ```

3. 若为做到逐字节一致而对某些 Elixir 行为做了近似或假设，逐条列出。
