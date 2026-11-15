# 开发环境热更新指南

## 开发方式：dev_start.bat vs 手动 Docker

| | `dev_start.bat`（推荐） | 手动 `docker cp` |
|---|---|---|
| 文件同步 | **自动**（bind mount `.:/app`） | 每次改完要 `docker cp` |
| 改完代码 | `docker restart` 重编译（`code_reloader` 已关） | 需要 cp + restart |
| 改完 UCL | 游戏内 `reload` | 游戏内 `reload` |
| 改完 JS | 浏览器 F5 | cp + restart + F5 |

**结论：用 `dev_start.bat` 启动的开发环境最方便；文件自动同步，但改完 Elixir 代码需 `docker restart` 重编译（见下方说明）。**

## 改动类型与刷新方式

| 改动类型 | 文件位置 | 刷新方式 |
|---------|---------|---------|
| UCL 世界数据 | `data/**/*.ucl` | 游戏内 `reload` |
| Elixir 源码 | `lib/**/*.ex` | `docker restart` 重编译（`code_reloader` 已关，见 `dev-code-reloader-signin-hang.zh-CN.md`） |
| JS/React 前端 | `assets/js/**/*.{js,jsx}` | 浏览器 F5 |
| Elixir 测试 | `test/**/*.exs` | `mix test`（容器内） |
| Mix 配置 | `config/*.exs` | 重启服务器 |

## 详细说明

### 1. UCL 数据（世界/NPC/物品/技能）

修改 `data/` 下的 `.ucl` 文件后，在游戏内输入：

```
reload
```

支持热加载的内容：
- NPC 属性（血量、技能、对话）
- 房间描述、出口
- 物品属性
- 商店货物
- 技能配置

不支持热加载（需重启）：
- 新增 NPC/房间（需重新解析整个世界）
- 修改 brain 行为树结构

### 2. Elixir 源码（编译机制）

`code_reloader` 已在 dev 环境关闭（原因见 `docs/dev-code-reloader-signin-hang.zh-CN.md`），改完 Elixir 源码**不会**自动重编译。`mix phx.server` 启动时会先 `mix compile`，因此重启容器即可把改动编进去：

```bash
docker restart wuxia_mud_dev-app-1
```

重启后自动编译所有改动，约 1~2 分钟恢复服务（过期检测要扫描 bind mount 上的源码）。

#### 为什么 `dev_start.bat` 能重新编译修改过的 `.ex`

这是由三层机制共同决定的：

| 层 | 位置 | 作用 |
|---|---|---|
| 1. 源码同步 | `docker-compose.dev.yml` 第 34 行 `- .:/app` | Windows 主机源码目录 bind mount 到容器 `/app`，Windows 上修改 `.ex` 会立即同步到容器内 |
| 2. 编译产物保留 | `docker-compose.dev.yml` 第 38 行 `app_build:/app/_build` | Named volume，容器重启时保留已编译 BEAM，不自动丢失 |
| 3. 关闭热重载 | `config/dev.exs` 第 21 行 `code_reloader: false` | 运行中的 BEAM 不会自动重新加载，必须容器重启 |
| 4. 触发编译 | `dev_start.bat` 第 51 行 `%COMPOSE% up app` → 容器入口点 `mix phx.server` | 容器启动时 Mix 比较源文件 mtime 与 BEAM mtime，源文件更新则重新编译 |

**完整链条**：你在 Windows 上修改 `.ex` → bind mount 同步到容器 → Ctrl+C 停止容器 → 再运行 `dev_start.bat` → 容器重新启动 → `mix phx.server` 启动 → Mix 检测源文件比已编译 BEAM 新 → **重新编译该文件** → 修改生效。

#### 新增的 `.ex` 文件还能编译吗？

**能。** 容器启动时，Mix 会扫描 `lib/`（以及其他源码路径）下所有 `.ex` 文件，包括新增的：

- **新增模块文件**：Mix 发现新的 `.ex` 文件，会把它编译成对应的 `.beam` 放入 `_build/dev/lib/ex_venture/ebin/`。容器启动后该模块即可被 `require`/`use`/调用。
- **前提**：新增文件必须放在 Mix 编译路径下（默认 `lib/`），且语法正确。如果新增文件有编译错误，容器启动会失败，需先修复再重启。
- **注意**：新增文件被编译进 `.beam` 后，代码中若未 `require`/`use` 或调用该模块，它只是静态存在于磁盘，不会自动运行；需要在现有代码中引用才会生效。

**验证新增文件是否编译成功**：
```bash
docker exec -w /app wuxia_mud_dev-app-1 ls _build/dev/lib/ex_venture/ebin/ | grep -i <新模块名>
```

见 `Elixir 源码` 表格中的“重启容器”刷新方式。

