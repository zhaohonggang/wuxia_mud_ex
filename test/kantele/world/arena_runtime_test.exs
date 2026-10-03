defmodule Kantele.World.ArenaRuntimeTest do
  @moduledoc """
  擂台拦截的**运行时**链路（走真实 movement_request，跨房间读状态）

  LPC 结构（d/city/underlt.c 被 wudao1~4 继承）：

      dest = query("exits/" + dir);
      if (!stringp(dest)) return ::valid_leave(me, dir);
      ob = find_object(dest);
      if (!objectp(ob) || wizardp(me)) return ::valid_leave(me, dir);
      if (ob->refuse(me)) return notify_fail("你凑什么热闹，现在不是你上去的时候。\n");

  注意 `ob` 是**目标房间**，而条件写在**观众席**房间上 —— 判定时要读另一个
  房间的状态。

  `underlt` 本身**没有通往 leitai 的出口**（LPC 里它是抽象基类，
  `create()` 是空的，只有 wudao1~4 真正实例化并定义了带 leitai 的出口），
  转换器把它也变成了一个实体房间，于是它的 `ob->refuse(me)` 条件
  **永远不会被触发**。这一组用例把这个事实也钉住。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Event
  alias Kalevala.Event.Movement
  alias Kalevala.World.Room.Context
  alias Kantele.World.{Arena, Loader, Trap}

  @handler Kalevala.World.Room.Callbacks.Kantele.World.Room
  @leitai "city:leitai"

  setup_all do
    world = Loader.load()

    Enum.each(world.zones, fn
      %{id: _} = zone -> Kantele.World.ZoneCache.cache(zone)
      _ -> :skip
    end)

    %{
      world: world,
      wudao1: Enum.find(world.rooms, &(&1.id == "city:wudao1")),
      underlt: Enum.find(world.rooms, &(&1.id == "city:underlt"))
    }
  end

  setup do
    Arena.open(@leitai)
    on_exit(fn -> Arena.open(@leitai) end)
    :ok
  end

  # 必须用**真正的 %Kalevala.Character{}**：`Kantele.Admin.Access.wizardp/1`
  # 的头个子句按结构体匹配，传普通 map 会落到兜底的 `wizardp(_) -> false`，
  # 于是巫师会被当成普通玩家拦下 —— 那是夹具问题，不是生产问题
  # （movement_request 里 event.data.character 就是真结构体）。
  defp player(wiz_level \\ 0, room \\ "city:wudao1") do
    %Kalevala.Character{
      id: "arena-test",
      name: "grant",
      pid: self(),
      room_id: room,
      attributes: %{"wiz_level" => wiz_level},
      inventory: [],
      meta: %Kantele.Character.PlayerMeta{temp: %{}, damage: %{}, env: %{}}
    }
  end

  test "wizardp 对普通 map 返回 false（所以夹具必须是真结构体）" do
    refute Kantele.Admin.Access.wizardp(%{attributes: %{"wiz_level" => 3}}),
           "普通 map 会落到 wizardp(_) -> false 这条兜底"

    assert Kantele.Admin.Access.wizardp(player(3))
    refute Kantele.Admin.Access.wizardp(player(0))
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

  describe "数据前提" do
    @tag :world_data
    test "wudao1 的 valid_leave 里有 ob->refuse(me)，且有通向擂台的方向", ctx do
      conds = ctx.wudao1.exit_vetoes |> Enum.map(& &1.condition) |> Enum.reject(&is_nil/1)
      assert Enum.any?(conds, &String.contains?(&1, "->refuse("))

      assert Enum.find(ctx.wudao1.exits, &(&1.exit_name == "leitai")),
             "wudao1 应有 leitai 方向"
    end

    @tag :world_data
    test "underlt 没有通往擂台的出口 —— 它的条件天然不会触发", ctx do
      targets = Enum.map(ctx.underlt.exits, & &1.end_room_id)

      refute @leitai in targets,
             "underlt 若有 leitai 出口则该条件可达；实际出口 #{inspect(targets)}"

      # 无论擂台开没关闭，往 underlt 的任何方向都不该被这条条件拦
      Arena.close(@leitai, %{name: "grant"})

      for e <- ctx.underlt.exits do
        assert {:proceed, _event, _exit} = move(ctx.underlt, player(0, "city:underlt"), e.exit_name),
               "#{e.exit_name} 不该被拦（underlt 没有擂台出口）"
      end
    end
  end

  describe "擂台开放时" do
    @tag :world_data
    test "所有方向都放行，且不下发任何副作用", ctx do
      for e <- ctx.wudao1.exits do
        assert {:proceed, _event, _exit} = move(ctx.wudao1, player(0), e.exit_name)
      end

      refute_received %Event{topic: "trap/effect"}
    end
  end

  describe "擂台关闭后" do
    @tag :world_data
    test "非巫师往 leitai 被拦下，并给出 LPC 原文", ctx do
      Arena.close(@leitai, %{name: "grant"})

      assert {:abort, _event, {:trapped, msg}} = move(ctx.wudao1, player(0), "leitai")
      assert msg == "你凑什么热闹，现在不是你上去的时候。"
    end

    @tag :world_data
    test "只有 leitai 那个方向被拦，其它方向照常", ctx do
      Arena.close(@leitai, %{name: "grant"})

      for e <- ctx.wudao1.exits, e.exit_name != "leitai" do
        assert {:proceed, _event, _exit} = move(ctx.wudao1, player(0), e.exit_name),
               "#{e.exit_name} 不该被拦"
      end
    end

    @tag :world_data
    test "巫师往 leitai 放行（LPC: !wizardp(ob) 才拒绝）", ctx do
      Arena.close(@leitai, %{name: "grant"})

      assert {:proceed, _event, _exit} = move(ctx.wudao1, player(3), "leitai")
    end

    @tag :world_data
    test "被拦时不产生任何副作用（擂台条件没有副作用）", ctx do
      Arena.close(@leitai, %{name: "grant"})
      move(ctx.wudao1, player(0), "leitai")

      refute_received %Event{topic: "trap/effect"},
                     "擂台拦截只读状态，不该下发任何副作用"
    end
  end

  describe "四个观众席房间都接同一份状态" do
    @tag :world_data
    test "wudao1~4 的 leitai 方向全部生效", ctx do
      Arena.close(@leitai, %{name: "grant"})

      for i <- 1..4 do
        room = Enum.find(ctx.world.rooms, &(&1.id == "city:wudao#{i}"))
        assert room

        assert {:abort, _event, {:trapped, _msg}} = move(room, player(0, room.id), "leitai"),
               "wudao#{i} 的 leitai 方向应当被拦"
      end
    end
  end

  describe "判定纯粹由状态驱动（没有硬编码擂台）" do
    @tag :world_data
    test "随便给另一个房间写上关闭状态，它也会开始拒绝", ctx do
      # Arena 不认房间 id，只看「有没有关闭状态」
      Arena.close("city:wudao1", %{name: "someone"})

      other = Enum.find(ctx.world.rooms, &(&1.id == "city:wudao2"))
      north = Enum.find(other.exits, &(&1.exit_name == "northwest")) || hd(other.exits)

      # wudao2 若有指向 wudao1 的出口，去它就应该被拒
      case Enum.find(other.exits, &(&1.end_room_id == "city:wudao1")) do
        nil ->
          assert north.exit_name, "wudao2 应至少有一个出口"

        e ->
          out = Trap.dispatch(other, player(0, other.id), e.exit_name)
          assert {:block, _msg, []} = out,
                 "目标房间被关闭时应当拒绝，实际 #{inspect(out)}"
      end

      Arena.open("city:wudao1")
    end
  end

  describe "指令注册" do
    test "lclose / lopen 都能解析并取到 here 参数" do
      assert {:ok, p} = Kantele.Character.Commands.parse("lclose here")
      assert p.function == :run
      assert p.params["arg"] == "here"

      assert {:ok, p2} = Kantele.Character.Commands.parse("lopen here")
      assert p2.function == :lopen
      assert p2.params["arg"] == "here"
    end

    test "不带 here 也能解析（LPC 里是回提示，不是「What?」）" do
      # LPC: lclose 不带参数 -> 「如果你要关闭擂台，请输入(lclose here)。」
      # 若解析失败，玩家看到的是「What?」，与原逻辑不符
      # 走 run_bare / lopen_bare 兜底（params 里没有 arg）
      assert {:ok, p} = Kantele.Character.Commands.parse("lclose")
      assert p.function == :run_bare

      assert {:ok, p2} = Kantele.Character.Commands.parse("lopen")
      assert p2.function == :lopen_bare
    end

    test "带 here 时参数取到 here" do
      assert {:ok, p} = Kantele.Character.Commands.parse("lclose here")
      assert p.params["arg"] == "here"
    end
  end
end