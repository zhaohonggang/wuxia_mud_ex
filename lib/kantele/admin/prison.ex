defmodule Kantele.Admin.Prison do
  @moduledoc """
  禁闭（地狱）daemon，对应 LPC `cmds/arch/throw.c` 的 `get_into_prison` /
  `is_in_prison` 语义。

  运行态用受监督 GenServer 持有的 public ETS 表，语义与 LPC daemon 一致：
  进程内有效、不落盘，重启 / 重载世界后清空（与 `Pkd` / `Vote` / `Security`
  同构）。刑期以 Unix 秒记录 `until`，`in_prison?/1` 读取时惰性清理过期刑期。

  ## LPC 时长单位（分钟）

  默认 20 分钟；后缀 `h` 小时(×60)、`d` 天(×1440)、`m` 月(×43200)、
  `y` 年(×525600)。无后缀即分钟。

  ## 允许的理由

  `flood`（重复信息）、`copy`（转述污言）、`rude`（口出污言）、
  `rumor`（造谣）、`bug`（利用系统错误）、`main`（维护档案）。

  ## 公共 API

  - `sentence/4`：判处禁闭，返回 `:ok` 或 `{:error, :invalid_reason}`
  - `release/1`：提前释放（对应 LPC `free`）
  - `in_prison?/1`：查询是否在禁闭中（惰性清理过期刑期）
  - `query_all/0`：列出当前全部有效刑期
  - `detail/1`：某人的刑期详情
  - `parse_duration/1`：解析 LPC 时长串为分钟数
  - `reasons/0`：允许的理由列表

  测试可用 `ensure!/0` 起一个链接到当前进程的临时实例。
  """

  use GenServer

  @table :kantele_prison

  @reasons ~w[flood copy rude rumor bug main]

  @default %{sentences: %{}}

  # ---- 进程 ----

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def ensure!() do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      _ -> :ok
    end

    # 与 Pkd/Vote 同构：补建可能被回收的 ETS 表。
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

  @doc "读取当前 daemon 状态（服务未启动时返回缺省）。"
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

  @doc "允许的理由列表。"
  def reasons(), do: @reasons

  @doc "某人是否在禁闭中（同时惰性清理过期刑期）。"
  def in_prison?(name) when is_binary(name) do
    case :ets.whereis(@table) do
      :undefined ->
        false

      _ ->
        state = read_state()
        now = now()
        sentence = Map.get(state.sentences, name)

        case sentence do
          nil ->
            false

          %{until: until} when until > now ->
            true

          _expired ->
            # 过期：从 ETS 摘除，避免刑期永久残留
            :ets.insert(@table, {@table, %{state | sentences: Map.delete(state.sentences, name)}})
            false
        end
    end
  end

  @doc "列出当前全部有效刑期（自动排除过期）。"
  def query_all() do
    case :ets.whereis(@table) do
      :undefined ->
        []

      _ ->
        state = read_state()
        now = now()

        active =
          state.sentences
          |> Enum.filter(fn {_name, s} -> s.until > now end)
          |> Map.new()

        # 顺带清理过期的
        if map_size(active) != map_size(state.sentences) do
          :ets.insert(@table, {@table, %{state | sentences: active}})
        end

        active |> Enum.map(fn {name, s} -> Map.put(s, :name, name) end)
    end
  end

  @doc "某人的刑期详情（过期返回 nil）。"
  def detail(name) when is_binary(name) do
    if in_prison?(name) do
      Map.get(read_state().sentences, name)
    else
      nil
    end
  end

  # ---- 修改（与 Pkd/Vote 同构：直接 ETS 写入，不经 GenServer.call）----

  @doc """
  判处某人禁闭。`name` 目标、`by` 执行者、`minutes` 分钟数、`reason` 理由。

  理由不在白名单返回 `{:error, :invalid_reason}`；分钟数 <= 0 返回
  `{:error, :invalid_duration}`。
  """
  def sentence(name, by, minutes, reason)
      when is_binary(name) and is_binary(by) and is_integer(minutes) and is_binary(reason) do
    cond do
      reason not in @reasons ->
        {:error, :invalid_reason}

      minutes <= 0 ->
        {:error, :invalid_duration}

      true ->
        ensure_table()

        entry = %{
          reason: reason,
          by: by,
          minutes: minutes,
          since: now(),
          until: now() + minutes * 60
        }

        current = read_state()
        write_state(%{current | sentences: Map.put(current.sentences, name, entry)})
    end
  end

  @doc "提前释放某人（对应 LPC `free`）。"
  def release(name) when is_binary(name) do
    ensure_table()
    current = read_state()
    write_state(%{current | sentences: Map.delete(current.sentences, name)})
  end

  # ---- 时长解析（纯函数，供命令与测试复用）----

  @doc """
  解析 LPC 时长串为分钟数。返回 `{:ok, minutes}` 或 `:error`。

      "20"   -> 20      "2h" -> 120     "1d" -> 1440
      "1m"   -> 43200   "1y" -> 525600
  """
  def parse_duration(nil), do: {:ok, 20}
  def parse_duration(""), do: {:ok, 20}

  def parse_duration(token) when is_binary(token) do
    case Regex.run(~r/^(-?\d+)([hdmy]?)$/, String.trim(token)) do
      [_, num, unit] ->
        n = String.to_integer(num)
        {:ok, n * multiplier(unit)}

      _ ->
        :error
    end
  end

  defp multiplier("h"), do: 60
  defp multiplier("d"), do: 60 * 24
  defp multiplier("m"), do: 1440 * 30
  defp multiplier("y"), do: 1440 * 365
  defp multiplier(_), do: 1

  defp now(), do: System.system_time(:second)

  defp write_state(state) do
    :ets.insert(@table, {@table, state})
    :ok
  end
end
