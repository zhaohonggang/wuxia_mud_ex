defmodule Kantele.Character.ArenaCommandTest do
  @moduledoc """
  `lclose` / `lopen` 的**执行**测试（跑真实的命令处理路径）

  ## 为什么必须是「执行」而不是「断言数据」

  这条命令的广播最初写成 `Kantele.Communication.broadcast/2` —— 那个函数
  **不存在**（该模块只有 `initial_channels/0`、`system_character/0`、
  `announce/2`），于是玩家一执行 `lclose here` 就把**角色进程**炸掉：

      ** (UndefinedFunctionError) function Kantele.Communication.broadcast/2
         is undefined or private
        lib/kantele/character/commands/arena_command.ex:113

  而当时的测试只断言「状态有没有写进去」，命令本身**一次都没跑过**。
  这已经是连续第 5 次「引用了没核实过的函数」：
  FeatureDamage、Kantele.Feature.Damage 的模块名、返回值解包、
  RoomChannel 的 announce、到这里的 broadcast。

  所以这组测试**真的调用 `run/2`**，并断言频道进程在命令之后还活着。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kantele.Character.ArenaCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.RoomChannel
  alias Kantele.World.Arena

  @room_id "city:wudao1"
  @channel "rooms:#{@room_id}"

  setup do
    channel = "rooms:arena-cmd-test-" <> Integer.to_string(System.unique_integer([:positive]))

    # 真注册一个房间频道：广播会真的走 GenServer.call 到它
    Kantele.Communication.register(channel, RoomChannel, room_id: @room_id)
    [{^channel, pid}] = :ets.lookup(Kantele.Communication.Channels, channel)

    on_exit(fn ->
      if Process.alive?(pid) do
        DynamicSupervisor.terminate_child(Kantele.Communication.Channels, pid)
      end

      Arena.open("city:leitai")
    end)

    Arena.open("city:leitai")

    %{channel: channel, channel_pid: pid}
  end

  defp conn(wiz_level, room_id \\ @room_id) do
    %Conn{
      character: %Character{
        id: "arena-cmd",
        name: "grant",
        pid: self(),
        room_id: room_id,
        attributes: %{"wiz_level" => wiz_level},
        inventory: [],
        meta: %PlayerMeta{
          # 命令最后会 prompt(CommandView, "prompt", ...)，那个视图要读
          # vitals/stats（渲染状态栏）。PlayerMeta 这两个字段默认是 nil，
          # 不给就会在 `nil.qi/0` 上炸 —— 夹具问题，不是被测代码问题。
          vitals: %Kantele.Character.Vitals{
            base_qi: 150, qi: 150, max_qi: 150,
            base_jing: 120, jing: 120, max_jing: 120,
            neili: 100, max_neili: 100
          },
          stats: %Kantele.Character.Stats{},
          combat: Kantele.Character.Combat.new(),
          temp: %{},
          damage: %{},
          env: %{}
        }
      }
    }
  end

  describe "lclose here（管理员）" do
    test "状态被写成关闭，且角色进程不崩" do
      assert Arena.close_by("city:leitai") == nil

      # 真的跑一遍命令处理路径
      ArenaCommand.run(conn(3), %{"arg" => "here"})

      assert Arena.close_by("city:leitai").by == "grant"
    end

    test "广播不会打死房间频道进程（这正是之前崩的地方）", ctx do
      ArenaCommand.run(conn(3), %{"arg" => "here"})

      assert Process.alive?(self()), "命令处理进程还活着"
      assert Process.alive?(ctx.channel_pid), "房间频道进程被广播打死了"
    end

    test "广播真的发出去了（频道进程存活即可 —— 它是同步处理 publish_request 的）" do
      # 真注册频道 + 真调用命令：若 broadcast/2 那种不存在的问题重现，
      # 这里会直接抛，而不会等到线上
      ArenaCommand.run(conn(3), %{"arg" => "here"})

      assert Process.alive?(self())
    end
  end

  describe "lopen here（管理员）" do
    test "状态被清回开放" do
      Arena.close("city:leitai", %{name: "grant"})
      assert Arena.close_by("city:leitai") != nil

      ArenaCommand.lopen(conn(3), %{"arg" => "here"})

      assert Arena.close_by("city:leitai") == nil
    end
  end

  describe "权限与参数校验（不崩、只回话）" do
    test "非管理员执行 lclose 不会写状态" do
      ArenaCommand.run(conn(0), %{"arg" => "here"})

      assert Arena.close_by("city:leitai") == nil
    end

    test "非管理员执行 lclose 不会崩" do
      # 之前 broadcast/2 的问题在这里也会崩（无条件走到 announce），
      # 所以这条也守着
      assert Process.alive?(self())
      ArenaCommand.run(conn(1), %{"arg" => "here"})
      assert Process.alive?(self())
    end

    test "不带 here 时不写状态（LPC 会回提示）" do
      ArenaCommand.run(conn(3), %{})

      assert Arena.close_by("city:leitai") == nil
    end

    test "已关闭时再 lclose 不会覆盖成自己（LPC: 「已经被…关闭用于比武了」）" do
      Arena.close("city:leitai", %{name: "someone-else"})

      ArenaCommand.run(conn(3), %{"arg" => "here"})

      assert Arena.close_by("city:leitai").by == "someone-else"
    end

    test "未关闭时 lopen 不会崩" do
      ArenaCommand.lopen(conn(3), %{"arg" => "here"})
      assert Process.alive?(self())
    end
  end

  describe "bare 形态（不带 here，走 run_bare / lopen_bare）" do
    test "run_bare 不崩且不写状态" do
      ArenaCommand.run_bare(conn(3), %{})
      assert Arena.close_by("city:leitai") == nil
      assert Process.alive?(self())
    end

    test "lopen_bare 不崩" do
      ArenaCommand.lopen_bare(conn(3), %{})
      assert Process.alive?(self())
    end
  end
end