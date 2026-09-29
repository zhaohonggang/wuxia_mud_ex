# 区域转换标准化流程（标准操作规程 SOP）

> 目的：将 `mud/d/<zone>` 的 LPC 源码标准化转换为可加载的 UTF-8 UCL，避免手工修补 UCL 导致的不可复现问题。
> 原则：**只改脚本，不改生成产物**。发现错误 → 定位脚本/参数 → 修复脚本 → 重跑。

### 工具链约定（重要）

三个脚本**一律在宿主机 PowerShell 里用 Python 运行**，不要 `docker exec`：

| 环节 | 命令 | 说明 |
|---|---|---|
| LPC → UCL | `python scripts\lpc_converter.py <语料目录> --zone <zone> --output data\world` | 传目录即自动递归所有 `.c` |
| 赋坐标 | `python scripts\assign_room_coords.py <zone>.ucl <center> --output <输出>` | 只收 2 个位置参数 |
| 校验 | `python scripts\validate_ucl.py <file.ucl>` | 退出码 0/1/2 |

原因与前提：
- **容器 `wuxia_mud_dev-app-1` 内没有 Python**（`python3: not found`），在容器里跑会直接失败。
- LPC 语料在**宿主机** `C:\files\git\mud\d\<zone>`；容器里的 `/mud/d` 只有 `city`，且不是 bind mount。
- 容器 `/app` 就是本仓库的 bind mount，所以 `data\world\<zone>.ucl` 宿主机与容器**共享同一份**，产出与校验都不需要 `docker cp`。
- 只有 Step 5 的热更加载与 `mix test` 需要进容器。
- Elixir 版 `scripts/assign_room_coords.exs` / `scripts/validate_ucl.exs` / `lib/kantele/world/lpc_converter.ex` 与 mix task `kantele.convert_lpc` **仍然存在**（部分 dev 辅助脚本仍在用），但**已不是主流程**，仅作遗留参考。

---

## 标准化流程（5 步闭环）

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. RUN CONVERTER          │  python scripts\lpc_converter.py        │
│      (LPC → UCL)          │  输出：<zone>.ucl + <zone>.comments.txt  │
├─────────────────────────────────────────────────────────────────────┤
│ 2. VALIDATE + LOAD TEST   │  python validate_ucl.py + reload_zone   │
│      (静态+动态校验)      │  全绿 + 容器能加载才能进下一步           │
├─────────────────────────────────────────────────────────────────────┤
│ 3. RUN COORDINATES        │  python assign_room_coords.py           │
│      (就地赋坐标+备份)    │  先备份 world_backup，再原地改写         │
├─────────────────────────────────────────────────────────────────────┤
│ 4. VALIDATE COORDS        │  python validate_ucl.py                 │
│      (坐标/编码/语法)     │  必须全绿才能进下一步                   │
├─────────────────────────────────────────────────────────────────────┤
│ 5. LOAD & SMOKE TEST      │  热更加载 + 自动冒烟测试 + 人工巡游      │
│      (热更/冒烟/人工)     │  通过 → 下一区域；失败 → 回步骤 1/3    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 详细步骤清单（每个区域必跑）

### Step 1 — 运行转换器
```powershell
# 宿主机 PowerShell，在仓库根目录执行
python scripts\lpc_converter.py C:\files\git\mud\d\<zone> --zone <zone> --output data\world

# 产出：
#   data\world\<zone>.ucl          （容器内即 /app/data\world\<zone>.ucl）
#   data\world\<zone>.comments.txt （注意是点号 .comments.txt，不是 _comments.txt）
```

> ⚠️ **重跑会清掉坐标**：目录模式是**整体覆盖** `<zone>.ucl`，不保留已赋的 `x/y/z`。
> 需要保留坐标时，先 `git stash`/备份，或改用 Step 3 的产物作为基准。

