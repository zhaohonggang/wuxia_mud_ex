# Elixir 语法参考（Kantele / wuxia_mud_ex 实测版）

> 面向「以后接手本项目的 AI」的硬约束参考。目的：写 / 改 `lib/**/*.ex`
> 时不再犯语法错误、不再踩已知坑。
>
> **本文所有规则均以本仓库实际代码与工具链为准**（Elixir **1.13.4** /
> Erlang **OTP 25.3.2.6**，见 `.tool-versions`）。凡与直觉或旧记忆冲突，
> **以本文为准**。每条规则标注「约定」/「坑」/「实测」。
>
> 配套文件：UCL 见 `docs/UCL语法参考.zh-CN.md`；项目宪章见 `AGENTS.md` §0。
>
> 提交前必做（AGENTS.md Core Rule #1）：
> - 改了 `lib/**/*.ex` → `mix compile` 必须过。
> - 改了 `data/**/*.ucl` → `python scripts/validate_ucl.py <文件>` 必须过。
> - `.exs`（测试 / 脚本 / 配置）提交前不做要求，跑测试时再修。

---

## 0. 一句话总览

本仓库是 **Elixir 1.13.4 / OTP 25** 的 Phoenix + Kalevala MUD 世界。
写 `.ex` 只需守住：

1. **模块**：`defmodule Kantele.XXX.Yyy do ... end`，文件名与模块名对应
   （`lib/kantele/world/items.ex` → `Kantele.World.Items`）。
2. **格式化**：`mix format` 必须过（120 列，见 `.formatter.exs` / `.credo.exs`）。
3. **长期进程**：一律走 `Behaviour`（`prompt/1` `init_state/1` `start_round/1`
   `stop_round/1` `status/1`）+ `Kalevala` 事件循环，**不裸用 `use GenServer`**。
4. **错误兜底**：`safe_run/2`、`safely/1` 包裹可能抛异常/退出的调用。
5. **定时**：用 `Kantele.Scheduler.schedule_once/2` / `schedule_recurring/2`，
   **不要用 `send_interval`**。
6. **数据形态**：ETS / 世界状态一律 **string-key**；结构体字段是 **atom-key**。
   新增读 ETS 的 helper 必须配一条插入真实数据的测试。

---

## 1. 工具链与命令（实测环境）

权威环境是 Docker（Elixir 1.13.4 / OTP 25）；Windows 原生只作辅助，
必须用仓库根的 `win_toolchain.cmd` 进入对齐 shell（版本对齐 1.13.4，
不要用系统的 Elixir 1.20 / OTP 29）。

Windows Git Bash 下的最小可跑环境（本机实测）：

```bash
export PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH
export MIX_HOME=/c/Users/honggang/tools/mix-1.13
export MIX_BUILD_PATH=/c/files/git/wuxia_mud_ex/_build_win13
export ERL_LIBS=$MIX_BUILD_PATH/lib
export MIX_ENV=test
export ERL_CRASH_DUMP_BYTES=0   # 必须！防止 13GB+ crash dump 占满 C 盘
```

| 目的 | 命令 |
|---|---|
| 编译（提交前必跑） | `mix compile` |
| 格式化 | `mix format` / 检查 `mix format --check-formatted` |
| Lint | `mix credo`（严格模式 `mix credo --all`） |
| 单文件测试 | `mix test test/kantele/xxx_test.exs` |
| 全量回归 | **AI 不得自行跑**（AGENTS.md §0.4）→ 登记 `docs/待全量回归清单.zh-CN.md` |

> ⚠️ **任何 `mix` 之前都要 `export ERL_CRASH_DUMP_BYTES=0`**。
> BEAM 遇 `eheap_alloc` 等不可恢复错误会往 cwd 写 `erl_crash.dump`，
> 内容 = 全进程堆 + 全 ETS 快照，实测 13–20 GB，可占满系统盘（已发生一次 13.9 GB）。

---

## 2. 模块与命名约定

### 2.1 模块骨架

```elixir
defmodule Kantele.World.Items do
  @moduledoc """
  物品定义查询 / 实例化（对应 LPC 的 `item` daemon）。
  简单一行也可 `@moduledoc "..."`。
  """

  require Logger          # 要用 Logger.* 宏必须 require

  alias Kantele.Character.Records
  alias Kantele.World.Item, as: ItemDef   # 别名消歧
  import Kalevala.Character.Conn, only: [put_character: 2]
end
```

