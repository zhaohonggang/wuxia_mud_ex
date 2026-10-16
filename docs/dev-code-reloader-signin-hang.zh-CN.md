# 排查：点「Sign in」无反应 —— `code_reloader` 与 Windows 9p bind mount

> 现象：浏览器里点「Sign in」没反应，`http://127.0.0.1:4000/sign-in` 请求超时；但页面本身能打开，静态资源正常。
> 结论：**不是 bug**，而是 dev 的 `code_reloader` 在 Windows bind mount 上每次请求都要扫描全项目源码，单次请求 ≈ 40s。
> 处置：把 `config/dev.exs` 的 `code_reloader` 改为 `false`。

---

## 1. 现象

- 容器 `wuxia_mud_dev-app-1`（PID 1 `mix phx.server`，`-sname app`）在运行，`wuxia_mud_dev-db-1` 健康。
- BEAM 正常监听 4000 / 4646 / 40877 / 4369。
- 静态资源 `GET /images/exventure.png` → **200**，秒回。
- 所有走 router 的请求（`/`、`/sign-in`、`/api/zones`、`/_health`、`/emails/sent`）全部**挂起**。
- `docker restart wuxia_mud_dev-app-1` 之后依旧：静态正常、应用路由卡住。
- 日志里被 `bot_auto` 的 `Received - "exercise 50"` 刷屏（与本次问题无关，见第 6 节）。

## 2. 排查过程（关键手法）

普通日志看不到卡点，因为 Logster 是在响应之后才记日志。于是**用远程 `:rpc` 抓运行中节点的进程栈**：

> 注意：`iex --remsh` 在容器的 "limited shell" 下会被忽略（提示 *the --remsh option will be ignored because IEx is running on limited shell*），所以改用「一次性节点 + `:rpc`」的方式。

在**一次性容器**里连到运行节点（同一 compose 网络，节点名 `app@<hostname>`，cookie 取 `/root/.erlang.cookie`）：

```bash
docker compose -f docker-compose.dev.yml run --rm --no-deps app \
  sh -c "cd /app && elixir --sname dbg --cookie <COOKIE> tmp/diag.exs"
```

`tmp/diag.exs` 核心：连上目标节点，抓进程的 `current_function` / `current_stacktrace` / `message_queue_len`。

```elixir
target = :"app@<hostname>"
Node.connect(target)
pids = :rpc.call(target, Process, :list, [])

pids
|> Enum.map(fn p ->
  :rpc.call(target, Process, :info, [p, [:current_function, :current_stacktrace, :message_queue_len, :registered_name]])
end)
|> Enum.filter(&is_list/1)
|> Enum.filter(fn i -> inspect(i[:current_stacktrace]) =~ ~r/Cowboy|Plug|Mix|Code|Reloader|Compile/ end)
|> Enum.each(fn i ->
  IO.puts("--- #{inspect(i[:registered_name])} mq=#{i[:message_queue_len]} cur=#{inspect(i[:current_function])}")
  IO.puts(inspect(i[:current_stacktrace], pretty: true, limit: 14))
end)
```

> 坑：远程 `Process.info(pid, :current_function)`（单 key）返回的是**元组** `{:current_function, x}`，不是 keyword list；单 key 用元组，多 key（list）才返回 keyword list。

抓到的关键栈（HTTP 请求进程）：

```
{GenServer, :call, 3}
{Phoenix.CodeReloader, :call, 2}          # ← 每个请求都经过这里
{Web.Endpoint, :plug_builder_call, 2}
...
```

同时 `Phoenix.CodeReloader.Server` 正忙在：

```
{Gem, :do_call, 4}
{File, :cwd, 0} / {File, :cwd!, 0} / {Path, :absname, 1}
{Mix.Compilers.Elixir, :warning_diagnostics, 1}
{Mix.Compilers.Elixir, :compile, 6}
{Mix.Task, :run_task, 3}
```

即：**每个请求 → `GenServer.call(CodeReloader.Server)` → 跑一次 `Mix.Compilers.Elixir.compile`**，而这个编译/扫描又卡在 `:file` 服务器的 `prim_file:read_info_nif`（即 `stat`）。

## 3. 根因

