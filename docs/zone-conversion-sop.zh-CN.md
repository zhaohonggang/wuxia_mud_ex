# 区域转换标准化流程（标准操作规程 SOP）

> 目的：将 `mud/d/<zone>` 的 LPC 源码标准化转换为可加载的 UTF-8 UCL，避免手工修补 UCL 导致的不可复现问题。
> 原则：**只改脚本，不改生成产物**。发现错误 → 定位脚本/参数 → 修复脚本 → 重跑。

### 工具链约定（重要）

三个脚本**一律在宿主机 PowerShell 里用 Python 运行**，不要 `docker exec`：

| 环节 | 命令 | 说明 |
|---|---|---|
| LPC → UCL | `python scripts\lpc_converter.py <语料目录> --zone <zone> --output data\world` | 传目录即自动递归所有 `.c` |
| 赋坐标 | `python scripts\assign_room_coords.py data\world\<zone>.ucl <center>` | 只收 2 个位置参数，**就地覆盖**，不再需要 `--output` |
| 校验 | `python scripts\validate_ucl.py <file.ucl>` | 退出码 0/1/2 |

原因与前提：
- **容器 `wuxia_mud_dev-app-1` 内没有 Python**（`python3: not found`），在容器里跑会直接失败。
- LPC 语料在**宿主机** `C:\files\git\mud\d\<zone>`；容器里的 `/mud/d` 只有 `city`，且不是 bind mount。
- 容器 `/app` 就是本仓库的 bind mount，所以 `data\world\<zone>.ucl` 宿主机与容器**共享同一份**，产出与校验都不需要 `docker cp`。
- **Step 2 的动态加载校验与 Step 5 的冒烟测试都需要进容器**（纯静态校验不够，见 Step 2.2）。
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
#     无需重启容器：data\world 与容器 /app/data\world 是 bind mount 同一份。
#     仓库里没有 World.reload_zone/1 这类按区热更函数（Kantele.World.Loader.load/1
#     一次性加载整个 data/world 目录），所以"动态校验"= 跑加载器的测试。
#     test env 下 config/test.exs 设了 server: false，不会抢 4000/4646 端口。
docker exec -w /app wuxia_mud_dev-app-1 sh -c 'MIX_ENV=test mix test test/kantele/world/'
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

### Step 4 — 坐标产出校验（`validate_ucl.py` + `check_room_coords.py`）
```powershell
python scripts\validate_ucl.py data\world\<zone>.ucl
python scripts\check_room_coords.py data\world\<zone>.ucl
```
赋坐标后 Step 2 的 Integrity 应当**转为通过**（孤儿房已补 `room_exits` 块）。

`check_room_coords.py` 负责几何正确性（`validate_ucl.py` 只管文本/Elias 兼容性），**硬失败项**：
- 每个房间都有 `x`/`y`/`z`
- 从原点房（坐标脚本钉住的中心房 `(0,0,0)`）**沿出口方向 BFS 可达全部房间**
- 没有孤立 `room_exits` 块

**警告项**（输出 `WARNING:`，退出码仍为 0）：
- `W1` 同坐标多房：LPC 出口图里存在菱形（`A-north-B-east-D` 与 `A-east-C-north-D`），两条路径算出同一格，必然叠房。**这是源数据固有现象，不要修**。
- `W2` 出口方向与两端坐标不符：来自预置的非零"锚点"坐标，以及孤儿层被钉在 `(0,0,z)`。同样是源数据固有现象。

> **不要为了消除 W1 去挪动房间。** 曾实现过"坐标冲突时螺旋外扩找空格"，实测会把方向/坐标一致性从 13.0% 打到 41.2%（13 个区共 411 条出口的坐标与其声明方向不符），
> 因为挪动一间房会打断所有指向它的出口方向，并沿其子树级联放大。对小地图而言，"某房偏离邻格一格"远比"411 条出口指向与方向矛盾的坐标"轻。
> **方向一致性优先于坐标唯一性**，该取舍已写入 `assign_room_coords.py` 的模块 docstring。

