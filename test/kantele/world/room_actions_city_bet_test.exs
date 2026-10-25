defmodule Kantele.World.RoomActions.City.BetTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 最小替身（同 `pig_room_test`）。

  与拱猪测试不同的是：赌场需要「庄家在场」才能下注，而 `Room.npc_characters_by_id/1`
  读的是房间进程的 `state.private.characters`，故这里支持通过 `characters:` 选项把
  庄家 NPC 注入房间，用于模拟「庄家在场」；不传则视为庄家不在。
  """
  use GenServer

  def start_link({room_id, opts}) do
    GenServer.start_link(__MODULE__, {room_id, opts},
      name: {:global, {Kalevala.World.Room, room_id}}
    )
  end

  @impl true
  def init({room_id, opts}) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id, state: Keyword.get(opts, :state, %{})},
       private: %{characters: Keyword.get(opts, :characters, []), item_instances: []}
     }}
  end
end

defmodule Kantele.World.RoomActions.City.BetTest do
  @moduledoc """
  P5-9 #9 一次性场景：赌场 `bet`（移植自 `d/city/bet.c`）。

  分层测试：
  1. **注册表**：`city:bet` 的 `do_bet` 指向 `City.Bet`。
  2. **`City.Bet` 接线**（动作 → 房间状态 / 角色 coins / 消息）：庄家在场校验、语法/
     种类/铜钱/窗口/重复下注各分支，以及成功下注。
  3. **`Casino` 纯逻辑**（核心玩法，无副作用）：开盘两枚不同骰、押注各校验分支、
     结算倍率数学（头彩/双对/七星/散星/空盘）。
  4. **跨进程结算**：`finish_round` 给赢家发 `casino/payout` 事件，由角色进程
     `CasinoPayoutEvent.credit` 加币（同 pig_room 的 `pig/seat` 跨进程模式）。

  注：`City.Bet` 的定时序列（`prepare→start→perform×2→finish`）用 `:timer.apply_after`
  编排，结构上与已测的 `RoomActions.Vehicle` 完全一致；本测试直接驱动各阶段对应的
  `Casino.*` 纯计算，仅在「跨进程结算」用例里实跑一次 `finish_round`（其尾部排的 5s
  重开盘定时器在测试进程退出后落空，无害）。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kantele.Character.CasinoPayoutEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Communication
  alias Kantele.World.Casino
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.City.Bet
  alias Kantele.World.RoomActions.City.BetTest.FakeRoom
  alias Kantele.World.RoomActionHandlers

  @room "city:bet"

  setup do
    room_id = "#{@room}:test#{System.unique_integer([:positive])}"
    # 默认带庄家在场（大多数用例需要）
    start_supervised!({FakeRoom, {room_id, [characters: [dealer()]]}})
    %{room_id: room_id}
  end

  # ---- 注册表 ---------------------------------------------------------------

  describe "注册表" do
    test "city:bet 的 do_bet 指向 City.Bet" do
      assert RoomActionHandlers.lookup("city:bet", "do_bet") == {:ok, {Bet, :run}}
    end

    test "非 do_bet 动词 → :not_handled（不接管全局命令）" do
      conn = conn("some:room", "p1", "张三")
      assert Bet.run(conn, %{verb: "do_something", trailing: "", room_id: "some:room"}) == :not_handled
    end

    test "无角色上下文 → :not_handled" do
      assert Bet.run(%Conn{}, %{verb: "do_bet", trailing: "tc 10 coin", room_id: @room}) ==
               :not_handled
    end

    test "changan:duchang（第二赌场实例）的 do_bet 也指向 City.Bet" do
      assert RoomActionHandlers.lookup("changan:duchang", "do_bet") == {:ok, {Bet, :run}}
    end
  end

  # ---- changan:duchang 第二实例（同 City.Bet，独立 room state） -----------------

  describe "changan:duchang 第二赌场实例（复用 City.Bet）" do
    test "下注：扣铜钱 + 记入房间状态 + 广播 vision（庄家 id 为 changan:zhuangjia）" do
      room_id = "changan:duchang:test#{System.unique_integer([:positive])}"
      # 长安本地庄家 NPC：id 含 zhuangjia、name 为「庄家」，与 UCL room_characters 一致
      start_supervised!(
        {FakeRoom,
         {room_id, [characters: [%Kalevala.Character{id: "changan:zhuangjia", name: "庄家"}]]}},
        id: :duchang_dealer
      )

      seed_open(room_id)

      result = run("sd 5 coin", conn(room_id, "p2", "李四"))

      # 扣币 1000 -> 995
      assert character_of(result).meta.coins == 995
      casino = state(room_id)
      assert casino.status == 1
      assert [%{player_id: "p2", name: "李四", kind: "sd", amount: 5}] = casino.bettors
      assert published(result) == ["李四拿出5文铜钱，押在双对上。\n"]
    end

    test "庄家不在 → 拒绝（与 city:bet 行为一致）" do
      room_id = "changan:duchang:nodlr#{System.unique_integer([:positive])}"
      # 第二个 FakeRoom 需独立 child id，避免与 setup 里那个冲突
      start_supervised!({FakeRoom, {room_id, []}}, id: :duchang_nodlr)
      seed_open(room_id)

      assert output(run("tc 10 coin", conn(room_id, "p1", "张三"))) ==
               "庄家都没有，你要和谁赌？\n"
    end
  end

  # ---- do_bet 接线 ----------------------------------------------------------

  describe "do_bet 接线" do
    test "庄家不在场 → 拒绝", %{room_id: base} do
      room_id = base <> "-nodlr"
      # 第二个 FakeRoom 需指定独立 child id，避免与 setup 里那个（默认 id 同为 FakeRoom）冲突
      start_supervised!({FakeRoom, {room_id, []}}, id: :bet_nodlr)

      result = run("tc 10 coin", conn(room_id, "p1", "张三"))

      assert output(result) == "庄家都没有，你要和谁赌？\n"
    end

    test "语法不对（非「种类 数量 货币」三段）→ 用法提示", %{room_id: room_id} do
      seed_open(room_id)

      assert output(run("tc", conn(room_id, "p1", "张三"))) ==
               "庄家讥笑道：哪里有你那样赌钱的？\n"

      assert output(run("tc abc coin", conn(room_id, "p1", "张三"))) ==
               "庄家讥笑道：哪里有你那样赌钱的？\n"
    end

    test "押注种类非法 → 你要押哪一种骰", %{room_id: room_id} do
      seed_open(room_id)

      assert output(run("xx 10 coin", conn(room_id, "p1", "张三"))) ==
               "庄家皱眉道：你要押哪一种骰？\n"

      # 房间状态未被写入
      assert state(room_id).bettors == []
    end

    test "铜钱不足 → 你有那么多钱吗", %{room_id: room_id} do
      seed_open(room_id)

      result = run("tc 99999 coin", conn(room_id, "p1", "张三", 100))

      assert output(result) == "庄家皱眉道：你有那么多钱吗？\n"
      # 没扣币、没记状态
      assert character_of(result).meta.coins == 100
      assert state(room_id).bettors == []
    end

    test "封盘中下注 → 现在正在赌呢", %{room_id: room_id} do
      Room.put_state_by_id(room_id, "casino", %{
        status: 2,
        big: {1, 2},
        res: [3, 4],
        bettors: []
      })

      assert output(run("tc 10 coin", conn(room_id, "p1", "张三"))) ==
               "庄家赔笑道：现在正在赌呢，请你稍等片刻。\n"
    end

    test "有效下注：扣铜钱 + 记入房间状态 + 广播 vision", %{room_id: room_id} do
      seed_open(room_id)

      result = run("tc 10 coin", conn(room_id, "p1", "张三"))

      # 扣币 1000 -> 990
      assert character_of(result).meta.coins == 990
      # 房间状态记下了这一注
      casino = state(room_id)
      assert casino.status == 1
      assert [%{player_id: "p1", name: "张三", kind: "tc", amount: 10}] = casino.bettors
      # 广播给房间：张三拿出10文铜钱，押在头彩上。
      assert published(result) == ["张三拿出10文铜钱，押在头彩上。\n"]
    end

    test "重复下注 → 你已经押过了", %{room_id: room_id} do
      seed_open(room_id)

      _first = run("tc 10 coin", conn(room_id, "p1", "张三"))
      second = run("sd 5 coin", conn(room_id, "p1", "张三"))

      assert output(second) == "庄家道：你已经押过了，就等着开盅吧。\n"
      # 仍是第一注，第二注没进来
      assert Enum.count(state(room_id).bettors) == 1
    end
  end

  # ---- Casino 纯逻辑 --------------------------------------------------------

  describe "Casino 纯逻辑" do
    test "new/0 初始未开盘" do
      assert Casino.new() == %{status: 0, big: nil, res: nil, bettors: []}
    end

    test "prepare/1 开出两枚不同的头彩骰、置押注窗口" do
      :rand.seed(:exsss, {1, 2, 3})
      state = Casino.prepare(Casino.new())

      assert state.status == 1
      assert {b1, b2} = state.big
      assert b1 != b2
      assert b1 in 1..6 and b2 in 1..6
      assert state.bettors == []
    end

    test "place_bet/4：非押注窗口" do
      state = %{status: 2, big: {1, 2}, res: [3, 4], bettors: []}
      assert Casino.place_bet(state, %{id: "p1", name: "张三"}, "tc", 10) ==
               {:error, "庄家赔笑道：现在正在赌呢，请你稍等片刻。\n"}
    end

    test "place_bet/4：种类非法" do
      state = %{status: 1, big: {1, 2}, res: nil, bettors: []}
      assert Casino.place_bet(state, %{id: "p1", name: "张三"}, "xx", 10) ==
               {:error, "庄家皱眉道：你要押哪一种骰？\n"}
    end

    test "place_bet/4：数量 < 1" do
      state = %{status: 1, big: {1, 2}, res: nil, bettors: []}
      assert Casino.place_bet(state, %{id: "p1", name: "张三"}, "tc", 0) ==
               {:error, "庄家皱眉道：那么少？不够，不够，再多押点。\n"}
    end

    test "place_bet/4：已押过" do
      state = %{
        status: 1,
        big: {1, 2},
        res: nil,
        bettors: [%{player_id: "p1", name: "张三", kind: "tc", amount: 10}]
      }

      assert Casino.place_bet(state, %{id: "p1", name: "张三"}, "sd", 5) ==
               {:error, "庄家道：你已经押过了，就等着开盅吧。\n"}
    end

    test "place_bet/4：合法 → 记录下注者" do
      state = %{status: 1, big: {1, 2}, res: nil, bettors: []}
      {:ok, new_state} = Casino.place_bet(state, %{id: "p1", name: "张三"}, "tc", 10)

      assert new_state.bettors == [%{player_id: "p1", name: "张三", kind: "tc", amount: 10}]
      # 不破坏既有下注者
      {:ok, new_state2} = Casino.place_bet(new_state, %{id: "p2", name: "李四"}, "sd", 5)
      assert Enum.count(new_state2.bettors) == 2
    end

    test "finish/1：头彩（res == big）→ 36 倍" do
      state = %{
        status: 2,
        big: {3, 4},
        res: [3, 4],
        bettors: [%{player_id: "p1", name: "张三", kind: "tc", amount: 10}]
      }

      {new_state, winner, total, payouts} = Casino.finish(state)

      assert winner == "tc"
      assert total == 36
      assert [%{won: true, payout: 360}] = payouts
      # 结算后状态归零、清空下注者
      assert new_state.status == 0
      assert new_state.bettors == []
    end

    test "finish/1：双对（两枚偶数相同）→ 12 倍" do
      state = %{
        status: 2,
        big: {3, 4},
        res: [2, 2],
        bettors: [%{player_id: "p1", name: "张三", kind: "sd", amount: 10}]
      }

      {_s, winner, total, payouts} = Casino.finish(state)

      assert winner == "sd"
      assert total == 12
      assert [%{won: true, payout: 120}] = payouts
    end

    test "finish/1：七星（点数和为 7）→ 6 倍" do
      state = %{
        status: 2,
        big: {1, 2},
        res: [3, 4],
        bettors: [%{player_id: "p1", name: "张三", kind: "qx", amount: 10}]
      }

      {_s, winner, total, payouts} = Casino.finish(state)

      assert winner == "qx"
      assert total == 6
      assert [%{won: true, payout: 60}] = payouts
    end

    test "finish/1：散星（点数和为 3/5/9/11）→ 3 倍" do
      state = %{
        status: 2,
        big: {5, 6},
        res: [1, 2],
        bettors: [%{player_id: "p1", name: "张三", kind: "sx", amount: 10}]
      }

      {_s, winner, total, payouts} = Casino.finish(state)

      assert winner == "sx"
      assert total == 3
      assert [%{won: true, payout: 30}] = payouts
    end

    test "finish/1：空盘 → 0 倍，无赢家" do
      state = %{
        status: 2,
        big: {5, 6},
        res: [1, 1],
        bettors: [%{player_id: "p1", name: "张三", kind: "tc", amount: 10}]
      }

      {_s, winner, total, payouts} = Casino.finish(state)

      assert winner == "none"
      assert total == 0
      assert [%{won: false, payout: 0}] = payouts
    end

    test "finish/1：多人多注，仅命中种类赢钱" do
      state = %{
        status: 2,
        big: {3, 4},
        res: [3, 4],
        bettors: [
          %{player_id: "p1", name: "张三", kind: "tc", amount: 10},
          %{player_id: "p2", name: "李四", kind: "sd", amount: 5}
        ]
      }

      {_s, winner, _total, payouts} = Casino.finish(state)

      assert winner == "tc"
      # p1 头彩命中 360；p2 双对未中 0
      assert [%{player_id: "p1", won: true, payout: 360}, %{player_id: "p2", won: false, payout: 0}] =
               payouts
    end

    test "payout/1 与 kind_name/1 可读名" do
      assert Casino.payout("tc") == 36
      assert Casino.payout("sd") == 12
      assert Casino.payout("qx") == 6
      assert Casino.payout("sx") == 3
      assert Casino.payout("xx") == 0

      assert Casino.kind_name("tc") == "头彩"
      assert Casino.kind_name("sd") == "双对"
      assert Casino.kind_name("qx") == "七星"
      assert Casino.kind_name("sx") == "散星"
    end
  end

  # ---- 跨进程结算 -----------------------------------------------------------

  describe "跨进程结算" do
    test "finish_round：给赢家发 casino/payout 事件（由角色进程加币）", %{room_id: room_id} do
      Room.put_state_by_id(room_id, "casino", %{
        status: 2,
        big: {3, 4},
        res: [3, 4],
        bettors: [%{player_id: "p1", name: "张三", kind: "tc", amount: 10}]
      })

      # 模拟赢家 p1 订阅自己的 characters:p1 频道
      subscribe_character("p1")

      :ok = Bet.finish_round(room_id)

      # 跨进程事件到达：赢家 p1 收到 payout=360
      assert_receive %Kalevala.Event{topic: "casino/payout", data: %{amount: 360}}, 500

      # 房间状态已结算归零（等待下一盘）
      assert state(room_id).status == 0
      assert state(room_id).bettors == []
    end

    test "CasinoPayoutEvent.credit/2：直接给角色加扁平铜钱" do
      conn = conn("some:room", "p1", "张三", 100)

      conn2 = CasinoPayoutEvent.credit(conn, %{data: %{amount: 360}})

      assert character_of(conn2).meta.coins == 460
    end

    test "CasinoPayoutEvent.credit/2：金额非整数原样返回" do
      conn = conn("some:room", "p1", "张三", 100)
      assert CasinoPayoutEvent.credit(conn, %{data: %{amount: "lots"}}) == conn
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp run(arg, conn) do
    case Bet.run(conn, %{verb: "do_bet", trailing: arg, room_id: conn.character.room_id}) do
      {:handled, conn2} -> conn2
      other -> other
    end
  end

  # 预先把赌场状态置为「押注中」（status 1），避免下注路径触发 prepare_round 的定时器。
  defp seed_open(room_id) do
    Room.put_state_by_id(room_id, "casino", %{
      status: 1,
      big: {1, 2},
      res: nil,
      bettors: []
    })
  end

  defp dealer do
    %Kalevala.Character{id: "changan_zhuangjia", name: "庄家"}
  end

  # 模拟某个角色进程订阅自己的 `characters:<id>` 频道：`send_payout` 会把
  # `%Kalevala.Event{topic: "casino/payout"}` 直接投到这里（真实运行时由 Foreman 路由
  # 给 CasinoPayoutEvent）。
  defp subscribe_character(id) do
    case Communication.register("characters:#{id}", Kantele.CharacterChannel, character_id: id) do
      :ok -> :ok
      {:error, :already_registered} -> :ok
    end

    :ok =
      Communication.subscribe("characters:#{id}",
        character: %Kalevala.Character{id: id}
      )
  end

  defp conn(room_id, id, name, coins \\ 1000) do
    %Conn{
      character: %Kalevala.Character{
        id: id,
        name: name,
        room_id: room_id,
        meta: %PlayerMeta{temp: %{}, coins: coins},
        inventory: []
      },
      private: %Private{channel_changes: []},
      output: []
    }
  end

  defp character_of(conn), do: conn.private.update_character || conn.character

  defp output(conn), do: Enum.map_join(conn.output, & &1.data)

  defp state(room_id), do: Room.get_state_by_id(room_id, "casino")

  defp published(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(fn
      {:publish, _chan, %{data: %{type: "vision"}}, _opts, _err} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _chan, event, _opts, _err} -> event.data.text end)
  end
end
