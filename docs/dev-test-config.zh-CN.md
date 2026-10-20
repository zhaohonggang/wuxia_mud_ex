# dev / test 环境配置总表（设置 + 位置）

> 用途：要改端口、换库、关机器人、查「这个开关到底在哪」时，先查这张表。
> 核对时间：2026-10-20；工具链见 `.tool-versions`（Elixir 1.13.4-otp-25 / Erlang 25.3.2.6 / Node 20.19.5）。

---

## 1. 三层结构

配置不是集中在一个文件里，而是分三层，改之前先确认在哪一层：

| 层 | 位置 | 生效时机 | 典型内容 |
|---|---|---|---|
| **编译期**（Elixir 配置） | `config/config.exs` → `config/{dev,test}.exs` | `mix compile` 时读入，**改了要重编译** | 开关、Endpoint、Logger、Mailer、Repo 的 pool |
| **运行期**（环境变量） | `.env`、`docker-compose.dev.yml` 的 `environment:` | 应用启动时由 Vapor 读入 | `DATABASE_URL`、`PORT`、`SECRET_KEY_BASE`、`POOL_SIZE` |
| **代码内常量** | 少量硬编码，如 `lib/ex_venture/application.ex:53` | 改代码 | telnet 端口 `4646` |

三层里**编译期最优先**（对 `Repo` 的 `url` 而言，见 §4.4）。

---

## 2. 加载顺序

```
config/config.exs                        ← 所有环境共用
  └─ config/config.exs:43-45
     if File.exists?("config/#{config_env()}.exs"), do: import_config ...
        ├─ config/dev.exs                ← MIX_ENV=dev
        └─ config/test.exs               ← MIX_ENV=test
config/releases.exs                      ← 仅 release（prod）运行时读，与上面两条无关
```

- 入口是 `import Config`（`config/config.exs:8`），`config_env()` / `import_config` 都由它提供。
  历史写法 `use Mix.Config` 已于 2026-10-20 全部替换（Elixir 1.11+ 会刷弃用警告）。
- ⚠️ **改 `config/*.exs` 会触发全量重编译**：Mix 把配置文件算作编译期依赖。
  实测一次全量测试从 ~280s 变成 ~330s（多出来的就是重编译），容器里 `mix phx.server` 同理。
- 没有 `config/prod.exs`；生产走 `config/releases.exs`。

---

## 3. 共用层 —— `config/config.exs`

| 设置 | 值 | 行 | 说明 |
|---|---|---|---|
| `:ex_venture, :namespace` | `Web` | 10-12 | Web 层模块前缀 |
| `:ex_venture, :ecto_repos` | `[ExVenture.Repo]` | 12 | |
| `:ex_venture, :listener, :start` | `true` | 14 | 是否起 telnet 监听（端口硬编码 4646）；test 覆盖为 `false` |
| `:ex_venture, :bots, :enabled` | `true` | 17 | 机器人（`data/bots/*.ucl`）；test 覆盖为 `false` |
| `:ex_venture, :enforce_exit_vetoes` | `true` | 26 | 房间出口阻挡（`valid_leave`）是否真拦；关掉=只放行不拦 |
| `Web.Endpoint` | `render_errors: [view: Web.ErrorView, accepts: ~w(html json)]`、`pubsub_server: ExVenture.PubSub` | 29-31 | |
| `:logger, :console` | `format: "$time $metadata[$level] $message\n"`、`metadata: [:request_id]` | 34-36 | dev 覆盖 format |
| `:phoenix, :json_library` | `Jason` | 39 | |
| `:porcelain, :driver` | `Porcelain.Driver.Basic` | 41 | |

---

## 4. dev 环境

### 4.1 `config/dev.exs`

