defmodule Kantele.World.Possession do
  @moduledoc """
  附身（possess）运行时状态。

  W3 arch 命令 `possess` 的预留接口（B2 W3 对象引擎二期）。本端口无 LPC 的
  body-swap / 会话重绑原语，故这里只维护「巫师 ↔ 目标生物」的附身映射，
  供 `possess` 命令记录与查询，并供将来的控制转移 / 说话者替换使用。

  表 `w3_possession`（公共命名表）：

      key   -> {:possessor, possessor_id}
      value -> %{target_id: id, target_name: binary, since: DateTime.t()}
      key   -> {:target, target_id}
      value -> possessor_id

  遵循 daemon 惯例（Pkd / Vote / Security / Prison / W3ObjectEngine）：
    - GenServer 持公共 ETS，写入直接 `:ets.insert` 不经 `GenServer.call`；
    - `ensure!/0` 补建表（必要时起一个链接到当前进程的实例）；
    - `read_state/0` 表缺失返缺省。
  """

  use GenServer

  @table :w3_possession

  @default_state %{possessions: []}

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

  # ---------------------------------------------------------------------------
  # 公共操作（直接 ETS，供命令模块调用）
  # ---------------------------------------------------------------------------

  @doc "记录附身：possessor 附身到 target。返回 :ok。"
  def possess(possessor_id, target_id, target_name)
      when is_binary(target_name) do
    ensure_table()

    entry = %{
      target_id: target_id,
      target_name: target_name,
      since: DateTime.utc_now()
    }

    :ets.insert(@table, {{:possessor, possessor_id}, entry})
    :ets.insert(@table, {{:target, target_id}, possessor_id})
    :ok
  end

  @doc "解除某个目标的附身（无论谁附身）。返回 :ok 或 {:error, :not_found}。"
  def release(target_id) do
    ensure_table()

    case :ets.lookup(@table, {:target, target_id}) do
      [{{:target, ^target_id}, possessor_id}] ->
        :ets.delete(@table, {:possessor, possessor_id})
        :ets.delete(@table, {:target, target_id})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  @doc "解除某附身者当前附身的所有目标（通常仅一个）。返回 :ok 或 {:error, :not_found}。"
  def release_by_possessor(possessor_id) do
    ensure_table()

    case :ets.lookup(@table, {:possessor, possessor_id}) do
      [{{:possessor, ^possessor_id}, %{target_id: target_id}}] ->
        :ets.delete(@table, {:possessor, possessor_id})
        :ets.delete(@table, {:target, target_id})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  @doc "某目标是否正被附身。"
  def possessed?(target_id) do
    :ets.member(@table, {:target, target_id})
  end

  @doc "查询附身者当前附身的目标，缺省 nil。"
  def target_of(possessor_id) do
    case :ets.lookup(@table, {:possessor, possessor_id}) do
      [{{:possessor, ^possessor_id}, %{target_id: target_id, target_name: target_name}}] ->
        %{target_id: target_id, target_name: target_name}

      [] ->
        nil
    end
  end

  @doc "查询某目标当前的附身者 id，缺省 nil。"
  def possessor_of(target_id) do
    case :ets.lookup(@table, {:target, target_id}) do
      [{{:target, ^target_id}, possessor_id}] -> possessor_id
      [] -> nil
    end
  end

  @doc "列出所有附身关系。返回 [%{possessor_id, target_id, target_name, since}]。"
  def list do
    :ets.match(@table, {{:possessor, :"$1"}, :"$2"})
    |> Enum.map(fn [possessor_id, %{target_id: target_id, target_name: target_name, since: since}] ->
      %{possessor_id: possessor_id, target_id: target_id, target_name: target_name, since: since}
    end)
  end

  @doc "底层 ETS 表名（测试用）。"
  def table, do: @table

  @doc """
  读取附身整体状态（服务未启动时返回缺省）。
  返回 `%{possessions: [%{possessor_id, target_id, target_name, since}]}`。
  """
  def read_state do
    if :ets.whereis(@table) == :undefined do
      @default_state
    else
      %{@default_state | possessions: list()}
    end
  end

  # ---------------------------------------------------------------------------
  # 内部
  # ---------------------------------------------------------------------------

  def ensure! do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      _ -> :ok
    end

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
