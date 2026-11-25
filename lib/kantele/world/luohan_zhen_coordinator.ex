defmodule Kantele.World.LuohanZhen.Coordinator do
  @moduledoc """
  十八罗汉大阵协调器（GenServer）。

  持有当前唯一挑战的 `Kantele.World.LuohanZhen.Challenge` 状态，执行纯状态机
  产生的副作用（房间出口封锁/恢复、NPC 移动、广播、定时器、战斗发起）。

  同一时间只允许一个挑战（对应 LPC `assigned_fighter` 互斥）。
  """

  use GenServer

  alias Kantele.World.LuohanZhen
  alias Kantele.Scheduler
  alias Kantele.World.Room

  @doc "启动协调器（空闲态，不依赖任何房间进程）。"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  发起挑战（同步）。由 `InquiryHandlers.LuohanZhen` 调用。

  返回 `{:ok, challenge}` 并把挑战注册到 Coordinator，或 `{:error, reason}`。
  """
  def start_challenge(fighter, master_npc) do
    GenServer.call(__MODULE__, {:start_challenge, fighter, master_npc}, 5000)
  end

  @doc "查询当前挑战（测试与外部校验用，如另一位长老的 ask_me 门控）。"
  def get_challenge do
    GenServer.call(__MODULE__, :get_challenge)
  end

  @doc "查询挑战者的临时标志（xuanku-asked / xuannan-asked / beat_count / fighting）。"
  def get_temp(fighter_id, key) do
    GenServer.call(__MODULE__, {:get_temp, fighter_id, key})
  end

  @doc "设置挑战者的临时标志。"
  def put_temp(fighter_id, key, value) do
    GenServer.cast(__MODULE__, {:put_temp, fighter_id, key, value})
    :ok
  end

  @doc "外部事件入口：玩家到场、另一位长老被问、战斗轮次定时器触发等。"
  def handle_event(fighter_id, event) do
    GenServer.cast(__MODULE__, {:event, fighter_id, event})
    :ok
  end

  @xuanku_npc "shaolin_xuan_ku"

  defp master_side(master_npc) do
    if Map.get(master_npc, :id) == @xuanku_npc, do: "xuanku", else: "xuannan"
  end

  # === GenServer callbacks ===

  @impl true
  def init(_opts) do
    {:ok, %{challenge: nil, timer_refs: %{}}}
  end

  @impl true
  def handle_call({:start_challenge, fighter, master_npc}, _from, state) do
    case LuohanZhen.initiate(fighter, master_npc) do
      {:error, reason} ->
        {:ok, {:error, reason}, state}

      {:ok, challenge, effects} ->
        challenge2 =
          case state.challenge do
            nil ->
              challenge

            %LuohanZhen{} = existing when existing.fighter_id == fighter.id ->
              # 同一玩家向第二位长老问询：合并门控状态
              LuohanZhen.merge(existing, master_side(master_npc))

            %LuohanZhen{} = _existing ->
              # 另一玩家正在挑战：拒绝（对应 LPC assigned_fighter 互斥）
              {:error, :challenge_in_progress}
          end

        case challenge2 do
          {:error, :challenge_in_progress} ->
            {:ok, {:error, :challenge_in_progress}, state}

          %LuohanZhen{} = merged ->
            state2 = %{state | challenge: merged}
            {:ok, {:ok, merged, effects}, execute_effects(state2, effects)}
        end
    end
  end

  def handle_call(:get_challenge, _from, state) do
    {:reply, state.challenge, state}
  end

  def handle_call({:get_temp, fighter_id, key}, _from, state) do
    value =
      case state.challenge do
        %LuohanZhen{} = challenge when challenge.fighter_id == fighter_id ->
          Map.get(challenge.temp_flags || %{}, key)
        _ ->
          nil
      end

    {:reply, value, state}
  end

  @impl true
  def handle_cast({:event, fighter_id, event}, state) do
    case state.challenge do
      nil ->
        {:noreply, state, []}

      %LuohanZhen{} = challenge when challenge.fighter_id == fighter_id ->
        {new_challenge, effects} =
          case event do
            :fighter_arrived -> on_fighter_arrived(challenge)
            :other_master_asked -> on_other_master_asked(challenge)
            :fighting_tick -> on_fighting_tick(challenge)
            :waiting_tick -> on_waiting_tick(challenge)
            :do_back -> on_do_back(challenge)
            :do_recruit -> on_do_recruit(challenge)
            _ -> {challenge, []}
          end

        {new_challenge, effects} =
          case new_challenge do
            {:ok, c, effects} -> {c, effects}
            {c, effects} -> {c, effects}
          end

        {:noreply, %{state | challenge: new_challenge}, execute_effects(state, effects)}

      _ ->
        {:noreply, state, []}
    end
  end

  def handle_cast({:put_temp, fighter_id, key, value}, state) do
    case state.challenge do
      %LuohanZhen{} = challenge when challenge.fighter_id == fighter_id ->
        {:noreply,
         %{state | challenge: %{challenge | temp_flags: Map.put(challenge.temp_flags || %{}, key, value)}},
         []}
      _ ->
        {:noreply, state, []}
    end
  end

  # === 定时器回调 ===

  @impl true
  def handle_info({:luohan_zhen_timer, ref_key}, state) do
    refs = state.timer_refs || %{}
    ref = Map.get(refs, ref_key)

    case ref do
      nil ->
        {:noreply, state, []}

      _ ->
        state2 = execute_effect(state, [{:cancel_timer, ref}])
        refs2 = Map.delete(refs, ref_key)

        case state2.challenge do
          nil ->
            {:noreply, %{state2 | timer_refs: refs2}, []}

          %LuohanZhen{} = challenge ->
            {new_challenge, effects} =
              case challenge.state do
                :waiting -> LuohanZhen.waiting(challenge)
                :fighting -> LuohanZhen.fighting(challenge, challenge.round)
                :finished -> {:ok, challenge, []}
                _ -> {:ok, challenge, []}
              end

            {new_challenge, effects} =
              case new_challenge do
                {:ok, c, effects} -> {c, effects}
                {c, effects} -> {c, effects}
              end

            state3 =
              %{state2 | challenge: new_challenge, timer_refs: refs2}

            {:noreply, state3, execute_effects(state3, effects)}
        end
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state, []}
  end

  # === 状态机事件处理 ===

  defp on_fighter_arrived(challenge) do
    case challenge.state do
      :waiting -> LuohanZhen.waiting(challenge)
      _ -> {challenge, []}
    end
  end

  defp on_other_master_asked(challenge) do
    case challenge.state do
      :waiting -> LuohanZhen.waiting(challenge)
      _ -> {challenge, []}
    end
  end

  defp on_waiting_tick(challenge) do
    case challenge.state do
      :waiting -> LuohanZhen.waiting(challenge)
      _ -> {challenge, []}
    end
  end

  defp on_fighting_tick(challenge) do
    case challenge.state do
      :fighting -> LuohanZhen.fighting(challenge, challenge.round)
      _ -> {challenge, []}
    end
  end

  defp on_do_back(challenge) do
    LuohanZhen.do_back(challenge)
  end

  defp on_do_recruit(challenge) do
    LuohanZhen.do_recruit(challenge)
  end

  # === 副作用执行 ===

  defp execute_effects(state, effects) do
    Enum.reduce(effects, state, fn effect, acc ->
      execute_effect(acc, effect)
    end)
  end

  defp execute_effect(state, effect) do
    case effect do
      {:broadcast, room_id, message} ->
        broadcast_room(room_id, message)
        state

      {:say, room_id, npc_name, message} ->
        say_room(room_id, npc_name, message)
        state

      {:move_npc, npc_id, from_room, to_room} ->
        move_npc_between_rooms(npc_id, from_room, to_room)
        state

      {:delete_exit, room_id, dir} ->
        Room.delete_exit(room_id, dir)
        state

      {:set_exit, room_id, dir, target} ->
        Room.set_exit(room_id, dir, target)
        state

      {:schedule_timer, ref_key, ms} ->
        ref = Scheduler.schedule_once(ms, fn ->
          send(__MODULE__, {:luohan_zhen_timer, ref_key})
        end)
        %{state | timer_refs: Map.put(state.timer_refs || %{}, ref_key, ref)}

      {:cancel_timer, ref} ->
        Scheduler.cancel(ref)
        state

      {:put_temp, _fighter_id, _key, _value} ->
        state  # 已由 handle_cast({:put_temp, ...}) 处理

      {:delete_temp, _fighter_id, _key} ->
        state  # 由 LuohanZhen 纯函数返回，Coordinator 层不再重复处理

      {:set_env, _fighter_id, _key, _value} ->
        state  # 持久化由 player 进程或 Records 层处理，此处降级

      {:delete_env, _fighter_id, _key} ->
        state

      {:add_combat_exp, _fighter_id, _amount} ->
        state  # 同上

      {:start_combat, _npc, _player} ->
        state  # 由 NpcAttack 处理，此处降级

      _ ->
        Logger.warn("LuohanZhen 未知 effect：#{inspect(effect)}")
        state
    end
  end

  # === 房间广播 ===

  defp broadcast_room(room_id, message) do
    case room_process(room_id) do
      {:ok, _pid} ->
        Room.tell_room(%Room{id: room_id}, message)
        :ok
      _ ->
        :ok  # 房间未启动时静默降级
    end
  end

  defp say_room(room_id, npc_name, message) do
    broadcast_room(room_id, "#{npc_name}说道：#{message}\n")
  end

  # === NPC 跨房间移动（操作房间进程 state.private.characters）===

  defp move_npc_between_rooms(npc_id, from_room_id, to_room_id) do
    case room_process(from_room_id) do
      {:ok, pid} ->
        state = :sys.get_state(pid)
        chars = Map.get(state.private || %{}, :characters, [])

        case Enum.find(chars, &(&1.id == npc_id)) do
          nil ->
            :ok  # NPC 不在源房间，忽略

          character when is_map(character) ->
            remove_character_from_room(from_room_id, character)
            add_character_to_room(to_room_id, character)
            :ok

          _ ->
            :ok
        end

      _ ->
        :ok  # 房间未启动时静默降级
    end
  end

  defp remove_character_from_room(room_id, character) do
    case room_process(room_id) do
      {:ok, pid} ->
        :sys.replace_state(pid, fn state ->
          private = Map.get(state, :private, %{}) || %{}
          chars = Map.get(private, :characters, []) || []
          new_private = Map.put(private, :characters, Enum.reject(chars, &(&1.id == character.id)))
          %{state | private: new_private}
        end)
        :ok
      _ ->
        :error
    end
  end

  defp add_character_to_room(room_id, character) do
    case room_process(room_id) do
      {:ok, pid} ->
        :sys.replace_state(pid, fn state ->
          private = Map.get(state, :private, %{}) || %{}
          chars = Map.get(private, :characters, []) || []
          new_private = Map.put(private, :characters, [character | chars])
          %{state | private: new_private}
        end)
        :ok
      _ ->
        :error
    end
  end

  defp room_process(room_id) when is_binary(room_id) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) -> {:ok, pid}
      _ -> :error
    end
  end

  defp room_process(_), do: :error
end
