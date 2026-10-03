defmodule Kantele.World.TrapWuxingRuntimeTest do
  @moduledoc """
  五行迷宫陷阱的**运行时**链路（走真实 movement_request）

  刻意不只测纯函数（那是 trap_wuxing_test.exs 的事），而是复现这条链路：

      房间进程 check_traps/3 纯算-> dispatch_trap_effects 发 "trap/effect"
      -> 角色进程 TrapEvent 应用副作用 -> 落盘 -> 渲染正文

  这条链路以前**根本不存在**，所以要钉住三件事：
    1. 房间侧真的判定了（不是被 enforceable? 挡掉）
    2. 副作用真的下发到角色进程
    3. abort 的 reason 里带上了正文，玩家能看到「掉进僧监」
  """
  use ExUnit.Case, async: false

  alias Kalevala.Event
  alias Kalevala.Event.Movement
  alias Kalevala.World.Room.Context
  alias Kantele.World.Loader

  @handler Kalevala.World.Room.Callbacks.Kantele.World.Room

  @room_id "shaolin:wuxing0"

  setup_all do
    world = Loader.load()

    Enum.each(world.zones, fn
      %{id: _} = zone -> Kantele.World.ZoneCache.cache(zone)
      _ -> :skip
    end)

    room = Enum.find(world.rooms, &(&1.id == @room_id))

    %{room: room, world: world}
  end

  defp move(room, player, dir) do
    exit = Enum.find(room.exits, &(&1.exit_name == dir))
    assert exit, "#{room.id} 没有方向 #{dir}"

    event = %Event{
      topic: Movement.Request,
      from_pid: self(),
      data: %Movement.Request{character: player, exit_name: dir}
    }

    context = %Context{
      data: room,
      characters: [],
      item_instances: [],
      assigns: %{},
      events: [],
      output: []
    }

    @handler.movement_request(room, context, event, exit)
  end

  defp player(temp) do
    %{pid: self(), name: "测试玩家", meta: %{temp: temp}}
  end

  describe "房间侧判定" do
    @tag :world_data
    test "wuxing0 带着 check_out 条件，陷阱路径能识别它", ctx do
      conditions =
        ctx.room.exit_vetoes
        |> Enum.map(& &1.condition)
        |> Enum.reject(&is_nil/1)

      assert Enum.any?(conditions, &String.contains?(&1, "check_out(")),
             "wuxing0 的 valid_leave 里应有 check_out(me)"
    end

    @tag :world_data
    test "往西 -> 拦下并掉进僧监（这条在 UCL 里是没有 condition 的条目）", ctx do
      assert {:abort, _event, {:trapped, msg}} = move(ctx.room, player(%{}), "west")
      assert msg == "你掉进机关，落入僧监。"
    end

    @tag :world_data
    test "往北 -> 计数 +1，正常放行", ctx do
      assert {:proceed, _event, _exit} = move(ctx.room, player(%{}), "north")
    end

    @tag :world_data
    test "往东/南 -> 不触发陷阱", ctx do
      assert {:proceed, _event, _exit} = move(ctx.room, player(%{}), "east")
      assert {:proceed, _event, _exit} = move(ctx.room, player(%{}), "south")
    end

    @tag :world_data
    test "往下（down，不在 LPC 的 dirs 里）-> 不触发", ctx do
      assert {:proceed, _event, _exit} = move(ctx.room, player(%{}), "down")
    end
  end

  describe "五行凑齐时从暗道脱困" do
    @tag :world_data
    test "金木火土=2、水=1 -> 往北凑成 2，脱困", ctx do
      temp = %{
        "wuxing/金" => 2,
        "wuxing/木" => 2,
        "wuxing/水" => 1,
        "wuxing/火" => 2,
        "wuxing/土" => 2
      }

      assert {:abort, _event, {:trapped, msg}} = move(ctx.room, player(temp), "north")
      assert msg == "你顺利地走出了五行迷宫。"
    end
  end

  describe "副作用真的下发给角色进程" do
    @tag :world_data
    test "往西会收到 trap/effect 事件，且含删除前缀 + 强制传送", ctx do
      move(ctx.room, player(%{"wuxing/金" => 9}), "west")

      assert_received %Event{topic: "trap/effect", data: %{effects: effects}}

      assert {:delete_prefix, "wuxing/"} in effects
      assert {:force_move, "shaolin:jianyu1"} in effects
    end

    @tag :world_data
    test "往北（未凑齐）也会下发 set_temp", ctx do
      move(ctx.room, player(%{"wuxing/水" => 1}), "north")

      assert_received %Event{topic: "trap/effect", data: %{effects: effects}}
      assert effects == [{:set_temp, "wuxing/水", 2}]
    end

    @tag :world_data
    test "往东不触发时**不发**事件（不能凭空改玩家状态）", ctx do
      move(ctx.room, player(%{"wuxing/金" => 5}), "east")

      refute_received %Event{topic: "trap/effect"}
    end
  end

  describe "MoveView 渲染陷阱正文" do
    test "直接渲染 reason 里的陷阱文案" do
      assert Kantele.Character.MoveView.render(
               "fail",
               %{reason: {:trapped, "你掉进机关，落入僧监。"}}
             ) == "你掉进机关，落入僧监。"
    end
  end

  describe "非五行房间不受影响" do
    @tag :world_data
    test "普通房间不会收到 trap/effect", ctx do
      other = Enum.find(ctx.world.rooms, &(&1.id == "shaolin:zhonglou6"))
      assert other

      exit = Enum.find(other.exits, &(&1.exit_name == "up")) || hd(other.exits)

      event = %Event{
        topic: Movement.Request,
        from_pid: self(),
        data: %Movement.Request{character: player(%{}), exit_name: exit.exit_name}
      }

      context = %Context{
        data: other,
        characters: [],
        item_instances: [],
        assigns: %{},
        events: [],
        output: []
      }

      @handler.movement_request(other, context, event, exit)

      refute_received %Event{topic: "trap/effect"}
    end
  end

  describe "按房间取规则（room_key 必须真的剥掉区前缀）" do
    @tag :world_data
    test "wuxing2 的机关是 north 而不是 west", ctx do
      room = Enum.find(ctx.world.rooms, &(&1.id == "shaolin:wuxing2"))
      assert room

      # wuxing2: 往 north 掉机关
      assert {:abort, _event, {:trapped, msg}} = move(room, player(%{}), "north")
      assert msg == "你掉进机关，落入僧监。"

      # wuxing2: 往 west 是普通转向（wuxing0 才是往 west 掉机关）
      assert {:proceed, _event, _exit} = move(room, player(%{}), "west")
    end

    @tag :world_data
    test "wuxing1 往 south 累加火（不是水）", ctx do
      room = Enum.find(ctx.world.rooms, &(&1.id == "shaolin:wuxing1"))
      assert room

      move(room, player(%{}), "south")

      assert_received %Event{topic: "trap/effect", data: %{effects: effects}}
      assert effects == [{:set_temp, "wuxing/火", 1}]
    end

    @tag :world_data
    test "五个房间的递增方向与元素全部对得上 LPC", ctx do
      for {id, dir, element} <- [
            {"shaolin:wuxing0", "north", "水"},
            {"shaolin:wuxing1", "south", "火"},
            {"shaolin:wuxing2", "east", "木"},
            {"shaolin:wuxing3", "north", "土"},
            {"shaolin:wuxing4", "west", "金"}
          ] do
        room = Enum.find(ctx.world.rooms, &(&1.id == id))

        assert Enum.find(room.exits, &(&1.exit_name == dir)),
               "#{id} 应有 #{dir} 出口（否则递增逻辑走不到）"

        move(room, player(%{}), dir)

        assert_received %Event{topic: "trap/effect", data: %{effects: effects}}
        assert effects == [{:set_temp, "wuxing/#{element}", 1}],
               "#{id} 往 #{dir} 应累加 #{element}"
      end
    end
  end
end
