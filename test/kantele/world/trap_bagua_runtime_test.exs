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
  alias Kantele.World.Trap.Bagua

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
    test "bagua0 往 坎（count=0）", ctx do
      r = room(ctx.world, "shaolin:bagua0")

      assert {:proceed, _event, _exit} = move(r, player(%{}), "坎")

      assert_received %Event{topic: "trap/effect", data: %{effects: effects}}

      assert {:set_temp, "bagua/count", 1} in effects
      assert {:damage, :jing, 50} in effects
      assert {:set_temp, "bagua/坎", 1} in effects
    end

    @tag :world_data
    test "bagua0 往 震（count=2）会昏厥", ctx do
      r = room(ctx.world, "shaolin:bagua0")

      assert {:proceed, _event, _exit} = move(r, player(%{"bagua/count" => 2}), "震")

      assert_received %Event{topic: "trap/effect", data: %{effects: effects}}
      assert {:faint} in effects
    end
  end

  describe "走错：只清零、无惩罚，且仍然放行" do
    @tag :world_data
    test "bagua0 往 坎（count=5，不匹配）", ctx do
      r = room(ctx.world, "shaolin:bagua0")

      assert {:proceed, _event, _exit} = move(r, player(%{"bagua/count" => 5}), "坎")

      assert_received %Event{topic: "trap/effect", data: %{effects: effects}}

      assert {:delete_temp, "bagua/count"} in effects
      refute Enum.any?(effects, &match?({:damage, _, _}, &1))
      refute Enum.any?(effects, &match?({:faint}, &1))
    end
  end

  describe "坤（kun）：清空整棵 bagua 子树" do
    @tag :world_data
    test "bagua0 往 坤", ctx do
      r = room(ctx.world, "shaolin:bagua0")

      assert {:proceed, _event, _exit} = move(r, player(%{"bagua/count" => 3}), "坤")

      assert_received %Event{topic: "trap/effect", data: %{effects: effects}}

      assert effects == [
               {:delete_temp, "bagua/count"},
               {:delete_prefix, "bagua/"}
             ]
    end
  end

  describe "脱困：同一方向连走 14 次掉进僧监" do
    @tag :world_data
    test "bagua0 往 坎 第 14 次被拦下并传送", ctx do
      r = room(ctx.world, "shaolin:bagua0")

      # 前 13 次：正常放行（每次之后清掉事件，避免污染后面的断言）
      for n <- 1..13 do
        temp = %{"bagua/count" => 0, "bagua/坎" => n - 1}
        assert {:proceed, _event, _exit} = move(r, player(temp), "坎"), "第 #{n} 次应放行"
        assert_received %Event{topic: "trap/effect", data: %{effects: e}}
        refute Enum.any?(e, &match?({:force_move, _}, &1)), "第 #{n} 次不该脱困"
      end

      drain_trap_events()

      # 第 14 次：bagua/坎 已经是 13 -> 14 > 13
      temp = %{"bagua/count" => 0, "bagua/坎" => 13}
      assert {:abort, _event, {:trapped, msg}} = move(r, player(temp), "坎")
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
    test "八个房间往 坎 都会推进 count", ctx do
      for r <- ctx.bagua do
        assert Enum.find(r.exits, &(&1.exit_name == "坎")), "#{r.id} 应有 kan 出口"

        assert {:proceed, _event, _exit} = move(r, player(%{}), "坎")

        assert_received %Event{topic: "trap/effect", data: %{effects: effects}}
        assert {:set_temp, "bagua/count", 1} in effects, "#{r.id} 应推进 count"
        assert {:damage, :jing, 50} in effects, "#{r.id} 应受 jing 伤"
      end
    end
  end

  describe "出口名已改回汉字，但拼音仍然能用" do
    @tag :world_data
    test "八个房间的出口名都是汉字（LPC 原样）", ctx do
      for r <- ctx.bagua do
        han = r.exits |> Enum.map(& &1.exit_name) |> Enum.filter(&String.length(&1) == 1)

        # 每个八卦房至少 8 个单字出口
        assert length(han) >= 8,
               "#{r.id} 的出口名应包含八个单字卦名，实际 #{inspect(Enum.map(r.exits, & &1.exit_name))}"
      end
    end

    @tag :world_data
    test "八个卦名的汉字与拼音一一对应，且指令都能解析", ctx do
      r = room(ctx.world, "shaolin:bagua0")
      names = Enum.map(r.exits, & &1.exit_name)

      # 数据侧是汉字
      for han <- ["乾", "兑", "坎", "坤", "巽", "离", "艮", "震"] do
        assert han in names, "bagua0 应有出口 #{han}"
      end

      # 指令侧汉字与拼音都注册了，且指向同一个 MoveCommand 函数
      for {han, pinyin, fn_name} <- [
            {"乾", "qian", :qian}, {"兑", "dui", :dui},
            {"坎", "kan", :kan}, {"坤", "kun", :kun},
            {"巽", "xun", :xun}, {"离", "li", :li},
            {"艮", "gen", :gen}, {"震", "zhen", :zhen}
          ] do
        assert {:ok, p1} = Kantele.Character.Commands.parse(han),
               "#{han} 应当能作为移动指令"

        assert {:ok, p2} = Kantele.Character.Commands.parse(pinyin),
               "#{pinyin} 应当仍能作为移动指令"

        assert p1.function == fn_name
        assert p2.function == fn_name,
               "#{pinyin} 应当和 #{han} 指向同一个函数（实际 #{p2.function}）"
      end
    end

    @tag :world_data
    test "陷阱对汉字与拼音的行为完全一致", _ctx do
      assert Bagua.evaluate(%{}, "坎") == Bagua.evaluate(%{}, "kan")
      assert Bagua.evaluate(%{"bagua/count" => 2}, "震") == Bagua.evaluate(%{"bagua/count" => 2}, "zhen")
      assert Bagua.evaluate(%{"bagua/count" => 3}, "坤") == Bagua.evaluate(%{"bagua/count" => 3}, "kun")
    end

    @tag :world_data
    test "Trap.Bagua 的 han/1 两种写法都返回同一个汉字", _ctx do
      for {pinyin, han} <- [{"qian", "乾"}, {"dui", "兑"}, {"kan", "坎"},
                            {"kun", "坤"}, {"xun", "巽"}, {"li", "离"},
                            {"gen", "艮"}, {"zhen", "震"}] do
        assert Kantele.World.Trap.Bagua.han(pinyin) == han
        assert Kantele.World.Trap.Bagua.han(han) == han,
               "汉字输入也应原样返回 #{han}"
      end
    end
  end

  describe "汉字映射表完整性（这里漏过一个「坎」）" do
    # 补 坎 之前，@han_to_pinyin 只有 7 条，于是「往坎」既不推进 count 也不下发
    # 任何 effects —— 表现为「这一卦踩了跟没踩一样」，不报任何错。
    # 纯逻辑测试当时全绿（它们直接传拼音），所以没能发现。
    @tag :world_data
    test "八个卦名的汉字都能归一到拼音，且归一后行为与拼音一致", _ctx do
      for {han, pinyin} <- [{"乾", "qian"}, {"坤", "kun"}, {"坎", "kan"},
                            {"离", "li"}, {"艮", "gen"}, {"震", "zhen"},
                            {"巽", "xun"}, {"兑", "dui"}] do
        assert Bagua.normalize_dir(han) == pinyin,
               "#{han} 应当归一到 #{pinyin}（实际 #{inspect(Bagua.normalize_dir(han))}）"
      end
    end

    @tag :world_data
    test "汉字方向名在数据里真的存在（漏了映射就会出现「这一卦没反应」）", ctx do
      r = room(ctx.world, "shaolin:bagua0")
      names = Enum.map(r.exits, & &1.exit_name)

      for han <- ["乾", "兑", "坎", "坤", "巽", "离", "艮", "震"] do
        assert han in names, "bagua0 缺少出口 #{han}"
        # 每个卦名都必须在映射表里
        assert Bagua.normalize_dir(han) != han, "#{han} 不在 @han_to_pinyin 里"
      end
    end
  end
end
