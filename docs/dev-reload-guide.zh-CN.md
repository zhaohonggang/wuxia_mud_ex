# 开发环境热更新指南

## 开发方式：dev_start.bat vs 手动 Docker

| | `dev_start.bat`（推荐） | 手动 `docker cp` |
|---|---|---|
| 文件同步 | **自动**（bind mount `.:/app`） | 每次改完要 `docker cp` |
| 改完代码 | 直接生效，等自动编译 | 需要 cp + restart |
| 改完 UCL | 游戏内 `reload` | 游戏内 `reload` |
| 改完 JS | 浏览器 F5 | cp + restart + F5 |

**结论：用 `dev_start.bat` 启动的开发环境最方便，改完代码等几秒自动编译即可。**

## 改动类型与刷新方式

| 改动类型 | 文件位置 | 刷新方式 |
|---------|---------|---------|
| UCL 世界数据 | `data/**/*.ucl` | 游戏内 `reload` |
| Elixir 源码 | `lib/**/*.ex` | 自动编译（bind mount）或 `docker restart` |
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

### 2. Elixir 源码

`mix phx.server` 开发模式下，容器内文件变化会自动检测编译。

**但**通过 `docker cp` 同步的文件可能不被 watcher 检测到，此时需要手动重启：

```bash
docker restart wuxia_mud_dev-app-1
```

重启后自动编译所有改动，约 25 秒恢复服务。

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
docker cp <本地文件> wuxia_mud_dev-app-1:/app/<容器路径>

# 健康检查
docker exec wuxia_mud_dev-app-1 wget -q -O- http://127.0.0.1:4000/_health
```

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