- **文件名 = 模块名**：`lib/kantele/world/items.ex` ↔ `Kantele.World.Items`。
- **目录名映射命名空间有约定**：`room_actions/` → `Kantele.World.RoomActions.*`
  （`room_actions/banquet.ex` → `Kantele.World.RoomActions.Banquet`）。
  但派发器例外：文件在 `lib/kantele/world/room_action_dispatcher.ex`（单数 `room_action`），
  模块却是 `Kantele.World.RoomAction`（单数）。改这块时以**该文件已有的 `defmodule` 行**为准。
- **`@moduledoc`** 用 `"""..."""`；Credo 对 `*Channel/*Controller/*Command/*Event/*View`
  后缀模块豁免 ModuleDoc（见 `.credo.exs` 的 `ignore_names`）。
- **`require Logger`** 先于使用；`alias` 放最前、`import` 次之（Credo `AliasOrder`）。

### 2.2 `def` / `defp` / `defdelegate` / `defstruct`

- **公开 API 用 `def`**，内部辅助用 `defp`（默认私有）。
- 委托用 `defdelegate`，或手写薄委托（本仓库倾向手写，便于加注释）。
- 结构体：

  ```elixir
  defmodule Kantele.Foo do
    defstruct [:id, :name, items: [], meta: %{}]
  end
  # 用：%Kantele.Foo{id: ..., name: ...}
  ```

  本仓库存在**裸 `defstruct`**（`Kantele.Foo` 形式）与**嵌套命名空间 `Foo.Bar`**
  两种风格，视周边代码保持一致即可，不强行统一。

### 2.3 命名

- 模块 `CamelCase`；函数 / 变量 `snake_case`；宏 / 模块属性 `@snake_case`。
- **谓词函数以 `?` 结尾**：`carry?/2`、`flag?/2`、`truthy?/1`、`perform_known?/2`。
- 危险 / 可能失败：`!` 结尾（`File.read!`）。

---

## 3. 格式化与 Credo（提交前必过）

- **格式化**：`mix format`（`.formatter.exs` 导入 `:ecto`/`:phoenix` 规则）。
  提交前 `mix format --check-formatted` 必须通过，否则 CI 挂。
- **Credo**：`.credo.exs` 关键点：
  - `strict: false`（默认非严格；`mix credo --all` 才跑全部）。
  - `Readability.MaxLineLength` **max_length: 120**，priority `:low`。
  - `Design.TagTODO` **exit_status: 2** → **TODO 注释会让 `mix credo` 失败**。
    本仓库为迁移留档使用大量 `TODO(migrate)`/`@todo`——**这是有意的**，
    改相关文件时不要删它们；但若你的改动会新增裸 `TODO`/`FIXME`，先确认是否该用
    `@doc`/`# 说明` 替代，避免 credo 退出码 2。
  - 大量 check 显式 `false`（`UnnecessaryAliasExpansion`、`LongQuoteBlocks`(默认开)、
    `MapInto`、`Specs`、`SinglePipe`、`ABCSize` 等）——不要指望 credo 抓所有重构问题。
- **模块属性**：`@name value` 用大写属性名（Credo `ModuleAttributeNames`）。

---

## 4. 长期进程模式（本项目最核心的架构约束）

### 4.1 一律走 Behaviour，不裸 `use GenServer`

本仓库**没有**直接 `use GenServer` 的守护进程。长活进程通过
`Kalevala.World.*` + `Kalevala.Character.Event` 的事件循环 + 一个
`@callback` 契约（Behaviour）来组织。典型 Behaviour（`lib/kantele/world/invasion/behaviour.ex`）：

```elixir
defmodule Kantele.World.Invasion.Behaviour do
  @callback prompt() :: String.t()
  @callback init_state() :: map()
  @callback start_wave(state :: map(), opts :: Keyword.t()) :: {:ok, map()} | {:error, term()}
  @callback stop_wave(state :: map()) :: {:ok, map()}
  @callback status(state :: map()) :: map()
end
```

各 daemon 实现该 Behaviour，由 `Kalevala` 的世界循环驱动。**新增守护进程先找
已有的 `*/behaviour.ex` 与 `mirror_daemon` / `story` / `invasion` 目录，
照抄其 `init_state / start_round / stop_round / status` 骨架**，不要自造 GenServer。

### 4.2 错误兜底：`safe_run/2` 与 `safely/1`

两个等价模式，按返回值语义二选一：

