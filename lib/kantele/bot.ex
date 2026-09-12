defmodule Kantele.Bot do
  @moduledoc """
  自动化机器人：以一个无 Socket 的玩家会话（`Kalevala.Character.Foreman`）登录游戏，
  按配置驱动自身走路 / 打猎 / 修炼。

  核心思想（与 `scripts/boar_dump.exs` 同一条已被验证的通路）：
  - `Foreman.start_player(self(), foreman_options ++ [protocol: self()])` 建会话；
  - `send(foreman, {:recv, :text, line})` 投递命令文本，走完整命令栈；
  - 战斗由角色的 1 秒心跳自驱（`CombatEvent.tick`），机器人只需读状态做决策。

  每个机器人一个 GenServer；由 `Kantele.Bot.Supervisor` 管理。
  """

  use GenServer

  require Logger

  alias Kantele.Character.Stats

  alias Kantele.BotConfig

  @world_wait_retries 60
  @world_wait_delay 1_000
  @kill_cooldown_ms 2_500

  defstruct [
    :config,
    :foreman,
    seq: 0,
    logged_in: false,
    train_index: 0,
    route_index: 0,
    save_counter: 0,
    last_kill_at: 0
  ]

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  def child_spec(config) do
    %{id: {:kantele_bot, config.key}, start: {__MODULE__, :start_link, [config]}}
  end

  @impl true
  def init(%BotConfig{} = config) do
    {:ok, %__MODULE__{config: config}, {:continue, :login}}
  end

  # ---- 登录阶段 ----

  @impl true
  def handle_continue(:login, state) do
    case wait_for_world() do
      :ok -> do_login(state)
      :timeout -> {:stop, :world_not_loaded, state}
    end
  end

  defp wait_for_world(attempt \\ 0) do
    case safe_start_room_id() do
      room_id when is_binary(room_id) ->
        :ok

      _ when attempt >= @world_wait_retries ->
        :timeout

      _ ->
        Process.sleep(@world_wait_delay)
        wait_for_world(attempt + 1)
    end
  end

  defp safe_start_room_id do
    Kantele.World.start_room_id()
  rescue
    _ -> nil
  catch
    _, _ -> nil
  end

  defp do_login(state) do
    cfg = state.config

    case start_foreman() do
      {:ok, foreman} ->
        msg = fn line ->
          send(foreman, {:recv, :text, line})
          Process.sleep(300)
        end

        # 登录三行（用户名/密码/角色名；密码不校验，任意）
        msg.(cfg.account)
        msg.(cfg.password)
        msg.(cfg.name)
        Process.sleep(1_000)

        Logger.info("bot #{cfg.name} logged in (foreman=#{inspect(foreman)})")

        {:noreply, %{state | foreman: foreman, logged_in: true}, {:continue, :start_tick}}

      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  defp start_foreman do
    opts = ExVenture.Application.KalevalaSupervisor.foreman_options() ++ [protocol: self()]

    case Kalevala.Character.Foreman.start_player(self(), opts) do
      {:ok, foreman} ->
        Process.monitor(foreman)
        {:ok, foreman}

      other ->
        Logger.error("bot foreman start failed: #{inspect(other)}")
        {:error, :foreman_start_failed}
    end
  end

  @impl true
  def handle_continue(:start_tick, state) do
    schedule_tick(state.config.tick_ms)
    {:noreply, state}
  end

  defp schedule_tick(ms), do: Process.send_after(self(), :tick, ms)

  # ---- 控制循环 ----

  @impl true
  def handle_info(:tick, state) do
    if state.logged_in and Process.alive?(state.foreman) do
      do_tick(state)
    else
      {:noreply, state}
    end
  end

  defp do_tick(state) do
    cfg = state.config
    snapshot = read_state(state.foreman)

    case snapshot do
      nil ->
        schedule_tick(cfg.tick_ms)
        {:noreply, state}

      st ->
        state = %{state | seq: state.seq + 1, save_counter: state.save_counter + 1}

        {state, action} =
          cond do
            st.vitals.qi <= 0 ->
              {state, nil}

            save_due?(state, cfg, st) ->
              {state, "save"}

            true ->
              decide(st, cfg, state)
          end

        case action do
          nil ->
            :ok

          line ->
            drain_mailbox()
            send(state.foreman, {:recv, :text, line})
        end

        schedule_tick(cfg.tick_ms)
        {:noreply, state}
    end
  end

  defp save_due?(state, cfg, st) do
    state.save_counter > 0 and rem(state.save_counter, cfg.save_every) == 0 and
      not in_combat?(st)
  end

  # ---- 感知：读 foreman 状态 ----

  defp read_state(foreman) do
    foreman
    |> :sys.get_state()
    |> Map.get(:character)
    |> case do
      nil ->
        nil

      character ->
        meta = character.meta

        %{
          room_id: character.room_id,
          name: character.name,
          vitals: meta.vitals,
          stats: meta.stats,
          combat: if(meta.combat, do: meta.combat, else: Kantele.Character.Combat.new())
        }
    end
  rescue
    _ -> nil
  catch
    _, _ -> nil
  end

  # ---- 决策（返回 {更新的 state, 动作命令 或 nil}）----

  defp decide(st, cfg, state) do
    cond do
      in_combat?(st) and ratio(st.vitals.qi, st.vitals.max_qi) < cfg.flee_qi ->
        {state, "逃跑"}

      in_combat?(st) and ratio(st.vitals.qi, st.vitals.max_qi) < cfg.heal_qi ->
        {state, "halt"}

      in_combat?(st) ->
        {state, nil}

      ratio(st.vitals.jing, st.vitals.max_jing) < 0.2 ->
        {state, nil}

      true ->
        case hunt_target(st, cfg, state) do
          target when is_binary(target) ->
            {%{state | last_kill_at: now_ms()}, "kill " <> target}

