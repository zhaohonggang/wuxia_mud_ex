defmodule Kantele.World.GuardedExitRuntimeTest do
  @moduledoc """
  `behavior = "guarded_exit"` 的运行时行为（todo 文档 三、B 节）

  背景：这套机制**早就接好了** —— `room.ex` 的 `check_guarders/4` 一直在调用
  `Kantele.Npc.Guarder.permit_pass/1`，`movement_request` 也确实调了它。
  16 个房间全部失效的真正原因是数据侧三处缺失：

    1. `loader` 根本不读 `behavior` / `behavior_config`（Room 结构里没这两个字段）
    2. 守卫 NPC 没有 `meta.guarder.family` -> `check_guarders` 的过滤条件
       `Map.get(c.meta, :guarder) && ...` 直接把它们全滤掉
    3. `behavior_config.direction` 不可信：转换器统一记成单个 direction，
       但原 LPC 的 valid_leave 有「只守某几个方向」和「除某方向外全守」两种

  本次先做 3 个数据齐备的房间（小步验证机制真的能拦住人）：
    baituo:damen   守 north              （LPC: present && dir == "north"）
    huashan:buwei1 除 south 外全守       （LPC: dir == "south" || !present -> return）
    huashan:square 守 northeast/east/north（LPC: 三个方向并列）
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

    rooms =
      Map.new(
        [
          {"baituo:damen", "men wei"},
          {"baituo:ximen", "men wei"},
          {"huashan:buwei1", "lu dayou"},
          {"huashan:laojun", "lao denuo"},
          {"huashan:square", "gao genming"}
        ],
        fn {rid, _guard} ->
          room = Enum.find(world.rooms, &(&1.id == rid))
          occupants = Enum.filter(world.characters, &(&1.room_id == rid))
          {rid, %{room: room, occupants: occupants}}
        end
      )

    %{world: world, rooms: rooms}
  end

  defp context_with(room, characters) do
    %Context{
      data: room,
      characters: characters,
      item_instances: [],
      assigns: %{},
      events: [],
      output: []
    }
  end

  defp room_exit(room, dir) do
    Enum.find(room.exits, &(&1.exit_name == dir))
  end

  defp mover(family_name) do
    family = if family_name, do: %{name: family_name}, else: nil
    %{pid: self(), name: "测试玩家", meta: %{family: family}}
  end

  # room 直接就是 %Room{}（测试里从 ctx.rooms[id].room 取），不是 %{room: ...} 包装
  defp move(room, characters, player, dir) do
    exit = room_exit(room, dir)

    assert exit, "#{room.id} 没有方向 #{dir}"

    event = %Event{
      topic: Movement.Request,
      from_pid: self(),
      data: %Movement.Request{character: player, exit_name: dir}
    }

    @handler.movement_request(room, context_with(room, characters), event, exit)
  end

  describe "loader 现在读得到 behavior / behavior_config" do
    @tag :world_data
    test "三个房间的 behavior 与方向规则都进了 Room 结构", ctx do
      for {rid, expected} <- [
            {"baituo:damen", {:guard_directions, ["north"]}},
            {"baituo:ximen", {:guard_directions, ["east"]}},
            {"huashan:buwei1", {:exempt_directions, ["south"]}},
            {"huashan:laojun", {:guard_directions, ["southup"]}},
            {"huashan:square", {:guard_directions, ["northeast", "east", "north"]}}
          ] do
        room = ctx.rooms[rid].room
        assert room.behavior == "guarded_exit", "#{rid} 的 behavior 没读进来"
        assert {key, dirs} = expected
        assert Map.get(room.behavior_config, key) == dirs, "#{rid} 的 #{key} 不对"
      end
    end

    @tag :world_data
    test "守卫 NPC 带上了 create_family 的门派", ctx do
      for {rid, family} <- [
            {"baituo:damen", "欧阳世家"},
            {"baituo:ximen", "欧阳世家"},
            {"huashan:buwei1", "华山派"},
            {"huashan:laojun", "华山派"},
            {"huashan:square", "华山派"}
          ] do
        guarders =
          ctx.rooms[rid].occupants
          |> Enum.filter(&Map.get(&1.meta, :guarder))

        assert guarders != [], "#{rid} 里没有带 guarder 的 NPC"
        assert Enum.all?(guarders, &(Map.get(&1.meta.guarder, :family) == family))
      end
    end
  end

  describe "baituo:damen —— 只守 north" do
    @tag :world_data
    test "无门派的玩家往北被门卫拦下（默认提示语）", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["baituo:damen"]
      assert {:abort, _event, {:guarder_denied, msg}} = move(room, occupants, mover(nil), "north")
      assert msg =~ "欧阳世家"
    end

    @tag :world_data
    test "往南（不设卡的方向）放行", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["baituo:damen"]
      assert {:proceed, _event, _exit} = move(room, occupants, mover(nil), "southdown")
    end

    @tag :world_data
    test "房里没有门卫时放行（LPC: !objectp(guarder) -> return 1）", ctx do
      %{room: room} = ctx.rooms["baituo:damen"]
      assert {:proceed, _event, _exit} = move(room, [], mover(nil), "north")
    end

    @tag :world_data
    test "同门弟子放行", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["baituo:damen"]
      assert {:proceed, _event, _exit} = move(room, occupants, mover("欧阳世家"), "north")
    end
  end

  describe "huashan:buwei1 —— 除 south 外全守" do
    @tag :world_data
    test "往南放行（豁免方向）", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["huashan:buwei1"]
      assert {:proceed, _event, _exit} = move(room, occupants, mover(nil), "south")
    end

    @tag :world_data
    test "往其他方向被陆大有拦下", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["huashan:buwei1"]

      denied =
        Enum.reject(room.exits, &(&1.exit_name == "south"))
        |> Enum.map(fn e ->
          match?({:abort, _, {:guarder_denied, _}}, move(room, occupants, mover(nil), e.exit_name))
        end)

      assert denied != [], "buwei1 至少应有一个方向被拦"
      assert Enum.all?(denied), "buwei1 除 south 外的方向都应被拦"
    end

    @tag :world_data
    test "华山派弟子放行", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["huashan:buwei1"]
      assert {:proceed, _event, _exit} = move(room, occupants, mover("华山派"), "north")
    end
  end

  describe "huashan:square —— 守 northeast/east/north" do
    @tag :world_data
    test "三个方向被高根明拦下", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["huashan:square"]

      for dir <- ["northeast", "east", "north"] do
        assert {:abort, _event, {:guarder_denied, msg}} = move(room, occupants, mover(nil), dir)
      end
    end

    @tag :world_data
    test "其余方向放行", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["huashan:square"]

      for exit <- room.exits, exit.exit_name not in ["northeast", "east", "north"] do
        assert {:proceed, _event, _exit} = move(room, occupants, mover(nil), exit.exit_name),
               "#{exit.exit_name} 不该被拦"
      end
    end
  end

  describe "背着他派的人上门" do
    @tag :world_data
    test "携带物里有别派的人 -> 拦下", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["huashan:square"]

      player = %{
        pid: self(),
        name: "测试玩家",
        meta: %{family: %{name: "华山派"}, carrying: [%{family: %{name: "日月神教"}}]}
      }

      assert {:abort, _event, {:guarder_denied, msg}} = move(room, occupants, player, "north")
    end

    @tag :world_data
    test "meta 里没有 carrying 字段时不崩（PlayerMeta 根本没这个字段）", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["huashan:square"]

      # PlayerMeta 是结构体且没有 :carrying；之前这里直接 meta.carrying 会 KeyError
      player = %{pid: self(), name: "测试玩家", meta: %Kantele.Character.PlayerMeta{}}
      assert {:abort, _event, {:guarder_denied, msg}} = move(room, occupants, player, "north")
    end
  end

  describe "baituo:ximen —— 只守 east（往庄内）" do
    @tag :world_data
    test "往东被门卫拦下", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["baituo:ximen"]
      assert {:abort, _event, {:guarder_denied, msg}} = move(room, occupants, mover(nil), "east")
      assert msg =~ "欧阳世家"
    end

    @tag :world_data
    test "往西（毒蛇出没方向，不设卡）放行", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["baituo:ximen"]
      assert {:proceed, _event, _exit} = move(room, occupants, mover(nil), "west")
    end

    @tag :world_data
    test "同门弟子往东放行", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["baituo:ximen"]
      assert {:proceed, _event, _exit} = move(room, occupants, mover("欧阳世家"), "east")
    end
  end

  describe "huashan:laojun —— 只守 southup" do
    @tag :world_data
    test "往 southup 被劳德诺拦下，且 family 是华山派而非华山剑宗", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["huashan:laojun"]

      guarders = Enum.filter(occupants, &Map.get(&1.meta, :guarder))
      assert guarders != []

      # LPC lao-denuo.c / kungfu/class/huashan/lao.c 都是
      # create_family("华山派", 14, "弟子")。数据里原本误写成「华山剑宗」，
      # 那样真华山派弟子会被自己的二师兄拦下。
      assert Enum.all?(guarders, &(Map.get(&1.meta.guarder, :family) == "华山派"))

      assert {:abort, _event, {:guarder_denied, msg}} =
               move(room, occupants, mover(nil), "southup")

      assert msg =~ "华山派"
    end

    @tag :world_data
    test "其他方向放行", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["huashan:laojun"]

      for exit <- room.exits, exit.exit_name != "southup" do
        assert {:proceed, _event, _exit} = move(room, occupants, mover(nil), exit.exit_name),
               "#{exit.exit_name} 不该被拦"
      end
    end

    @tag :world_data
    test "华山派弟子往 southup 放行", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["huashan:laojun"]
      assert {:proceed, _event, _exit} = move(room, occupants, mover("华山派"), "southup")
    end
  end

  describe "拦截正文能传到玩家眼前" do
    @tag :world_data
    test "abort 的 reason 里带上了 LPC 拒绝语", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["huashan:square"]

      assert {:abort, _event, {:guarder_denied, msg}} = move(room, occupants, mover(nil), "north")

      # LPC feature/guarder.c 的默认文案（守卫没有自定义 guarder/refuse_*）
      assert msg =~ "华山派"
      assert msg =~ "不得入内"
    end

    @tag :world_data
    test "baituo:damen 给出欧阳世家的默认文案", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["baituo:damen"]

      assert {:abort, _event, {:guarder_denied, msg}} = move(room, occupants, mover(nil), "north")
      assert msg =~ "欧阳世家"
    end

    @tag :world_data
    test "同门弟子不会被拦，也就不该产生正文", ctx do
      %{room: room, occupants: occupants} = ctx.rooms["huashan:square"]
      assert {:proceed, _event, _exit} = move(room, occupants, mover("华山派"), "north")
    end
  end

  describe "MoveView 渲染守卫正文" do
    test "直接渲染 reason 里的守卫文案" do
      assert Kantele.Character.MoveView.render(
               "fail",
               %{reason: {:guarder_denied, "对不起，不是我们华山派的人不得入内！"}}
             ) == "对不起，不是我们华山派的人不得入内！"
    end

    test "{npc} / {name} 占位被替换掉" do
      rendered =
        Kantele.Character.MoveView.render(
          "fail",
          %{reason: {:guarder_denied, "{npc}拦住{name}，冷笑道：重地不得入内！"}}
        )

      assert rendered == "守门人拦住你，冷笑道：重地不得入内！"
      refute rendered =~ "{npc}"
      refute rendered =~ "{name}"
    end
  end

  describe "守卫缺席时一律放行" do
    @tag :world_data
    test "三个房间在无守卫时都不拦", ctx do
      for {rid, _} <- ctx.rooms do
        room_ctx = ctx.rooms[rid]
        room = room_ctx.room

        for exit <- room.exits do
          assert {:proceed, _event, _exit} = move(room, [], mover(nil), exit.exit_name),
                 "#{rid} 的 #{exit.exit_name} 不该被拦"
        end
      end
    end
  end
end