```elixir
# 返回 nil（"失败就跳过"）—— story.ex
defp safe_run(fun) do
  fun.()
rescue
  e -> Logger.warn("story step action failed - #{Exception.message(e)}"); nil
catch
  :exit, reason -> Logger.warn("story step action failed - #{inspect(reason)}"); nil
end

# 返回 {:ok, val} / {:error, info}（"失败要上报"）—— kickoff.ex
defp safely(fun) do
  {:ok, fun.()}
rescue
  exception -> {:error, error_info(exception, __STACKTRACE__)}
catch
  kind, value ->
    exception = RuntimeError.exception(message: "#{kind}: #{inspect(value)}")
    {:error, error_info(exception, __STACKTRACE__)}
end
```

> **坑**：`rescue` **抓不到 `:exit`**（进程退出是 exit signal，不是异常）。
> 需要兜住进程退出必须同时 `catch :exit, reason`。上面两段都是 `rescue` + `catch`
> 双写，缺一个都会漏。

---

## 5. 调度（定时任务）

统一用 `Kantele.Scheduler`（`lib/kantele/scheduler.ex`），**不要用 `:timer.send_interval`**：

```elixir
Kantele.Scheduler.schedule_once(5_000, fn -> IO.puts("5s 后") end)     # 一次性，返回 ref
Kantele.Scheduler.schedule_recurring(1_000, fn -> IO.puts("每 1s") end) # 周期，返回 ref
Kantele.Scheduler.cancel(ref)                                           # 取消
```

- `schedule_once(ms, fun)` → `:timer.apply_after`，`fun` 在**调用进程**里执行。
- `schedule_recurring(ms, fun)` → spawn 循环，带 `ref` 可取消。
- 项目内还有 `schedule_revive/2`、`schedule_liandu_finish/3` 等领域封装，优先复用。

---

## 6. 字符串与输出（Windows 中文坑）

| 场景 | 错误 | 正确 |
|---|---|---|
| 写文件含中文 | `IO.write("中文")` → **`:no_translation`**（Windows 代码页） | `File.write!(path, text)`（显式 UTF-8） |
| 拼路径 | `Path.join(a, b, c)` | `Path.join(a, Path.join(b, c))`（**没有 3 参数版**） |
| 删文件 | `File.rm/2` | 不存在这个函数；用 `File.rm/1` 或 `File.rm_rf/1` |
| 换行 | 字符串里写真实 `\n` | Elixir 里用 `"\n"`（这是真换行）；UCL 里才是字面 `\n`（见 UCL 文档 §6） |

- 需要 `/` 的路径在 **UCL 值里必须加引号**（`"tie-zhang/lei"`）；Elixir 侧无此限。
- 编辑丢失可从 session transcript jsonl 的 `function_call.arguments` 还原（历史教训）。

---

## 7. 数据形态：string-key vs atom-key（高频坑）

- **结构体（Struct）字段 = atom**：`conn.character`、`item.id`、`instance.meta`。
  用 `%{... | field: v}`、`Map.put/3`、`field` 直接读。
- **ETS / 世界动态状态 / 解析出的 JSON-like map = string**：`state["foo"]`、
  `character.skills["force"]`、`meta.environment["x"]`。
- **跨边界（ETS ↔ 结构体）务必确认 key 类型**：同一份数据别一半 atom 一半 string。
- 典型例子（`mirror_daemon/zixu.ex`）：
  - `meta.stats.skills` 是 **string-key map**（`"force" => 500`）；
  - `meta.stats.mapped` 的值是 **atom**（`%{ "force" => :huntian_baojian }`）；
  - `meta.inquiries` 是 **string-key map**（`"宝镜" => :ask_mirror`）。

> **配套测试纪律（R19）**：新增读 ETS 或读 `Money` 的 helper，必须加一条
> 「插入一行真实数据 / 传一个非零金额」的测试——列表来源与列表渲染必须同形，
> 否则能编译通过、只在真实数据下才炸（历史上 `Auction.list_auctions/0` 就踩过）。

---

## 8. 枚举与「累加器重绑定」陷阱（R20，已发生 4 次）

**绝对不要在 `Enum.each` / `for` 里重绑定外层累加器**：

```elixir
# ❌ 错误：lines 的重绑定是全新局部变量，循环结束即丢弃，什么都没发生
lines = []
Enum.each(items, fn item -> lines = lines ++ [item] end)

# ✅ 正确：用 Enum.map
lines = Enum.map(items, fn item -> item end)

# ✅ 正确：用 Enum.reduce 把累加器带出来
lines = Enum.reduce(items, [], fn item, acc -> acc ++ [item] end)
```