nil ->
              case train_target(st, cfg, state) do
                {line, train_index} ->
                  {%{state | train_index: train_index}, line}

                nil ->
                  {state, march_action} = march_step(st, cfg, state)
                  {state, march_action}
              end
        end
    end
  end

  defp in_combat?(st), do: st.combat.enemies != []

  defp ratio(_numer, 0), do: 0.0
  defp ratio(numer, denom), do: numer / max(denom, 1)

  defp hunt_target(st, cfg, state) do
    allowed =
      not_no_fight?(st.room_id) and
        (cfg.hunt_rooms == [] or st.room_id in cfg.hunt_rooms) and
        (state.last_kill_at == 0 or now_ms() - state.last_kill_at >= @kill_cooldown_ms)

    if allowed do
      mobs = room_names(st.room_id, st.name)
      Enum.find(cfg.hunt, fn mob -> mob in mobs end)
    end
  end

  defp train_target(st, cfg, state) do
    if cfg.train != [] and
         Stats.available_potential(st.stats) >= cfg.train_potential and
         ratio(st.vitals.jing, st.vitals.max_jing) >= cfg.train_jing do
      count = length(cfg.train)
      index = rem(state.train_index, count)
      line = Enum.at(cfg.train, index)
      train_index = if index == count - 1, do: 0, else: index + 1
      {line, train_index}
    end
  end

  defp not_no_fight?(room_id) do
    not Enum.member?(Kantele.World.room_flags(room_id), "no_fight")
  end

  defp march_step(st, cfg, state) do
    case cfg.hunt_rooms do
      [] ->
        fallback_march(st, cfg, state)

      hunt_rooms ->
        if st.room_id in hunt_rooms do
          {state, nil}
        else
          case nav_step(st.room_id, hunt_rooms) do
            {dir, _path} -> {state, dir}
            nil -> fallback_march(st, cfg, state)
          end
        end
    end
  end

  defp fallback_march(st, cfg, state) do
    case cfg.march do
      [] ->
        {state, random_exit(st.room_id)}

      route ->
        index = rem(state.route_index, length(route))
        state = %{state | route_index: state.route_index + 1}
        {state, Enum.at(route, index)}
    end
  end

  defp nav_step(start_id, goal_ids) do
    case bfs_path([{start_id, []}], MapSet.new([start_id]), goal_ids) do
      [dir | rest] -> {dir, rest}
      _ -> nil
    end
  end

  defp bfs_path([], _visited, _goal_ids), do: nil

  defp bfs_path([{room_id, path} | queue], visited, goal_ids) do
    if room_id in goal_ids do
      path
    else
      neighbors =
        room_id
        |> room_exits()
        |> Enum.reject(fn {_dir, dest} -> is_nil(dest) or MapSet.member?(visited, dest) end)
        |> Enum.uniq_by(fn {_dir, dest} -> dest end)

      visited =
        Enum.reduce(neighbors, visited, fn {_dir, dest}, acc -> MapSet.put(acc, dest) end)

      queue = queue ++ Enum.map(neighbors, fn {dir, dest} -> {dest, path ++ [dir]} end)
      bfs_path(queue, visited, goal_ids)
    end
  end

  defp room_exits(room_id) do
    with {:ok, zone} <- Kantele.World.ZoneCache.get(zone_id(room_id)),
         room when not is_nil(room) <- Enum.find(zone.rooms, &(&1.id == room_id)) do
      Enum.map(room.exits, fn exit -> {exit.exit_name, exit.end_room_id} end)
    else
      _ -> []
    end
  end

  defp random_exit(room_id) do
    zone_id = room_id |> String.split(":") |> hd()

    case find_room(zone_id, room_id) do
      %{exits: exits} when exits != [] ->
        exits |> Enum.map(& &1.exit_name) |> Enum.random()

      _ ->
        nil
    end
  end

  defp find_room(zone_id, room_id) do
    case Kantele.World.ZoneCache.get(zone_id) do
      {:ok, zone} ->
        Enum.find(zone.rooms, &(&1.id == room_id))

      _ ->
        nil
    end
  end

  defp zone_id(room_id), do: room_id |> String.split(":") |> hd()

  @doc """
  房间内角色名列表（排除自己与在线玩家；仅用于找打猎目标）
  """
  def room_names(room_id, self_name) do
    Kantele.Communication.subscribers("rooms:#{room_id}")
    |> Enum.map(fn {_channel, pid, _opts} -> pid end)
    |> Enum.reject(&player_pid?/1)
    |> Enum.flat_map(fn pid ->
      if Process.alive?(pid) do
        character_name(pid)
      else
        []
      end
    end)
    |> Enum.reject(&(&1 == self_name))
    |> Enum.uniq()
  end

  defp character_name(pid) do
    case :sys.get_state(pid) do
      %{character: %{name: name}} -> [name]
      _ -> []
    end
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  defp player_pid?(pid) do
    Kantele.Character.Presence.characters()
    |> Enum.any?(fn ch -> ch.pid == pid end)
  end

  # ---- 其他 GenServer 回调 ----

  @impl true
  def handle_info({:DOWN, _ref, :process, _foreman, reason}, state) do
    Logger.warning("bot #{state.config.name} foreman down: #{inspect(reason)}")

    if state.config.relog do
      {:noreply, %{state | foreman: nil, logged_in: false}, {:continue, :login}}
    else
      {:stop, :foreman_down, state}
    end
  end

  def handle_info({:send, _data}, state) do
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.foreman && Process.alive?(state.foreman) do
      DynamicSupervisor.terminate_child(Kantele.Character.Foreman.Supervisor, state.foreman)
    end

    :ok
  end

  # 清空 protocol 输出邮箱（本进程就是 protocol pid，战斗/房间广播都会进来）
  defp drain_mailbox do
    receive do
      {:send, _} -> drain_mailbox()
    after
      0 -> :ok
    end
  end

  defp now_ms, do: System.monotonic_time(:millisecond)

  @doc "机器人运行统计（供 Registry.status/排障）"
  def stats(pid) do
    case safe_get_state(pid) do
      %{config: cfg} = st ->
        %{
          key: cfg.key,
          name: cfg.name,
          who: cfg.who,
          tick_ms: cfg.tick_ms,
          logged_in: st.logged_in,
          seq: st.seq
        }

      _ ->
        nil
    end
  end

  defp safe_get_state(pid) do
    :sys.get_state(pid)
  rescue
    _ -> nil
  end
end