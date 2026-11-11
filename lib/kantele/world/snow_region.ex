defmodule Kantele.World.SnowRegion do
  @moduledoc """
  雪原寒冷（Q2 v2 疾病/雪原封路，对应 LPC `d/guanwai/gwxuedi.h`）

  LPC 里 `gwxuedi.h` 挂在关外（guanwai）房间上，提供两套寒冷机制：

  1. `valid_leave`（出关危险 / 「封路」）：玩家在冬月（12,1,2,3,4,5）离开关外房间时，
     `do_cold(me, 3, 0)` 以 3 倍系数结算寒冷伤害——出关比待在关外更冷；
  2. `cold_effect`（关内持续寒冷）：关外房间每约 4-6 秒对室内所有玩家 `do_cold(ob, 1, con)`，
     系数 1。

  本模块把两者统一到一个守护进程（链式 tick，与 SeasonEvent 同），周期性遍历在线玩家，
  对「身处关外房间 + 冬月」者施加系数 1 的寒冷；出关的 3 倍寒冷由 `MoveEvent.commit`
  在离开关外房间时经 `cold_event_for/3` 投出 `snow/cold` 事件。两套路径都落到玩家自身
  进程的 `Kantele.World.SnowRegionEvent.cold/2` 处理（扣气 + 文案 + 按阈值落冻伤）。

  ## 伤害公式（逐字对齐 LPC `do_cold`）

      damage = 35 - (con_resist + warm)
      con_resist = con/2 + random(con)        # 体质抗力，关外胡家再 -25
      born == "关外胡家"  → damage -= 25
      damage < 0          → 0
      hour <= 6  || >= 18 → damage += damage/2   (×1.5)
      hour <= 4  || >= 22 → damage += damage/2   (再 ×1.5)
      hour 11..13         → damage -= damage/2   (×0.5)
      damage *= scale     (出关 3 / 关内 1)
      damage > 0 → receive_damage("qi", damage)
      qi < 50 && damage > 10 → apply_condition("ill_dongshang", existing + 5 + damage/3)

  `warm` = 角色 `apply/warm` + 房间 `warm`（端口未建模保暖，恒为 0，代码保留加减分支）。

  ## 可测性

  `cold_damage/5`、`cold_msg/1`、`dongshang_duration/2`、`winter?/1`、`guanwai?/1`
  均为纯函数，单测直接覆盖；`cold_event_for/3` 仅做「冬月 + 关外」门控与伤害结算，
  返回可注入 `snow/cold` 事件，便于行为测试。
  """

  use GenServer

  require Logger

  alias Kalevala.Event
  alias Kantele.Character.Presence
  alias Kantele.Character.Stats
  alias Kantele.Scheduler
  alias Kantele.World.GameTime
  alias Kantele.World.Room

  @default_cycle_ms 5_000

  @winter_months [12, 1, 2, 3, 4, 5]
  @guanwai_prefix "guanwai:"
  @born_hu_family "关外胡家"

  defstruct [:cycle_ms, :seed]

  @doc false
  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  def start_link(opts) do
    case opts[:name] do
      :anonymous ->
        GenServer.start_link(__MODULE__, opts, [])

      _ ->
        GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
    end
  end

  # ---- 公开 API ----

  @doc "立即推进一档（test/运维用）；返回 :ok"
  def tick(server \\ __MODULE__), do: GenServer.call(server, :tick)

  # ---- GenServer 回调 ----

  @impl true
  def init(opts) do
    seed = Keyword.get(opts, :seed)
    :rand.seed(:exsss, default_seed(seed))

    state = %__MODULE__{cycle_ms: Keyword.get(opts, :cycle_ms, @default_cycle_ms), seed: seed}
    {:ok, schedule_tick(fire_cold(state), self())}
  end

  @impl true
  def handle_call(:tick, _from, state) do
    {:reply, :ok, schedule_tick(fire_cold(state), self())}
  end

  @impl true
  def handle_info(:tick, state) do
    {:noreply, schedule_tick(fire_cold(state), self())}
  end

  # ---- 内部：周期性关内寒冷 ----

  defp fire_cold(state) do
    if winter?(GameTime.game_localtime().month) do
      Enum.each(safe_characters(), fn ch ->
        room_id = room_id_of(ch)

        case cold_event_for(ch, room_id, 1) do
          %Event{} = event -> send(Map.get(ch, :pid), event)
          _ -> :ok
        end
      end)
    end

    state
  end

  # ---- 出关/关内寒冷事件构造（供 MoveEvent 与守护进程复用） ----

  @doc """
  给定角色、所在房间与系数，构造 `snow/cold` 事件；非冬月或非关外返回 `nil`。

  `scale`：出关 3 / 关内 1（对应 LPC `do_cold` 的第二个参数）。
  """
  def cold_event_for(character, room_id, scale) do
    if not winter?(GameTime.game_localtime().month) or not guanwai?(room_id) do
      nil
    else
      hour = GameTime.hour()
      con = con_resistance(character)
      warm = char_warm(character) + room_warm(room_id)
      born_hu? = born_hu?(character)
      {damage, msg} = cold_damage(con, warm, hour, scale, born_hu?)

      %Event{
        from_pid: self(),
        topic: "snow/cold",
        data: %{damage: damage, msg: msg}
      }
    end
  end

  # ---- 纯函数：伤害与文案 ----

  @doc "冬月？"
  def winter?(month), do: month in @winter_months

  @doc "关外房间？（room_id 以 guanwai: 开头）"
  def guanwai?(room_id) when is_binary(room_id), do: String.starts_with?(room_id, @guanwai_prefix)
  def guanwai?(_), do: false

  @doc """
  纯函数：寒冷伤害与文案（对应 LPC `do_cold`）。

  `con` 为已折算的抗力（`con/2 + random(con)`，见 `con_resistance/1`）；
  `warm` 为角色+房间保暖之和；`scale` 为系数（出关 3 / 关内 1）。
  返回 `{damage, msg}`。
  """
  def cold_damage(con, warm, hour, scale, born_hu? \\ false) do
    dmg = 35 - (con + warm)
    dmg = if born_hu?, do: dmg - 25, else: dmg
    dmg = max(dmg, 0)
    dmg = if hour <= 6 or hour >= 18, do: dmg + div(dmg, 2), else: dmg
    dmg = if hour <= 4 or hour >= 22, do: dmg + div(dmg, 2), else: dmg
    dmg = if hour >= 11 and hour <= 13, do: dmg - div(dmg, 2), else: dmg
    dmg = max(dmg * scale, 0)
    {dmg, cold_msg(dmg)}
  end

  @doc "寒冷文案阈值（对应 LPC do_cold 的 msg 分支）"
  def cold_msg(dmg) when dmg > 80,
    do: "一股刺骨的寒风吹过，你只觉得浑身血液都快被冻住了！\n"

  def cold_msg(dmg) when dmg > 60,
    do: "一股刺骨的寒风吹过，你只觉得浑身非常僵硬！\n"

  def cold_msg(dmg) when dmg > 40,
    do: "一股刺骨的寒风吹过，你只觉得冷气透过衣衫钻了进来，浑身没有半点热气！\n"

  def cold_msg(dmg) when dmg > 20,
    do: "一股刺骨的寒风吹过，你只觉得人都要麻木了！\n"

  def cold_msg(dmg) when dmg > 10,
    do: "一股刺骨的寒风吹过，你只觉得天气非常的冷！\n"

  def cold_msg(dmg) when dmg > 0,
    do: "一股刺骨的寒风吹过，你感觉到有点冷！\n"

  def cold_msg(_),
    do: "一股刺骨的寒风吹过，可是你身上还是挺暖和的。\n"

  @doc """
  冻伤持续时间（对应 LPC `apply_condition("ill_dongshang", existing + 5 + damage/3)`）。

  仅当 `damage > 10`（且调用方另判 qi < 50）才落冻伤；`existing` 为当前已有冻伤时长。
  """
  def dongshang_duration(damage, existing \\ 0) when damage > 10, do: existing + 5 + div(damage, 3)
  def dongshang_duration(_damage, _existing), do: 0

  # ---- 角色解析 helpers ----

  defp con_resistance(character) do
    con =
      case get_in(character, [:meta, :stats]) do
        %Stats{} = stats -> Stats.query_con(stats)
        _ -> 0
      end

    div(con, 2) + default_rng(max(con, 1))
  end

  defp char_warm(character) do
    temp = get_in(character, [:meta, :temp]) || %{}
    int(Map.get(temp, "apply/warm"))
  end

  defp room_warm(nil), do: 0

  defp room_warm(room_id) do
    snap = safe_snapshot(room_id)
    int(Map.get(snap, :attrs, %{})["warm"])
  end

  defp born_hu?(character) do
    case get_in(character, [:meta, :family]) do
      family when is_map(family) -> Map.get(family, :born_family) == @born_hu_family
      _ -> false
    end
  end

  defp room_id_of(ch) do
    case Map.get(ch, :room_id) do
      id when is_binary(id) -> id
      _ -> nil
    end
  end

  defp safe_characters() do
    Presence.characters()
  rescue
    _ -> []
  end

  defp safe_snapshot(room_id) do
    Room.snapshot(room_id)
  rescue
    _ -> %{}
  end

  defp int(nil), do: 0
  defp int(n) when is_integer(n), do: n
  defp int(n) when is_float(n), do: trunc(n)

  defp int(n) when is_binary(n) do
    case Integer.parse(String.trim(n)) do
      {v, _} -> v
      _ -> 0
    end
  end

  defp int(_), do: 0

  # ---- 内部：rng / seed / tick ----

  @doc "模拟 LPC `random(max)`：返回 0..max-1；max<=0 返回 0"
  def default_rng(max) when max > 0, do: :rand.uniform(max) - 1
  def default_rng(_), do: 0

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
