defmodule Kantele.Admin.Security do
  @moduledoc """
  授权注册表：记录巫师对各玩家授予的「可越权使用命令」集合。

  对应 LPC `cmds/arch/grant.c` 的 granted 命令列表。存于内存（public ETS），
  无 DB 依赖，进程内有效、不落盘，重启 / 重载世界后清空（与 `Pkd` / `Vote`
  daemon 一致）。

  ## 公共 API

  - `grant/2`：授予某玩家一个命令
  - `revoke/2`：撤销某玩家的某命令授权
  - `granted?/2`：查询玩家是否被授权某命令
  - `list_for/1`：列出某玩家被授权的全部命令
  - `clear/1`：清空某玩家的全部授权

  测试可用 `ensure!/0` 起一个链接到当前进程的临时实例。
  """

  use GenServer

  @table :kantele_security

  # user_name => [command, ...]
  @default %{}

  # ---- 进程 ----

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def ensure!() do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      _ -> :ok
    end

    # 与 Pkd/Vote 同构：用例 start_link 的表可能已随进程退出被回收，
    # 补建一次，避免注册名仍在而表不在导致后续写入 ArgumentError。
    ensure_table()
    :ok
  end

  @impl true
  def init(_opts) do
    ensure_table()
    {:ok, nil}
  end

  defp ensure_table() do
    if :ets.whereis(@table) == :undefined do
      try do
        :ets.new(@table, [:public, :named_table, read_concurrency: true])
        :ets.insert(@table, {@table, @default})
      rescue
        ArgumentError -> :ok
      end
    end
  end

  # ---- 查询 ----

  @doc "读取当前授权状态（服务未启动时返回缺省）。"
  def read_state() do
    case :ets.whereis(@table) do
      :undefined ->
        @default

      _ ->
        case :ets.lookup(@table, @table) do
          [{table_key, state}] when table_key == @table -> state
          [] -> @default
        end
    end
  end

  @doc "玩家是否被授权使用某命令。"
  def granted?(user_name, command) when is_binary(user_name) and is_binary(command) do
    read_state()
    |> Map.get(user_name, [])
    |> Enum.member?(command)
  end

  @doc "列出某玩家被授权的全部命令。"
  def list_for(user_name) when is_binary(user_name) do
    read_state()
    |> Map.get(user_name, [])
  end

  # ---- 修改（与 Pkd/Vote 同构：直接 ETS 写入，不经 GenServer.call）----

  @doc "授予某玩家一个命令授权。"
  def grant(user_name, command) when is_binary(user_name) and is_binary(command) do
    ensure_table()

    new_state =
      Map.update(read_state(), user_name, [command], fn list ->
        if command in list, do: list, else: [command | list]
      end)

    write_state(new_state)
  end

  @doc "撤销某玩家的某命令授权。"
  def revoke(user_name, command) when is_binary(user_name) and is_binary(command) do
    ensure_table()

    new_state =
      Map.update(read_state(), user_name, [], fn list ->
        List.delete(list, command)
      end)

    write_state(new_state)
  end

  @doc "清空某玩家的全部授权。"
  def clear(user_name) when is_binary(user_name) do
    ensure_table()
    write_state(Map.delete(read_state(), user_name))
  end

  defp write_state(state) do
    :ets.insert(@table, {@table, state})
    :ok
  end
end
