defmodule Kantele.World.W3ObjectEngine do
  @moduledoc """
  W3 对象引擎核心（GenServer，公共 ETS）。

  对应 LPC W3 对象系统的运行时注册表。提供对象实例的注册、查询、销毁与列表，
  供 `call` / `reboot` / `shutdown` 等 arch 命令复用。

  表 `w3_objects`（公共命名表）：

      key   -> {:object, id}
      value -> %{module: atom, state: map, owner: binary | nil,
                created_at: DateTime.t(), parent: id | nil}

  系统级受控操作（reboot / shutdown）调度记录：

      key   -> {:system, :scheduled}
      value -> %{action: :reboot | :shutdown, delay_ms: non_neg_integer,
                actor: binary, scheduled_at: DateTime.t(), dry_run: boolean}

  遵循 daemon 惯例（Pkd / Vote / Security / Prison）：
    - GenServer 持公共 ETS，写入直接 `:ets.insert` 不经 `GenServer.call`；
    - `ensure!/0` 补建表（必要时起一个链接到当前进程的实例）；
    - `read_state/0` 表缺失返缺省。

  安全约束：`reboot` / `shutdown` 这类「应用层受限」系统操作，真实停机 / 重启
  仅在配置 `config :ex_venture, Kantele.World.W3ObjectEngine, allow_system_actions: true`
  显式开启时才会执行（dry-run 默认）；其余环境仅记录调度意图并返回确认文案，
  不触达 OS / 容器。
  """

  use GenServer

  @table :w3_objects
  @system_key {:system, :scheduled}

  @default_state %{objects: %{}, system: nil}

  # ---------------------------------------------------------------------------
  # GenServer API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    ensure_table()
    {:ok, %{}}
  end

  def handle_info({:system_action, action}, state) do
    if allow_system_actions?() do
      execute_system_action(action)
    end

    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # 公共操作（直接 ETS，供命令模块调用）
  # ---------------------------------------------------------------------------

  @doc """
  注册一个已实例化的对象引擎条目。

  `module` 应为可被 `call` 调用的 Elixir 模块原子；`state` 存对象运行时态，
  由调用方维护；`owner` 为注册者角色名（用于调用时权限校验）。
  """
  def register(id, module, state, owner \\ nil) when is_atom(module) and is_map(state) do
    ensure_table()

    entry = %{
      module: module,
      state: state,
      owner: owner,
      created_at: DateTime.utc_now(),
      parent: nil
    }

    :ets.insert(@table, {{:object, id}, entry})
    :ok
  end

  @doc """
  查询对象条目，`id` 不存在时返回 `nil`。
  """
  def lookup(id) do
    case :ets.lookup(@table, {:object, id}) do
      [{{:object, ^id}, entry}] -> entry
      [] -> nil
    end
  end

  @doc """
  销毁对象条目，返回 `:ok` 或 `{:error, :not_found}`。
  """
  def unregister(id) do
    key = {:object, id}

    if :ets.member(@table, key) do
      :ets.delete(@table, key)
      :ok
    else
      {:error, :not_found}
    end
  end

  @doc """
  列出所有已注册对象的 ID。
  """
  def list do
    :ets.select(@table, [{{{:object, :"$1"}, :_}, [], [:"$1"]}])
  end

  @doc """
  读取对象引擎整体状态（服务未启动时返回缺省）。

  返回 `%{objects: %{id => entry}, system: system_info | nil}`。
  """
  def read_state do
    if :ets.whereis(@table) == :undefined do
      @default_state
    else
      objects =
        :ets.select(@table, [{{{:object, :"$1"}, :"$2"}, [], [{{:"$1", :"$2"}}]}])
        |> Map.new()

      %{@default_state | objects: objects, system: scheduled_system()}
    end
  end

  defp scheduled_system do
    key = @system_key

    case :ets.lookup(@table, key) do
      [{^key, info}] -> info
      [] -> nil
    end
  end

  # ---------------------------------------------------------------------------
  # 系统级受控操作（reboot / shutdown）
  # ---------------------------------------------------------------------------

  @doc """
  调度一次系统级操作（`reboot` / `shutdown`）。

  返回 `{:ok, info}`，`info` 含 `action` / `delay_ms` / `actor` / `scheduled_at` /
  `dry_run`。

  真实停机 / 重启仅在配置 `allow_system_actions: true` 时执行，否则仅记录调度
  意图（dry-run），确保测试与开发环境安全、不崩溃。

  延迟通过内部 `Process.send_after` 投递到本 GenServer；若引擎进程未启动（测试 /
  独立 harness），则仅记录意图、不实际执行。
  """
  def schedule_system(action, delay_ms \\ 0, actor \\ "system")
      when action in [:reboot, :shutdown] and is_integer(delay_ms) and delay_ms >= 0 do
    ensure_table()

    info = %{
      action: action,
      delay_ms: delay_ms,
      actor: actor,
      scheduled_at: DateTime.utc_now(),
      dry_run: not allow_system_actions?()
    }

    :ets.insert(@table, {@system_key, info})

    if allow_system_actions?() and Process.whereis(__MODULE__) do
      Process.send_after(__MODULE__, {:system_action, action}, delay_ms)
    end

    {:ok, info}
  end

  @doc """
  取消已调度的系统操作（如有）。
  """
  def cancel_system do
    ensure_table()
    :ets.delete(@table, @system_key)
    :ok
  end

  defp allow_system_actions? do
    Application.get_env(:ex_venture, __MODULE__, [])[:allow_system_actions] == true
  end

  # 应用层受限停机 / 重启：仅停止 / 重启本应用，不触达 OS / 容器。
  defp execute_system_action(:shutdown) do
    Application.stop(:ex_venture)
  end

  defp execute_system_action(:reboot) do
    Application.stop(:ex_venture)
    Application.start(:ex_venture)
  end

  # ---------------------------------------------------------------------------
  # 内部
  # ---------------------------------------------------------------------------

  def ensure! do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      _ -> :ok
    end

    # 与 Pkd/Vote 同构：用例 start_link 的表可能已随进程退出被回收，
    # 补建一次，避免注册名仍在而表不在导致后续写入 ArgumentError。
    ensure_table()
    :ok
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      try do
        :ets.new(@table, [:public, :named_table, read_concurrency: true])
      rescue
        ArgumentError -> :ok
      end
    end
  end
end
