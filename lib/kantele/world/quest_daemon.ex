defmodule Kantele.World.QuestDaemon do
  @moduledoc """
  开放任务守护（Q1-T3，对应 LPC daemons/questd.c 的 heartbeat 生成与超时回收）

  - 心跳用 `Scheduler.schedule_once` 链式推进（`schedule_recurring` 的取消有 bug，勿用）；
  - 每轮：回收 `expires_at` 已过的任务 → 按品种轮转补足并发上限（deliver/supply 优先）；
  - 新任务在 general 频道公告（真实玩家可见）；
  - 任务池存于 GenServer state，NPC 侧按 `officer_npc` 查询分发（`quest_for/1,2`）；
  - 生成数据取自真实世界缓存（`ZoneCache`/`Items`）；无候选取到时本轮静默跳过。

  测试/运维可注入实例：`start_link([name: nil, cycle_ms: 40])` + `insert/2,3`，
  `tick/1,2` 同步跑一轮便于确定性地验证心跳与过期回收。
  """

  use GenServer

  require Logger

  alias Kantele.Quest.Generator
  alias Kantele.Scheduler

  @kinds [:deliver, :supply, :search, :explore]
  @default_cycle_ms 60_000
  @default_max_active 3

  defstruct quests: %{},
          cycle_ms: @default_cycle_ms,
          max_active: @default_max_active,
          kind_cursor: 0,
          zone_id: nil,
          item_id: nil

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

  @doc "当前在池中的全部开放任务"
  def active(server \\ __MODULE__), do: GenServer.call(server, :active)

  @doc "按任务 id 查询"
  def get(server \\ __MODULE__, id), do: GenServer.call(server, {:get, id})

  @doc "某 NPC 作为委员当前可分发的开放任务（最早生成者优先）；无则 nil"
  def quest_for(server \\ __MODULE__, npc_id), do: GenServer.call(server, {:quest_for, npc_id})

  @doc "立即生成一个指定类型任务并入池；返回 `{:ok, quest}` 或 `{:error, reason}`"
  def create(server \\ __MODULE__, kind) do
    GenServer.call(server, {:create, kind})
  end

  @doc "直接注入一条任务记录（测试/运维用）；覆盖同 id"
  def insert(server \\ __MODULE__, quest) do
    GenServer.call(server, {:insert, quest})
  end

  @doc "完成任务，从池中移除"
  def finish(server \\ __MODULE__, id), do: GenServer.cast(server, {:finish, id})

  @doc "同步跑一轮（过期回收 + 补货）；返回当前 active 列表，便于测试断言"
  def tick(server \\ __MODULE__), do: GenServer.call(server, :tick)

  # ---- GenServer 回调 ----

  @impl true
  def init(opts) do
    state = %__MODULE__{
      cycle_ms: Keyword.get(opts, :cycle_ms, @default_cycle_ms),
      max_active: Keyword.get(opts, :max_active, @default_max_active),
      zone_id: Keyword.get(opts, :zone_id),
      item_id: Keyword.get(opts, :item_id)
    }

    {:ok, schedule_tick(state, self())}
  end

  @impl true
  def handle_call(:active, _from, state) do
    {:reply, Map.values(state.quests), state}
  end

  def handle_call({:get, id}, _from, state) do
    {:reply, Map.get(state.quests, id), state}
  end

  def handle_call({:quest_for, npc_id}, _from, state) do
    quest =
      state.quests
      |> Map.values()
      |> Enum.sort_by(&Map.get(&1, :created_at, 0))
      |> Enum.find(&(&1.officer_npc == npc_id))

    {:reply, quest, state}
  end

  def handle_call({:create, kind}, _from, state) do
    {state, quest} = generate_one(state, kind)
    {:reply, quest, state}
  end

  def handle_call({:insert, quest}, _from, state) do
    state = register(state, quest)
    {:reply, {:ok, Map.get(state.quests, quest.id)}, state}
  end

  def handle_call(:tick, _from, state) do
    state = run_round(state)
    {:reply, Map.values(state.quests), state}
  end

  @impl true
  def handle_cast({:finish, id}, state) do
    {:noreply, %{state | quests: Map.delete(state.quests, id)}}
  end

  @impl true
  def handle_info(:tick, state) do
    {:noreply, schedule_tick(run_round(state), self())}
  end

  # ---- 心跳（schedule_once 链式；不用 recurring）----

  defp schedule_tick(state, pid) do
    Scheduler.schedule_once(state.cycle_ms, fn -> send(pid, :tick) end)
    state
  end

  # ---- 一轮：回收 + 补货 ----

  defp run_round(state) do
    state
    |> expire()
    |> replenish()
  end

  defp expire(%{quests: quests} = state) do
    now = :os.system_time(:second)

    {expired, kept} =
      Enum.split_with(quests, fn {_id, quest} -> Map.get(quest, :expires_at, 0) < now end)

    if expired != [] do
      Logger.info("QuestDaemon 回收 #{length(expired)} 个到期开放任务")
    end

    %{state | quests: Map.new(kept)}
  end

  # 按品种轮转补货；池满即停；游标推进一整组，保证下一轮从下一品种起始
  defp replenish(state) do
    kinds = rotated(@kinds, state.kind_cursor)

    state =
      Enum.reduce_while(kinds, state, fn kind, acc ->
        if map_size(acc.quests) >= acc.max_active do
          {:halt, acc}
        else
          case generate_one(acc, kind) do
            {acc, {:ok, _quest}} -> {:cont, acc}
            {acc, {:error, _reason}} -> {:cont, acc}
          end
        end
      end)

    %{state | kind_cursor: rem(state.kind_cursor + length(@kinds), max(length(@kinds), 1))}
  end

  # 生成一个任务并入池；新任务返回 {:ok, quest}，无候选 {:error, reason}
  defp generate_one(state, kind) do
  result =
    try do
      Generator.generate(to_string(kind), generator_opts(state))
    rescue
      _ -> {:error, :generate_failed}
    end

  case result do
    {:ok, quest} ->
      {state, quest} = {register(state, quest), quest}
      announce(quest)
      Logger.info("QuestDaemon 生成开放任务 #{quest.id}（#{quest.type}，委员 #{quest.officer_npc}）")
      {state, {:ok, quest}}

    {:error, reason} ->
      {state, {:error, reason}}
  end
end

  defp register(state, quest) do
    now = :os.system_time(:second)

    record =
      quest
      |> Map.put(:created_at, now)
      |> Map.put(:expires_at, now + (Map.get(quest, :limit) || 1800))

    %{state | quests: Map.put(state.quests, record.id, record)}
  end

  # 传给 Generator 的覆盖项（默认空，测试注入 zone_id/item_id 保证确定性）
  defp generator_opts(state) do
    base =
      if state.zone_id do
        [zone_id: state.zone_id]
      else
        []
      end

    if state.item_id do
      base ++ [item_id: state.item_id]
    else
      base
    end
  end

  defp rotated(list, offset) do
    count = length(list)

    case count do
      0 -> []
      _ ->
        shift = rem(offset, count)
        {a, b} = Enum.split(list, shift)
        b ++ a
    end
  end

  defp announce(quest) do
    officer = Map.get(quest, :officer_npc, "")

    text =
      case quest.type do
        "deliver" ->
          "有人张贴了一则送货委托，委托牌落在#{officer}处。"

        "supply" ->
          "库房贴出收购#{quest.item_name}的告示，收物的人在#{officer}处。"

        _ ->
          "客栈公告板上挂出一道新鲜差事，可以找#{officer}打听。"
      end

    try do
      Kantele.Communication.announce("general", "#{text}\n")
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
  end
end