### Step 2 — 产出校验（自动化脚本 `validate_ucl.py` + 游戏加载验证）
```powershell
# 2.1 静态校验（5 项全绿）
python scripts\validate_ucl.py data\world\<zone>.ucl

# 2.2 动态加载校验（确认 Elixir/Elias 真正能解析并加载）
#     无需重启容器：data\world 与容器 /app/data\world 是 bind mount 同一份
docker exec wuxia_mud_dev-app-1 iex --remsh app@<host> -e 'World.reload_zone("<zone>")'
```
**校验项**（5 项全部执行、互不短路；失败时逐行打印 `❌ <Check>: <detail>`）：

| 类别 | 检查点 | 失败即阻断 |
|------|--------|------------|
| Encoding | 合法 UTF-8、无 UTF-8 BOM、无 UTF-16LE BOM、无 CR（只允许 LF） | ✅ |
| Syntax | 内置最小 UCL 递归下降解析器能完整解析（不依赖容器/Elias） | ✅ |
| Structure | 存在 `zones "<zone>"`、`rooms "..."`、`room_exits "..."` 三类块 | ✅ |
| Integrity | `rooms "..."` 数量 == `room_exits "..."` 数量，且 > 0 | ✅ |
| Chars | 无同行 `} }`、无 `, }`、双引号成对 | ✅ |

退出码：`0` 全绿 / `1` 有检查失败（或文件读不了）/ `2` 参数个数不对。

> **注意**：Step 2 的 Integrity 只比对 `rooms` 与 `room_exits` 的**数量**，**不做逐房间匹配**。
> 转换刚产出、尚未赋坐标时，孤儿房间还没有 `room_exits` 块，因此 Integrity 失败是**正常**的（例如 `data/world_backup/test_before.ucl` 是 34 rooms / 33 room_exits，房间 `liandan_lin` 缺块，赋坐标后补齐）。**这正是 Step 3 存在的意义**，不要因此判定转换器有 bug。
> 若要断言"逐房间都有出口"，需另写检查，参考 Step 4 的人工项。

> **失败处理**：定位是转换器 bug（如字符串未转义、括号不匹配） → 修 `scripts\lpc_converter.py` → **重跑 Step 1**，不得手改 `.ucl`。

### Step 3 — 运行坐标脚本（就地覆盖 <zone>.ucl，备份到 world_backup）
```powershell
# 3.1 先备份原始转换产物（供对比/回滚）
Copy-Item data\world\<zone>.ucl data\world_backup\<zone>.ucl -Force

# 3.2 直接就地赋坐标（不再产出 <zone>_coords.ucl）
python scripts\assign_room_coords.py data\world\<zone>.ucl <center_room>
```
- `<center_room>` 取自 `docs/mud-d-zone-center-connections.zh-CN.md`
- 只接受 `<zone.ucl> <start_room_id>` 两个位置参数（**没有** zone 名参数）
- **不带 `--output` 即就地覆盖输入文件**（原有 `--output` 仍可用，但新流程不再需要中间文件）
- 选项只认长形式：`--dry-run`（打印不写盘）、**`--output <file>` 或 `--output=<file>`**。**`-o` 不存在且会被静默吞掉**，误用会导致就地覆盖

### Step 4 — 坐标产出校验（复用 `validate_ucl.py` + 额外人工检查）
```powershell
python scripts\validate_ucl.py data\world\<zone>.ucl
```
赋坐标后 Step 2 的 Integrity 应当**转为通过**（孤儿房已补 `room_exits` 块）。

以下检查**不由脚本覆盖**，需人工或另行核对：
- 所有 `rooms` 有非零坐标（或显式 `(0,0,0)` 仅限中心房）
- 坐标无冲突（同坐标不超过 1 个房间）
- 中心房坐标为 `(0,0,0)`
- BFS 连通：从中心房可达所有本区房间
- 每个 `room_exits` 目标要么本区 `rooms.<id>.id`，要么外部绝对路径

> **失败处理**：定位 `scripts/assign_room_coords.py` bug（方向向量、BFS 队列、孤儿房堆叠） → 修脚本 → **重跑 Step 3**，不得手改坐标。