| 设置 | 值 | 行 | 说明 |
|---|---|---|---|
| `ExVenture.Repo, :show_sensitive_data_on_connection_error` | `true` | 10 | 连不上库时打印敏感信息（仅 dev） |
| `Web.Endpoint, :server` | `true` | 19 | |
| `Web.Endpoint, :debug_errors` | `true` | 20 | |
| `Web.Endpoint, :code_reloader` | **`false`** | 21 | **故意关的**：Windows 9p bind mount 上每次请求扫全项目源码 ≈ 40s，见 `docs/dev-code-reloader-signin-hang.zh-CN.md` |
| `Web.Endpoint, :check_origin` | `false` | 22 | |
| `Web.Endpoint, :watchers` | `node dev-poll-watch.js`（`cd: assets`） | 23-28 | 前端构建监听 |
| `:phoenix_live_reload, :dirs` | `lib` / `priv/gettext` / `priv/static` / `assets/{css,js,static}` | 34 | |
| `:phoenix_live_reload, :backend` | `:fs_poll`，`interval: 700` | 35-36 | 同上：9p 不传 inotify，改轮询 |
| `Web.Endpoint, :live_reload, :patterns` | 静态资源 / `po` / `lib/web/{live,views}` / `lib/web/templates` | 39-47 | |
| `ExVenture.Mailer, :adapter` | `Bamboo.LocalAdapter` | 49 | 邮件存内存，看 `/emails/sent` |
| `:logger, :console, :format` | `"[$level] $message\n"` | 52 | 覆盖共用层的 format |
| `:phoenix, :stacktrace_depth` | `20` | 56 | |
| `:phoenix, :plug_init_mode` | `:runtime` | 59 | 编译更快 |
| `:phoenix, :logger` | `false` | 61 | |
| `:stein_storage` | `backend: :file`、`file_backend_folder: "uploads/"` | 63-65 | 上传落本地 `uploads/` |
| `:ex_venture, :enable_jing_learn_cost` | `true` | 69 | C2 灰度：learn 耗精 |
| `:ex_venture, :enable_exp_gate` | `true` | 70 | C2 灰度：learn exp 门 |

### 4.2 容器运行期变量 —— `docker-compose.dev.yml:21-31`

`x-app-base.environment`（`setup` 与 `app` 两个容器共用）：

| 变量 | 值 | 行 | 说明 |
|---|---|---|---|
| `MIX_ENV` | `dev` | 22 | |
| `DATABASE_URL` | `postgresql://postgres:postgres@db:5432/ex_venture_dev` | 24 | **容器内**走 compose 网络名 `db` |
| `POOL_SIZE` | `15` | 25 | 覆盖 `.env` 的 10 |
| `SECRET_KEY_BASE` | 固定串 | 26 | dev 用，勿用于生产 |
| `PORT` | `4000` | 27 | Web 端口（**覆盖 `.env` 的 4600**） |
| `HOST` | `localhost` | 28 | |
| `URL_PORT` | `4000` | 29 | 生成绝对 URL 用 |
| `URL_SCHEME` | `http` | 30 | |
| `DEPLOY_ENV` | `development` | 31 | 影响注册/找回密码等行为 |

数据库容器（`docker-compose.dev.yml:50-56`）：`postgres:12-alpine`，库 `ex_venture_dev` / 用户 `postgres` / 密码 `postgres`。

### 4.3 端口

| 端口 | 用途 | 位置 |
|---|---|---|
| `4000` | Web（`http://localhost:4000`） | `docker-compose.dev.yml:118` + `PORT`（:27） |
| `4646` | 游戏 telnet | `docker-compose.dev.yml:119` + **硬编码** `lib/ex_venture/application.ex:53` |
| `15432` | 宿主机访问 PostgreSQL（→ 容器 5432） | `docker-compose.dev.yml:70`（宿主 5432 已被本机 PG 占用） |

> 改 telnet 端口要同时改两处：`application.ex:53` 的 `port: 4646` 和 compose 的 `"4646:4646"` 映射。

### 4.4 数据库地址到底取哪个？—— `ExVenture.Repo.init/2`

`lib/ex_venture/repo.ex:11-20` 的优先级（**这是最容易踩错的一处**）：

```
config/<env>.exs 里已写的 :url   ← 优先，命中就不看环境变量
        ↓ 没写
Vapor 读 DATABASE_URL            ← 环境变量 > .env（Dotenv 先加载，真环境变量覆盖）
```

- **dev**：`config/dev.exs` 没设 `url` → 走 `DATABASE_URL`。
  - 容器里 = `db:5432`（compose `environment`，:24）
  - 宿主机直跑 = `localhost`（`.env:3`，需 compose 已映射 15432 或本机有库）
