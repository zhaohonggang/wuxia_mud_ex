defmodule Kantele.Communication.AnnounceE2ETest do
  @moduledoc """
  系统广播的**端到端**验证：真的注册一个 RoomChannel 进程再发公告

  ## 为什么必须这么测

  `Kantele.Communication.announce/2` 内部是 `try/rescue + catch :exit` 包着的，
  任何异常都只会变成一条 `Logger.warn` 和 `{:error, :announce_failed}`。所以：

    * 断言返回值**测不出来** —— 崩与不崩返回的是同样的东西
    * 纯函数单测也**测不出来** —— `publish_request/4` 只是被调用，
      没有真实 GenServer 被它打死

  真正会出事的是「频道进程被打死」：它会**级联** ——
  紧接着玩家的 `unsubscribe("rooms:...")` 因为频道已不存在而
  `** (EXIT) no process`，把玩家进程一起带走。

  所以核心断言是 **Process.alive?/1**：发完公告之后频道进程必须还活着，
  而且还能再发一次。

  ## 夹具上的两个坑（都踩过）

    * `Cache.register` 遇到同名频道会返回 `{:error, :already_registered}`，
      而 `:ets.lookup` 仍返回**上一个测试**留下的死 pid -> 后续断言全莫名其妙地失败。
      频道表是 `:protected`（只有 owner 能写），测试进程 **删不掉** ETS 记录。
      所以这里给每个测试生成**唯一频道名**，不复用。
    * `register/3` 成功才返回 `:ok`，必须断言，否则「注册失败但继续往下跑」
      会把夹具问题伪装成被测代码的问题。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Character
  alias Kantele.Character.PlayerMeta
  alias Kantele.Communication
  alias Kantele.Feature.Damage
  alias Kantele.RoomChannel

  setup do
    room_id = "shaolin:test-announce-e2e-#{System.unique_integer([:positive])}"
    channel = "rooms:#{room_id}"

    assert Communication.register(channel, RoomChannel, room_id: room_id) == :ok,
           "注册房间频道应当成功"

    [{^channel, pid}] = :ets.lookup(Communication.Channels, channel)
    assert Process.alive?(pid), "注册后频道进程应当存活"

    # 注意：不能用 GenServer.stop/1。频道是以 :permanent 挂在
    # Kantele.Communication.Channels 这个 DynamicSupervisor 下的，
    # 正常 stop 会触发**重启**，连续几次之后 supervisor 会因重启强度超限而死掉，
    # 后面每个测试的 register 都会报
    #   ** (EXIT) no process ... Kantele.Communication.Channels
    # —— 变成「夹具把被测代码搞崩」的假象。terminate_child 才是正确姿势。
    on_exit(fn ->
      if Process.alive?(pid) do
        DynamicSupervisor.terminate_child(Communication.Channels, pid)
      end
    end)

    %{room_id: room_id, channel: channel, channel_pid: pid}
  end

  defp alive?(channel) do
    case :ets.lookup(Communication.Channels, channel) do
      [{^channel, pid}] -> Process.alive?(pid)
      _ -> false
    end
  end

  defp character(room_id) do
    %Character{
      id: "player-announce-e2e",
      name: "grant",
      pid: self(),
      room_id: room_id,
      inventory: [],
      meta: %PlayerMeta{
        vitals: %Kantele.Character.Vitals{
          base_qi: 150, qi: 150, max_qi: 150,
          base_jing: 120, jing: 120, max_jing: 120,
          neili: 100, max_neili: 100
        },
        stats: %Kantele.Character.Stats{con: 20},
        combat: Kantele.Character.Combat.new(),
        temp: %{},
        damage: %{},
        env: %{},
        followers: []
      }
    }
  end

  describe "系统广播不会打死房间频道进程" do
    test "announce 之后频道进程仍存活", ctx do
      Communication.announce(ctx.channel, "测试公告")

      assert alive?(ctx.channel),
             "announce 之后房间频道进程死了 —— 玩家随后 unsubscribe 会级联崩溃"
    end

    test "连发多次都不会死（第一次可能侥幸，第二次才是真活着）", ctx do
      for i <- 1..5 do
        Communication.announce(ctx.channel, "第 #{i} 条公告")
        assert alive?(ctx.channel), "第 #{i} 次公告后频道死了"
      end
    end

    test "频道消失后 announce 只记日志、不搞崩调用方", ctx do
      ref = Process.monitor(ctx.channel_pid)
      DynamicSupervisor.terminate_child(Communication.Channels, ctx.channel_pid)
      assert_receive {:DOWN, ^ref, :process, _, _}
      refute Process.alive?(ctx.channel_pid)

      # ETS 里还留着死 pid（模拟频道异常消失）
      assert {:error, :announce_failed} = Communication.announce(ctx.channel, "无人接收")

      # 调用方（这里就是测试进程）还活着 —— 这正是之前级联崩溃的形态
      assert Process.alive?(self())
    end
  end

  describe "Feature.Damage 的昏厥公告走真实频道" do
    test "unconcious 之后频道进程仍存活", ctx do
      # 线上崩的就是这条链：unconcious -> handle_unconcious
      #   -> announce -> Communication.announce -> publish_request
      assert {:ok, c} = Damage.unconcious(character(ctx.room_id))

      assert c.meta.vitals.qi == 0
      assert alive?(ctx.channel), "昏厥广播把房间频道打死了"
    end

    test "昏厥后还能再发公告（频道确实没被打死）", ctx do
      assert {:ok, _} = Damage.unconcious(character(ctx.room_id))
      assert alive?(ctx.channel)

      Communication.announce(ctx.channel, "之后的公告")
      assert alive?(ctx.channel)
    end

    test "受伤 / 创伤不会打死频道（不走 announce，但也不该崩）", ctx do
      assert {:ok, c1} = Damage.receive_damage(character(ctx.room_id), :jing, 50)
      assert c1.meta.vitals.jing == 70
      assert alive?(ctx.channel)

      assert {:ok, _c2} = Damage.receive_wound(character(ctx.room_id), :qi, 50)
      assert alive?(ctx.channel)
    end
  end

  describe "玩家自己发消息的准入判定没被放宽" do
    test "不在本房间的玩家发布会被拒（且频道不死）", ctx do
      event = %Kalevala.Event{
        acting_character: nil,
        from_pid: self(),
        topic: Kalevala.Event.Message,
        data: %Kalevala.Event.Message{
          channel_name: ctx.channel,
          character: %Character{room_id: "shaolin:elsewhere"},
          id: Kalevala.Event.Message.generate_id(),
          text: "hi",
          type: "speech"
        }
      }

      assert {:error, :not_in_room} =
               Communication.publish(ctx.channel, event,
                 character: %Character{room_id: "shaolin:elsewhere"}
               )

      assert alive?(ctx.channel)
    end

    test "在本房间的玩家发布放行", ctx do
      event = %Kalevala.Event{
        acting_character: nil,
        from_pid: self(),
        topic: Kalevala.Event.Message,
        data: %Kalevala.Event.Message{
          channel_name: ctx.channel,
          character: %Character{room_id: ctx.room_id},
          id: Kalevala.Event.Message.generate_id(),
          text: "hi",
          type: "speech"
        }
      }

      assert Communication.publish(ctx.channel, event, character: %Character{room_id: ctx.room_id}) == :ok
      assert alive?(ctx.channel)
    end
  end
end