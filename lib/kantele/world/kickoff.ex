defmodule Kantele.World.Kickoff do
  @moduledoc """
  Kicks off the world by loading and booting it

  加载分两层兜底（详见 docs/session-prompts-b6.zh-CN.md）：

  - **解析层**（`Kantele.World.Loader.load/0` + `load_help/0`）：此时新世界尚未
    落地，失败即放弃本次加载，旧世界 100% 完好；
  - **编排层**（逐个 cache/start）：中途失败会留下半更新的世界，兜底保证本进程
    不死并如实记录状态，不回滚。

  首次启动（`start: true`）加载失败则按原行为崩溃退出，交由监督树重启，
  让运维在部署期尽早发现坏数据；游戏内 `reload` 走软兜底，回执真实结果。
  """

  use GenServer

  require Logger

  alias Kalevala.World.CharacterSupervisor
  alias Kalevala.World.RoomSupervisor
  alias Kantele.Config
  alias Kantele.World.Loader
  alias Kantele.World.ZoneCache

  defstruct boot?: false, last_load: nil, loader: Loader

  # reload 是同步调用，超时放宽以覆盖完整加载耗时
  @reload_timeout 60_000
  # 状态/回执中错误摘要的最大字符数，完整错误与堆栈只进日志
  @error_summary_length 300

  @doc false
  def start_link(opts) do
    config = Keyword.take(opts, [:start, :loader])
    otp_opts = Keyword.take(opts, [:name])

    GenServer.start_link(__MODULE__, config, otp_opts)
  end

  @doc """
  同步触发世界热更

  返回 `:ok` 或 `{:error, last_load}`（含时间/原因/文件），不再"假成功"。
  加载进程未运行或中途崩溃时也回执错误，不向调用方抛出。
  """
  def reload(server \\ __MODULE__) do
    case GenServer.whereis(server) do
      nil ->
        {:error, error_status("世界加载进程未运行", nil)}

      pid ->
        try do
          GenServer.call(pid, :reload, @reload_timeout)
        catch
          :exit, reason ->
            {:error, error_status("世界加载进程异常退出：#{inspect(reason)}", nil)}
        end
    end
  end

  @doc """
  查询上一次世界加载的结果

  返回 `%{status: :ok | :error, at: DateTime, error: String.t | nil,
  file: String.t | nil}`；尚未加载过（或进程未运行）时为 nil。
  """
  def status(server \\ __MODULE__) do
    case GenServer.whereis(server) do
      nil ->
        nil

      pid ->
        try do
          GenServer.call(pid, :status)
        catch
          :exit, _ ->
            nil
        end
    end
  end

  @impl true
  def init(config) do
    state = %__MODULE__{
      boot?: Keyword.get(config, :start, false),
      loader: Keyword.get(config, :loader, Loader)
    }

    case state.boot? do
      true ->
        {:ok, state, {:continue, :load}}

      false ->
        {:ok, state}
    end
  end

  @impl true
  def handle_call(:reload, _from, state) do
    {reply, state} = load_world(%{state | boot?: false})
    {:reply, reply, state}
  end

  def handle_call(:status, _from, state) do
    {:reply, state.last_load, state}
  end

  @impl true
  def handle_continue(:load, state) do
    {_reply, state} = load_world(state)
    {:noreply, state}
  end

  # ---- 加载流程：解析层 -> 编排层，各自兜底 ----

  defp load_world(state) do
    case safely(fn -> parse_world(state.loader) end) do
      {:ok, {world, help_topics}} ->
        apply_world(world, help_topics, state)

      {:error, info} ->
        handle_failure(info, :parse, state)
    end
  end

  # 帮助主题与纯解析无副作用，提前到解析层一起加载
  defp parse_world(loader) do
    world = loader.load()
    help_topics = loader.load_help()

    {world, help_topics}
  end

  defp apply_world(world, help_topics, state) do
    result =
      safely(fn ->
        Enum.each(world.items, &cache_item/1)

        Enum.each(world.zones, fn zone ->
          zone
          |> ZoneCache.cache()
          |> Loader.strip_zone()
          |> start_zone()
        end)

        Enum.each(world.rooms, &start_room/1)
        Enum.each(world.characters, &start_character/1)

        Enum.each(help_topics, fn help_topic ->
          Kalevala.Help.put(help_topic)
        end)

        :ok
      end)

    case result do
      {:ok, :ok} ->
        {:ok, %{state | boot?: false, last_load: ok_status()}}

      {:error, info} ->
        handle_failure(info, :orchestration, state)
    end
  end

  # 把任意异常/退出/抛出统一收拢成错误信息，保证加载进程不死
  defp safely(fun) do
    {:ok, fun.()}
  rescue
    exception ->
      {:error, error_info(exception, __STACKTRACE__)}
  catch
    kind, value ->
      exception = RuntimeError.exception(message: "#{kind}: #{inspect(value)}")

      {:error, error_info(exception, __STACKTRACE__)}
  end

  defp error_info(exception, stacktrace) do
    file =
      case exception do
        %{file: file} when is_binary(file) -> file
        _ -> nil
      end

    message = Exception.message(exception) || inspect(exception)

    %{
      message: message,
      file: file,
      exception: exception,
      stacktrace: stacktrace
    }
  end

  # ---- 失败处理 ----

  # 首次启动：记日志后按原异常崩溃，交给监督树重启，让运维尽早发现坏数据
  defp handle_failure(info, phase, %{boot?: true}) do
    Logger.error([
      "首次启动加载世界失败（",
      phase_name(phase),
      "），进程即将退出重启 - ",
      describe_error(info)
    ])

    reraise info.exception, info.stacktrace
  end

  # reload：记录状态、按开关公告、回执失败；进程存活、旧世界保持运行
  defp handle_failure(info, phase, state) do
    status = error_status(info.message, info.file)

    Logger.error([
      "世界加载失败（",
      phase_name(phase),
      "），放弃本次加载，旧世界保持运行 - ",
      describe_error(info)
    ])

    announce_failure(status, phase)

    {{:error, status}, %{state | boot?: false, last_load: status}}
  end

  defp phase_name(:parse), do: "解析层"
  defp phase_name(:orchestration), do: "编排层"

  defp describe_error(info) do
    Exception.format(:error, info.exception, info.stacktrace)
  end

  # general 频道公告受 config 开关控制（data/config.ucl 的 world.broadcast_load_failures）。
  # 配置缺失（如测试环境）、频道不存在等一律吞掉只记日志，不影响加载进程本身
  defp announce_failure(status, phase) do
    if broadcast_enabled?() do
      text = failure_notice(status, phase)

      case Kantele.Communication.announce("general", text) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warn("世界加载失败公告发布未成功 - #{inspect(reason)}")
      end
    end
  end

  defp broadcast_enabled?() do
    # Elias 会把裸 true 解析成字符串 "true"，两种取值都认（与 loader 同约定）；
    # 配置进程未运行（如测试环境）时视为关闭
    try do
      Config.get([:world, :broadcast_load_failures]) in [true, "true"]
    rescue
      _ ->
        false
    catch
      :exit, _ ->
        false
    end
  end

  defp failure_notice(status, :parse) do
    "世界数据解析失败#{location_text(status.file)}，本次加载已放弃，" <>
      "旧世界继续运行，请管理员查看日志。"
  end

  defp failure_notice(status, :orchestration) do
    "世界数据应用失败#{location_text(status.file)}，世界可能处于部分更新状态，" <>
      "请管理员查看日志。"
  end

  defp location_text(nil), do: ""
  defp location_text(file), do: "（#{file}）"

  # ---- 状态记录 ----

  defp ok_status() do
    %{status: :ok, at: DateTime.utc_now(), error: nil, file: nil}
  end

  defp error_status(message, file) do
    %{
      status: :error,
      at: DateTime.utc_now(),
      error: truncate(message, @error_summary_length),
      file: file
    }
  end

  defp truncate(string, max_chars) do
    case String.length(string) do
      length when length <= max_chars ->
        string

      _ ->
        String.slice(string, 0, max_chars) <> "…"
    end
  end

  # ---- 世界进程编排（与原实现一致）----

  defp start_zone(zone) do
    config = %{
      supervisor_name: Kantele.World,
      callback_module: Kantele.World.Zone
    }

    case GenServer.whereis(Kalevala.World.Zone.global_name(zone)) do
      nil ->
        Kalevala.World.start_zone(zone, config)

      pid ->
        reset_characters(zone)
        Kalevala.World.Zone.update(pid, zone)
    end
  end

  defp start_room(room) do
    config = %{
      supervisor_name: RoomSupervisor.global_name(room.zone_id),
      callback_module: Kantele.World.Room
    }

    item_instances = Map.get(room, :item_instances, [])
    room = Map.delete(room, :item_instances)

    case GenServer.whereis(Kalevala.World.Room.global_name(room)) do
      nil ->
        Kalevala.World.start_room(room, item_instances, config)

      pid ->
        Kalevala.World.Room.update_items(pid, item_instances)
        Kalevala.World.Room.update(pid, room)
    end
  end

  defp start_character(character) do
    config = [
      supervisor_name: CharacterSupervisor.global_name(character.meta.zone_id),
      communication_module: Kantele.Communication,
      initial_controller: Kantele.Character.SpawnController,
      quit_view: {Kantele.Character.QuitView, "disconnected"}
    ]

    Kalevala.World.start_character(character, config)
  end

  defp cache_item(item) do
    Kantele.World.Items.put(item.id, item)
  end

  # clean out all existing characters by terminating them
  defp reset_characters(zone) do
    Enum.map(character_pids(zone.id), fn pid ->
      send(pid, :terminate)
    end)
  end

  defp character_pids(zone_id) do
    case GenServer.whereis(CharacterSupervisor.global_name(zone_id)) do
      nil ->
        []

      pid ->
        Enum.map(DynamicSupervisor.which_children(pid), fn {_, pid, _, _} ->
          pid
        end)
    end
  end
end
