defmodule Kantele.World.SeasonEvent do
  @moduledoc """
  季节发病事件（Q2 v2 疾病系统，对应 LPC `adm/daemons/natured.c` 的 `event_noon`）

  ## 触发时机

  链式 tick（`Scheduler.schedule_once`，与 Weather/GameTime 同）：每 `cycle_ms`
  读 `GameTime.game_localtime/0`，当游戏钟跨入「正午」（hour == 12）且当日尚未
  触发，则跑一次 `event_noon`。游戏时间倍率为 12（现实 1s = 游戏 12s），故每天
  正午约每 2 现实小时出现一次，每天最多触发一次。

  ## event_noon 语义（逐字对齐 LPC）

  1. `random(4) != 0` 直接 return —— 仅 1/4 概率实际发作；
  2. 按月份选病种：`3..5→ill_kesou`、`6..8→ill_zhongshu`、`9..11→ill_shanghan`、
     `12,1,2→ill_dongshang`，并各带 `ic` 抗力阈值（kesou/zhongshu/shanghan=5，
     dongshang=0）；
  3. `random(4) == 0` 时覆盖为 `ill_fashao`（沿用本月的 `ic`，与 LPC 一致——
     LPC 覆盖分支只改 `ill`/`msg`，不动 `ic`）；
  4. 遍历在线角色（`Presence.characters/0`，对应 LPC `users()`）：
     - 仅玩家（`id` 以 `"player:"` 开头，对应 LPC `users()` 的实际受众）；
     - 环境须 `outdoors`（`Room.snapshot/1` 的 `attrs["outdoors"]`，对应
       LPC `environment(ob)->query("outdoors")`）；
     - 抗力 `con = con/2 + random(con)`，并按病种加减 warm：
       `ill_shanghan`/`ill_dongshang` 加 warm，`ill_zhongshu` 减 warm，
       `ill_fashao` 不变（warm 当前端口未建模，恒为 0，代码保留加减分支）；
     - `con + ic < 25` 则落病：`apply_condition(ill, 30 - con)`，对应 Elixir
       经 `condition/apply` 事件落到角色自身进程的 `ConditionEvent`。

  ## 可测性

  `plan_noon/3` 为纯函数：给定月份、已解析的候选角色列表（`%{pid, outdoors?,
  con, warm, player?}`）与可注入 rng，返回落病指令列表。对时间/进程/随机源零依赖，
  单测直接覆盖；`resolve_targets/1` 仅做真实角色 → 候选角色的 I/O 映射。
  """

  use GenServer

  require Logger

  alias Kalevala.Event
  alias Kantele.Character.Presence
  alias Kantele.Character.Stats
  alias Kantele.Scheduler
  alias Kantele.World.GameTime
  alias Kantele.World.Room

  @default_cycle_ms 60_000

  @fashao_msg "你偶感风寒，竟而发起烧来。\n"

  defstruct [:cycle_ms, :seed, :last_noon_key]

  @type candidate :: %{
          pid: pid() | nil,
          outdoors?: boolean(),
          con: integer(),
          warm: integer(),
          player?: boolean()
        }

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

    state = %__MODULE__{
      cycle_ms: Keyword.get(opts, :cycle_ms, @default_cycle_ms),
      seed: seed
    }

    {:ok, schedule_tick(maybe_noon(state), self())}
  end

  @impl true
  def handle_call(:tick, _from, state) do
    {:reply, :ok, schedule_tick(maybe_noon(state), self())}
  end

  @impl true
  def handle_info(:tick, state) do
    {:noreply, schedule_tick(maybe_noon(state), self())}
  end

  # ---- 内部：正午判定与触发 ----

  defp maybe_noon(state) do
    %{hour: hour, year: year, month: month, day: day} = GameTime.game_localtime()
    key = {year, month, day}

    if hour == 12 and state.last_noon_key != key do
      fire_noon(state, month, key)
    else
      state
    end
  end

  defp fire_noon(state, month, key) do
    # 1/4 概率实际发作（LPC：random(4) 非 0 直接 return）
    if default_rng(4) == 0 do
      month
      |> resolve_targets()
      |> Enum.each(&apply_illness/1)
    end

    %{state | last_noon_key: key}
  end

  # ---- 真实角色 → 候选角色（I/O 映射） ----

  @doc """
  取在线玩家，解析出 `plan_noon/3` 所需的候选角色列表并调用纯函数落病。
  """
  def resolve_targets(month) do
    characters = safe_characters()

    candidates =
      Enum.map(characters, fn ch ->
        %{
          pid: Map.get(ch, :pid),
          outdoors?: outdoors?(room_id_of(ch)),
          con: con_of(ch),
          warm: warm_of(ch, room_id_of(ch)),
          player?: player?(ch)
        }
      end)

    plan_noon(month, candidates)
  end

  # ---- 纯函数：给定候选角色，返回落病指令 ----

  @doc """
  纯函数：根据月份与候选角色列表计算正午落病指令。

  `rng(max)` 模拟 LPC `random(max)`：返回 `0..max-1`；`max <= 0` 时返回 0。
  每条指令：`%{pid, cnd, duration, announce}`（announce 为「染病」初告，由
  `ConditionEvent` 经 `info["announce"]` 一次性渲染）。

  发作的每跳文案（咳嗽/中暑等）由 `Kantele.Illness.do_effect/3` 经
  `condition_messages` 广播，不在此返回。
  """
  def plan_noon(month, candidates, rng \\ &__MODULE__.default_rng/1) do
    # LPC：if (random(4)) return; —— 3/4 概率不发病，仅 1/4 继续
    if rng.(4) != 0 do
      []
    else
      {cnd, ic, msg} = illness_for_month(month)

      {cnd, msg} =
        if rng.(4) == 0 do   # 1/4 概率覆盖为发烧（不改 ic，与 LPC 一致）
          {"ill_fashao", @fashao_msg}
        else
          {cnd, msg}
        end

      Enum.flat_map(candidates, fn c ->
        if c.player? and c.outdoors? do
          con = div(c.con, 2) + rng.(max(c.con, 1))
          con = adjust_warm(con, c.warm, cnd)

          if con + ic < 25 and c.pid != nil do
            [%{pid: c.pid, cnd: cnd, duration: 30 - con, announce: msg}]
          else
            []
          end
        else
          []
        end
      end)
    end
  end

  def illness_for_month(month) when month in 3..5,
    do: {"ill_kesou", 5, "忽然喉头一阵痕痒，你感觉似乎要咳嗽了。\n"}

  def illness_for_month(month) when month in 6..8,
    do: {"ill_zhongshu", 5, "突然你胸臆之间一阵翻腾，你中暑了。\n"}

  def illness_for_month(month) when month in 9..11,
    do: {"ill_shanghan", 5, "陡的你打了个冷战，头昏沉沉的，你得伤寒病了。\n"}

  def illness_for_month(month) when month in [12, 1, 2],
    do: {"ill_dongshang", 0, "你肢体末端一阵僵直，看来你被冻伤了。\n"}

  # 按病种加减 warm（LPC：shanghan/dongshang 加，zhongshu 减，fashao 不变）
  @doc false
  def adjust_warm(con, warm, "ill_shanghan"), do: con + warm
  def adjust_warm(con, warm, "ill_dongshang"), do: con + warm
  def adjust_warm(con, warm, "ill_zhongshu"), do: con - warm
  def adjust_warm(con, _warm, _cnd), do: con

  # ---- 落病：经 condition/apply 事件落到角色自身进程 ----

  defp apply_illness(%{pid: pid, cnd: cnd, duration: duration, announce: announce})
       when is_pid(pid) do
    send(pid, %Event{
      from_pid: self(),
      topic: "condition/apply",
      data: %{name: cnd, info: %{"duration" => duration, "announce" => announce}}
    })
  end

  defp apply_illness(_), do: :ok

  # ---- 角色解析 helpers ----

  defp player?(ch) do
    case Map.get(ch, :id) do
      id when is_binary(id) -> String.starts_with?(id, "player:")
      _ -> false
    end
  end

  defp room_id_of(ch) do
    case Map.get(ch, :room_id) do
      id when is_binary(id) -> id
      _ -> nil
    end
  end

  defp outdoors?(nil), do: false

  defp outdoors?(room_id) do
    snap = safe_snapshot(room_id)
    Map.get(snap, :attrs, %{})["outdoors"] == true
  end

  defp con_of(ch) do
    case Map.get(ch, :meta) do
      %{stats: stats} -> Stats.query_con(stats)
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp warm_of(ch, room_id) do
    char_warm = char_warm(ch)
    room_warm = room_warm(room_id)
    char_warm + room_warm
  end

  # apply/warm：角色临时属性（端口未建模保暖衣物，恒 0）
  defp char_warm(ch) do
    temp = get_in(ch, [:meta, :temp]) || %{}
    int(Map.get(temp, "apply/warm"))
  end

  # room warm：房间临时属性（端口未建模房间保暖，恒 0）
  defp room_warm(nil), do: 0

  defp room_warm(room_id) do
    snap = safe_snapshot(room_id)
    int(Map.get(snap, :attrs, %{})["warm"])
  end

  defp safe_snapshot(room_id) do
    Room.snapshot(room_id)
  rescue
    _ -> %{}
  end

  defp safe_characters() do
    Presence.characters()
  rescue
    _ -> []
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