### Step 5 — 热更加载 + 冒烟测试
```bash
# 5.1 无需 docker cp：data\world 与容器 /app/data\world 是同一份（bind mount）
#     Step 3 产出的 <zone>_coords.ucl 需先就位为 <zone>.ucl，再热更

# 5.2 热更（不重启容器）
docker exec wuxia_mud_dev-app-1 iex --remsh app@<host> -e 'World.reload_zone("<zone>")'

# 5.3 自动化冒烟
docker exec wuxia_mud_dev-app-1 mix test test/zone_<zone>_test.exs

# 5.4 人工巡游（巫师号）
#   goto <zone>/<center> → walk 全图 → 检查 exits/描述/NPC/物品/任务
#   记录：test_logs/<zone>_wizard_<date>.md

# 5.5 玩家验收（可选）
#   从 city 走官道进区 → 完成主线/战斗/技能 → 传送回城
#   记录：test_logs/<zone>_player_<date>.md
```

---

## 自动化校验脚本 `validate_ucl.py`

```powershell
# 用法
python scripts\validate_ucl.py <file.ucl>
```

纯标准库实现（仅用 `re` / `sys`），**不依赖容器、不依赖 Elixir/Elias**。5 项检查全部执行、互不短路，任何输入都不抛未捕获异常。

```python
# scripts/validate_ucl.py（370 行，要点）
CHECK_ORDER = ["Encoding", "Syntax", "Structure", "Integrity", "Chars"]

# 1. Encoding —— 原始字节
#    合法 UTF-8；非 EF BB BF(UTF-8 BOM) 开头；非 FF FE 开头；不含 0x0D
# 2. Syntax —— 内置最小 UCL 递归下降解析器
#    覆盖 lpc_converter.py 真实产物的子集：name "v" { } 块、key = value、
#    内联嵌套对象 key = { }、数组 [ ]（可空/跨行/元素可为 { k = v }）、
#    标量（双引号字符串含 \" 转义、数字、rooms.damen.id 形式的引用、[]、{}）、
#    # 行注释、闭合 } 可与值粘连。失败给出 1-based 行号。
#    注意用 [ \t] 而非 \s 判断同行双闭括号（\s 会匹配换行而误报）
# 3. Structure —— 全文 multiline 搜 zones "…" / rooms "…" / room_exits "…"
# 4. Integrity —— rooms 数 == room_exits 数 且 > 0
# 5. Chars —— [ \t]*}[ \t]*} 、,[ \t]*} 、双引号字节数为偶数
```

退出码：`0` 全绿 / `1` 有检查失败或文件读不了 / `2` 参数个数不对。
成功 stdout：`✅ All checks passed: <path>`；失败逐行 `❌ <Check>: <detail>`。

### 回归测试

