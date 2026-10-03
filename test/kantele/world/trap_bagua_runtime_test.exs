defmodule Kantele.World.TrapBaguaRuntimeTest do
  @moduledoc """
  八卦阵陷阱的**运行时**链路（走真实 movement_request）

  前两轮 bug 都是纯逻辑测试全绿、运行时静默失效：

    * 五行迷宫 `room_key` 没剥掉区前缀 -> 所有方向都不触发
    * `force_move` 只改 room_id -> 提示弹了但人没动

  所以这里坚持从「房间 id + 方向」一路断言到「下发了什么 effects」。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Event
  alias Kalevala.Event.Movement
  alias Kalevala.World.Room.Context
  alias Kantele.World.Loader

  @handler Kalevala.World.Room.Callbacks.Kantele.World.Room

  setup_all do
    world = Loader.load()

    Enum.each(world.zones, fn
      %{id: _} = zone -> Kantele.World.ZoneCache.cache(zone)
      _ -> :skip
    end)

    # 只有 bagua0~bagua7 是阵里的八卦房。另外还有一个 shaolin:bagua
    # （d/shaolin/bagua.c，阵心「八卦阵阵眼」），它 include 的是别的头文件、
    # 没有 check_dirs、只有 down/up 两个出口 —— 别把它算进来。
    bagua =
      Enum.filter(world.rooms, fn r ->
        Regex.match?(~r/^shaolin:bagua[0-7]$/, r.id)
      end)

    %{world: world, bagua: bagua}
  end

  defp room(world, id), do: Enum.find(world.rooms, &(&1.id == id))

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

  # 一个用例里连走多次时，**必须**先把邮箱清空 ——
  # 否则 assert_received 会拿到上几步留下的旧 trap/effect，
  # 于是「第 14 次才脱困」这种断言会读到第 1 次的事件而误判。
  defp drain_trap_events do
    receive do
      %Event{topic: "trap/effect"} -> drain_trap_events()
    after
      0 -> :ok
    end
  end

  describe "八个房间都带 check_dirs 条件" do
    @tag :world_data
    test "bagua0~bagua7 的 valid_leave 里都有它", ctx do
      assert length(ctx.bagua) == 8

      for r <- ctx.bagua do
        conds = r.exit_vetoes |> Enum.map(& &1.condition) |> Enum.reject(&is_nil/1)
        assert Enum.any?(conds, &String.contains?(&1, "check_dirs(")),
               "#{r.id} 应有 check_dirs 条件"
      end
    end
  end

  describe "走对：计数 +1 并吃伤害，仍放行" do
    @tag :world_data
    test "bagua0 往 kan（count=0）", ctx do
      r = room(ctx.world, "shaolin:bagua0")

      assert {:proceed, _event, _exit} = move(r, player(%{}), "kan")

      assert_received %Event{topic: "trap/effect", data: %{effects: effects}}

      assert {:set_temp, "bagua/count", 1} in effects
      assert {:damage, :jing, 50} in effects
      assert {:set_temp, "bagua/坎", 1} in effects
    end

    @tag :world_data
    test "bagua0 往 zhen（count=2）会昏厥", ctx do
      r = room(ctx.world, "shaolin:bagua0")

      assert {:proceed, _event, _exit} = move(r, player(%{"bagua/count" => 2}), "zhen")

      assert_received %Event{topic: "trap/effect", data: %{effects: effects}}
      assert {:faint} in effects
    end
  end

  describe "走错：只清零、无惩罚，且仍然放行" do
    @tag :world_data
    test "bagua0 往 kan（count=5，不匹配）", ctx do
      r = room(ctx.world, "shaolin:bagua0")

      assert {:proceed, _event, _exit} = move(r, player(%{"bagua/count" => 5}), "kan")

      assert_received %Event{topic: "trap/effect", data: %{effects: effects}}

      assert {:delete_temp, "bagua/count"} in effects
      refute Enum.any?(effects, &match?({:damage, _, _}, &1))
      refute Enum.any?(effects, &match?({:faint}, &1))
    end
  end

  describe "坤（kun）：清空整棵 bagua 子树" do
    @tag :world_data
    test "bagua0 往 kun", ctx do
      r = room(ctx.world, "shaolin:bagua0")

      assert {:proceed, _event, _exit} = move(r, player(%{"bagua/count" => 3}), "kun")

      assert_received %Event{topic: "trap/effect", data: %{effects: effects}}

      assert effects == [
               {:delete_temp, "bagua/count"},
               {:delete_prefix, "bagua/"}
             ]
    end
  end

  describe "脱困：同一方向连走 14 次掉进僧监" do
    @tag :world_data
    test "bagua0 往 kan 第 14 次被拦下并传送", ctx do
      r = room(ctx.world, "shaolin:bagua0")

      # 前 13 次：正常放行（每次之后清掉事件，避免污染后面的断言）
      for n <- 1..13 do
        temp = %{"bagua/count" => 0, "bagua/坎" => n - 1}
        assert {:proceed, _event, _exit} = move(r, player(temp), "kan"), "第 #{n} 次应放行"
        assert_received %Event{topic: "trap/effect", data: %{effects: e}}
        refute Enum.any?(e, &match?({:force_move, _}, &1)), "第 #{n} 次不该脱困"
      end

      drain_trap_events()

      # 第 14 次：bagua/坎 已经是 13 -> 14 > 13
      temp = %{"bagua/count" => 0, "bagua/坎" => 13}
      assert {:abort, _event, {:trapped, msg}} = move(r, player(temp), "kan")
      assert msg == "你踩动了机关，掉进僧监。"

      assert_received %Event{topic: "trap/effect", data: %{effects: effects}}
      assert {:delete_prefix, "bagua/"} in effects
      assert {:force_move, "shaolin:jianyu"} in effects
    end

    @tag :world_data
    test "僧监这个目标房间真实存在", ctx do
      assert Enum.find(ctx.world.rooms, &(&1.id == "shaolin:jianyu")),
             "LPC 里是 move(__DIR__\"jianyu\")，得确认 shaolin:jianyu 在世界里"
    end
  end

  describe "非八卦方向不触发" do
    @tag :world_data
    test "bagua1 往 down / up 原样放行且不发事件", ctx do
      r = room(ctx.world, "shaolin:bagua1")

      assert {:proceed, _event, _exit} = move(r, player(%{"bagua/count" => 5}), "down")
      refute_received %Event{topic: "trap/effect"}

      assert {:proceed, _event, _exit} = move(r, player(%{"bagua/count" => 5}), "up")
      refute_received %Event{topic: "trap/effect"}
    end

    @tag :world_data
    test "五行迷宫房间不会被当成八卦阵", ctx do
      r = room(ctx.world, "shaolin:wuxing0")

      # wuxing0 往西是五行机关，不是八卦；不该下发 damage/faint/wound
      assert {:abort, _event, {:trapped, _msg}} = move(r, player(%{}), "west")

      assert_received %Event{topic: "trap/effect", data: %{effects: effects}}
      refute Enum.any?(effects, &match?({:damage, _, _}, &1))
      refute Enum.any?(effects, &match?({:wound, _, _}, &1))
      refute Enum.any?(effects, &match?({:faint}, &1))
    end
  end

  describe "阵心 shaolin:bagua 不参与迷宫" do
    @tag :world_data
    test "它没有 check_dirs，往 down/up 不触发任何效果", ctx do
      r = room(ctx.world, "shaolin:bagua")
      assert r, "阵心房间应存在"

      assert Enum.all?(r.exit_vetoes, &is_nil(&1.condition)),
             "阵心的 valid_leave 不该有条件（LPC bagua.c 没有 valid_leave）"

      for dir <- ["down", "up"] do
        assert {:proceed, _event, _exit} = move(r, player(%{"bagua/count" => 3}), dir)
        refute_received %Event{topic: "trap/effect"}
      end
    end
  end

  describe "每个房间都能触发（规则是共享头文件，八房一致）" do
    @tag :world_data
    test "八个房间往 kan 都会推进 count", ctx do
      for r <- ctx.bagua do
        assert Enum.find(r.exits, &(&1.exit_name == "kan")), "#{r.id} 应有 kan 出口"

        assert {:proceed, _event, _exit} = move(r, player(%{}), "kan")

        assert_received %Event{topic: "trap/effect", data: %{effects: effects}}
        assert {:set_temp, "bagua/count", 1} in effects, "#{r.id} 应推进 count"
        assert {:damage, :jing, 50} in effects, "#{r.id} 应受 jing 伤"
      end
    end
  end
end