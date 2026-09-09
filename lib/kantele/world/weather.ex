defmodule Kantele.World.Weather do
  @moduledoc """
  Weather/season GenServer (Q2-T2, LPC adm/nature + weatherd.c 的天象推演)

  - 状态：`season`（春/夏/秋/冬）+ `weather`（rain/sun/wind）+ `phase`（当前时段行）；
  - 每 `cycle_ms` tick：读 `GameTime.game_localtime/0` → `step/2` 纯函数推进；
    - 换季（季节变化）：随机重选本季天气表（四季×3），视为天象特大变化播报；
    - 时段变化（phase.hour 变化）：按新行的 time_msg/desc_msg 播报；
  - 播报走 `Kantele.Communication.announce("general", ...)`（Q2-T0 后真实可见）；
  - **所有定时用 `Scheduler.schedule_once` 链式**（`schedule_recurring` 取消有 bug 勿用）。

  API（供 look 注入与测试）：
  - `season/0`、`weather/0`、`current_table/0`、`current_phase/0`
  - `outdoor_description/0`（含颜色 tag 的时段描写，供户外房间 look 注入）
  - `time_msg/0`、`light/0`（当前亮/暗二元；v2 光线功能用）

  测试/运维可注入实例：`start_link([name: :anonymous, seed: 1, announce: false,
  cycle_ms: 40])`；`step/2` 为纯函数可直接单测。
  """

  use GenServer

  require Logger

  alias Kantele.Scheduler
  alias Kantele.World.GameTime
  alias Kantele.World.Weather.Data

  @default_cycle_ms 10_000
  @weathers [:rain, :sun, :wind]
  @season_names %{spring: "春", summer: "夏", autumn: "秋", winter: "冬"}
  @weather_names %{rain: "雨", sun: "晴", wind: "风"}

  defstruct [:cycle_ms, :seed, :channel, :announce?, :season, :weather, :phase]

  @type t :: %__MODULE__{}

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

  @doc "当前季节（:spring/:summer/:autumn/:winter）"
  def season(server \\ __MODULE__), do: GenServer.call(server, :season)

  @doc "当前天气（:rain/:sun/:wind）"
  def weather(server \\ __MODULE__), do: GenServer.call(server, :weather)

  @doc "当前套表 key（如 :spring_rain）"
  def current_table(server \\ __MODULE__), do: GenServer.call(server, :current_table)

  @doc "当前时段行 %{hour, time_msg, desc_msg, outcolor}"
  def current_phase(server \\ __MODULE__), do: GenServer.call(server, :current_phase)

  @doc "户外房间 look 注入的天气/昼夜段（含颜色 tag；无则 nil）"
  def outdoor_description(server \\ __MODULE__), do: GenServer.call(server, :outdoor_description)

  @doc "当前时辰语（time_msg）"
  def time_msg(server \\ __MODULE__), do: GenServer.call(server, :time_msg)

  @doc "当前光照（:light / :dark，用于 v2 光线功能与文案）"
  def light(server \\ __MODULE__) do
    case GenServer.call(server, :phase_hour) do
      hour when hour in 6..17 -> :light
      _ -> :dark
    end
  end

  @doc "立即推进一档（test/运维用）；返回 :ok"
  def tick(server \\ __MODULE__), do: GenServer.call(server, :tick)

  # ---- 纯状态机（可单测）：给定当前游戏钟，返回新状态与播报列表 ----

  @doc """
  推进天象：`ctx = %{season:, weather:, phase:}` 与 `GameTime.game_localtime/0` 结果。

  返回 `{new_ctx, [announcement_text]}`：
  - 换季 → 随机重选本季天气表 + 「换季」播报；
  - 时段变化 → 按新行播报；
  - 无变化 → 空播报。
  """
  def step(ctx, game_localtime) do
    new_season = game_localtime.season
    {new_weather, table_key} =
      if new_season != ctx.season do
        w = pick_weather()
        {w, table_key(new_season, w)}
      else
        {ctx.weather, table_key(new_season, ctx.weather)}
      end

    phase = Data.select_phase(Data.table(table_key), game_localtime.hour)

    announcements =
      cond do
        new_season != ctx.season ->
          [
            "【天象】#{@season_names[new_season]}季已至，天色转为#{@weather_names[new_weather]}天：#{phase.time_msg}。"
          ]

        phase.hour != ctx.phase.hour ->
          ["【天象】#{phase.time_msg}：#{phase.desc_msg}"]

        true ->
          []
      end

    {%{ctx | season: new_season, weather: new_weather, phase: phase}, announcements}
  end

  @doc "按季随机选一种天气（rain/sun/wind）"
  def pick_weather() do
    Enum.at(@weathers, :rand.uniform(3) - 1)
  end

  @doc "套表 key：season+weather 拼接（如 :spring_rain）"
  def table_key(season, weather), do: :"#{season}_#{weather}"

  # ---- GenServer 回调 ----

  @impl true
  def init(opts) do
    seed = Keyword.get(opts, :seed)
    :rand.seed(:exsss, default_seed(seed))

    game_lt = GameTime.game_localtime()
    {ctx, _announcements} =
      step(
        %__MODULE__{
          cycle_ms: Keyword.get(opts, :cycle_ms, @default_cycle_ms),
          seed: seed,
          channel: Keyword.get(opts, :channel, "general"),
          announce?: Keyword.get(opts, :announce, true),
          season: :winter,
          weather: :sun,
          phase: %{hour: nil}
        },
        game_lt
      )

    {:ok, schedule_tick(ctx, self())}
  end

  @impl true
  def handle_call(:season, _from, state), do: {:reply, state.season, state}
  def handle_call(:weather, _from, state), do: {:reply, state.weather, state}

  def handle_call(:current_table, _from, state) do
    {:reply, table_key(state.season, state.weather), state}
  end

  def handle_call(:current_phase, _from, state), do: {:reply, state.phase, state}

  def handle_call(:outdoor_description, _from, state) do
    {:reply, render_phase(state.phase), state}
  end

  def handle_call(:time_msg, _from, state), do: {:reply, state.phase.time_msg, state}
  def handle_call(:phase_hour, _from, state), do: {:reply, state.phase.hour, state}

  def handle_call(:tick, _from, state) do
    {:reply, :ok, schedule_tick(advance(state), self())}
  end

  @impl true
  def handle_info(:tick, state) do
    {:noreply, schedule_tick(advance(state), self())}
  end

  @impl true
  def terminate(_reason, _state), do: :ok

  # ---- 内部 ----

  defp advance(state) do
    {new_state, announcements} =
      step(state, GameTime.game_localtime())

    Enum.each(announcements, &announce(state, &1))
    new_state
  end

  defp announce(%__MODULE__{announce?: false}, _text), do: :ok

  defp announce(%__MODULE__{channel: nil}, _text), do: :ok

  defp announce(%__MODULE__{channel: channel}, text) do
    Kantele.Communication.announce(channel, text)
    :ok
  rescue
    e ->
      Logger.warn("Weather announce failed: #{Exception.message(e)}")
  end

  defp render_phase(%{time_msg: time_msg, desc_msg: desc_msg, outcolor: outcolor}) do
    IO.iodata_to_binary(
      [~s({color foreground="#{outcolor}"}[#{time_msg}]#{desc_msg}{/color}), "\n"]
    )
  end

  defp render_phase(_), do: nil

  defp default_seed(seed) when is_integer(seed), do: {seed, 0, 0}

  defp default_seed(_) do
    seed = :erlang.phash2([:os.system_time(:millisecond), node()])
    {seed, 0, 0}
  end

  defp schedule_tick(state, pid) do
    Scheduler.schedule_once(state.cycle_ms, fn -> send(pid, :tick) end)
    state
  end
end