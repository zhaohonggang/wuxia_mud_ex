defmodule Kantele.World.ExitVetoRuntimeTest do
  @moduledoc """
  valid_leave 拦截的**运行时**行为（走 handler 的真实调用形态）

  这里刻意不测 `LpcCondition` 的纯函数（那是 lpc_condition_test.exs 的事），
  而是复现一个之前被漏掉的事实：

      Kalevala.World.Room.Context.new/1 的 `characters` 只来自房间生成的 NPC，
      **玩家本人不在其中**。

  所以 `movement_request` 若用 `context.characters` 找 mover，玩家移动时恒为 nil，
  整段拦截（连同原有的 guarder）都不会执行 —— 这正是线上「侍卫在场却走进去了」
  的原因。本模块用真实世界数据 + 真实 handler 断言它确实会拦。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Event
  alias Kalevala.Event.Movement
  alias Kalevala.World.Room.Context
  alias Kantele.World.Loader

  # handler 是 `defimpl Kalevala.World.Room.Callbacks for Kantele.World.Room`，
  # 编译后的模块名就是下面这个
  @handler Kalevala.World.Room.Callbacks.Kantele.World.Room

  @room_id "beijing:kangfu_men"

  setup_all do
    world = Loader.load()
    room = Enum.find(world.rooms, &(&1.id == @room_id))

    # ZoneCache 真实运行时由 Kickoff 填充；这里播种，供 exit_veto_message 回查提示语
    Enum.each(world.zones, fn
      %{id: zone_id} = zone -> Kantele.World.ZoneCache.cache(zone)
      _ -> :skip
    end)

    %{room: room, occupants: Enum.filter(world.characters, &(&1.room_id == @room_id))}
  end

  defp movement_event(mover, dir) do
    %Event{
      topic: Movement.Request,
      from_pid: self(),
      data: %Movement.Request{character: mover, exit_name: dir}
    }
  end

  defp context_with(room, characters, _mover) do
    # Context.new/1 的产物形状：characters 里只有 NPC，没有玩家
    %Context{
      data: room,
      characters: characters,
      item_instances: [],
      assigns: %{},
      events: [],
      output: []
    }
  end

  @tag :world_data
  test "context.characters 里没有玩家 —— 这正是必须从事件取 mover 的原因", ctx do
    player = %{pid: self(), name: "测试玩家", meta: %{}}

    context = context_with(ctx.room, ctx.occupants, player)

    # 前提：按 pid 在 context.characters 里找不到玩家
    assert Enum.find(context.characters, &(&1.pid == self())) == nil
    # 但事件里带着玩家
    assert Map.get(movement_event(player, "east").data, :character) == player
  end

  @tag :world_data
  test "从事件取到 mover 后，侍卫在场的向东移动会被 veto 拦下", ctx do
    player = %{pid: self(), name: "测试玩家", meta: %{}}

    # 先直接验证判定函数（不依赖 GenServer 的 render）
    assert {:deny, msg} =
             @handler.check_exit_vetoes(
               ctx.room,
               context_with(ctx.room, ctx.occupants, player),
               player,
               "east"
             )

    assert msg =~ "康府侍卫"
  end

  @tag :world_data
  test "换方向 / 房内无人时放行", ctx do
    player = %{pid: self(), name: "测试玩家", meta: %{}}
    context = context_with(ctx.room, ctx.occupants, player)

    assert :allow = @handler.check_exit_vetoes(ctx.room, context, player, "west")

    empty = context_with(ctx.room, [], player)
    assert :allow = @handler.check_exit_vetoes(ctx.room, empty, player, "east")
  end

  # ---- 回归：曾经让拦截必然失效的三个缺陷 ----

  @tag :world_data
  test "别名字段能穿过 Meta.Trim（否则 present() 永远匹配不到人）", ctx do
    guard = Enum.find(ctx.occupants, &(to_string(&1.name) =~ "侍卫"))

    trimmed = Kalevala.Meta.trim(Map.get(guard, :meta))

    assert Enum.member?(Map.get(trimmed, :aliases) || [], "shi wei"),
           "trim 之后必须仍保留 aliases，否则 present('shi wei') 失效"
  end

  @tag :world_data
  test "能按房间+方向取回 LPC 提示语（房间侧 Context.render 在移动链路是空操作）" do
    assert Kantele.World.exit_veto_message("beijing:kangfu_men", "east") =~ "康府侍卫"

    # 方向不匹配 / 房间不存在 -> nil，视图要能兜底
    assert Kantele.World.exit_veto_message("beijing:kangfu_men", "west") == nil
    assert Kantele.World.exit_veto_message("beijing:no_such_room", "east") == nil
  end

  test "MoveView fail 子句：自定义 reason 不崩，且能渲染提示语" do
    event = %{reason: :exit_vetoed, from: "beijing:kangfu_men", exit_name: "east"}

    assert Kantele.Character.MoveView.render("fail", event) =~ "康府侍卫"

    # 没有房间数据时也要安全返回（不能崩掉角色进程）
    safe = Kantele.Character.MoveView.render("fail", %{reason: :exit_vetoed})

    assert IO.iodata_to_binary(safe) |> String.trim() == ""
  end

  test "中止返回值必须是 Kalevala 期望的 3 元组（4 元组会让房间抛 CaseClauseError）" do
    # Kalevala.World.Room.Movement.handle_request/3 只匹配这两个形状
    source = File.read!("lib/kantele/world/room.ex")

    refute source =~ "{:abort, event, :exit_vetoed,",
           "exit_vetoed 中止必须是 3 元组 {:abort, event, reason}"

    refute source =~ "{:abort, event, :guarder_denied,",
           "guarder_denied 中止必须是 3 元组 {:abort, event, reason}"
  end
end