- `config/dev.exs`：`code_reloader: true`。
- `lib/web/endpoint.ex` 的请求管线里，`Plug.Static` 之后、router 之前，dev 下会插入 `Phoenix.CodeReloader` plug：

  ```
  Plug.Static
  → (code_reloading? 时) Phoenix.LiveReloader + Phoenix.CodeReloader
  → RequestId / Telemetry / Parsers / MethodOverride / Head / Logster / Session
  → Plug.Static (uploads)
  → Web.Router
  ```

- `Phoenix.CodeReloader.call/2` 会 `GenServer.call(Phoenix.CodeReloader.Server, ...)`，Server 串行地跑一次项目编译（`Mix.Compilers.Elixir.compile`）来做「是否过期 → 是否重编」判断。
- 源码目录 `.:/app` 是 **Windows → WSL2 的 9p bind mount**，`stat` 极慢，且 `:file` 服务器串行处理所有文件操作。
- 于是**每个请求**都要等约 40s 的源码扫描（实测连续三次：`40s / 46s / 45s`）。
- 静态资源在 reloader **之前**，不经过这条链路，所以只有它正常。

一句话：**页面能打开（静态），但任何 POST/GET 应用路由都被「每请求一次的全项目编译检查」拖死。**

## 4. 修复

`config/dev.exs`（第 21 行）：

```diff
 config :ex_venture, Web.Endpoint,
   server: true,
   debug_errors: true,
-  code_reloader: true,
+  code_reloader: false,
   check_origin: false,
```

**注意：`code_reloader` 是 `Phoenix.Endpoint` 的编译期配置**（`use Phoenix.Endpoint` 时读入并决定是否插入 reloader plug）。所以**只改 config + 重启不够**，必须让 endpoint 重新编译。做法：改动/触碰 `lib/web/endpoint.ex`（更新 mtime）后重启容器：

```bash
docker restart wuxia_mud_dev-app-1
```

重启时 `mix phx.server` 会先 `mix compile`（见第 5 节），从而把新配置编进 endpoint。启动约 **120s**（过期检测要扫描 9p 上的源码）。

## 5. 验证

```
req1 took 0s
req2 took 0s
req3 took 0s
```

- `GET /sign-in` → 200，表单 `action="/sign-in"`。
- `POST /sign-in`（无 CSRF）→ 403，**0s**（403 是缺 CSRF 的预期结果，证明管线不再卡）。
- `GET /_health` → `{"last_load_error":null,"status":"OK","world":"ok"}`。

dev 库当时只有 1 个用户：`admin@example.com` / `admin`（`username=grant`）。

## 6. 误区：DB 里大量的 `INSERT INTO "users"` 是不是死循环？

**不是。** 那些日志时间戳是 `2026-09-02`（历史，约 6 周前），而且：

- 线上/dev 库 `ex_venture_dev` 当时只有 **1 个 user / 3 个 character**；
- 连接池正常：`15 idle + 1 active`（`POOL_SIZE=15`）；
- 近 5 分钟无任何 INSERT 日志。

唯一键冲突 `users_lower_username_index`（`username=user`，即 `test/support/test_helpers.ex` 里的 `player/0` 固定用户名）属于**测试夹具**特征，多半是当年 `mix test` 的历史输出，与本次登录卡住无关。

> 顺带观察：抓栈时看到约 **16600** 个进程（其中 16367 个空闲 `gen_server:loop`）与 **111 个 `prim_inet:accept0`**；`bot_auto` 在刷 `exercise 50`。这些不影响本次结论，但值得后续单独关注。

## 7. 关掉 `code_reloader` 的后果（仅影响 dev）

**失去：**
- `lib/**/*.ex` 改完**不再自动重编译**，必须重启容器。
- `.eex` 模板 / view 改动同样要重启。
- `@external_resource` / `__phoenix_recompile__?` 触发的重编译失效。
- 浏览器 `live_reload` 对 CSS/JS/静态资源仍会 F5；但对 Elixir/模板改动，刷新后看到的仍是旧代码（因为没重编译）。

**仍正常：**
- 启动时编译、`mix test` / `mix format` / `mix credo` 不受影响。
- 游戏内 UCL `reload`（NPC/房间/物品/商店/技能配置）是运行时数据热加载，照旧可用。
- 静态资源、webpack 产物照常。

