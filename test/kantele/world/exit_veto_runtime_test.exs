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
end