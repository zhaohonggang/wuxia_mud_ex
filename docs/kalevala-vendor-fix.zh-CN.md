# Kalevala 框架 Vendor 化与启动竞态修复

> 记录 2026-09-01 对 Kalevala 依赖的改动：原因、过程与验证。
> 对应提交：`aaf0192`（分支 `kalevala`）

---

## 一、背景现象

服务器启动时会反复出现两类崩溃日志：

### 1. 启动竞态：`:erlang.send(:undefined, ...)`

```
[error] GenServer #PID<0.846.0> terminating
** (ArgumentError) argument error
    :erlang.send(:undefined, %Kalevala.Event{...topic: Kalevala.Event.Movement...})
    (kalevala 0.1.0) lib/kalevala/character/foreman.ex:230:
        anonymous fn/2 in Kalevala.Character.Foreman.send_events/1
```

**根因**：玩家连接、NPC 刷出（wander）时，角色在房间里产生移动事件（`Kalevala.Event.Movement`）。`send_events/1` 通过
`Conn.event_router/1` → `Private.default_event_router/1` 用 `:global.whereis_name(Room.global_name(room_id))` 查目标房间的全局名。

在启动并发窗口里，房间的全局名**尚未注册**时，`whereis_name/1` 返回 `:undefined`。`Conn.event_router/1` 有两个子句：
- `event_router: nil` → 走 `default_event_router`
- 其它值 → 直接返回

`:undefined` 既不是 `nil`，于是被第二个子句匹配，`send_events` 里执行 `send(:undefined, event)` 崩溃。

### 2. guarder 守卫 KeyError

```
** (KeyError) key :guarder not found in: %{__struct__: Kalevala.Meta.Trimmed, vitals: ...}
    (ex_venture 0.1.0) lib/kantele/world/room.ex:328
```

**根因**：`Kantele.World.Room.check_guarders/3` 里写的是 `c.meta.guarder && Guarder.is_guarder?(c)`。
房间 `context.characters` 里的角色 meta 是**被裁剪过的** `%Kalevala.Meta.Trimmed{}`（只含 `vitals`），没有 `:guarder` 字段，
因此点语法 `c.meta.guarder` 直接抛 `KeyError`。

> 说明：这两处崩溃均在**启动期**（NPC 刷出 / 玩家进入）触发，与本批兄弟系统（brothers/swear）功能无关，属于框架/既有代码的竞态与健壮性缺陷。

---

## 二、为什么选择 Vendor 方案

Kalevala 原本是 **Hex 依赖**：

```elixir
# mix.exs 修改前
{:kalevala, "~> 0.1"}
```

它被 `mix deps.get` 下载到容器内 `deps/kalevala/`，并编译进 `_build`。`deps` 与 `_build` 在
`docker-compose.dev.yml` 中是**独立的 Docker 命名卷**，且被 `.gitignore` / `.dockerignore` 忽略——**不进 git**。

要修复 `conn.ex` 的启动竞态，需要给它打补丁，而直接改容器内的 `deps/kalevala` 是**临时的**：容器重建 / `mix deps.get`
后补丁即被冲掉，无法持久化。

可行的方案：
- **A. Vendor 为 path 依赖（本次采用）**：把整个 Kalevala 源码镜像进仓库 `vendor/kalevala`，改 `mix.exs` 为
  `{:kalevala, path: "vendor/kalevala"}`。补丁留在仓库里，永久生效。
- **B. 改为 git 依赖并 fork 打补丁**：仓库里只多一个补丁 diff（更轻量），但需要托管一个 fork 并通过 git 依赖。

本次按用户确认采用**方案 A**。

---

## 三、实施过程

### 1. 拷贝源码到仓库

在容器内把 Hex 拉取的源码镜像到仓库的 `vendor/kalevala`：

```bash
mkdir -p /app/vendor/kalevala
cp -r /app/deps/kalevala/lib /app/vendor/kalevala/
cp /app/deps/kalevala/mix.exs /app/vendor/kalevala/
cp /app/deps/kalevala/LICENSE /app/vendor/kalevala/
cp /app/deps/kalevala/.formatter.exs /app/vendor/kalevala/
```

共 **47 个 `.ex` 源文件** + `mix.exs`、`LICENSE`、`.formatter.exs`。