**权衡：** 请求从 `40~46s → 0s`；代价是「改 Elixir 代码后需重启」。

> 若以后想「既快又自动重载」：把源码也放到 Docker 命名卷，或让主机与容器的文件系统不再是 9p（避免慢 `stat`），再开回 `code_reloader: true`。

## 8. 开发工作流：改完代码怎么让它重新编译

### 8.1 `_build` / `deps` 在命名卷，源码在 bind mount

来自 `docker-compose.dev.yml` 的挂载：

```yaml
volumes:
  - .:/app                      # 源码：Windows bind mount（9p，慢）
  - app_deps:/app/deps          # 依赖：Linux 命名卷（快）
  - app_build:/app/_build       # 编译产物：Linux 命名卷（快）
  - app_node_modules:/app/assets/node_modules
  - app_mix_home:/root/.mix
  - app_hex_cache:/root/.hex
```

所以**编译产物写入很快**，慢的是**「过期检测」要扫描 bind mount 上的源码**（这也是关掉 reloader 能提速的原因）。

### 8.2 `dev_start.bat` 会重新编译吗？—— 会

- `dev_start.bat` 最后一步是 `docker compose up app`（第 55 行，前台）。
- app 容器命令是 `elixir --sname app -S mix phx.server`（compose 第 116 行）。
- `mix phx.server` 内部走 `Mix.Tasks.Run`，**默认会先 `mix compile`**（除非加 `--no-compile`，见 Phoenix 任务说明）。
- 因此 `Ctrl+C` 杀掉后再跑 `dev_start.bat`，**会重新编译**；启动多花约 1~2 分钟属正常。

**注意事项：**
1. `Ctrl+C` 必须真的把容器停掉。前台 `docker compose up` 收到 Ctrl+C 通常会 stop 容器；但直接关终端窗口可能让容器继续后台运行，此时再 `up app` 会认为「已在运行」而**不重建、不重编译**，还可能占着 4000 端口。先 `docker ps` 确认（或先 `docker compose -f docker-compose.dev.yml down`）。
2. **更快的等价做法**：改完 `lib/**` 直接
   ```bash
   docker restart wuxia_mud_dev-app-1
   ```
   即可（`dev_start.bat` 还会跑 `setup` 一次性容器做 `mix deps.get` / yarn / `ecto.migrate`，更慢）。

## 9. 附：常用命令

```bash
# 计时三连测（放进容器执行）
for i in 1 2 3; do s=$(date +%s); wget -q -O /dev/null -T 120 http://127.0.0.1:4000/sign-in; e=$(date +%s); echo "req$i took $((e-s))s"; done

# 健康检查
docker exec wuxia_mud_dev-app-1 sh -c 'wget -q -O- -T 5 http://127.0.0.1:4000/_health'

# 重启（改完 Elixir 代码后）
docker restart wuxia_mud_dev-app-1

# 看是否已有容器占用/运行
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

## 10. 相关文件

| 文件 | 说明 |
|---|---|
| `config/dev.exs` | `Web.Endpoint` 配置，`code_reloader` 开关在第 21 行 |
| `lib/web/endpoint.ex` | 请求管线：`Plug.Static` → (`Phoenix.CodeReloader`) → … → `Web.Router` |
| `docker-compose.dev.yml` | app 命令 `mix phx.server`、命名卷 `app_build`/`app_deps`、`POOL_SIZE=15` |
| `dev_start.bat` | 一键启动；第 55 行 `docker compose up app` |
| `deps/phoenix/lib/phoenix/code_reloader.ex` | `call/2` = 每请求触发 `reload!` |
| `deps/phoenix/lib/mix/tasks/phx.server.ex` | `phx.server` 默认走 `Mix.Tasks.Run`（会编译） |
| `test/support/test_helpers.ex` | `player/0` 固定 `username: "user"`（DB 冲突日志来源） |

> 相关：`docs/dev-reload-guide.zh-CN.md`（通用热更新指南）。该文档中「Elixir 源码自动编译」的描述在 `code_reloader: false` 之后已不再成立，请以本文为准。
