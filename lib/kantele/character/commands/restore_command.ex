defmodule Kantele.Character.RestoreCommand do
  @moduledoc """
  恢复命令：`restore [<玩家>]`

  对应 LPC `cmds/arch/restore.c` 的「从存档恢复玩家数据」核心语义。本端口玩家数据
  存于 Postgres，无 LPC 的扁平文件备份系统，故实现为：向目标角色进程发送
  `character/restore` 事件，由其自身从数据库存档重载运行态（与 `character/teleport`
  同款「外部发起、自身执行」模式，见 `Kantele.Character.RestoreEvent`）。

  - `restore`（无参）：恢复**自己**。
  - `restore <玩家>`：恢复房间内名为该玩家的在线角色（需其有存档）。

  仅巫师可用。目标无存档 / 不在场时给出明确提示。
  """

  use Kalevala.Character.Command

  alias Kalevala.Event
  alias Kantele.Character.BeastTaming
  alias Kantele.Character.CommandView
  alias Kantele.Character.Commands.WizArch
  alias Kantele.World.ObjectRestore

  def run(conn, params) do
    WizArch.guard(conn, params, &handle/2)
  end

  defp handle(conn, %{"rest" => rest}) do
    arg = String.trim(rest)

    if arg == "" do
      restore_self(conn)
    else
      restore_named(conn, arg)
    end
  end

  defp handle(conn, _params), do: restore_self(conn)

  defp restore_self(conn) do
    me = conn.character
    do_restore(conn, me.name, me.pid)
  end

  defp restore_named(conn, arg) do
    case BeastTaming.find(conn, arg) do
      nil ->
        reply(conn, "这里没有名字叫 #{arg} 的玩家。\n")

      target ->
        do_restore(conn, target.name, target.pid)
    end
  end

  defp do_restore(conn, name, target_pid) do
    case resolve_save(conn, name) do
      {:ok, _info} ->
        send(target_pid, %Event{from_pid: self(), topic: "character/restore", data: %{}})
        reply(conn, "已向#{name}发送恢复指令，其角色状态将从存档重载。\n")

      {:error, :not_found} ->
        reply(conn, "找不到#{name}的存档，无法恢复。\n")
    end
  end

  # 生产环境走 ObjectRestore（数据库存档核验）；单测可经 conn.private[:restore_save_for] 注入。
  defp resolve_save(conn, name) do
    case Map.get(conn.private || %{}, :restore_save_for) do
      fun when is_function(fun, 1) -> fun.(name)
      _ -> ObjectRestore.info(name)
    end
  end

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