`check_room_coords.py` 自身也有 fixture 回归（改了它就要跑）：
```powershell
python scripts\test_check_room_coords.py
```
fixture 与权威预期在 `test\fixtures\check_room_coords\`，改动该脚本后必须同步更新 `expected.json`（精确的退出码 + 精确的 problem/warning 集合）。

> **失败处理**：定位 `scripts/assign_room_coords.py` bug（方向向量、BFS 队列、孤儿房堆叠、垂直连接方向） → 修脚本 → **重跑 Step 3**，不得手改坐标。

### Step 5 — 热更加载 + 冒烟测试
```bash
# 5.1 无需 docker cp：data\world 与容器 /app/data\world 是同一份（bind mount）

# 5.2 加载校验（同 Step 2.2：跑加载器测试；新增区域必须整体重载世界，不能靠游戏内
#     `reload` 热更——见 docs/dev-reload-guide.zh-CN.md「不支持热加载：新增 NPC/房间」）
docker exec -w /app wuxia_mud_dev-app-1 sh -c 'MIX_ENV=test mix test test/kantele/world/'

# 5.3 自动化冒烟
docker exec -w /app wuxia_mud_dev-app-1 sh -c 'MIX_ENV=test mix test'

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
# 5. Chars —— [ \t]*}[ \t]*} 、,[ \t]*} 、双引号字节数为偶数、
#    raw $N/$n、字符串内 []、room_exits 块内重复方向键、值里泄漏的 Python repr
```

退出码：`0` 全绿 / `1` 有检查失败或文件读不了 / `2` 参数个数不对。
成功 stdout：`✅ All checks passed: <path>`；失败逐行 `❌ <Check>: <detail>`。

### 回归测试

16 个 fixture + 权威对照表在 `test\fixtures\validate_ucl\`，`expected.json` 记录每个用例的**退出码**与 **`failing_checks` 集合**（多报和漏报都算失败）：

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
| Chars | `41_bad_chars_duplicate_exit_key` | exit 1 |
| Chars | `42_bad_chars_python_repr` | exit 1 |
| Encoding | `50_bad_encoding_crlf` / `51_bad_encoding_bom` / `52_bad_encoding_invalid_utf8` | exit 1 |

> `11_bad_syntax_double_quote` 固定了真实转换器 bug（`direction = ""north""`）。
> `51_bad_encoding_bom` 固定了 Elixir 版 `check_encoding` 漏检 UTF-8 BOM 的缺陷。
> `41_bad_chars_duplicate_exit_key` 固定了 shaolin 的重复 `up` 键（elias 把重复键并成数组，
> loader 的 `String.split` 收到数组就崩）。
> `42_bad_chars_python_repr` 固定了 taishan 的 `_parse_accept_body` 布尔/列表混淆 bug。
> 改 `validate_ucl.py` 后请重跑这 16 例 + `data\world\test.ucl`（应 exit 0）。

> **遗留**：`scripts/validate_ucl.exs` 仍在仓库里，但**完全不可用**——它 `case` 的是 `{:ok,_}` / `{:error,_}`，而 `Elias.parse/1` 成功返回**裸 map**、失败**抛异常**，实测对 100% 输入（含合法文件）都抛 `CaseClauseError`。它另有 2 处已知缺陷：`check_chars` 的 `\s` 误报连续 `}` 行、`check_encoding` 漏检 UTF-8 BOM。这三点已在 `expected.json` 的 `known_exs_defects_do_not_reproduce` 中固化为回归用例，**不要**改回 Elixir 版行为。

---

## 单区域一键跑（示例：baituo）

```powershell
# 1. 转换（宿主机）
python scripts\lpc_converter.py C:\files\git\mud\d\baituo --zone baituo --output data\world

# 2. 校验转换产出（赋坐标前 Integrity 失败属正常，见 Step 2 说明）
python scripts\validate_ucl.py data\world\baituo.ucl
docker exec -w /app wuxia_mud_dev-app-1 sh -c 'MIX_ENV=test mix test test/kantele/world/'

# 3. 备份 + 赋坐标（就地覆盖）
Copy-Item data\world\baituo.ucl data\world_backup\baituo.ucl -Force
python scripts\assign_room_coords.py data\world\baituo.ucl guangchang

