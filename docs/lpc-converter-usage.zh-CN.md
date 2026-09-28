# LPC→UCL 转换器使用文档（LPCConverter）

> 关联代码：`lib/kantele/world/lpc_converter.ex`（约 3240 行）、`lib/mix/tasks/kantele.convert_lpc.ex`
> 消费方：`lib/kantele/world/loader.ex`（载入 `data/world/*.ucl`）
> 语料：`C:\files\git\mud\d\`（7140 个 `.c`）→ 分析样本见 `lpc_example/`，测试世界见 `test_minimal_world_v2_modified/`

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

## 二、最简用法：Mix Task

```bash
# 单个文件
mix kantele.convert_lpc lpc_example/room/room_qianting.c --zone liuxi

# 目录递归（所有 .c）
mix kantele.convert_lpc lpc_example/room --recursive --zone liuxi
```

### 参数

| 参数 | 说明 | 默认 |
|---|---|---|
| `--zone <id>` | 输出 zone id | 由路径推断 |
| `--output <dir>` | UCL 输出目录 | `data/world` |
| `--recursive` | 目录下递归转换所有 `.c` | `false`（默认单文件） |
| `--single` | 单文件模式标记 | `true`（保留，无实际分支） |

### Mix Task 行为

- 文件 `foo.c` → 对象 id 取 `foo`（`-` 规范化为 `_`，如 `worker-liu.c` → `worker_liu`）。
- 输出文件：`<output>/<zone>.ucl`，zone 头自动补 `zones "<zone>" { name = "<zone>" }`。
- **去重**：目标 `.ucl` 已含 `# Generated from <path>` 或同名 `rooms/characters/items "..."` 则跳过，不重复追加。
- 注释额外写到 `<zone>.comments.txt`（两套输出，正文带注释的才进 ucl）。
- `--zone` 未给时，zone id 推断规则：**父目录名**，`-` → `_`（注意与模块 API 的推断规则不同，见 §四）。

---

## 三、直接调用模块 API

### `convert_file/2`

```elixir
alias Kantele.World.LPCConverter

{:ok, {ucl, comments}} = LPCConverter.convert_file(
  "test_minimal_world_v2_modified/room/bet.c",
  zone_id: "test",          # 缺省则按文件名推断（basename rootname，`-`→`_`）
  base_path: "test_minimal_world_v2_modified/room",   # 解析 __DIR__ / inherit 的相对根
  include_comments: true    # 缺省 true
)
```

- 实际返回 `{:ok, {ucl_string, comments_string}}`（模块 moduledoc 里写的 `{:ok, ucl_string}` 已过时，以 Mix Task 与测试的模式匹配为准）。
- 出错返回 `{:error, reason}`。

### `convert_string/2`

与 `convert_file/2` 同构，输入换成 LPC 字符串（测试用）：

```elixir
{:ok, {ucl, _comments}} =
  LPCConverter.convert_string(File.read!("test_minimal_world_v2_modified/room/cave.c"),
    base_path: "test_minimal_world_v2_modified/room")
```

### `parse_ast/3`（内部，测试常用）

返回 AST 结构，可在断言中直接取字段（如 `ast.exit_vetoes`、`ast.engage`、`ast.accept`），见测试文件 `test/kantele/world/lpc_converter_room_test.exs`。

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

| 脚本 | 作用 |
|---|---|
| `classify_file.exs <path>` | 单个 LPC 文件 → 打印 `ROOM / NPC / ITEM / SKILL / GENERIC / ERROR` |
| `batch_classify.exs <file_list>` | 批量分类并打印统计（需要容器挂载语料路径） |
| `_genlist.exs` | 在容器里对 `/corpus/d` 全量普查 generic 文件列表 |

用 `mix run` 执行：

```bash
mix run classify_file.exs test_minimal_world_v2_modified/room/bet.c
```

---

## 七、测试

```bash
MIX_ENV=test mix test test/kantele/world/lpc_converter_room_test.exs
MIX_ENV=test mix test test/kantele/world/lpc_converter_npc_functions_test.exs
```

用例覆盖：valid_leave 出口阻挡、item_desc 拼接、engage（accept_fight/hit/kill）、杂货/守卫/闲谈抽取、继承链合并（子覆盖父、父的父并入、循环不递归）等。

---

## 八、已知边界

- **启发式解析**：`get_last_return` 对复杂嵌套可能取错 → `accept` 置 nil 不输出（运行时按缺省放行）。
- **`::` 继承回退**（父类函数不可见）：只进 `note` 注释，不猜测。
- **skill / generic**：不做数据化输出，原文进注释。
- **Windows / Docker bind mount** 下 UCL 重生成偶发 `File.Error: invalid argument`，重试即可。