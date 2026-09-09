defmodule Kantele.World.Invasion do
  @moduledoc """
  Q4 入侵守护进程：周期刷新 24 只外族 NPC（3 国族 × 5 级），全服广播，
  击杀奖励 exp/potential/体会/威望/阅历，全歼触发大奖，闲置自毁。
  """

  use GenServer

  require Logger

  alias Kantele.World.Invasion.Behaviour
  alias Kantele.Communication
  alias Kantele.World.ZoneCache
  alias Kantele.World.Story.Gift

  @default_start_delay 600_000       # 10 min after boot
  @default_wave_interval 3_600_000   # 1 hour between waves
  @total_invaders 24
  @idle_timeout 600_000              # 10 min idle → despawn

  # LPC level distribution: 1×L5, 2×L4, 3×L3, 6×L2, 12×L1
  @level_distribution [
    {5, 1},
    {4, 2},
    {3, 3},
    {2, 6},
    {1, 12}
  ]

  @nation_weights [japanese: 1, english: 1, european: 1]

  @impl Behaviour
  def prompt(), do: "{color foreground=\"magenta\"}【 入  侵 】{/color}"

  @impl Behaviour
  def init_state() do
    %{
      wave_number: 0,
      wave_pid: nil,
      invaders: %{},       # number => %{pid, room_id, level, nation, born_time, alive: true}
      total_killed: 0,
      all_killed: false,
      timer_ref: nil,
      wave_active: false
    }
  end

  @impl Behaviour
  def start_wave(state, opts \\ []) do
    if state.wave_active do
      {:error, :wave_already_active}
    else
      state =
        state
        |> Map.put(:wave_active, true)
        |> Map.put(:total_killed, 0)
        |> Map.put(:all_killed, false)
        |> Map.put(:invaders, %{})
        |> Map.update(:wave_number, 0, &(&1 + 1))

      {:ok, spawn_invaders(state, opts)}
    end
  end

  @impl Behaviour
  def stop_wave(state) do
    # 杀掉本波所有还活着的 NPC
    Enum.each(state.invaders, fn {_num, %{pid: pid, alive: true}} ->
      if Process.alive?(pid), do: Process.exit(pid, :shutdown)
    end)

    cancel_timers(state)
    {:ok, %{state | wave_active: false, invaders: %{}, timer_ref: nil}}
  end

  @impl Behaviour
  def status(state) do
    %{
      wave_number: state.wave_number,
      wave_active: state.wave_active,
      invaders_alive: Enum.count(state.invaders, fn {_, v} -> v.alive end),
      total_killed: state.total_killed,
      all_killed: state.all_killed
    }
  end

  # ---- GenServer callbacks ----

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @impl true
  def init(opts) do
    state =
      init_state()
      |> Map.put(:start_delay, Keyword.get(opts, :start_delay, @default_start_delay))
      |> Map.put(:wave_interval, Keyword.get(opts, :wave_interval, @default_wave_interval))

    # 开机延迟后首波
    schedule_next_wave(state)
    {:ok, state}
  end

  @impl true
  def handle_info(:wave_tick, state) do
    # 周期触发：若上一波已全歼或超时收摊，启动新波
    if state.wave_active && !state.all_killed do
      # 上一波未全歼也未超时，等待下次 tick（或可选：强制收摊再启动新波）
      schedule_next_wave(state)
      {:noreply, state}
    else
      # 启动新波
      case start_wave(state) do
        {:ok, new_state} ->
          announce("{color foreground=\"magenta\"}【 入  侵 】{/color} 第 #{new_state.wave_number} 波外族入侵开始！24 名入侵者已散落各地。\n")
          schedule_next_wave(new_state)
          {:noreply, new_state}
        {:error, _} ->
          schedule_next_wave(state)
          {:noreply, state}
      end
    end
  end

  # NPC 死亡回调（由 CombatEvent.die 通过 on_died/2 触发）
  def on_died(server \\ __MODULE__, number, killer) do
    GenServer.cast(server, {:npc_died, number, killer})
  end

  # NPC 闲置自毁回调（由 NPC 进程内 Process.send_after 触发）
  def on_idle(server \\ __MODULE__, number) do
    GenServer.cast(server, {:npc_idle, number})
  end

  @impl true
  def handle_cast({:npc_died, number, killer}, state) do
    invader = Map.get(state.invaders, number)

    cond do
      invader && invader.alive ->
        new_invader = %{invader | alive: false}
        new_state = %{state | invaders: Map.put(state.invaders, number, new_invader), total_killed: state.total_killed + 1}

        # 击杀奖励（按级 + 强者减奖）在 CombatEvent.die 里已给 exp/potential/威望/阅历
        # 这里只做广播与全歼判定
        killer_name = killer_name(killer)
        nation_title = invader_nation_title(invader.nation, invader.level)
        announce(
          "{color foreground=\"magenta\"}【 入  侵 】{/color} #{killer_name} 在 #{invader.room_id} 击杀了 #{nation_title}#{invader.name}！\n"
        )

        if new_state.total_killed >= @total_invaders do
          new_state = %{new_state | all_killed: true}
          announce(
            "{color foreground=\"magenta\"}【 入  侵 】{/color} 本波入侵者已被全歼！全体同胞获得丰厚奖赏！\n"
          )
        end

        {:noreply, new_state}

      invader && !invader.alive ->
        # 重复死亡忽略
        {:noreply, state}

      true ->
        # 非本波 NPC（旧波次残留），记日志不广播
        Logger.debug("invasion: unknown/already-dead invader #{number}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:npc_idle, number}, state) do
    invader = Map.get(state.invaders, number)

    cond do
      invader && invader.alive ->
        if Process.alive?(invader.pid) do
          Process.exit(invader.pid, :shutdown)
        end
        new_invader = %{invader | alive: false}
        new_state = %{state | invaders: Map.put(state.invaders, number, new_invader)}

        announce(
          "{color foreground=\"magenta\"}【 入  侵 】{/color} #{invader_nation_title(invader.nation, invader.level)}#{invader.name} 久候不遇，悻悻撤退了。\n"
        )

        {:noreply, new_state}

      true ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, status(state), state}
  end

  def handle_call(:start_wave, _from, state) do
    {:reply, start_wave(state), state}
  end

  def handle_call(:stop_wave, _from, state) do
    {:reply, stop_wave(state), state}
  end

  # ---- 私有 ----

  defp schedule_next_wave(state) do
    # 取消旧 timer
    if ref = state.timer_ref, do: :erlang.cancel_timer(ref)

    interval = Map.get(state, :wave_interval, @default_wave_interval)
    ref = :timer.send_interval(interval, :wave_tick)

    # 不把 ref 存回 state（GenServer 状态不跨进程），下次 tick 里再存
    # 这里只保证定时器存在；state.timer_ref 仅作 cancel 用，若 restart 会丢，可接受
    %{state | timer_ref: ref}
  end

  defp cancel_timers(state) do
    if ref = state.timer_ref do
      :erlang.cancel_timer(ref)
    end
    state
  end

  defp spawn_invaders(state, _opts) do
    # 选出生房间池：liuxi 区非 no_fight 房间
    room_ids = pick_spawn_rooms()

    # 打乱 level_distribution 生成 24 个 {level, nation} 元组
    entries = build_invader_entries()

    Enum.reduce(entries, state, fn {level, nation, number}, acc ->
      room_id = Enum.random(room_ids)
      invader = Kantele.World.Invasion.NPC.build_invader(nation, level, number, room_id)

      # 启动 NPC 进程（复用 Kalevala.World.start_character 路径）
      config = [
        supervisor_name: Kalevala.World.CharacterSupervisor.global_name(invader.meta.zone_id),
        communication_module: Kantele.Communication,
        initial_controller: Kantele.Character.SpawnController,
        quit_view: {Kantele.Character.QuitView, "disconnected"}
      ]

      case Kalevala.World.start_character(invader, config) do
        {:ok, pid} ->
          # 记录登记
          invader_info = %{
            pid: pid,
            room_id: room_id,
            level: level,
            nation: nation,
            born_time: System.system_time(:second),
            alive: true,
            name: invader.name
          }
          %{acc | invaders: Map.put(acc.invaders, number, invader_info)}

        {:error, reason} ->
          Logger.warn("invasion spawn invader #{number} (#{nation} L#{level}) failed - #{inspect(reason)}")
          acc
      end
    end)
    |> then_announce_spawned()
  end

  defp then_announce_spawned(state) do
    # 给 NPC 进程内发送闲置自毁定时器（10 分钟）
    Enum.each(state.invaders, fn {number, %{pid: pid, alive: true}} ->
      Process.send_after(pid, {:invasion_idle_check, number}, @idle_timeout)
    end)

    state
  end

  defp pick_spawn_rooms() do
    zone = ZoneCache.get("liuxi")

    case zone do
      nil ->
        # 兜底：仅中央广场
        ["liuxi:guangchang"]
      %Kantele.World.Zone{rooms: rooms} ->
        rooms
        |> Enum.filter(fn room ->
             room.flags && not Enum.member?(room.flags, "no_fight")
           end)
        |> Enum.map(& &1.id)
    end
  end

  defp build_invader_entries() do
    # 生成 24 个 {level, nation, number}（number 1..24）
    nations = [:japanese, :english, :european]

    @level_distribution
    |> Enum.flat_map(fn {level, count} ->
         Enum.map(1..count, fn _ -> {level, Enum.random(nations)} end)
       end)
    |> Enum.shuffle()
    |> Enum.with_index(1)
    |> Enum.map(fn {{level, nation}, number} -> {level, nation, number} end)
  end

  defp announce(text) do
    Communication.announce("general", text)
  rescue
    e -> Logger.warn("invasion announce failed - #{Exception.message(e)}")
  catch
    :exit, reason -> Logger.warn("invasion announce failed - #{inspect(reason)}")
  end

  defp killer_name(nil), do: "无名侠士"
  defp killer_name(%{name: name}), do: name
  defp killer_name(name) when is_binary(name), do: name

  defp invader_nation_title(:japanese, _level), do: "倭寇·"
  defp invader_nation_title(:english, _level), do: "英夷·"
  defp invader_nation_title(:european, _level), do: "西洋·"
  defp invader_nation_title(nation, _level), do: "#{nation}·"
end