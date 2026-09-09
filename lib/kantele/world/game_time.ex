defmodule Kantele.World.GameTime do
  @moduledoc """
  游戏时间服务（Q2-T1，对应 LPC timed_event/game_time）

  - 单一时间源：所有换算走 `Kantele.World.GameTime.Calendar` 纯函数；
  - 支持 `now` 注入（测试/运维场景北极星时间），否则实时取系统墙钟；
  - **全部用 `Scheduler.schedule_once` 链式推进**（`schedule_recurring` 取消有 bug 勿用）；
  - tick 每 `cycle_ms` 重算当前游戏钟并刷新 state，供后续阶段（Weather）对齐游戏小时。

  测试/运维可注入实例：`start_link([name: :anonymous, now: <真实秒>, cycle_ms: 40])`。
  """

  use GenServer

  alias Kantele.Scheduler
  alias Kantele.World.GameTime.Calendar

  @default_cycle_ms 1000

  defstruct [:cycle_ms, :now, :last]

  @doc false
  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  @doc "启动；`name: :anonymous` 时不注册全局名（供测试匿名实例）"
  def start_link(opts) do
    case opts[:name] do
      :anonymous ->
        GenServer.start_link(__MODULE__, opts, [])

      _ ->
        GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
    end
  end

  # ---- 公开 API ----

  @doc "当前游戏钟表（含 season 便捷字段）"
  def game_localtime(server \\ __MODULE__),
    do: GenServer.call(server, :game_localtime)

  @doc "当前游戏 DateTime（测试/换算用）"
  def datetime(server \\ __MODULE__), do: GenServer.call(server, :datetime)

  @doc "当前游戏小时（0-23）"
  def hour(server \\ __MODULE__), do: GenServer.call(server, :hour)

  @doc "当前季节（:spring/:summer/:autumn/:winter）"
  def season(server \\ __MODULE__), do: GenServer.call(server, :season)

  # ---- GenServer 回调 ----

  @impl true
  def init(opts) do
    state = %__MODULE__{
      cycle_ms: Keyword.get(opts, :cycle_ms, @default_cycle_ms),
      now: Keyword.get(opts, :now),
      last: nil
    }

    {:ok, schedule_tick(refresh(state), self())}
  end

  @impl true
  def handle_call(:game_localtime, _from, state) do
    {:reply, localtime(state), state}
  end

  def handle_call(:datetime, _from, state) do
    {:reply, Calendar.datetime(now(state)), state}
  end

  def handle_call(:hour, _from, state) do
    %{hour: hour} = localtime(state)
    {:reply, hour, state}
  end

  def handle_call(:season, _from, state) do
    %{season: season} = localtime(state)
    {:reply, season, state}
  end

  def handle_call(:tick, _from, state) do
    {:reply, :ok, schedule_tick(refresh(state), self())}
  end

  @impl true
  def handle_info(:tick, state) do
    {:noreply, schedule_tick(refresh(state), self())}
  end

  # ---- 内部 ----

  defp now(%__MODULE__{now: now}) when is_integer(now), do: now
  defp now(%__MODULE__{}), do: :os.system_time(:second)

  defp localtime(state) do
    lt = Calendar.localtime(now(state))
    Map.put(lt, :season, Calendar.season(lt.month))
  end

  defp refresh(%__MODULE__{} = state) do
    %{state | last: localtime(state)}
  end

  defp schedule_tick(state, pid) do
    Scheduler.schedule_once(state.cycle_ms, fn -> send(pid, :tick) end)
    state
  end
end