# 4. 校验坐标产出（两项都应全绿）
python scripts\validate_ucl.py data\world\baituo.ucl
python scripts\check_room_coords.py data\world\baituo.ucl

# 5. 加载 + 冒烟
docker exec -w /app wuxia_mud_dev-app-1 sh -c 'MIX_ENV=test mix test test/kantele/world/'
docker exec -w /app wuxia_mud_dev-app-1 sh -c 'MIX_ENV=test mix test'
```

## 产出新鲜度自检（改了转换器必跑）

`data/world_backup/<zone>.ucl` 是 SOP Step 3.1 在 `assign_room_coords.py` 就地改写**之前**做的
字节级拷贝，所以它正好等于「当前转换器对该区会产出什么」。重新转换到**各自独立的空目录**再
比对哈希，就能回答「`data/world` 是不是当前脚本的产物」：

```python
# 每个区用自己的 mkdtemp 空目录，绝不能共用一个 —— 共用会让先转的区污染后转的区
out = subprocess.run([PY, CONV, LPC/z, "--zone", z, "--output", mkdtemp()])
assert sha256(out) == sha256(f"data/world_backup/{z}.ucl")
```

当前基线（2026-10-01）：**70 个区中 69 个字节级一致，唯一例外是 `city`，差 8 字节**，就是
`guangchang` 的 `liuxi` 出口：

```
转换到 data/world（已填充）  liuxi = liuxi.rooms.guangchang.id
转换到空目录（集合为空）    liuxi = minimal_world.rooms.guangchang.id
```

这是**设计内的**，不是缺陷：`_INSTALLED_ZONE_IDS` 来自 `--output` 的内容，只有目录被填满时
方向名反查才生效；查不到时退回字面区名，得到一条诚实的悬空引用（loader 会丢弃），而不是把
出口整个删掉。SOP 始终以 `--output data\world` 转换，所以入库产物是可复现的。

> 这个自检是必需的 —— 就是它抓出了 E 项把「未安装」写成**门禁**的那个缺陷（见错误表）。
> **共用一个暂存目录做新鲜度检查，本身就会造成假漂移**，因为后转的区会看见先转区的 `.ucl`。

---

## 全库可达性排查（`world_reachability.py`）

`check_room_coords.py` 只保证**单区内**每间房都能从该区中心房走到，不保证这个区能从世界别处走到。
跨区连通性用另一个工具：

```powershell
# 全库可达率 + 分类明细 + 每区表格
python scripts\world_reachability.py --zones

# 逐个不可达房间回 mud\d\<区> 找同名 .c，打印其 set("exits", ...)
python scripts\world_reachability.py --show-sources

# 机器可读
python scripts\world_reachability.py --json out.json
```

当前基线（2026-10-01）：从 `city:guangchang` 可达 **4115/4455（92.4%）**，340 间不可达，
**全部属于设计/语料层面的原因，无一是转换缺陷**（分类明细见
`docs/ucl-conversion-fix-checklist.zh-CN.md` 的 G 项）。

> ⚠️ **这个工具必须与 loader 侧对账。** 初版因为三个缺陷报成 4099/4455，被
> `test/cross_zone_wiring_test.exs` 里的真实 BFS 抓出来：
> ① 出口值带双引号（`south = "sammatti.rooms.blacksmith.id"`，手工维护区常见）被正则丢弃 ——
>    Elias 解析成字符串、`Loader.dereference/3` 照样能解引用，少算了 29 个房间；
> ② 区名正则不允许连字符（`kissa-jarvi`）；
> ③ BFS 不检查目标房间是否存在，把 58 条悬空出口也计进 `seen`。
>
> 手工维护区里被双引号包住的跨区出口共 3 处：`liuxi:shanlu -south-> "sammatti.rooms.blacksmith.id"`、
> `sammatti:town_square -south-> "kissa-jarvi.rooms.gates.id"`、
> `sammatti:blacksmith -north-> "liuxi.rooms.shanlu.id"`。它们构成
> `city → liuxi → sammatti → kissa-jarvi` 这条链，改这些文件时别把引号去掉（loader 能处理，
> 但任何按文本匹配的诊断工具都会漏）。

判定「真缺陷 vs 语料如此」的顺序：

1. 全语料扫 `/d/<区>/<文件>` 的 inbound 引用，逐行区分**静态出口** / `startroom=` /
   `me->move()` / `#define` 物件路径 / NPC 表 —— 只有静态出口才该被转换；