- **test**：`config/test.exs:16-20` 显式设了 `url` → **永远优先**，环境变量里的 `DATABASE_URL` 被忽略。
  这是**故意的**：compose 注入的 `DATABASE_URL` 指向 dev 库，读了会让测试清空开发库。

---

## 5. test 环境

### 5.1 `config/test.exs`

| 设置 | 值 | 行 | 说明 |
|---|---|---|---|
| `ExVenture.Repo, :pool` | `Ecto.Adapters.SQL.Sandbox` | 17 | 每个用例一个事务，结束回滚 |
| `ExVenture.Repo, :url` | `TEST_DATABASE_URL` 环境变量，否则 `postgresql://postgres:postgres@localhost:15432/ex_venture_test` | 18-20 | 见 §4.4 |
| `Web.Endpoint, :http` | `[port: 4002]` | 25 | 端口仅占位（server 关着） |
| `Web.Endpoint, :server` | `false` | 26 | 测试不起 HTTP 服务 |
| `ExVenture.Mailer, :adapter` | `Bamboo.TestAdapter` | 28 | 用 `assert_email_sent` 断言 |
| `:ex_venture, :listener, :start` | `false` | 30 | 不起 telnet，避免抢 4646 |
| `:ex_venture, :bots, :enabled` | `false` | 33 | 机器人会登录真实世界打怪，必须关 |
| `:ex_venture, :kantele_world, :kickoff` | `false` | 36 | 不播种世界（房间由测试按需起） |
| `:logger, :level` | `:warn` | 39 | 只打 warning/error |
| `:bcrypt_elixir, :log_rounds` | `4` | 41 | 降哈希成本，加速测试 |
| `:stein_storage, :backend` | `:test` | 43 | 上传走内存后端 |

### 5.2 两种跑法

**容器（权威环境）** —— 必须显式传 `TEST_DATABASE_URL`，因为容器里没有 `localhost:15432`：

```bash
docker compose -f docker-compose.dev.yml run --rm \
  -e MIX_ENV=test \
  -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test \
  app mix test
```

> 注意：`app` 容器若正在跑 `mix phx.server`（PID 1），`docker exec` 进去会因 4000/4646
> 被占报 `eaddrinuse`，用 `run --rm` 起一次性容器（见 `AGENTS.md` 的 `## Quick Commands`）。

**宿主机（辅助）**：

```bash
export PATH="/c/Program Files/Erlang OTP/bin:/c/Program Files/Elixir/bin:$PATH"
mix test                     # 连 localhost:15432，需 compose 的 db 已起
mix test --seed 488742       # 固定种子复现随机失败
```

### 5.3 测试基础设施里的隐含设置

| 项 | 位置 | 作用 |
|---|---|---|
| `mix test` 前置钩子 | `mix.exs:83` | `["ecto.create --quiet", "ecto.migrate", "test"]` —— 每次跑测试先建库+迁移 |
| `test/support` 只在 test 编译 | `mix.exs:38` | `elixirc_paths(:test) = ["lib", "test/support"]` |
| 每次运行前清库 | `test/test_helper.exs:4-33` | `TRUNCATE ... RESTART IDENTITY CASCADE` 全部表 |
| **清库保险丝** | `test/test_helper.exs:12` | 库名不以 `_test` 结尾直接 `raise`，防止误清 dev/生产 |
| 沙盒默认模式 | `test/test_helper.exs:36` | `Sandbox.mode(Repo, :manual)` |
| 同步用例的共享连接 + 退出复位 | `test/support/{conn,data,channel}_case.ex` | `async: false` 用例 `{:shared, self()}`，并在 `on_exit` 同步切回 `:manual`（R17，见 `docs/data-world-comments-progress.zh-CN.md`） |
| 世界是否播种 | `config/test.exs:36` | `kickoff: false`；需要真实世界的用例自己 `start_supervised` |

---

## 6. dev vs test 对照

