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

    # ZoneCache 真实运行时由 Kickoff 填充；ExitVetoContext 的 present(id, room)
    # 要靠它取物品别名，测试里得自己播种
    Enum.each(world.zones, fn
      %{id: _} = zone -> Kantele.World.ZoneCache.cache(zone)
      _ -> :skip
    end)

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

  # ---- all_dirs：LPC 本来就拦所有方向的条件 ----

  describe "all_dirs（本来就拦所有方向）" do
    @tag :world_data
    test "标了 all_dirs 的条件会执行，不再被方向守卫误挡" do
      world = Kantele.World.Loader.load()
      room = Enum.find(world.rooms, &(&1.id == "city:eproom"))

      veto = Enum.find(room.exit_vetoes, &(&1.condition =~ "pigging_seat"))
      assert veto, "city:eproom 应有「玩拱猪时不能走」的条件"
      assert veto.all_dirs, "该条件应标了 all_dirs（LPC 里确实没有 dir 判断）"

      playing = player_with_temp(%{"pigging_seat" => 1})

      assert {:deny, msg} =
               @handler.check_exit_vetoes(room, context_with(room, [], playing), playing, "north")

      assert msg =~ "拱猪"

      idle = player_with_temp(%{})

      for dir <- ["north", "west", "up"] do
        assert :allow = @handler.check_exit_vetoes(room, context_with(room, [], idle), idle, dir)
      end
    end

    @tag :world_data
    test "房间作用域的 present 也能找到房里的物品（LPC present(id, room) 语义）" do
      world = Kantele.World.Loader.load()
      room = Enum.find(world.rooms, &(&1.id == "shaolin:dmyuan2"))

      veto = Enum.find(room.exit_vetoes, &(&1.condition =~ "xisui jing"))
      assert veto, "shaolin:dmyuan2 应有「心法不见了不许走」的条件"
      assert veto.all_dirs

      items = Map.get(room, :item_instances, []) || []
      assert Enum.any?(items, fn i -> Map.get(i, :item_id) =~ "xisuijing" end),
             "房里应有 items.xisuijing（LPC 的 xisui jing 别名）"

      me = player_with_temp(%{})

      # 书在 -> 放行
      assert :allow = @handler.check_exit_vetoes(room, context_with(room, [], me), me, "south")

      # 书不在 -> 拦（只搜角色会误判成永远拦着，把人锁死）
      stripped = %{room | item_instances: []}

      assert {:deny, msg} =
               @handler.check_exit_vetoes(stripped, context_with(stripped, [], me), me, "south")

      assert msg =~ "心法"
    end
  end

  # ---- 合并方向守卫后的条件 ----

  describe "外层方向守卫已合并" do
    @tag :world_data
    test "death:qiao1 条件里带上了 dir（转换器原本丢了外层守卫）" do
      world = Kantele.World.Loader.load()
      room = Enum.find(world.rooms, &(&1.id == "death:qiao1"))

      veto = Enum.find(room.exit_vetoes, &(&1.condition =~ "mengpo_tang"))
      assert veto, "应有孟婆桥的条件"
      assert veto.condition =~ "dir"
      assert Kantele.World.LpcCondition.direction_scoped?(veto.condition)
      assert Kantele.World.LpcCondition.enforceable?(veto.condition)

      mengpo = %{name: "孟婆", pid: self(), meta: %{aliases: ["meng po", "meng", "po"]}}
      weak = player_with_skill(100)

      # 内力不足 + 没喝孟婆汤 + 孟婆在场 -> 向北被拦
      assert {:deny, msg} =
               @handler.check_exit_vetoes(room, context_with(room, [mengpo], weak), weak, "north")

      assert msg =~ "孟婆"

      # 方向不对 -> 放行（这正是补回守卫的意义：原来这条会拦所有方向）
      assert :allow = @handler.check_exit_vetoes(room, context_with(room, [mengpo], weak), weak, "south")

      # 内力够 -> 放行
      strong = player_with_skill(600)
      assert :allow = @handler.check_exit_vetoes(room, context_with(room, [mengpo], strong), strong, "north")
    end

    @tag :world_data
    test "通配方向（direction = ~）的 veto 也能取到提示语" do
      # shaolin:dmyuan2 的条件是 all_dirs（direction 为 ~），若只按方向精确匹配，
      # 玩家会被拦下却看不到原因 —— 这正是线上反馈的现象
      assert Kantele.World.exit_veto_message("shaolin:dmyuan2", "south") =~ "心法"
      assert Kantele.World.exit_veto_message("shaolin:dmyuan2", "down") =~ "心法"

      # 方向精确匹配的仍然优先
      assert Kantele.World.exit_veto_message("beijing:kangfu_men", "east") =~ "康府侍卫"
      assert Kantele.World.exit_veto_message("beijing:kangfu_men", "west") == nil
    end

    @tag :world_data
    test "无法合并的只剩 6 条，且都是表达能力不足而非遗漏" do
      world = Kantele.World.Loader.load()

      unscoped =
        Enum.flat_map(world.rooms, fn r -> Enum.map(r.exit_vetoes || [], &{r.id, &1}) end)
        |> Enum.filter(fn {_id, v} -> is_binary(v.condition) end)
        |> Enum.reject(fn {_id, v} ->
          Kantele.World.LpcCondition.direction_scoped?(v.condition) or v.all_dirs or
            not Kantele.World.LpcCondition.supported?(v.condition) or
            not Kantele.World.LpcCondition.enforceable?(v.condition)
        end)
        |> Enum.map(fn {id, _v} -> id end)

      # 6 = 原有 4 条 + changan:qunyulou 与 xiyu:xxh6 各多一条。
      # 后两条是纯 gender 条件（`=='女性'` / `!='无性'`），本来被 supported? 挡着；
      # gender 落地后它们进入这一组，但**仍然不能执行** —— 因为没限定方向，
      # 一旦执行就是把该房间所有出口都变成女性门禁（男玩家出不来）。
      assert length(unscoped) == 6,
             "预期剩 6 条，实际 #{length(unscoped)}: #{inspect(unscoped)}"

      joined = Enum.join(unscoped, " | ")

      assert joined =~ "kediandayuan"  # 依赖目的地房间内容，无法表达
      assert joined =~ "bingqifang"    # 需要按 id 统计背包数量（转换残留 j > 1）
      assert joined =~ "nantian"       # 裸标识符 mengzhu
      assert joined =~ "xxh6"          # this_player()-> 链式调用
      assert joined =~ "qunyulou"      # gender 已可用，但没限定方向
    end
  end

  defp player_with_temp(temp) do
    %{pid: self(), name: "测试玩家", meta: %{temp: temp}}
  end

  defp player_with_skill(force) do
    %{pid: self(), name: "测试玩家", meta: %{temp: %{}, stats: %{skills: %{"force" => force}}}}
  end


end