- 该 bug **无编译警告、`mix credo` 也抓不到**（`VariableRebinding` check 默认 `false`）。
- 历史后果：`make`（制药）永远不消耗草药 = 无限制药。
- 同理：`for` 的 `reduce` 形态、`Enum.into` 都可以，但**不要依赖「循环内重新赋值外层变量」**。

---

## 9. 错误处理惯用法

- **`case` + tagged tuple**：`{:ok, v}` / `{:error, reason}` 是本仓库主流。
- **薄委托兜错**：`def publish_error(conn, _error), do: conn`（失败不改 conn）。
- **`with`**：链式多步、任一步 `{:error, _}` 即短路（Credo `WithClauses` 建议用）。
- **`:global` 注册名**：`:global.register_name/3` 成功返回 `:yes`、名字被占返回 `:no`
  **静默失败**——测试里 fake room 不要抢生产 `:global` 名（AGENTS.md R16）。
- **`Records.save/1` 永不 raise/exit**：返回 `:ok | :error`，吞掉
  `DBConnection.OwnershipError`（很多测试不 check-out 连接就靠它）。

---

## 10. 测试约定

- **Helper**：`test/support/test_helpers.ex`（`build_conn/1`、`build_character/1`、`player/0`）。
- **Case 模板**：`ConnCase` / `ChannelCase` / `DataCase`（`test/support/`）。
- **CI seed**：`--seed 731933` 复现 flaky。
- **Sandbox 交接窗**（R17）：`async: false` 测试把 SQL sandbox 设成 `{:shared, self()}`
  （全局模式），owner 退出后有一段窗口会把**已死 owner 的连接**借给下一个测试 →
  `** (EXIT) shutdown: "owner exited"`（exit，`rescue` 抓不到）。`on_exit` 同步重置 +
  `Records.save/1` 的 `catch :exit` 两侧都要保留。
- **`reload_command_test`** 已知 flaky（60s 超时），`mix test` 整体卡住时可排除它。
- 关键测试文件：
  - `test/kantele/quest/chain_walk_test.exs` — 任务链
  - `test/kantele/world/signature_npc_test.exs` — 签名 NPC
  - `test/kantele/world/mirror_daemon_test.exs` — MirrorDaemon
  - `test/kantele/world/kickoff_test.exs` — 世界加载 / UCL 改动后先跑

---

## 11. 常见错误速查

| 你写的 | 现象 | 正确写法 |
|---|---|---|
| `use GenServer` 裸守护进程 | 不符合本仓库架构 | 走 `*/behaviour.ex` + `Kalevala` 事件循环 |
| `send_interval(...)` | 调度不一致、难取消 | `Kantele.Scheduler.schedule_recurring/2` |
| `IO.write("中文")` | Windows `:no_translation` | `File.write!(path, text)` |
| `Path.join(a, b, c)` | 编译错误 | `Path.join(a, Path.join(b, c))` |
| `File.rm(path, opts)` | 函数不存在 | `File.rm(path)` / `File.rm_rf(path)` |
| `Enum.each` 里 `acc = acc ++ [x]` | 静默无效果（R20） | `Enum.map` / `Enum.reduce` 带出累加器 |
| 只 `rescue` 想兜进程退出 | `:exit` 漏网 | `rescue` + `catch :exit, reason` 双写 |
| TODO 注释新增裸 `TODO` | `mix credo` exit 2 | 用 `@doc`/`#` 说明，或确认 `.credo.exs` 策略 |
| 超 120 列一行 | `mix format --check-formatted` 挂 | `mix format` 自动折行 |
| 新增读 ETS 的 helper 无测试 | 真数据才炸（R19） | 加一条插真实行的测试 |

---

## 12. 提交前自测片段

```bash
# 1) 编译（改了 lib/**/*.ex 必跑）
mix compile

# 2) 格式化 + credo（CI 同款）
mix format --check-formatted
mix credo

# 3) 定向测试（改动相关，自行跑；全量不要自行跑）
mix test test/kantele/world/xxx_test.exs

# 4) 改了 UCL → 校验
python scripts/validate_ucl.py data/world/<zone>.ucl
```

> 记住：**提交顺序 = 先 `mix compile` + `mix format` + 相关单测过，再 commit；
> 全量回归登记清单等用户指示。** 详见 `AGENTS.md` Core Rule #1 与 §0.4。