| 项 | dev | test |
|---|---|---|
| 世界播种（`kantele_world.kickoff`） | 未设 → 代码默认 `true`（`lib/kantele/world.ex:157`） | `false` |
| telnet 监听（`:listener.start`） | `true`（4646） | `false` |
| 机器人（`:bots.enabled`） | `true` | `false` |
| Web 服务 | `server: true`，`PORT=4000` | `server: false`，`http port 4002`（占位） |
| 数据库 | `ex_venture_dev`（`DATABASE_URL`） | `ex_venture_test`（config 里写死） |
| 连接池 | `POOL_SIZE=15`（compose）/ `10`（`.env`） | Sandbox（每用例一连接） |
| Mailer | `Bamboo.LocalAdapter` | `Bamboo.TestAdapter` |
| 日志 | `[$level] $message`，无元数据 | 只 warning/error |
| 上传 | `:file` → `uploads/` | `:test`（内存） |
| 代码热重载 | `code_reloader: false` + `fs_poll` 轮询 | — |
| 出口阻挡 | `true` | `true`（共用层，未覆盖） |
| C2 灰度（`enable_jing_learn_cost` / `enable_exp_gate`） | `true` / `true`（`config/dev.exs:69-70`） | 未设 → 代码默认 `false`（`lib/kantele/character/learn_gate.ex:36,39`） |

---

## 7. 常见改动索引

| 想改什么 | 改哪里 |
|---|---|
| Web 端口（容器） | `docker-compose.dev.yml:27`（`PORT`）+ `:118` 端口映射 |
| Web 端口（宿主直跑） | `.env` 的 `PORT` / `URL_PORT`（当前 `4600`） |
| telnet 端口 | `lib/ex_venture/application.ex:53` + `docker-compose.dev.yml:119` |
| dev 库地址 | `docker-compose.dev.yml:24`（容器）/ `.env:3`（宿主） |
| test 库地址 | 环境变量 `TEST_DATABASE_URL`，或 `config/test.exs:18-20` 的兜底值 |
| 关机器人 | `config/config.exs:17`（全局）或 `config/test.exs:33`（仅测试） |
| 测试是否播种世界 | `config/test.exs:36` |
| 出口阻挡总开关 | `config/config.exs:26`（改完重启，编译期读取） |
| 日志级别 | `config/test.exs:39`、`config/dev.exs:52` |
| 邮件去哪看 | dev 打开 `http://localhost:4000/emails/sent`（`Bamboo.LocalAdapter`） |
| 上传目录 | `config/dev.exs:63-65` |
| 开/关代码热重载 | `config/dev.exs:21` —— **别轻易开**，见 §4.1 那条注释 |

---

## 8. 坑（都踩过）

1. **`.env.test` 目前没有任何代码读取。** `ExVenture.Config` 的三个 provider 都是 `%Dotenv{}`
   默认参数，只加载 `.env`。测试库地址实际由 `config/test.exs` 决定（`repo.ex` 里 config 优先）。
   `.env.test` 属于历史残留，改它不会有任何效果。
2. **`.env` 的 `PORT=4600` 和容器的 `4000` 不一致。** 容器里 compose `environment` 覆盖 `.env`
   （Vapor：Dotenv 先加载，真环境变量后覆盖）。所以在容器里访问 4000，在宿主机直跑却是 4600。
3. **不要用 `DATABASE_URL` 指测试库。** compose 注入的它指向 `ex_venture_dev`；
   `test/test_helper.exs` 会 `TRUNCATE` 整库，接错库等于清空开发数据。用 `TEST_DATABASE_URL`。
4. **改 `config/*.exs` 要重编译**，容器里第一次 `mix phx.server` 会明显变慢；`mix test` 同理。
5. **`code_reloader: false` 是故意的**，不是漏配。打开会让 Windows bind mount 上每个请求
   扫全项目源码（≈40s），表现为「点登录没反应」。
6. **telnet 端口是硬编码**，不在任何 `.exs` 里；只改 compose 映射会连不上。

---

## 9. 自查命令

不启动应用、不连库，直接看某个环境最终解析出来的配置：

```bash
# 需要 elixir 在 PATH 里
elixir -e 'c = Config.Reader.read!("config/config.exs", env: :test, target: :host); IO.inspect(c[:ex_venture])'
elixir -e 'c = Config.Reader.read!("config/config.exs", env: :dev,  target: :host); IO.inspect(c[:ex_venture][Web.Endpoint])'
```

定位某个开关的全部出现位置：

```bash
grep -rn "enforce_exit_vetoes\|kantele_world\|TEST_DATABASE_URL" config/ lib/ docker-compose.dev.yml .env*
```
