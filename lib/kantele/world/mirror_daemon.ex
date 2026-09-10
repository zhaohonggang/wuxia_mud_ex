defmodule Kantele.World.MirrorDaemon do
  @moduledoc """
  Q5 宝镜任务守护进程：周期性分发 30 个任务物品到随机 NPC（TaskCarrier），
  玩家向子虚道人领宝镜定位，找到 NPC 给物品上交得奖励。
  """

  use GenServer

  require Logger

  alias Kantele.World.MirrorDaemon.Behaviour
  alias Kantele.Communication
  alias Kantele.World.ZoneCache

  @behaviour Behaviour

  @default_start_delay 60_000       # 1 min after boot
  @default_round_interval 180_000   # 3 min between rounds (LPC 180s)
  @total_tasks 30                   # UCL 中定义的 task 物品数（可通过 opts 覆盖供测试）
  @default_zone "liuxi"             # 任务散落区域（可通过 opts 覆盖供测试）

  @impl Behaviour
  def prompt(), do: "{color foreground=\"yellow\"}【 宝  镜 】{/color}"

  @impl Behaviour
  def init_state() do
    %{
      round_number: 0,
      tasks: %{},           # task_name => %{pid, room_id, npc_name, npc_id, owner, owner_id, alive: true}
      total_completed: 0,
      all_completed: false,
      timer_ref: nil,
      round_active: false
    }
  end

  @impl Behaviour
  def start_round(state, opts \\ []) do
    if state.round_active do
      {:error, :round_already_active}
    else
      state =
        state
        |> Map.put(:round_active, true)
        |> Map.put(:total_completed, 0)
        |> Map.put(:all_completed, false)
        |> Map.put(:tasks, %{})
        |> Map.update(:round_number, 0, &(&1 + 1))

      {:ok, spawn_tasks(state, opts)}
    end
  end

  @impl Behaviour
  def stop_round(state) do
    Enum.each(state.tasks, fn {_name, %{pid: pid, alive: true}} ->
      if Process.alive?(pid), do: Process.exit(pid, :shutdown)
    end)

    cancel_timers(state)
    {:ok, %{state | round_active: false, tasks: %{}, timer_ref: nil}}
  end

  @impl Behaviour
  def status(state) do
    %{
      round_number: state.round_number,
      round_active: state.round_active,
      tasks_alive: Enum.count(state.tasks, fn {_, v} -> v.alive end),
      total_completed: state.total_completed,
      all_completed: state.all_completed
    }
  end

  # ---- GenServer callbacks ----

  def child_spec(opts) do
    %{
      id: opts[:id] || opts[:name] || __MODULE__,
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
      |> Map.put(:round_interval, Keyword.get(opts, :round_interval, @default_round_interval))
      |> Map.put(:zone_id, Keyword.get(opts, :zone_id, @default_zone))
      |> Map.put(:total_tasks, Keyword.get(opts, :total_tasks, @total_tasks))

    # 开机延迟后首轮
    schedule_next_round(state)
    {:ok, state}
  end

  @impl true
  def handle_info(:round_tick, state) do
    if state.round_active && !state.all_completed do
      schedule_next_round(state)
      {:noreply, state}
    else
      case start_round(state) do
        {:ok, new_state} ->
          announce(
            "{color foreground=\"yellow\"}【 宝  镜 】{/color} 第 #{new_state.round_number} 轮宝镜任务重新分布完毕！30 件任务物品已散落各地。\n"
          )
          schedule_next_round(new_state)
          {:noreply, new_state}
        {:error, _} ->
          schedule_next_round(state)
          {:noreply, state}
      end
    end
  end

  # 任务物品被上交回调（由 give_task 命令触发）
  def on_task_completed(server \\ __MODULE__, task_name, player) do
    GenServer.cast(server, {:task_completed, task_name, player})
  end

  @impl true
  def handle_cast({:task_completed, task_name, player}, state) do
    task = Map.get(state.tasks, task_name)

    cond do
task && task.alive ->
        new_task = %{task | alive: false}
        new_state = %{state | tasks: Map.put(state.tasks, task_name, new_task), total_completed: state.total_completed + 1}

        announce(
          "{color foreground=\"yellow\"}【 宝  镜 】{/color} #{player.name} 将 #{task.owner} 的 #{task_name} 送还，获得丰厚奖赏！\n"
        )

        # 里程碑奖励在 give_task 命令里已处理
        # 这里只判定全完成（注意：Elixir if 块内的重绑定不会外泄，需用表达式返回值）
        new_state =
          if new_state.total_completed >= state.total_tasks do
            announce(
              "{color foreground=\"yellow\"}【 宝  镜 】{/color} 本轮宝镜任务已全部完成！\n"
            )

            %{new_state | all_completed: true, round_active: false}
          else
            new_state
          end

        {:noreply, new_state}

      task && !task.alive ->
        {:noreply, state}

      true ->
        Logger.warning("MIRROR_CAST_UNKNOWN name=#{task_name}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, status(state), state}
  end

  def handle_call(:start_round, _from, state) do
    case start_round(state) do
      {:ok, new_state} -> {:reply, {:ok, new_state}, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:stop_round, _from, state) do
    case stop_round(state) do
      {:ok, new_state} -> {:reply, {:ok, new_state}, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  # ---- 私有 ----

  defp schedule_next_round(state) do
    if ref = state.timer_ref, do: :erlang.cancel_timer(ref)

    interval = Map.get(state, :round_interval, @default_round_interval)
    ref = :timer.send_interval(interval, :round_tick)

    %{state | timer_ref: ref}
  end

  defp cancel_timers(state) do
    if ref = state.timer_ref do
      :erlang.cancel_timer(ref)
    end
    state
  end

  defp spawn_tasks(state, _opts) do
    # 从 UCL 加载所有 task 物品定义
    task_items = load_task_items(state)

    room_ids = pick_spawn_rooms(state)

    if room_ids == [] do
      Logger.warn("mirror_daemon: no spawnable rooms in zone #{state.zone_id}, aborting round")
      state
    else
      Enum.reduce(task_items, state, fn {task_name, task_def}, acc ->
        room_id = Enum.random(room_ids)
        npc_name = task_def.owner
        npc_id = task_def.owner_id

        # 创建 TaskCarrier NPC（携带该 task 物品）
        invader = Kantele.World.MirrorDaemon.TaskCarrier.build_carrier(
          task_name, task_def, room_id, state.zone_id
        )

        config = [
          supervisor_name: Kalevala.World.CharacterSupervisor.global_name(invader.meta.zone_id),
          communication_module: Kantele.Communication,
          initial_controller: Kantele.Character.SpawnController,
          quit_view: {Kantele.Character.QuitView, "disconnected"}
        ]

        result =
          try do
            Kalevala.World.start_character(invader, config)
          rescue
            e -> {:error, {:rescue, Exception.message(e)}}
          catch
            :exit, reason -> {:error, {:exit, inspect(reason)}}
          end

        case result do
          {:ok, pid} ->
            task_info = %{
              pid: pid,
              room_id: room_id,
              npc_name: npc_name,
              npc_id: npc_id,
              owner: task_def.owner,
              owner_id: task_def.owner_id,
              alive: true
            }
            %{acc | tasks: Map.put(acc.tasks, task_name, task_info)}

          {:error, reason} ->
            Logger.warn("mirror_daemon spawn task carrier for #{task_name} failed - #{inspect(reason)}")
            acc
        end
      end)
      |> then_announce_spawned()
    end
  end

  defp then_announce_spawned(state) do
    Enum.each(state.tasks, fn {_name, %{pid: p, alive: true}} ->
      # 这里不需要闲置自毁，任务完成由玩家上交驱动
      :ok
    end)

    state
  end

  defp load_task_items(state) do
    # 从 Items 缓存中读取 zone 下所有 "zone:task/*" 物品
    prefix = "#{state.zone_id}:task/"

    Kantele.World.Items.keys()
    |> Enum.filter(fn id -> String.starts_with?(id, prefix) end)
    |> Enum.map(fn id ->
      case Kantele.World.Items.get(id) do
        {:ok, item} ->
          name = String.replace(id, prefix, "")
          {
            name,
            %{
              owner: item.meta.owner || "未知目标",
              owner_id: item.meta.owner_id || "unknown",
              description: item.description || "",
              item_id: id
            }
          }
        _ -> nil
      end
    end)
    |> Enum.filter(&(not is_nil(&1)))
    |> Enum.into(%{})
  end

  defp pick_spawn_rooms(state) do
    case ZoneCache.get(state.zone_id) do
      {:ok, %Kantele.World.Zone{rooms: rooms}} ->
        rooms
        |> Enum.filter(fn room ->
             room.flags && not Enum.member?(room.flags, "no_fight")
           end)
        |> Enum.map(& &1.id)

      _ ->
        ["#{state.zone_id}:guangchang"]
    end
  end

  defp announce(text) do
    Communication.announce("waidi", text)
  rescue
    e -> Logger.warn("mirror_daemon announce failed - #{Exception.message(e)}")
  catch
    :exit, reason -> Logger.warn("mirror_daemon announce failed - #{inspect(reason)}")
  end
end