> **这是整库镜像，不是手写**。path 依赖必须整体编译，因此框架全部源码必须入仓库。
> 多个 `room.ex` / `zone.ex` / `item.ex` 重名是**文件路径巧合**，但模块命名空间不同
> （项目是 `Kantele.*`，框架是 `Kalevala.*`），编译产物是不同的 beam，互不冲突，**代码不重复**。

### 2. 打补丁：`conn.ex`（唯一修改的文件）

`vendor/kalevala/lib/kalevala/character/conn.ex` 的 `default_event_router/1`：

```elixir
character ->
  {:global, name} = Room.global_name(character.room_id)

  case :global.whereis_name(name) do
    pid when is_pid(pid) -> pid
    # Room's global name not yet registered (startup race). Return nil
    # so send_events skips the send instead of send/2 to :undefined.
    _ -> nil
  end
```

`nil` 会被 `send_events` 的 `case Conn.event_router(conn)` 的 `nil -> conn` 子句捕获，**跳过发送**，不再崩溃。

### 3. 修复 guarder KeyError

`lib/kantele/world/room.ex` 的 `check_guarders/3`：

```elixir
# 改前
c.meta.guarder && Guarder.is_guarder?(c)

# 改后（对裁剪后的 Trimmed meta 安全）
Map.get(c.meta, :guarder) && Guarder.is_guarder?(c)
```

### 4. 重写 SwearRequestEvent（顺带修复结构缺陷）

初版 `SwearRequestEvent.call/2` 用了多层嵌套 `if/case`，**少了一个 `end`**，导致后续兄弟模块
（`ForwardEvent` / `LookEvent` / `CombatEvent` 等）被错误地嵌套进 `SwearRequestEvent` 内，出现形如
`Kantele.World.Room.SwearRequestEvent.Kantele.World.Room.LookEvent` 的异常模块引用警告。

重写为 `case` + `cond` 的扁平结构，`end` 配平，消除嵌套泄漏。

### 5. 切换为 path 依赖

```elixir
# mix.exs 修改后
{:kalevala, path: "vendor/kalevala"}
```

并从 `mix.lock` 删除 kalevala 的 hex 条目（path 依赖不进 lock）。

> ⚠️ **重要**：期间一次性执行 `mix deps.get` 曾触发**全量重解析**，把 `plug`/`cowboy`/`ranch`/`jason` 等
> 升级到不兼容 Elixir 1.11.1 的版本（如 `plug 1.20.3` 要求 Elixir ~> 1.15），导致编译失败。
> **解决办法**：`git checkout mix.lock` 恢复全部锁定版本，仅删除 kalevala 一行，再 `mix deps.get`。
> 教训：切换为 path 依赖时，**务必保持 `mix.lock` 其余条目不变**，只动 kalevala 相关，避免误升级。

---

## 四、编译与验证

- 编译需用**增量** `mix compile`（不要 `--force`，否则会连带重编译被锁定的旧版 `plug` 并失败）。
- `mix deps` 确认 kalevala 解析为 `(vendor/kalevala)`。
- `diff -rq deps/kalevala/lib vendor/kalevala/lib`：**只有 `conn.ex` 一处差异**，证实其余文件与上游一致。
- 容器重启（`docker compose up -d app`）后，最近日志**无** `:erlang.send(:undefined, ...)` 崩溃，也**无** guarder KeyError。
- 测试基线 878 tests / 27 failures（27 个为预存在的测试隔离问题，与本变更无关）。

---

## 五、文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `mix.exs` | 修改 | kalevala 改为 path 依赖 |
| `mix.lock` | 修改 | 删除 kalevala hex 条目 |
| `vendor/kalevala/**` | 新增 | Kalevala 0.1.0 全量源码镜像（约 50 个文件） |
| `vendor/kalevala/lib/kalevala/character/conn.ex` | 修改 | 启动竞态 `:undefined` 保护（唯一改动） |
| `lib/kantele/world/room.ex` | 修改 | guarder `Map.get` 修复 + SwearRequestEvent 重写 |

---

## 六、注意事项 / 后续

- **不要对 vendor 里的其它文件做无谓修改**：保持与上游一致，便于日后 diff / 升级。
- 若想更轻量：可改走 **git 依赖 + fork**，仓库只存补丁 diff（方案 B）。
- `mix deps.get` 时注意 `mix.lock` 版本锁定，避免误升级。
- 若日后升级 Kalevala，需重新镜像新版本并核对补丁。