14 个 fixture + 权威对照表在 `test\fixtures\validate_ucl\`，`expected.json` 记录每个用例的**退出码**与 **`failing_checks` 集合**（多报和漏报都算失败）：

```powershell
# 逐个跑，人工核对
Get-ChildItem test\fixtures\validate_ucl\*.ucl | ForEach-Object {
  python scripts\validate_ucl.py $_.FullName
  "exit=$LASTEXITCODE  <- $($_.Name)"
}
```

| 类别 | 用例 | 预期 |
|---|---|---|
| 应通过 | `01_ok_minimal` / `02_ok_nested_consecutive_braces` / `03_ok_comments_with_quotes` | exit 0 |
| Syntax | `10_bad_syntax_unclosed` / `11_bad_syntax_double_quote` / `12_bad_syntax_unbalanced_quote` | exit 1 |
| Structure | `20_bad_structure_no_zone` / `21_bad_structure_no_exits` | exit 1 |
| Integrity | `22_bad_integrity_zero_rooms` / `30_bad_integrity_mismatch` | exit 1 |
| Chars | `40_bad_chars_double_close` | exit 1 |
| Encoding | `50_bad_encoding_crlf` / `51_bad_encoding_bom` / `52_bad_encoding_invalid_utf8` | exit 1 |

> `11_bad_syntax_double_quote` 固定了真实转换器 bug（`direction = ""north""`）。
> `51_bad_encoding_bom` 固定了 Elixir 版 `check_encoding` 漏检 UTF-8 BOM 的缺陷。
> 改 `validate_ucl.py` 后请重跑这 14 例 + `data\world\test.ucl`（应 exit 0）。

> **遗留**：`scripts/validate_ucl.exs` 仍在仓库里，但**完全不可用**——它 `case` 的是 `{:ok,_}` / `{:error,_}`，而 `Elias.parse/1` 成功返回**裸 map**、失败**抛异常**，实测对 100% 输入（含合法文件）都抛 `CaseClauseError`。它另有 2 处已知缺陷：`check_chars` 的 `\s` 误报连续 `}` 行、`check_encoding` 漏检 UTF-8 BOM。这三点已在 `expected.json` 的 `known_exs_defects_do_not_reproduce` 中固化为回归用例，**不要**改回 Elixir 版行为。

---

## 单区域一键跑（示例：baituo）

```powershell
# 1. 转换（宿主机）
python scripts\lpc_converter.py C:\files\git\mud\d\baituo --zone baituo --output data\world

# 2. 校验转换产出（赋坐标前 Integrity 失败属正常，见 Step 2 说明）
python scripts\validate_ucl.py data\world\baituo.ucl
docker exec wuxia_mud_dev-app-1 iex --remsh app@<host> -e 'World.reload_zone("baituo")'

# 3. 备份 + 赋坐标（就地覆盖）
Copy-Item data\world\baituo.ucl data\world_backup\baituo.ucl -Force
python scripts\assign_room_coords.py data\world\baituo.ucl guangchang

# 4. 校验坐标产出（应全绿）
python scripts\validate_ucl.py data\world\baituo.ucl

# 5. 热更 + 冒烟（这两步才需要进容器）
docker exec wuxia_mud_dev-app-1 iex --remsh app@<host> -e 'World.reload_zone("baituo")'
docker exec -w /app wuxia_mud_dev-app-1 mix test test/zone_baituo_test.exs
```

---

## 错误分类与定位表

| 现象 | 可能原因 | 定位脚本 |
|------|----------|----------|
| `Syntax: ... (line N)` 报错 | 字符串含未转义引号/逗号、或括号/数组不闭合 | `scripts\lpc_converter.py` 的 `generate_room_ucl` / `generate_*_ucl` |
| `Encoding:` 失败 | 写出时未强制 UTF-8 / 混入 BOM / 混入 CR | `scripts\lpc_converter.py` 的 `open(..., encoding="utf-8", newline="")` |
| `room_exits` 缺闭合 `}` | 生成时 `}` 与上行合并 | `scripts\lpc_converter.py` 的 `generate_room_ucl` / `build_exits_block` |
| `Chars: double closing brace` | 同行出现 `} }` | `scripts\lpc_converter.py` 的 `build_exits_block` |
| `Integrity: rooms(N) != room_exits(M)` | 孤儿房还没有 `room_exits` 块（**赋坐标前属正常**）；若赋坐标后仍失败则是 bug | `scripts\assign_room_coords.py` 的 `drain` / `visit_neighbour` / `orphans` |
| 坐标冲突/全 0 | BFS 队列/方向向量/孤儿房逻辑 | `scripts\assign_room_coords.py` |
| 跨区出口指向不存在房间 | 转换器未解析外部路径、或目标区未转 | `scripts\lpc_converter.py` 的 `extract_exit_*`、跨区依赖顺序 |

---

## 文档维护
- 本文档位于 `docs/zone-conversion-sop.zh-CN.md`
- 每完成一个区域，在 `docs/zone-conversion-checklist.zh-CN.md` 打勾并记录：区域、日期、关键修复 commit
- 发现新错误模式 → 追加到「错误分类与定位表」 → 修对应脚本 → 回滚重跑