### 3. 前端 JS/React

修改 `assets/js/` 下的文件后：

```bash
docker cp assets/js/... wuxia_mud_dev-app-1:/app/assets/js/...
docker restart wuxia_mud_dev-app-1
```

然后在**浏览器**中按 **F5** 刷新页面（清缓存用 Ctrl+Shift+R）。

### 4. 测试

在容器内运行测试：

```bash
docker exec -w /app wuxia_mud_dev-app-1 sh -c 'MIX_ENV=test mix test'
```

## 容器管理速查

```bash
# 查看容器状态
docker ps

# 查看最近日志
docker logs wuxia_mud_dev-app-1 --tail 30

# 重启（最常用的刷新方式）
docker restart wuxia_mud_dev-app-1

# 同步文件到容器
docker cp <本地文件> wuxia_mud_dev-app-1:/app/<容器路径
# 健康检查
docker exec wuxia_mud_dev-app-1 wget -q -O- http://127.0.0.1:4000/_health
```

## Docker 文件位置

Docker Desktop 在 Windows 上用 WSL2 后端运行，所有容器/镜像/数据卷都保存在 `docker-desktop` 这个 WSL 发行版的虚拟磁盘里，不是普通 Windows 目录。

| 内容 | 位置 |
|---|---|
| docker-desktop 虚拟磁盘（宿主机） | `F:\Docker\DockerDesktopWSL\main\ext4.vhdx` |
| Docker 根目录（WSL 内） | `/var/lib/docker/` |
| 数据卷（WSL 内） | `/var/lib/docker/volumes/<卷名>/_data/` |
| 主要卷 | `wuxia_mud_dev_postgres_data`（dev 库 `ex_venture_dev`）、`wuxia_mud_ex_postgres-data`（旧生产库 `ex_venture`）、`app_deps` / `app_build` / `app_mix_home` / `app_hex_cache` / `app_node_modules` |

访问方式：
- Windows 文件管理器直接输入：`\\wsl$\docker-desktop\var\lib\docker\volumes\...`
- 或命令行进入：`wsl -d docker-desktop bash`，之后浏览 `/var/lib/docker/volumes/`

备份/迁移数据库 = 复制对应卷目录（或整个 vhdx）。

注意：
- **游戏源码/世界数据不在 docker 里**：app 容器是 bind mount 宿主仓库 `C:\files\git\wuxia_mud_ex` → `/app`，`data/world/*.ucl`、`lib/` 直接看 Windows 目录即可。
- 与 Ubuntu WSL（`C:\Users\honggang\AppData\Local\wsl\...\ext4.vhdx`）无关，那个磁盘里没有 docker 引擎或游戏数据。

## 重启服务器

### Docker 容器内开发服务器

```bash
# 仅重启容器（保留数据，推荐）
docker restart wuxia_mud_dev-app-1

# 彻底重建（代码/依赖有大改动时）
docker-compose down && docker-compose up -d
```

### 本地原生运行（非 Docker）

如果服务器是通过 `mix phx.server` 在本地启动的：

```bash
# 在项目目录下
mix phx.server
```

服务器默认运行在 4646 端口（telnet）和 4000 端口（web）。

## 查找并杀死隐藏的服务器进程

### 场景：CMD 窗口关了但服务器还在跑

服务器进程可能仍在后台运行，端口被占用导致新实例启动失败。

### Windows

```powershell
# 查看占用 4000 端口（web）的进程
netstat -ano | findstr :4000

# 查看占用 4646 端口（telnet）的进程
netstat -ano | findstr :4646

# 找到 PID 后杀死进程（替换 <PID>）
taskkill /PID <PID> /F

# 或者直接按名称杀所有 beam.smp 进程（Elixir/Erlang 运行时）
taskkill /IM beam.smp.exe /F
```

### Linux/macOS

```bash
# 查看占用端口的进程
lsof -i :4000
lsof -i :4646

# 杀死进程
kill <PID>

# 强制杀死
kill -9 <PID>
```

### 一键清理（推荐）

```powershell
# Windows PowerShell：杀掉所有 Erlang/Elixir 进程
Get-Process beam.smp -ErrorAction SilentlyContinue | Stop-Process -Force
```

### 杀完之后

确认端口释放后再启动：

```bash
# 检查端口是否还被占用
netstat -ano | findstr ":4000"

# 无输出 = 端口已释放，可以启动
mix phx.server
```

## Docker 环境下的端口冲突

如果 Docker 容器和本地进程同时占用端口：

```bash
# 查看哪些容器在用端口
docker ps --format "table {{.Names}}\t{{.Ports}}"

# 停止所有相关容器
docker stop $(docker ps -q --filter "ancestor=wuxia_mud_dev")

# 再启动
docker-compose up -d
```
