# LPC→UCL 转换器使用文档（LPCConverter）

> ## 🛑 已归档（2026-10-01）—— 转换器工作已完成，不再运行转换器
>
> LPC → UCL 转换已全部完成并验收（checklist A–I 全 ✅、3018 tests / 0 failures、
> 全库可达 4115/4455、跨区悬空 0）。**本文件是当时的使用手册，仅作历史/参考保留**，
> 不是当前主流程；后续在 `data/world` 及各区 UCL 上的改动请改用新的方法。
> 若确需重出/修改某区 UCL，须先阅读 `docs/ucl-conversion-fix-checklist.zh-CN.md`
> 与 `docs/zone-conversion-sop.zh-CN.md`（已归档）的「产出新鲜度自检」，恢复可复现
> 环境后再做。

> 关联代码：**主用实现** `scripts/lpc_converter.py`（2608 行，Python）；**遗留/参考** `lib/kantele/world/lpc_converter.ex`（3166 行，Elixir）、`lib/mix/tasks/kantele.convert_lpc.ex`（Mix task）
> 消费方：`lib/kantele/world/loader.ex`（载入 `data/world/*.ucl`）
> 语料：`C:\files\git\mud\d\`（7140 个 `.c`）→ 分析样本见 `lpc_example/`，测试世界见 `test_minimal_world_v2_modified/`
>
> Elixir 版**仍然存在且仍被使用**（mix task、仓库根的 `classify_file.exs` / `batch_classify.exs` / `_genlist.exs`、Elixir 单测都还调它），
> 但**日常转换走 Python**：容器 `wuxia_mud_dev-app-1` 内没有 Python，Python 只能在宿主机跑。
> 两个实现需**同步维护**，改动解析行为时两边都要改（详见 `lpc-converter-extension-plan.zh-CN.md` 顶部说明）。

---

## 一、是什么

把 Lua 风格 LPC 源文件（`.c`）转换成本项目 `Kantele.World.Loader` 能直接解析的 **UCL 数据文件**（写进 `data/world/*.ucl`）。编译器不做运行时解释，只把"数据型内容"语义成 UCL，把"逻辑型内容"保留为带函数名/条件/行号的注释，保证信息不丢。

### 支持的 LPC 语法

- `set(key, value)` / `set_name(name, aliases)`
- `inherit X;`（含 `#define` 宏继承，如 `#define LIANDAN_LIN __DIR__"liandan_lin"` 后 `inherit LIANDAN_LIN;`）
- 继承链合并（父类属性为底、子类覆盖；循环继承以 `source_path` 去重防死循环）
- heredoc 字符串 `@LONG ... LONG`
- mapping（`([ key : value, ... ])`）与 array（`({ ... })`）
- `__DIR__` 宏解析为相对路径
- room / npc / item / skill 常见 `set` 字段模式
- 编码转换：源文件通常是 **GBK/GB2312**，自动转 UTF-8（已是合法 UTF-8 则原样保留）

---

## 二、最简用法：Python CLI

> ⚠️ **务必在宿主机 PowerShell 里跑，不要 `docker exec`**。
> - 容器 `wuxia_mud_dev-app-1` **没有 Python**（`python3: not found`），只有 Elixir/OTP。
> - LPC 语料在**宿主机** `C:\files\git\mud\d\<zone>`（7140 个 `.c`）；容器内 `/mud/d` 只有一个 `city` 目录且**不是 bind mount**，容器里读不到全量语料。
> - 容器 `/app` 就是仓库 `C:\files\git\wuxia_mud_ex` 的 **bind mount**，所以宿主机 `data\world\x.ucl` ≡ 容器 `/app/data/world/x.ucl` —— **不需要 `docker cp`**，宿主机转换完，容器内 `Kantele.World.Loader` 立刻就能读到。
> - 宿主机需自备 Python 3（本机为 3.14）。PowerShell **不支持 `&&`**；需要写文件时请用 Python 或 `Set-Content -Encoding UTF8`（PowerShell 的 `>` 会产出 UTF-16 文件）。

```powershell
# 单个文件
python scripts\lpc_converter.py lpc_example\room\room_qianting.c --zone liuxi

# 目录（自动递归，无需任何递归开关）
python scripts\lpc_converter.py lpc_example\room --zone liuxi

# 真实语料：整个区域一次性转换
python scripts\lpc_converter.py C:\files\git\mud\d\beijing --zone beijing

# 换输出目录（默认 data\world；仅调试用，别把产物写进 data\world 以外的正式路径）
python scripts\lpc_converter.py C:\files\git\mud\d\wudang --zone wudang --output C:\temp\ucl_out
```

### 参数

| 参数 | 说明 | 默认 |
|---|---|---|
| `PATH`（位置参数） | 单个 `.c` 文件，或一个目录 | 必填 |
| `--zone <id>` | 输出 zone id | 目录模式按**父目录名**推断；单文件模式也按父目录名推断（见下方说明） |
| `--output <dir>` | UCL 输出目录 | `data/world` |

**没有 `--recursive`，也没有 `--single`。** `PATH` 是目录就**自动递归**遍历其下所有 `.c`（等价 `Path.wildcard(dir/**.c)`：先目录、后文件，各自字典序）；`PATH` 是文件就只转这一个。Python CLI 源码里虽然会解析 `--recursive` 开关，但该变量从未被使用（死代码），**写了也没有任何效果**，不要依赖它。

### Python 脚本行为

- 对象 id 取文件 rootname，`-` → `_`（`worker-liu.c` → `worker_liu`），用于目录模式内的同名去重。
- 输出文件：`<output>\<zone>.ucl`，首行自动补 `zones "<zone>" { name = "<zone>" }`。
- **注释单独写 `<output>\<zone>.comments.txt`**（注意是**点号** `.comments.txt`，不是下划线 `_comments.txt`）。ucl 正文只放数据型内容，注释型内容（generic/skill 提示、UNHANDLED 兜底）只进 comments 文件。
- **去重**（⚠️ 两种模式行为不同，务必分清）：
  - **单文件模式**：会读已存在的 `<zone>.ucl`，若其中已含 `# Generated from <path> by LPCConverter` 或同名 `rooms "..."` / `characters "..."` / `items "..."`，打印 `<id> already exists in <file>, skipping append` 并**跳过追加**；否则打印 `Appended to <file>`；文件不存在则打印 `Created <file>`。
  - **目录模式**：先把所有对象在内存里累积、按对象 id 去重（同 id 只保留首次出现），最后**整体覆盖**写出 `<zone>.ucl` 和 `<zone>.comments.txt`，结束打印 `Wrote N objects to <file>` 与 `Wrote comments to <file>`（有失败文件再补一行 `Failed on N files: [...]`）。**目录模式不做"已存在就跳过"检查，也不追加** —— 它每次都重写整个 zone 文件。混用两种模式时注意这个差别。
- **`--zone` 推断规则**：CLI 一律按 **PATH 的父目录名**（`-` → `_`）。这与模块 API 不同（`convert_file` 省略 `zone_id` 时按**文件名**推断），见 §三。

---

## 三、直接调用模块 API

### `convert_file(lpc_path, zone_id=None, base_path=None, include_comments=True, include_header=True)`

Python 版返回**三元组** `(ucl, comments, err)` —— **不是** Elixir 的 `{:ok, _}` / `{:error, _}`。成功时 `err is None`，失败时前两项为 `None`、`err` 为错误字符串。

在**仓库根目录**下，两种导入方式都可用（已实测）：

```python
# 方式 A：仓库根当作包根（scripts/ 无 __init__.py，靠 Python 3.3+ 隐式命名空间包）
from scripts.lpc_converter import convert_file

# 方式 B：把 scripts/ 直接挂到 sys.path
import sys
sys.path.insert(0, "scripts")
import lpc_converter
convert_file = lpc_converter.convert_file
```

用法：

```python
ucl, comments, err = convert_file(
    r"test_minimal_world_v2_modified\room\bet.c",
    zone_id="test",              # 缺省则按【文件名】rootname 推断（- → _），如上例会推断成 "bet"
    base_path=None,              # 缺省取 lpc_path 的 dirname；用于解析 __DIR__ / inherit 的相对根
    include_comments=True,       # 缺省 True
    include_header=True,         # 缺省 True，控制是否写 "# Generated from ..." 头
)
if err is not None:
    print("转换失败:", err)      # err 是字符串，不是异常
else:
    print(ucl[:200])
    print(comments[:200])
```

- ⚠️ **zone 推断与 CLI 不同**：CLI 按**父目录名**推断（§二），`convert_file` 按**文件名**推断。批处理时若不想每个文件都落到各自的 `<文件名>.ucl`，请显式传 `zone_id`。
- 这三个脚本（`lpc_converter.py` / `assign_room_coords.py` / `validate_ucl.py`）都**只能在宿主机跑**，因为容器内没有 Python。

### `convert_string` —— Python 版**没有**这个便捷入口

Elixir 的 `LPCConverter.convert_string/2`（`lib/kantele/world/lpc_converter.ex:56`）在 Python 侧**没有对应实现**。要按字符串转换，直接用内部 `_parse_lpc`（`scripts/lpc_converter.py:2341`）自己拼装：

```python
from scripts.lpc_converter import _parse_lpc, _generate_ucl

content = open(r"test_minimal_world_v2_modified\room\cave.c", "rb").read()   # 必须是 bytes
ast = _parse_lpc(content, r"test_minimal_world_v2_modified\room\cave.c",
                 r"test_minimal_world_v2_modified\room")
if ast is None:
    ...  # 解析失败
else:
    ucl, comments = _generate_ucl(ast, "test", True, True)
```

- `_parse_lpc(content: bytes, source_path: str, base_path: str)` 的入参是 **bytes**（编码转换在它内部完成：源文件多为 GBK/GB2312，自动转 UTF-8），返回 `AST` 或 `None`。
- `_generate_ucl(ast, zone_id, include_comments, include_header=True)` 返回 `(ucl, comments)` 二元组。
- 这两个都是**下划线私有函数**，没有兼容性保证；`convert_file` 就是它们的薄封装，优先用 `convert_file`。

### AST 产出（替代 Elixir 的 `parse_ast/3`）

Python **没有** `parse_ast/3` 这个函数。AST 由 `_parse_lpc` 产出，类型是 `scripts/lpc_converter.py:161` 的 `AST` 类实例，字段名与 Elixir `lpc_converter/ast.ex` 的 struct **一一对应**，但是**普通属性**（不是 map 键，也不是 `ast.exit_vetoes` 这种访问——Elixir 那边 `ast` 是 map 才能用点语法，Python 侧 `ast` 是对象，点语法同样可用）：

```python
ast.exit_vetoes      # list，出口阻挡条件（→ UCL valid_leave）
ast.valid_leave      # 同上
ast.engage           # dict | None，accept_fight/hit/kill 抽取结果
ast.accept           # dict | None，accept_object 抽取结果
ast.guard            # dict | None，permit_pass 守卫
ast.greetings        # list | None
ast.enter            # list | None，init() 台词
ast.inherit_files    # list，已解析的 inherit 目标
ast.source_path      # str
ast.unhandled        # dict，UNHANDLED 兜底桶（functions / switch_tables / switch_pools /
                     #   conditional_branches / complex_conditionals / raw_code_blocks ...）
```

Elixir 侧的字段级断言仍在 `test/kantele/world/lpc_converter_room_test.exs` 等测试里，Python 侧**没有对应的单测**，靠 `test\fixtures\validate_ucl\expected.json` + 真实产物回归兜底（见 §七）。

---

## 四、对象类型判定与输出结构

转换器合并继承链后按 `determine_object_type/1` 分五类，输出不同 UCL 段：

| 判定 | 输出段 | UCL 示例 |
|---|---|---|
| 房间（room） | `rooms "id"` + `room_exits "id"`（+ 可选 `room_characters "id"`） | `rooms "bet" { name = "赌场" ... }` |
| NPC（npc） | `characters "id"` | `characters "duke" { name = "赌场管事" ... }` |
| 物品（item） | `items "id"` | — |
| 技能（skill） | 无 UCL 段，仅注释（技能以 Elixir 模块实现，见 `lib/kantele/combat/skills/`） | `# Skill file: ...` |
| generic | 无 UCL 段，注释提示手工转换 | `# Generic LPC file: ... # Requires manual conversion` |

### 房间输出样例（`data/world/test.ucl` 实际产物）

```ucl
# Generated from test_minimal_world_v2_modified/room/bet.c by LPCConverter
# Zone: test

    rooms "bet" {
      name = "赌场"
      description = "大厅里摆满大大小小的赌桌..."
      x = 0
      y = 0
      z = 2
      item_desc = {
        paizi = "##...##"
      }
    }
    room_exits "bet" {
      room_id = rooms.bet.id
      up = rooms.cave.id
      down = rooms.beidajie1.id
      south = rooms.duchang.id
    }
    room_characters "bet" {
      room_id = rooms.bet.id
      characters = [
        { id = characters.duke.id },
        { id = characters.zhuangjia.id }
      ]
    }
```

### NPC 能落的数据

- 基础属性：`title / nickname / gender / age / shen_type / score / startroom / aliases`
- `combat` 块（attitude / combat_exp / 五维）
- `goods = [...]`（出售物，找不到的路径以 `# 注释` 保留）、`inquiries`（问答）
- `chats` / `chat_chance`（概率闲聊）、`skills`、`carry`
- 语义化函数区块：`enter`（init）、`greetings`、`accept`（accept_object，含 `fail_msg` 台词池）、`guarder`（permit_pass 守卫）、`engage`（accept_fight/hit/kill：accept/msg/retaliate/spawn）
- 未处理内容整体落入 `# ==== UNHANDLED CONTENT ====` 注释（switch 表、条件分支按函数名+行号分桶保留原文）

### 房间出口阻挡（exit vetoes）

`init()` 里 `notify_fail` 式的出口阻挡被语义为 `valid_leave = [...]`，条件行原样保留为注释：

```ucl
valid_leave = [
{
    # 阻挡条件（原样保留）：dir == "in" && objectp(present("mang she", environment(me)))
    direction = "in"
    message = "蟒蛇盘在岩洞口，将路封了个严实。"
}
]
```

---

## 五、输出 → Loader → 游戏

1. 转换产物放进 `data/world/`（默认 `data/world/<zone>.ucl`）。
2. `Kantele.World.Loader.load_folder/1`（`loader.ex:51-60`）读取 `data/world` 下**所有** `.ucl`，按 zone key 用 `Enum.into(%{})` 合并成 world data。
3. `Kantele.World.Kickoff` 启动/重载时消费，房间/NPC/物品实例化进运行时。

> ⚠️ **同一 zone 只应有一个 `.ucl` 文件定义**。多个文件（如同时存在 `test.ucl`、`test_assigned.ucl`、`test_zero.ucl`）会按 `File.ls!` 字母序**后者覆盖前者**，导致整个 zone 被替换（此前 `test:damen` 丢失 `up` 出口即由此引起，已把重复文件移出到 `data/world_backup/`）。

---

## 六、辅助脚本（仓库根目录）

> ⚠️ **这三个仍是遗留 Elixir 脚本**，且仍在调用 Elixir 的 `Kantele.World.LPCConverter`。
> **日常转换走 Python**（§二 / §三）；这几个脚本只在需要 Elixir 侧的 dev 排查时用。

| 脚本 | 作用 |
|---|---|
| `classify_file.exs <path>` | 单个 LPC 文件 → 打印 `ROOM / NPC / ITEM / SKILL / GENERIC / ERROR` |
| `batch_classify.exs <file_list>` | 批量分类并打印统计（需要容器挂载语料路径） |
| `_genlist.exs` | 在容器里对 `/corpus/d` 全量普查 generic 文件列表 |

用 `mix run` 执行（`mix` 只在容器内可用，宿主机没装 Elixir）：

```bash
docker exec -w /app wuxia_mud_dev-app-1 mix run classify_file.exs test_minimal_world_v2_modified/room/bet.c
```

---

## 七、测试

**Elixir 单测仍然存在且仍可跑**（容器内执行，Python 不参与）：

```bash
docker exec -w /app -e MIX_ENV=test wuxia_mud_dev-app-1 mix test test/kantele/world/lpc_converter_room_test.exs
docker exec -w /app -e MIX_ENV=test wuxia_mud_dev-app-1 mix test test/kantele/world/lpc_converter_npc_functions_test.exs
```

用例覆盖：valid_leave 出口阻挡、item_desc 拼接、engage（accept_fight/hit/kill）、杂货/守卫/闲谈抽取、继承链合并（子覆盖父、父的父并入、循环不递归）等。

**Python 侧没有等价的单元测试。** 回归靠两条线兜底：

1. **产物格式校验**：`python scripts\validate_ucl.py data\world\<zone>.ucl`，判定基准是 `test\fixtures\validate_ucl\expected.json`（含各检查项的实测 ground truth）。
2. **真实产物比对**：拿 `scripts\lpc_converter.py` 重新生成 zone，与既有 `data\world\<zone>.ucl` 逐项对照。

> `data\world\*.ucl` 是**生成产物**：不要手改，也不要为了"清理"而删除或重生成到别的路径。

---

## 八、已知边界

- **启发式解析**：`get_last_return` 对复杂嵌套可能取错 → `accept` 置 nil 不输出（运行时按缺省放行）。
- **`::` 继承回退**（父类函数不可见）：只进 `note` 注释，不猜测。
- **skill / generic**：不做数据化输出，原文进注释。
- **目录模式整体覆盖**：见 §二 —— 目录转换每次重写整个 `<zone>.ucl`，不追加、不做"已存在就跳过"检查。
- **zone 推断双规则**：CLI 按父目录名、模块 API 按文件名，见 §二 / §三。
- **Windows / Docker bind mount** 下 UCL 重生成偶发 `File.Error: invalid argument`，重试即可。