defmodule Kantele.Bot.Registry do
  @moduledoc """
  机器人注册表：世界就绪后按 `data/bots/*.ucl` 批量启动机器人，并记录
  每个机器人的 pid / 配置，供 `who` 过滤隐藏、状态查询与启停控制。
  """

  use GenServer

  require Logger

  alias Kantele.BotConfig

  @world_wait_retries 120
  @world_wait_delay 1_000

  defstruct bots: %{}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  # ---- 公共 API ----

  @doc "机器人是否在 `who` 中隐藏（未启用 who 的机器人）"
  def hidden?(name) do
    name in hidden_names()
  end

  @doc "全部隐藏机器人的角色名集合"
  def hidden_names do
    gen_server_call_else(fn ->
      GenServer.call(__MODULE__, :hidden_names, 5_000)
    end, MapSet.new())
  end

  @doc "启动一个已配置的机器人（按配置 key）"
  def start(name) do
    GenServer.call(__MODULE__, {:start, name}, 10_000)
  end

  @doc "停掉一个机器人（按配置 key）"
  def stop(name) do
    GenServer.call(__MODULE__, {:stop, name}, 10_000)
  end

  @doc "机器人运行状态列表"
  def status do
    GenServer.call(__MODULE__, :status, 5_000)
  end

  @doc "全部已启用配置（含未启动的）"
  def configured do
    GenServer.call(__MODULE__, :configured, 5_000)
  end

  # ---- GenServer ----

  defp gen_server_call_else(fun, fallback) do
    fun.()
  rescue
    _ -> fallback
  catch
    :exit, _ -> fallback
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    case world_ready?() do
      true ->
        state = start_enabled(state)
        {:noreply, state}

      false ->
        {:noreply, state, {:continue, :bootstrap}}
    end
  end

  defp world_ready?(attempt \\ 0) do
    case safe_start_room_id() do
      room_id when is_binary(room_id) ->
        true

      _ when attempt >= @world_wait_retries ->
        false

      _ ->
        Process.sleep(@world_wait_delay)
        world_ready?(attempt + 1)
    end
  end

  defp safe_start_room_id do
    Kantele.World.start_room_id()
  rescue
    _ -> nil
  catch
    _, _ -> nil
  end

  defp start_enabled(state) do
    BotConfig.load_all()
    |> Enum.reduce(state, fn {_key, config}, acc ->
      if config.enabled do
        start_bot(config, acc)
      else
        acc
      end
    end)
  end

  defp start_bot(%BotConfig{key: key, enabled: false} = config, state) do
    {config, state |> Map.update!(:bots, &Map.put(&1, key, %{config: config, pid: nil}))}
  end

  defp start_bot(%BotConfig{} = config, state) do
    case DynamicSupervisor.start_child(Kantele.Bot.Supervisor, {Kantele.Bot, config}) do
      {:ok, pid} ->
        Logger.info("bot #{config.key} started (pid=#{inspect(pid)})")

        bot_info = %{config: config, pid: pid}
        new_bots = Map.put(state.bots, config.key, bot_info)
        %{state | bots: new_bots}

      {:error, {:already_started, pid}} ->
        Map.put(state.bots, config.key, %{config: config, pid: pid})

      {:error, reason} ->
        Logger.error("bot #{config.key} start failed: #{inspect(reason)}")
        state
    end
  end

  @impl true
  def handle_call(:hidden_names, _from, state) do
    names =
      state.bots
      |> Map.values()
      |> Enum.filter(fn %{config: cfg} -> not cfg.who end)
      |> Enum.map(fn %{config: cfg} -> cfg.name end)
      |> MapSet.new()

    {:reply, names, state}
  end

  def handle_call({:start, name}, _from, state) do
    case Map.get(state.bots, name) do
      nil ->
        {:reply, {:error, :not_configured}, state}

      %{pid: pid} when is_pid(pid) and pid != nil ->
        case Process.alive?(pid) do
          true -> {:reply, {:ok, :already_running}, state}
          false -> restart_bot(name, state)
        end

      %{config: config} ->
        state = start_bot(config, state)
        {:reply, {:ok, Map.fetch!(state.bots, name).pid}, state}
    end
  end

  defp restart_bot(name, state) do
    %{config: config} = Map.fetch!(state.bots, name)
    state = start_bot(%{config | enabled: true}, state)
    {:reply, {:ok, Map.get(state.bots, name, %{}).pid}, state}
  end

  def handle_call({:stop, name}, _from, state) do
    case Map.get(state.bots, name) do
      %{pid: pid} when is_pid(pid) ->
        if Process.alive?(pid) do
          DynamicSupervisor.terminate_child(Kantele.Bot.Supervisor, pid)
        end

        {:reply, :ok, state}

      _ ->
        {:reply, :ok, state}
    end
  end

  def handle_call(:status, _from, state) do
    statuses =
      state.bots
      |> Enum.map(fn {_key, %{config: cfg, pid: pid}} ->
        run = if is_pid(pid) and Process.alive?(pid), do: Kantele.Bot.stats(pid), else: nil
        %{config: cfg, running: run != nil, stats: run}
      end)

    {:reply, statuses, state}
  end

  def handle_call(:configured, _from, state) do
    {:reply, Map.keys(state.bots), state}
  end
end