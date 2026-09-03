# W3 Arch 重度命令说明

> 本文档记录 W3 批次 arch 巫师重度命令的 LPC 原始功能。
> Elixir 实现为 stubs（因依赖 LPC 对象系统，无直接等价物）。

## 命令对照表

| 命令 | LPC 源文件 | 功能说明 |
|------|-------------|----------|
| `build` | `cmds/wiz/build.c` | 动态创建新房间或物件，需要指定房间区域、出口、描述等参数。LPC 中 `new()` 代替 `clone_object()`。 |
| `call` | `cmds/wiz/call.c` | 调用任意对象的方法，语法类似 `call obj->function(args)`。用于调试、临时修改对象状态。 |
| `smash` | `cmds/wiz/smash.c` | 永久销毁对象，调用 `destruct(obj)`。类似 Elixir `GenServer.stop(pid)` 但更彻底。 |
| `possess` | `cmds/wiz/possess.c` | 巫师附身 NPC，控制 NPC 的所有行动。NPC 原有 AI 被覆盖，巫师可输入 NPC 命令。 |
| `throw` | `cmds/wiz/throw.c` | 让 NPC 或玩家投掷指定物品到目标方向/位置。 |
| `var` | `cmds/wiz/var.c` | 列出并修改对象的内部变量值。调试用，可实时观察/改变对象状态。 |
| `setsk` | `cmds/wiz/setsk.c` | 设置玩家的技能等级，格式 `setsk <player> <skill> <level>`。用于快速调等级测试。 |
| `purge` | `cmds/wiz/purge.c` | 清除房间内的所有物件（NPC、掉落的物品等），但不删除房间本身。 |
| `restore` | `cmds/wiz/restore.c` | 从 `.o` 文件恢复 NPC/房间/物品的存档状态。LPC 对象有内置 `save_object()` / `restore_object()`。 |
| `register` | `cmds/wiz/register.c` | 注册新巫师权限，需要 admin 批准。设置 `wizardp()` 返回 true。 |
| `reboot` | `cmds/wiz/reboot.c` | 热重载游戏世界，不断开现有玩家连接。类似 `mix phx.restart` 但不停机。 |
| `shutdown` | `cmds/wiz/shutdown.c` | 正常关闭游戏服务器，所有玩家收到消息后断开。 |
| `grant` | `cmds/wiz/grant.c` | 授予其他玩家巫师权限或提升权限等级。调用 `valid_grant()` 检查授权者权限。 |
| `changeuser` | `cmds/wiz/changeuser.c` | 修改用户账号属性（密码、email、删除账号等），admin 专属。 |

## LPC 对象系统说明

LPC 是「一切皆对象」的语言，核心机制：

```c
// 克隆对象
object obj = clone_object("/std/npc.c");

// 调用方法
obj->setup();

// 销毁对象
destruct(obj);

// 保存/恢复对象状态
save_object("path/to/file");
restore_object("path/to/file");
```

这些命令都依赖 LPC 的：
- **运行时类型系统**：对象可以动态接收任意消息
- **持久化机制**：`save_object()` 内置序列化
- **动态代码执行**：`call_other()` 可以调用任意对象的方法

## Elixir 为什么不实现

Elixir 的设计哲学完全不同：

| LPC | Elixir |
|-----|--------|
| 一切皆对象 | 一切皆进程 |
| 动态方法调用 | GenServer.call / send |
| 内置持久化 | Ecto / Repo |
| 单一继承 | Behavior / Protocol |
| 解释型 | 编译型 |

**Elixir 等价实现思路**：
- `build` → Web 后台「创建房间」表单 + `Repo.insert`
- `call` → `IEx.pry` 调试或 `mix run --eval`
- `smash` → `Repo.delete` 或 `DynamicSupervisor.terminate_child`
- `possess` → 目前无等价实现
- `grant` → Web 后台「用户管理」手动设置 wiz_level

## 当前实现状态

全部 14 个命令已创建 stub 模块，代码仅：

```elixir
defmodule Kantele.Character.BuildCommand do
  use Kalevala.Character.Command
  def run(conn, _params), do: conn
end
```

功能通过 Web Admin 后台实现（`lib/web/controllers/admin/`）。

## 参考资料

- LPC 源码目录：`C:\files\git\mud\cmds\wiz\`
- 巫师权限系统：`lib/kantele/admin/access.ex`
- Web 后台：`lib/web/controllers/admin/`
