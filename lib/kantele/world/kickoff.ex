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
        # 基础设施必须先在线，且要早于 cleanup_stale_processes/1：
        # Kalevala.Cache.keys/1、get/1 直读 ETS 表（表不存在抛 ArgumentError），
        # put/2、delete/1 走 GenServer.call（进程不在会 exit）。生产环境由
        # Kantele.World 监督树启动；测试中直接启动 Kickoff 时在此兜底。
        ensure_world_infrastructure()

        # A3 f1 Diff-stop：在缓存新世界之前，先终止不再存在的 zone/房间/角色，
        # 防止热更后僵尸进程堆积。终止顺序：角色 → 房间 → zone。
        cleanup_stale_processes(world)

        Enum.each(world.items, &cache_item/1)

        new_room_ids = MapSet.new(Enum.map(world.rooms, & &1.id))
        old_room_ids_for_zones =
          safe_zone_keys()
          |> MapSet.new()
          |> MapSet.intersection(MapSet.new(Enum.map(world.zones, & &1.id)))
          |> Enum.flat_map(fn zone_id ->
            case safe_zone_get(zone_id) do
              {:ok, zone} -> zone_room_ids(zone)
              _ -> []
            end
          end)
          |> MapSet.new()
          |> MapSet.difference(new_room_ids)

        Enum.each(world.zones, fn zone ->
          zone
          |> ZoneCache.cache()
          |> Loader.strip_zone()
          |> start_zone(old_room_ids_for_zones)
        end)

        Enum.each(world.rooms, &start_room/1)

        # 防御性清理：确保所有不应存在的房间注册名都被移除，
        # 防止 RoomSupervisor 等异步进程在 start_zone 之后重新注册旧房间
        Enum.each(old_room_ids_for_zones, &stop_room/1)

        Enum.each(world.characters, &start_character/1)

        # Q5-T3：子虚道人常驻子虚观（随世界加载挂进 liuxi 区角色监督树）
        spawn_zixu(world)

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

  defp start_zone(zone, old_room_ids) do
    config = %{
      supervisor_name: Kantele.World,
      callback_module: Kantele.World.Zone
    }

    zone_pid = GenServer.whereis(Kalevala.World.Zone.global_name(zone))
    room_sup_pid = :global.whereis_name({Kalevala.World.RoomSupervisor, zone.id})
    zone_sup_pid = :global.whereis_name({Kalevala.World.ZoneSupervisor, zone.id})

    # 只有 Zone / RoomSupervisor / ZoneSupervisor 三者都活着才算「可原地更新」。
    # 任一缺失说明上一轮清理留下了半死的监督树：此时若直接重建，RoomSupervisor
    # 会因 {:already_started, dead_pid} 启动失败；若当作存活只做 update，
    # 房间又会因 RoomSupervisor 已注销而 :noproc。
    if Enum.all?([zone_pid, room_sup_pid, zone_sup_pid], &alive_pid?/1) do
      Enum.each(old_room_ids, &stop_room/1)
      reset_characters(zone)
      Kalevala.World.Zone.update(zone_pid, zone)
    else
      purge_zone_tree(zone.id)
      {:ok, new_zone_sup_pid} = Kalevala.World.start_zone(zone, config)
      :global.register_name({Kalevala.World.ZoneSupervisor, zone.id}, new_zone_sup_pid)
    end
  end

  defp alive_pid?(pid) when is_pid(pid), do: Process.alive?(pid)
  defp alive_pid?(_), do: false

  # 终止单个房间进程并注销其 :global 名字。房间是 RoomSupervisor
  # （DynamicSupervisor）的 :permanent 子进程，直接 :kill 会被重启并重新
  # 注册，所以优先用 terminate_child/2 正常摘除。
  defp stop_room(room_id) do
    name = {Kalevala.World.Room, room_id}

    case :global.whereis_name(name) do
      pid when is_pid(pid) ->
        supervisor =
          case safe_get_state(pid) do
            {:ok, %{supervisor_name: sup}} -> sup
            _ -> nil
          end

        terminate_supervised_child(supervisor, pid)
        wait_for_exit(pid)
        :global.unregister_name(name)

      _ ->
        :ok
    end
  end

  # 把 DynamicSupervisor 的 :permanent 子进程正常摘除。直接 :kill 会被
  # 监督树按重启策略拉起，甚至触发重启强度上限让整个 supervisor :shutdown。
  # 仅在找不到归属（或子进程已不在监督树里）时降级为 :kill。
  defp terminate_supervised_child(nil, pid), do: Process.exit(pid, :kill)

  defp terminate_supervised_child(supervisor, pid) do
    try do
      case DynamicSupervisor.terminate_child(supervisor, pid) do
        :ok -> :ok
        _ -> Process.exit(pid, :kill)
      end
    rescue
      _ -> Process.exit(pid, :kill)
    catch
      :exit, _ -> Process.exit(pid, :kill)
    end
  end

  # 幂等清理 zone 整棵监督树：先把 ZoneSupervisor 从 Kantele.World
  # 正常摘除（其子进程随之退出），再清掉残留的 :global 注册名。
  defp purge_zone_tree(zone_id) do
    [zone_sup_name | child_names] = zone_global_names(zone_id)

    case :global.whereis_name(zone_sup_name) do
      pid when is_pid(pid) ->
        terminate_supervised_child(Kantele.World, pid)
        wait_for_exit(pid)

      _ ->
        :ok
    end

    Enum.each(child_names, fn name ->
      case :global.whereis_name(name) do
        pid when is_pid(pid) ->
          Process.exit(pid, :kill)
          wait_for_exit(pid)

        _ ->
          :ok
      end
    end)

    # 无论进程是否仍登记，都显式注销，防止 :global 残留脏名字
    Enum.each([zone_sup_name | child_names], &:global.unregister_name/1)
    :ok
  end

  defp zone_global_names(zone_id) do
    [
      {Kalevala.World.ZoneSupervisor, zone_id},
      {Kalevala.World.RoomSupervisor, zone_id},
      {Kalevala.World.CharacterSupervisor, zone_id},
      {Kalevala.World.Zone, zone_id}
    ]
  end

  # ZoneCache 里的 rooms 可能是 list（测试桩）或 map（真实 UCL 数据）
  defp zone_room_ids(zone) do
    case Map.get(zone, :rooms, []) do
      rooms when is_list(rooms) -> Enum.map(rooms, &Map.get(&1, :id))
      rooms when is_map(rooms) -> Map.values(rooms) |> Enum.map(&Map.get(&1, :id))
      _ -> []
    end
  end

  # 将测试桩/外部传入的 plain map 房间转为 Kantele.World.Room 结构体，
  # 否则 `Kalevala.World.Room.init/1` 会调用 `Callbacks.init/1`，而该协议
  # 只对 `Kantele.World.Room` 结构体有实现，plain map 会抛 Protocol.UndefinedError。
  defp to_room_struct(room) when is_map(room) and not is_struct(room) do
    %Kantele.World.Room{
      id: room.id,
      zone_id: room.zone_id,
      exits: Map.get(room, :exits, []),
      flags: Map.get(room, :flags, []),
      actions: Map.get(room, :actions, %{})
    }
  end

  defp to_room_struct(room), do: room

  defp start_room(room) do
    item_instances =
      Map.get(room, :item_instances, [])
      |> Enum.map(&Kantele.World.Item.materialize_book/1)

    room = to_room_struct(Map.delete(room, :item_instances))

    config = %{
      supervisor_name: RoomSupervisor.global_name(room.zone_id),
      callback_module: Kantele.World.Room
    }

    case GenServer.whereis(Kalevala.World.Room.global_name(room)) do
      nil ->
        result = Kalevala.World.start_room(room, item_instances, config)

        case result do
          {:ok, pid} ->
            # Belt-and-suspenders：确保房间进程在 :global 下可被按名查找。
            # Kalevala.World.start_room/3 已通过 genserver_options 的 name: 注册，
            # 这里再显式 register 一次，防止 DynamicSupervisor 解析 {:global, ...}
            # 监督引用时的边界情况导致注册缺失。
            :global.register_name({Kalevala.World.Room, room.id}, pid)

          {:error, reason} ->
            Logger.warn("start_room #{inspect(room.id)} failed: #{inspect(reason)}")
        end

        result

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

  # 子虚道人：不随 UCL 数据定义，而是在世界就绪后按代码模板启动。
  # 只在本次加载的世界实际包含 liuxi 区时才派生；其他加载（如测试桩世界）
  # 不派生，避免往真实 liuxi 监督树里塞 NPC 造成跨测试/跨加载污染。
  defp spawn_zixu(world) do
    if Enum.any?(world.zones, &(&1.id == "liuxi")) do
      _ = Kantele.World.MirrorDaemon.Zixu.start_zixu()
    end

    :ok
  end

  # ---- A3 f1 Diff-stop：清理热更后不再存在的进程 ----

  # 终止不再存在的 zone/房间/角色。终止顺序：角色 → 房间 → zone。
  # 必须在缓存新世界之前调用，此时 ZoneCache 仍保留旧世界的 zone 条目。
  defp cleanup_stale_processes(world) do
    new_zone_ids = MapSet.new(Enum.map(world.zones, & &1.id))
    new_room_ids = MapSet.new(Enum.map(world.rooms, & &1.id))
    new_character_ids = MapSet.new(Enum.map(world.characters, & &1.id))

    # 1. 在仍保留的 zone 中：终止不再存在的角色（豁免 zixu 代码模板 NPC）
    surviving_zones =
      MapSet.intersection(safe_zone_keys() |> MapSet.new(), new_zone_ids)

    Enum.each(surviving_zones, fn zone_id ->
      case :global.whereis_name({Kalevala.World.CharacterSupervisor, zone_id}) do
        pid when is_pid(pid) ->
          if Process.alive?(pid) do
            children =
              try do
                DynamicSupervisor.which_children(pid)
              rescue
                _ -> []
              catch
                :exit, _ -> []
              end

            Enum.each(children, fn {_, child_pid, _, _} ->
              case safe_get_state(child_pid) do
                {:ok, %{character: %{id: char_id}}} when is_binary(char_id) ->
                  if not(MapSet.member?(new_character_ids, char_id)) and
                       char_id != "zixu_daoren" do
                    # Foreman 的 handle_info(:terminate) 会以 :normal 退出，
                    # 作为 :permanent 子进程不会被 CharacterSupervisor 重启
                    send(child_pid, :terminate)
                  end
                _ ->
                  :ok
              end
            end)
          end
        _ ->
          :ok
      end
    end)

    # 2. 在仍保留的 zone 中：终止不再存在的房间进程
    known_room_ids =
      surviving_zones
      |> Enum.flat_map(fn zone_id ->
        case safe_zone_get(zone_id) do
          {:ok, zone} -> zone_room_ids(zone)
          _ -> []
        end
      end)
      |> MapSet.new()

    old_room_ids = MapSet.difference(known_room_ids, new_room_ids)
    Enum.each(old_room_ids, &stop_room/1)

    # 3. 终止不再存在的 zone：房间进程 + 整棵监督树的 :global 名字一并清干净。
    #    ZoneSupervisor 是 Supervisor（use Supervisor），陷阱退出信号，
    #    :shutdown 被忽略，必须用 :kill；先杀它本身，避免 :one_for_one
    #    策略在子进程死亡时把子进程重启。显式注销所有注册名，防止后续
    #    同名 zone 重建时出现 already_started / noproc。
    old_zone_ids = MapSet.difference(safe_zone_keys() |> MapSet.new(), new_zone_ids)
    Enum.each(old_zone_ids, fn zone_id ->
      case safe_zone_get(zone_id) do
        {:ok, zone} -> Enum.each(zone_room_ids(zone), &stop_room/1)
        _ -> :ok
      end

      purge_zone_tree(zone_id)
      safe_zone_delete(zone_id)
    end)

    :ok
  end

  # 等待进程真正退出，避免 Process.exit 的异步性导致 :global 注册名尚未清理
  # 就被后续逻辑读取而误判为“进程仍在运行”。
  defp wait_for_exit(pid, attempts \\ 100) when is_pid(pid) do
    if Process.alive?(pid) and attempts > 0 do
      Process.sleep(10)
      wait_for_exit(pid, attempts - 1)
    end
  end

  defp wait_for_exit(_pid, _attempts), do: :ok

  # 包装 :sys.get_state/2，统一返回 {:ok, state}，避免进程在 which_children
  # 与 get_state 之间已退出而抛异常
  defp safe_get_state(pid) when is_pid(pid) do
    try do
      {:ok, :sys.get_state(pid)}
    rescue
      _ -> {:error, :process_gone}
    catch
      _, _ -> {:error, :process_gone}
    end
  end

  defp safe_get_state(_), do: {:error, :not_a_pid}

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

  # ---- 基础设施兜底 ----

  # 生产环境这两个进程由 Kantele.World 监督树启动；测试中直接启动 Kickoff，
  # 或上一个用例把链接到 Kickoff 的 ZoneCache 一并带下线时，在此补齐。
  # 必须在 cleanup_stale_processes/1 之前调用。
  defp ensure_world_infrastructure do
    case GenServer.whereis(Kantele.World) do
      pid when is_pid(pid) ->
        if Process.alive?(pid), do: :ok, else: start_kalevala_world()

      nil ->
        start_kalevala_world()
    end

    case GenServer.whereis(ZoneCache) do
      pid when is_pid(pid) ->
        if Process.alive?(pid), do: :ok, else: start_zone_cache()

      nil ->
        start_zone_cache()
    end

    :ok
  end

  # Kalevala.Cache 的 keys/get 直读 ETS 表，表不存在抛 ArgumentError；
  # put/delete 走 GenServer.call，进程不在会 exit。热更清理不应因缓存短暂
  # 不可用而打断整次加载，统一降级为「无旧数据」/ no-op。
  defp safe_zone_keys do
    try do
      ZoneCache.keys()
    rescue
      _ -> []
    catch
      :exit, _ -> []
    end
  end

  defp safe_zone_get(zone_id) do
    try do
      ZoneCache.get(zone_id)
    rescue
      _ -> {:error, :not_found}
    catch
      :exit, _ -> {:error, :not_found}
    end
  end

  defp safe_zone_delete(zone_id) do
    try do
      ZoneCache.delete(zone_id)
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end

    :ok
  end

  defp start_kalevala_world do
    case Kalevala.World.start_link(name: Kantele.World) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} ->
        raise "无法启动 Kalevala.World (Kantele.World): #{inspect(reason)}"
    end
  end

  defp start_zone_cache do
    case ZoneCache.start_link(id: ZoneCache, name: ZoneCache) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} ->
        raise "无法启动 ZoneCache: #{inspect(reason)}"
    end
  end
end
