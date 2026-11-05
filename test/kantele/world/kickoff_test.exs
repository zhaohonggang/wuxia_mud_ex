defmodule Kantele.World.KickoffTest do
  use ExUnit.Case, async: false

  alias Kantele.Character.ChannelView
  alias Kantele.Character.ReloadView
  alias Kantele.Character.WorldStatusView
  alias Kantele.World.Kickoff
  alias Kantele.World.KickoffTest.StubLoader
  alias Kantele.World.ZoneCache

  @moduledoc """
  世界加载兜底行为测试

  通过 StubLoader（模式经 Application env 注入）覆盖：
  解析层失败/编排层失败时进程存活、旧状态保留、回执真实结果、可恢复。
  """

  setup do
    Application.put_env(:ex_venture, :kickoff_stub_loader_mode, :ok)

    on_exit(fn ->
      Application.delete_env(:ex_venture, :kickoff_stub_loader_mode)
    end)

    :ok
  end

  defp set_mode(mode) do
    Application.put_env(:ex_venture, :kickoff_stub_loader_mode, mode)
  end

  defp start_kickoff(opts \\ []) do
    name = Module.concat(Kickoff, "Test#{System.unique_integer([:positive])}")

    {:ok, pid} =
      Kickoff.start_link(Keyword.merge([name: name, start: false, loader: StubLoader], opts))

    {pid, name}
  end

  defp wait_until(fun, attempts \\ 200)

  defp wait_until(_fun, 0), do: flunk("等待条件超时")

  defp wait_until(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      wait_until(fun, attempts - 1)
    end
  end

  describe "解析层兜底" do
    test "load 抛错时进程存活并回执失败原因" do
      set_mode(:raise)
      {pid, name} = start_kickoff()

      assert {:error, last_load} = Kickoff.reload(name)
      assert last_load.status == :error
      assert last_load.error =~ "模拟坏掉的 UCL 数据"
      assert Process.alive?(pid)

      # 状态查询与回执一致
      assert %{status: :error, error: error} = Kickoff.status(name)
      assert error == last_load.error
    end

    test "LoaderError 归因到具体文件时回执带文件名" do
      set_mode(:raise_with_file)
      {_pid, name} = start_kickoff()

      assert {:error, last_load} = Kickoff.reload(name)
      assert last_load.file == "data/world/liuxi.ucl"
      assert last_load.error =~ "liuxi.ucl"
    end

    test "失败后修复数据再次 reload 可恢复成功（旧世界结构仍在）" do
      set_mode(:raise)
      {pid, name} = start_kickoff()

      assert {:error, _} = Kickoff.reload(name)
      assert Process.alive?(pid)

      set_mode(:ok)
      assert :ok = Kickoff.reload(name)
      assert %{status: :ok} = Kickoff.status(name)
      assert Process.alive?(pid)
    end
  end

  describe "编排层兜底" do
    test "cache/start 阶段抛错时进程存活且记录失败" do
      set_mode(:broken_items)
      {pid, name} = start_kickoff()

      assert {:error, last_load} = Kickoff.reload(name)
      assert last_load.status == :error
      assert last_load.error != nil
      assert Process.alive?(pid)

      # 编排层失败不回滚，但后续加载仍能正常进行
      set_mode(:ok)
      assert :ok = Kickoff.reload(name)
      assert %{status: :ok} = Kickoff.status(name)
    end
  end

  describe "首次启动策略" do
    test "启动期加载失败按原行为崩溃退出，交由监督树重启" do
      set_mode(:raise)

      # trap_exit 必须在 start_link 前设置，否则测试进程会被连带击杀
      Process.flag(:trap_exit, true)
      {pid, _name} = start_kickoff(start: true)

      assert_receive {:EXIT, ^pid, _reason}, 1_000
      refute Process.alive?(pid)
    end

    test "启动期加载成功则进程存活且状态为 ok" do
      set_mode(:ok)
      {pid, name} = start_kickoff(start: true)

      wait_until(fn ->
        case Kickoff.status(name) do
          %{status: :ok} -> true
          _ -> false
        end
      end)

      assert Process.alive?(pid)
    end
  end

  describe "视图渲染" do
    test "world_status 未加载过" do
      text = WorldStatusView.render("display", %{last_load: nil})
      assert text =~ "尚未加载"
    end

    test "world_status 成功" do
      text =
        WorldStatusView.render("display", %{
          last_load: %{status: :ok, at: DateTime.utc_now(), error: nil, file: nil}
        })

      assert text =~ "成功"
    end

    test "world_status 失败含时间/文件/原因" do
      text =
        WorldStatusView.render("display", %{
          last_load: %{
            status: :error,
            at: DateTime.utc_now(),
            error: "世界数据文件处理失败",
            file: "data/world/liuxi.ucl"
          }
        })

      assert text =~ "失败"
      assert text =~ "liuxi.ucl"
      assert text =~ "世界数据文件处理失败"
    end

    test "reload 失败回执文案含文件与原因" do
      text =
        ReloadView.render("reload_failed", %{
          error: "世界数据文件处理失败（data/world/liuxi.ucl）：少了右花括号",
          file: "data/world/liuxi.ucl"
        })

      assert text =~ "加载失败"
      assert text =~ "data/world/liuxi.ucl"
      assert text =~ "旧世界继续运行"
    end

    test "系统公告模板带虚拟角色（Web 端 reducer 需要 id/name）" do
      rendered = ChannelView.render("system", %{channel_name: "general", text: "测试公告"})

      assert rendered.text != nil
      assert rendered.data.character.name == "系统"
      assert is_binary(rendered.data.character.id)
    end
  end

  describe "A3 f1 Diff-stop：热更清理不再存在的进程" do
    test "zone 被移除后 ZoneSupervisor 及其房间进程均被终止" do
      # 首次加载 dz:alpha（含房间 dz:alpha:r1）
      set_mode(:diff_stop_v1)
      {pid, name} = start_kickoff()

      assert :ok = Kickoff.reload(name)
      assert %{status: :ok} = Kickoff.status(name)

      # dz:alpha 的 ZoneSupervisor 应该在运行
      assert is_pid(:global.whereis_name({Kalevala.World.ZoneSupervisor, "dz:alpha"}))
      # 房间 dz:alpha:r1 应该在运行
      assert is_pid(:global.whereis_name({Kalevala.World.Room, "dz:alpha:r1"}))

      # 切换到 dz:beta（dz:alpha 不再存在）
      set_mode(:diff_stop_v2)
      assert :ok = Kickoff.reload(name)

      # dz:alpha 的 ZoneSupervisor 已被终止（及其整棵监督树）
      refute is_pid(:global.whereis_name({Kalevala.World.ZoneSupervisor, "dz:alpha"}))
      # dz:alpha 的房间进程已随 zone 一并终止
      refute is_pid(:global.whereis_name({Kalevala.World.Room, "dz:alpha:r1"}))
      # dz:beta 的 ZoneSupervisor 和房间应正常运行
      assert is_pid(:global.whereis_name({Kalevala.World.ZoneSupervisor, "dz:beta"}))
      assert is_pid(:global.whereis_name({Kalevala.World.Room, "dz:beta:r2"}))
    end

    test "zone 保留但房间被移除后，仅房间进程被终止，zone 和角色保留" do
      # 首次加载 dz:alpha（含房间 dz:alpha:r1）
      set_mode(:diff_stop_v1)
      {_pid, name} = start_kickoff()

      assert :ok = Kickoff.reload(name)
      assert is_pid(:global.whereis_name({Kalevala.World.Room, "dz:alpha:r1"}))
      refute is_pid(:global.whereis_name({Kalevala.World.Room, "dz:alpha:r2"}))

      # 切换到 dz:alpha 的 v3 版本（同 zone，房间换成 r2，r1 被移除）
      set_mode(:diff_stop_v3)
      assert :ok = Kickoff.reload(name)

      # zone 仍在（zone id 相同，ZoneSupervisor 未被终止）
      assert is_pid(:global.whereis_name({Kalevala.World.ZoneSupervisor, "dz:alpha"}))
      # 旧房间 r1 已被终止
      refute is_pid(:global.whereis_name({Kalevala.World.Room, "dz:alpha:r1"}))
      # 新房间 r2 已启动
      assert is_pid(:global.whereis_name({Kalevala.World.Room, "dz:alpha:r2"}))
    end

    test "多次 reload 后 ZoneCache 中不再存在的 zone 条目被清理" do
      set_mode(:diff_stop_v1)
      {_pid, name} = start_kickoff()
      assert :ok = Kickoff.reload(name)

      # ZoneCache 应包含 dz:alpha
      assert {:ok, _zone} = ZoneCache.get("dz:alpha")

      set_mode(:diff_stop_v2)
      assert :ok = Kickoff.reload(name)

      # dz:alpha 的 ZoneCache 条目应已删除
      assert {:error, :not_found} = ZoneCache.get("dz:alpha")
      # dz:beta 的 ZoneCache 条目应存在
      assert {:ok, _zone} = ZoneCache.get("dz:beta")
    end
  end
end

defmodule Kantele.World.KickoffTest.StubLoader do
  @moduledoc false

  # 测试桩：按 Application env 的模式返回不同结果，避免依赖真实 data 目录与全局进程
  def load() do
    case mode() do
      :raise ->
        raise "模拟坏掉的 UCL 数据"

      :raise_with_file ->
        raise Kantele.World.LoaderError,
          message: "世界数据文件处理失败",
          file: "data/world/liuxi.ucl",
          reason: RuntimeError.exception("unexpected token")

      :broken_items ->
        # item 为空 map 时 cache_item 取 item.id 会抛错，命中编排层兜底
        %Kantele.World{items: [%{}], zones: [], rooms: [], characters: []}

      :ok ->
        # 返回一个最小但有效的 world，走完整编排层（cache/start 各阶段）。
        # 用每次唯一的 zone id，避免砸进真实 "liuxi" 全局命名/ZoneCache：
        # 否则会污染套件中真实 liuxi 世界（镜像房间泄漏），随机顺序下偶发失败。
        # 使用纯 map（Kalevala start 阶段仅按 map 字段处理，不依赖 struct）。
        zone_id = "kstub-#{System.unique_integer([:positive])}"

        zixu_room = %{
          id: "#{zone_id}:zixu_guan",
          zone_id: zone_id,
          item_instances: []
        }

        stub_zone = %{
          id: zone_id,
          rooms: [zixu_room],
          room_exits: [],
          characters: %{}
        }

        %Kantele.World{
          zones: [stub_zone],
          rooms: [zixu_room],
          characters: [],
          items: []
        }

      # A3 f1 Diff-stop 测试专用 world：固定 zone id，方便跨 reload 对比
      :diff_stop_v1 ->
        stub_zone_and_room("dz:alpha", "dz:alpha:r1")

      :diff_stop_v3 ->
        # 同 zone "dz:alpha"，但房间换成 r2（模拟房间被移除的场景）
        stub_zone_and_room("dz:alpha", "dz:alpha:r2")

      :diff_stop_v2 ->
        stub_zone_and_room("dz:beta", "dz:beta:r2")
    end
  end

  # 构造固定 zone id 的最小 world（单 room，无角色），供 Diff-stop 跨 reload 对比
  defp stub_zone_and_room(zone_id, room_id) do
    room = %{
      id: room_id,
      zone_id: zone_id,
      item_instances: []
    }

    stub_zone = %{
      id: zone_id,
      rooms: [room],
      room_exits: [],
      characters: %{}
    }

    %Kantele.World{
      zones: [stub_zone],
      rooms: [room],
      characters: [],
      items: []
    }
  end

  def load_help(), do: []

  defp mode() do
    Application.get_env(:ex_venture, :kickoff_stub_loader_mode, :ok)
  end
end