2. 逐房间比对「LPC 源码图的邻居集合」与「UCL 产物图的邻居集合」，差集才是转换丢失。

> 出口值 `[a,b,c]` 形式的运行时选房，工具按「并集可达」处理。因为加载器每次只挑一个，
> 这是**乐观**读法：报出来的不可达房间在任何取随机结果下都不可达，「有时到不了」的房间不会出现在报告里。

---

## 错误分类与定位表

| 现象 | 可能原因 | 定位脚本 |
|------|----------|----------|
| `Syntax: ... (line N)` 报错 | 字符串含未转义引号/逗号、或括号/数组不闭合 | `scripts\lpc_converter.py` 的 `generate_room_ucl` / `generate_*_ucl` |
| `Encoding:` 失败 | 写出时未强制 UTF-8 / 混入 BOM / 混入 CR | `scripts\lpc_converter.py` 的 `open(..., encoding="utf-8", newline="")` |
| `room_exits` 缺闭合 `}` | 生成时 `}` 与上行合并 | `scripts\lpc_converter.py` 的 `generate_room_ucl` / `build_exits_block` |
| `Chars: double closing brace` | 同行出现 `} }` | `scripts\lpc_converter.py` 的 `build_exits_block` |
| `Syntax: expected '='`（`accept` 块附近） | 转换器把 Python 的 `str(dict)`/`str(list)` 直接插值进 UCL | `scripts\lpc_converter.py` 的 `_parse_accept_body` / `_build_accept_ucl`（注意 `or` 返回的是最后**操作数**，可能是 list 而不是 bool） |
| `Chars: raw Python repr ...` | 同上，`[{'k': 'v'}]` 这类单引号 repr 漏出 | 同上 |
| `Syntax: expected member key`（`item_desc` 附近） | `item_desc` 的 key 是**中文**（如 changan/qunyuys8.c 的 `"床"` / `"大床"`），`_normalize_item_keyword` 把非 ASCII 全替换成 `_` 再剥首尾 → 空 key，产出裸 ` = "..."` | `scripts/lpc_converter.py` 的 `_generate_room_item_desc`（须对**归一化后**的 keyword 判空，中文 key 直接跳过） |
| `Syntax: expected '='`（`items.` 附近） | objects 映射的 key 是**运行时拼接**的路径（如 `"/clone/book/" + books[random(sizeof(books))]`），字符串里含 `/` 被 `_looks_like_path` 误判为路径，basename 变成表达式 | `scripts/lpc_converter.py` 的 `_looks_like_path` / `_room_id_from_path`；须用 `_is_dynamic_expr()` + `_SAFE_ID_RE` 跳过（**注意**：不要为此加 Chars 检查项，shaolin 的 `items.fojing1+random(2).id` 是合法写法会误报） |
| `ERROR: start room '<x>' not found` | 中心房名与产物里的 room id 不一致。转换器 `_norm_id` 把 LPC 文件名中的 `-` 归一为 `_`（`beian-daokou` → `beian_daokou`） | 核对 `docs/mud-d-zone-center-connections.zh-CN.md` 与实际产物里的 `rooms "<id>"`；改文档中心房名，**不要**改脚本 |
| 容器报 `Kantele.World.LoaderError ... elias ... syntax error before: ', ['","']`（**纯静态校验查不出**） | **elias 0.2.8 自身的 leex 分词缺陷**：`Word = [^0-9{}\*\/#\n\[\]=\s'":\;\\-]+` 的排除集里**没有逗号**，所以 leex 最长匹配会把 `a,` 吞成一个 word；但只要逗号前紧邻**数字**（digit 是独立 token），逗号就会单独 lex 成 `comma`，而 `elias_parser.yrl` 的 `words -> ...` 没有 comma 产生式 → 解析中止 | 实测：`(: a, 'b' :)` `(: ab, 'c' :)` `(: a_b, 'c' :)` 能解析；`(: a1, 'b' :)` `(: ask_me_1, 'b' :)` **不能**。值内容不可改且无任何可解析写法（`words` 既无 comma 也无 newline 产生式，反斜杠/多层引号都藏不住逗号）→ `scripts/lpc_converter.py` 的 `_elias_safe_value()` 跳过该值并留 `#` 注释；`validate_ucl.py` 的 `_ELIAS_UNLEXABLE_RE` 负责回归（fixture 44）。**注意**：文本类检查必须先 `_strip_comments()`，否则转换器自己写的说明注释会误报 |
| 容器报 `elias ... syntax error before: ', ['"6"']]'`（**纯静态校验查不出**） | **UCL 的 key 里不能含数字**。`elias_parser.yrl` 只接受 `assignment -> word equality ...`，而 leex 的 `Word` 排除 `0-9`、`Digit = [0-9]+` 是独立 token，所以 `hole6 = rooms.b.id` 被切成 `word "hole"` + `digit "6"` 赋值闭合不了。LPC 源码里确实存在这种方向名（huashan/s.c 的 `"hole1".."hole6"`） | 实测：`hole` `hole_` 能解析；`hole6` `hole_6` `6hole` **都不能**。**值侧不受影响**（`rooms.lockroom6.id` 正常），只有 key 受限 → `scripts/lpc_converter.py` 的 `_EXIT_DIR_RE` 收紧为 `^[A-Za-z_][A-Za-z_]*$`，非法方向跳过并留注释；`validate_ucl.py` 的 `_ELIAS_BAD_KEY_RE` 负责回归（fixture 45）。注意 huashan 那 6 条 `hole*` 是**冗余反向链接**（每个 `lockroomN` 自己都有 `out = rooms.s.id`，且 `kuihua_2 -up-> lockroom1`），跳过不会造成不可达 |
| 容器报 `elias ... syntax error before: ', ['" "']]'`（token 是个**空格**） | **引号串里 `\` 后面跟空白**。`elias_parser.yrl` 只有 `words -> back_slash word words` 和 `words -> back_slash quotes words`，反斜杠接空格/行尾都没有产生式。根因通常是转换器把 LPC 的**行尾续行符 `\`** 保留了：mingjiao/miaorenbuluo.c 的 `@TEXT` 块某行以 `口\` 结尾，本意是换行续接，转换器却先把换行折成空格再留下反斜杠，产出 `口\ 中` | `_LPC_CONTINUATION = \\[ \t]*\r?\n` 必须在**换行转空格之前**应用——已在 `scripts/lpc_converter.py` 的 `_sanitize_ucl_sval()` 开头处理（那是所有字符串的最终出口，heredoc 与普通字面量都覆盖），`_parse_heredocs_from_raw()` 里也加了一道。`validate_ucl.py` 的 `_ELIAS_STRAY_BACKSLASH_RE` 负责回归（fixture 46）。实测：`a\ b` 与结尾 `a\` 失败，`a\bcd` 与普通空格正常 |
| `Chars: duplicate exit key '<dir>' in room_exits '<id>'` | 同一房间同一方向写了两个出口；elias 会并成数组，loader `String.split` 收到数组而崩 | `scripts\assign_room_coords.py` 的 `_add_vertical_exits` / `_merge_new_exits`（垂直连接必须**换用空闲方向**，不能重复用同一方向） |
| 赋坐标后**孤儿房不可达** | 垂直连接因为方向已被占用而被**跳过**，整层挂不上主区 | `scripts\assign_room_coords.py` 的 `_add_vertical_exits`（应从 `UP_DIR_CANDIDATES`/`DOWN_DIR_CANDIDATES` 里挑空闲方向，而不是 `continue`） |
| 某区整区不可达，且**语料里也没有别的区指向它** | 语料本身从未接入，引擎不校验单向可达 | 语料级缺口，不是转换缺陷。`register` 有 4 条 `out = city.rooms.guangchang.id` 但没人走进去；`tulong` 全语料零条 inbound 引用 |
| 某区整区不可达，但语料里有 `startroom = "/d/xxx/..."` 或 `me->move("/d/xxx/...")` | 该区**运行时靠脚本送达**，本来就不该走进去 | 转换器不把 `startroom` / `move()` / 物件表变成出口是正确的。`death`、`jinshe` 属此类 |
| 产物里出现 `# skipped unresolvable object path '/* sizeof() == 5 */ ...'`，房间**该有的 NPC/物件不见了** | `create_body` 是从**原始文本**抽出来的，之前只过 `_strip_cpp_comments`（剥 `//`），**没过 `_strip_c_comments`（剥 `/* */`）**。语料习惯在 `set("objects", ([ ... ]))` 紧前面写一个块注释标注数量：`([ /* sizeof() == 5 */ __DIR__"npc/fujiang" : 1,` —— 注释糊在路径前面，路径就没有 determinate id，整条被丢 | 已在 `scripts\lpc_converter.py` 的 `_parse_lpc()` 里改为 `create_body = _strip_c_comments(_strip_cpp_comments(create_body))`。**实测恢复 19 个物件**：`changan` 8（`bingying1..6` 的府兵+4 卫兵、`dangpu` 店小二、`kezhan` 小二）、`meizhuang` 4、`tiezhang` 3、`death` 1、`hangzhou` 1、`wanjiegu` 1。语料里有 400 个文件的 `create()` 含 `/* */`，但只有这些条目真受影响。`scripts\test_lpc_path_rules.py` G 段有回归断言 |
| SOP 重跑后 `git diff` 里几十个 `.comments.txt` 全是**同样几行在换顺序**，`.ucl` 却没变 | 转换器里遍历了 **set**（`other_fn_names - handled`），而 Python 每进程随机化字符串哈希（`PYTHONHASHSEED`），迭代顺序逐次不同 | `scripts\lpc_converter.py` 的 `_extract_unhandled_content()` 改用 `sorted(unhandled_fn_names)`。**排查手法**：同一区转换两次、显式设不同的 `PYTHONHASHSEED` 再比哈希。修完后 SOP 已幂等 —— 连续两次重跑 `git diff --stat` 完全相同 |
| 转换到**空目录/ 部分目录**后，产物里所有跨区出口变成 `# skipped exit ...` | `_classify_exit_path` 曾把「目标区未安装」写成**门禁**（`if tzone not in installed: skip`），于是产出取决于 `--output` 里恰好有哪些 `.ucl` | 已改成**优先**而非门禁：方向名能反查到已安装 zone 时用它，否则照常输出 `<zone>.rooms.<room>.id`，让 loader 的 `not is_nil` 去处理真死链。见 `scripts/lpc_converter.py` 的 `_INSTALLED_ZONE_IDS` 注释块 |
| 房间明明有 `set("exits", ...)`，产物却没有 `room_exits` 块 | **`set("exits")` 写在了 `create()` 之外的函数里** —— 转换器只从 `create()` 抽 `set()` | 全语料 4287 个含 `set("exits")` 的文件里只有 4 个写在别处，其中 2 个是房间：`death/god1.c`（`reset()`）、`death/lunhuisi.c`（`recreate()`，且它的 `create()` 是故意封死的机关房）。已在 `scripts\lpc_converter.py` 的 `_backfill_exits_outside_create()` 处理：**`create()` 保持权威**，只在完全没有声明出口时回退全文扫描。**危害不只是少两条边** —— 房间变成无出口孤儿后，`assign_room_coords.py` 会给它合成 `up`/`down`，**静默顶替**作者写的出口（`god1` 的 `down : "/d/city/wumiao"` 被换成了本地 `emptyroom`） |
| 同坐标多房（菱形环路） | 朴素 BFS 下两条不同路径算出同一 delta，两房重叠 | `scripts\assign_room_coords.py` 的 `_visit_neighbour`（需用 `_place`/`_free_coord` 做去重放置） |
| `Integrity: rooms(N) != room_exits(M)` | 孤儿房还没有 `room_exits` 块（**赋坐标前属正常**）；若赋坐标后仍失败则是 bug | `scripts\assign_room_coords.py` 的 `drain` / `visit_neighbour` / `orphans` |
| 容器日志 `Delaying ...ChatAction` 刷屏、队列涨到几十上百 | **NPC 闲聊自激反馈环**（运行时缺陷，与转换无关）。`SpawnController.event/2` 对每个收到的事件都跑行为树，NPC 又订阅了 `rooms:<room>`，而 `ChatAction` 恰好发回同一频道——**发言者收到自己的消息**。每条消息引发房间内 N 个 NPC 各掷一次骰，繁殖率 = N × `chat_chance`/100，>1 即指数发散（mingjiao `miaorenbuluo` 放 4 个 `miaozuwushi` × 30 = **1.2**）。LPC 原本在 `call_out` 心跳上评估 | `Kantele.Brain.Conditions.ChatChance`（冷却 + 概率，默认 500 ms）替代裸 `Random`，`ChatAction` 在**发布前**写 session 时间戳。详见 `docs/npc-chat-cooldown.zh-CN.md` |
| 坐标冲突/全 0 | BFS 队列/方向向量/孤儿房逻辑 | `scripts\assign_room_coords.py` |
| `Integrity: no rooms defined` / `Structure: missing rooms, room_exits` | **该区本来就一个房间都没有**（纯物件区）。`mud/d/tangmen` 只有 `obj/feidao.c`、`obj/jili.c`，产物就只有 `zones` + `items` 块。这类文件是**合法的**——elias 能解析，`Loader.load/1` 也带着它正常加载整个世界 | `validate_ucl.py` 的 `_is_object_only_zone()` 做**窄化豁免**：`zones` 块存在 + `rooms` 与 `room_exits` 均为 0 + 至少一个 `items`/`characters` 块（证明转换器确实跑过）。这样「转换器把房间全丢了」仍抓得到——`22_bad_integrity_zero_rooms` 只有 zones 块、无任何物件，**仍然失败**；fixture `47_ok_object_only_zone` 锁定豁免行为。**别与 `special` 混淆**：六道轮回那 6 间房是有房间的，只是完全没有 `set("exits")`，属于另一类，照常走赋坐标即可（`assign_room_coords.py` 会为无出口的孤儿房补 `room_exits` 块并使其可达） |
| 跨区出口指向不存在房间 | 转换器未解析外部路径、或目标区未转 | `scripts\lpc_converter.py` 的 `extract_exit_*`、跨区依赖顺序 |
| 出口写成了 `rooms.<x>.id`，但 `<x>` 在本区不存在（悬空） | **已知源数据缺陷，非转换器问题**：LPC 源码里就写着这个不存在的房间名（房间被作者删除但出口未同步，或裸名指错了区——按 MudOS 语义裸名解析为同目录，或子目录路径写错）。加载器 `dereference/3` 返回 `nil`，`parse_exits/3` 的 `not is_nil` 过滤把它丢弃；elias 与 `validate_ucl.py` 都不报错，产物自洽，只是玩家看不到也走不了这个方向 | **不要在转换器里"发明"目标**。登记留档：`docs/ucl-dangling-exits.zh-CN.md`（当前 18 条 / 9 个区）。若要修，只能改 LPC 语料 `C:\files\git\mud`（外部只读参考，需先确认） |

---

## 文档维护
- 本文档位于 `docs/zone-conversion-sop.zh-CN.md`
- 每完成一个区域，在 `docs/zone-conversion-checklist.zh-CN.md` 打勾并记录：区域、日期、关键修复 commit
- 发现新错误模式 → 追加到「错误分类与定位表」 → 修对应脚本 → 回滚重跑
- **发现任何新的语言错误（包括用户报告的 Elias 解析错误、容器加载失败等） → 必须在 `scripts/validate_ucl.py` 中新增对应检查项，并更新 `test/fixtures/validate_ucl/expected.json` 回归用例 → 重跑全部回归测试确认无误后方可继续**
