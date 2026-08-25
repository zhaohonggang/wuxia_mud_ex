defmodule Kantele.World.KickoffTest do
  use ExUnit.Case, async: false

  alias Kantele.Character.ChannelView
  alias Kantele.Character.ReloadView
  alias Kantele.Character.WorldStatusView
  alias Kantele.World.Kickoff
  alias Kantele.World.KickoffTest.StubLoader

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
        # item 为 nil 时 cache_item 取 item.id 会抛错，命中编排层兜底
        %Kantele.World{items: [nil]}

      :ok ->
        %Kantele.World{}
    end
  end

  def load_help(), do: []

  defp mode() do
    Application.get_env(:ex_venture, :kickoff_stub_loader_mode, :ok)
  end
end
