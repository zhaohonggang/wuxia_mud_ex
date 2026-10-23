defmodule Kantele.World.RoomActions.City.PigRoomTest.FakeRoom do
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

defmodule Kantele.World.RoomActions.City.PigRoomTest do
  @moduledoc """
  P5-4ad：拱猪房动作接线测试（`RoomActions.City.PigRoom`）。

  只测「动作 → 房间状态 / 角色 temp / 消息」这一层；牌局规则本身在
  `Kantele.World.PigGameTest`。对应 LPC `inherit/room/pigroom.c` 的十个 `do_*`。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Communication
  alias Kantele.World.PigGame
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.City.PigRoom
  alias Kantele.World.RoomActions.City.PigRoomTest.FakeRoom
  alias Kantele.World.RoomActionHandlers

  @room "city:eproom"

  setup do
    room_id = "#{@room}:test#{System.unique_integer([:positive])}"
    start_supervised!({FakeRoom, {room_id, []}})
    %{room_id: room_id}
  end

  describe "注册表" do
    test "四间拱猪房的十个动词都指向 PigRoom" do
      handlers =
        ~w(do_sit do_leave do_deal do_bid do_pass do_play do_refresh do_skip do_claim)

      for room <- ["city:eproom", "city:nproom", "city:sproom", "city:wproom"] do
        for handler <- handlers do
          assert RoomActionHandlers.lookup(room, handler) == {:ok, {PigRoom, :run}}
        end
      end
    end
  end

  describe "sit" do
    test "坐下：写入房间牌局状态、设置自己的 pigging_seat、广播 vision", %{room_id: room_id} do
      conn = run("sit", "north", conn(room_id, "p1", "张三"))

      game = game(room_id)
      assert PigGame.seat_of(game, "p1") == "north"
      assert game.server == "p1"

      assert character_of(conn).meta.temp["pigging_seat"] == "north"
      assert published(conn) == ["{npc}坐上了北边的位子。\n"]
      assert output(conn) == ""
    end

    test "座位非法：只给本人提示，不写状态", %{room_id: room_id} do
      conn = run("sit", "middle", conn(room_id, "p1", "张三"))

      assert output(conn) == "你想坐在哪里？\n"
      assert Room.get_state_by_id(room_id, "pig_game") == nil
      assert character_of(conn).meta.temp["pigging_seat"] == nil
    end

    test "自己的座位由本进程直接落地（不走事件）", %{room_id: room_id} do
      _ = run("sit", "north", conn(room_id, "p1", "张三"))

      # 行动者自己的 {:temp, ...} 直接写 conn，不给任何人发 pig/seat
      refute_receive %Kalevala.Event{topic: "pig/seat"}, 100
      assert PigGame.seat_of(game(room_id), "p1") == "north"
    end
  end

  describe "leave" do
    test "离座清掉自己的座位", %{room_id: room_id} do
      _ = run("sit", "north", conn(room_id, "p1", "张三"))
      _ = run("sit", "west", conn(room_id, "p2", "李四"))

      conn = run("leave", "", conn(room_id, "p2", "李四"))

      assert PigGame.seat_of(game(room_id), "p2") == nil
      assert character_of(conn).meta.temp["pigging_seat"] == nil
      assert published(conn) == ["{npc}不想再拱了，站了起来！\n"]
    end

    test "没坐下就 leave", %{room_id: room_id} do
      conn = run("leave", "", conn(room_id, "p1", "张三"))
      assert output(conn) == "你现在没有在拱猪！\n"
    end

    test "桌长散桌：同桌其他人收到 pig/seat(nil) 事件清掉座位", %{room_id: room_id} do
      seat_all(room_id)

      # 模拟 p2 的角色进程在自己的频道上
      subscribe_character("p2")

      _conn = run("leave", "", conn(room_id, "p1", "张三"))

      assert_receive %Kalevala.Event{topic: "pig/seat", data: %{seat: nil}}, 500
      assert PigGame.pl_count(game(room_id)) == 0
    end
  end

  describe "deal / bid / pass" do
    test "四人齐后桌长发牌 → 卖牌阶段", %{room_id: room_id} do
      seat_all(room_id)
      subscribe_character("p1")

      _conn = run("deal", "", conn(room_id, "p1", "张三"))
      game = game(room_id)

      assert game.stage == :bidding
      assert PigGame.seat_of(game, "p1") == "north"
      assert Enum.all?(PigGame.seats(), fn s -> length(game.cards[s]) == 13 end)
      # 行动者自己的手牌私发到 characters:p1
      assert_receive {:room_message, "你得到的牌为：" <> _}, 500
    end

    test "非桌长发牌被拒", %{room_id: room_id} do
      seat_all(room_id)

      conn = run("deal", "", conn(room_id, "p2", "李四"))

      assert output(conn) == "你不是桌长！\n"
      assert game(room_id).stage == :dealing
    end

    test "sell 与 bid 等价", %{room_id: room_id} do
      seat_all(room_id)
      _ = run("deal", "", conn(room_id, "p1", "张三"))

      # 找出猪在谁手上，由该玩家卖出
      game = game(room_id)

      seat =
        Enum.find(PigGame.seats(), fn s -> PigGame.has_card(game.cards[s], PigGame.spig()) end)

      id = game.pl[seat].id

      conn = run("sell", "sq", conn(room_id, id, "玩家"))

      assert game(room_id).bid_flag == 1
      assert published(conn) == ["{npc}说道：我卖黑桃Ｑ！\n"]
    end

    test "pass 四次开拱", %{room_id: room_id} do
      seat_all(room_id)
      _ = run("deal", "", conn(room_id, "p1", "张三"))

      for id <- ~w(p1 p2 p3 p4), do: run("pass", "", conn(room_id, id, id))

      assert game(room_id).stage == :playing
      assert PigGame.current_turn(game(room_id)) == "north"
    end

    # `sell` 同时是全局命令（卖物品）。没坐桌时必须放行，否则拱猪房里卖不了东西。
    test "没坐桌时 sell 交回全局命令", %{room_id: room_id} do
      assert run("sell", "长剑", conn(room_id, "p1", "张三")) == :not_handled
      assert game(room_id) == nil
    end

    test "坐在桌上但还没发牌时 sell 仍被拦截", %{room_id: room_id} do
      seat_all(room_id)

      conn = run("sell", "sq", conn(room_id, "p1", "张三"))

      assert conn != :not_handled
      assert output(conn) == "现在不是卖牌的时候！\n"
    end
  end

  describe "play / refresh" do
    test "轮到的玩家出牌，牌桌视图私发给在场的人", %{room_id: room_id} do
      to_playing(room_id)

      game = game(room_id)
      card = hd(game.cards["north"])
      conn = run("play", card_arg(card), conn(room_id, "p1", "张三"))

      assert published(conn) == ["{npc}出了一张#{PigGame.card_str(card)}！\n"]
      assert game(room_id).roundcard_count == 1
      refute PigGame.has_card(game(room_id).cards["north"], card)
    end

    test "没轮到的玩家出牌被拒", %{room_id: room_id} do
      to_playing(room_id)

      conn = run("play", "s2", conn(room_id, "p2", "李四"))

      assert output(conn) == "还没轮到你出牌！\n"
      assert game(room_id).roundcard_count == 0
    end

    # 还没开拱就出牌：LPC `do_play` 先判 `pig_stage != PIG_PLAYING`，所以报的是
    # 「现在不是出牌阶段」而不是「还没轮到你出牌」。
    test "还没开拱就出牌 → 现在不是出牌阶段", %{room_id: room_id} do
      seat_all(room_id)
      _ = run("deal", "", conn(room_id, "p1", "张三"))

      conn = run("play", "s2", conn(room_id, "p1", "张三"))

      assert output(conn) == "现在不是出牌阶段！\n"
    end

    test "refresh 私发手牌", %{room_id: room_id} do
      seat_all(room_id)
      subscribe_character("p1")
      _ = run("deal", "", conn(room_id, "p1", "张三"))
      flush_messages()

      _conn = run("refresh", "", conn(room_id, "p1", "张三"))

      assert_receive {:room_message, "你手上有这些牌：\n" <> _}, 500
    end
  end

  describe "claim / skip" do
    test "skip 需要桌长", %{room_id: room_id} do
      seat_all(room_id)
      _ = run("deal", "", conn(room_id, "p1", "张三"))

      denied = run("skip", "", conn(room_id, "p2", "李四"))
      assert output(denied) == "只有桌长才能跳过这副牌！\n"

      ok = run("skip", "", conn(room_id, "p1", "张三"))
      assert published(ok) == ["桌长{npc}决定跳过这副牌！！\n"]
      assert game(room_id).stage == :dealing
    end

    test "claim 在未开拱时被拒", %{room_id: room_id} do
      seat_all(room_id)
      _ = run("deal", "", conn(room_id, "p1", "张三"))

      conn = run("claim", "", conn(room_id, "p1", "张三"))
      assert output(conn) == "你想干什么？\n"
    end
  end

  describe "无角色上下文" do
    test "没有 character 时交回全局命令" do
      assert PigRoom.run(%Conn{}, %{verb: "sit", trailing: "north", room_id: @room}) ==
               :not_handled
    end
  end

  # ---- helpers ----

  defp run(verb, arg, conn) do
    PigRoom.run(conn, %{verb: verb, trailing: arg, room_id: conn.character.room_id})
  end

  # 模拟某个角色进程订阅自己的 `characters:<id>` 频道：`{:tell, id, text}` 会以
  # `{:room_message, text}` 投到这里（真实运行时由 Foreman 渲染）。
  #
  # `Kantele.CharacterChannel.subscribe_request/3` 会校验 `options[:character].id`
  # 与频道 `config[:character_id]` 一致，所以订阅时必须带上同 id 的 character。
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

  defp seat_all(room_id) do
    run("sit", "north", conn(room_id, "p1", "张三"))
    run("sit", "west", conn(room_id, "p2", "李四"))
    run("sit", "south", conn(room_id, "p3", "王五"))
    run("sit", "east", conn(room_id, "p4", "赵六"))
    :ok
  end

  # 四人齐 → 发牌 → 四家全 pass → 进入 `:playing`（`round_order[0]` 是 north=p1）。
  defp to_playing(room_id) do
    seat_all(room_id)
    _ = run("deal", "", conn(room_id, "p1", "张三"))
    for id <- ~w(p1 p2 p3 p4), do: run("pass", "", conn(room_id, id, id))
    :ok
  end

  defp game(room_id), do: Room.get_state_by_id(room_id, "pig_game")

  # 把牌号转成 LPC 的输入形式（如 10 → "SQ"）
  defp card_arg(card) do
    suit = Enum.at(~w(S H D C), PigGame.suit(card))
    rank = Enum.at(~w(2 3 4 5 6 7 8 9 T J Q K A), PigGame.rank(card))
    suit <> rank
  end

  defp conn(room_id, id, name) do
    %Conn{
      character: %Kalevala.Character{
        id: id,
        name: name,
        room_id: room_id,
        meta: %PlayerMeta{temp: %{}},
        inventory: []
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp character_of(conn), do: conn.private.update_character || conn.character

  defp output(conn), do: Enum.map_join(conn.output, & &1.data)

  # 清空测试进程邮箱里堆积的 `{:room_message, _}`（每个动作都会给同桌人私发牌桌）
  defp flush_messages do
    receive do
      _ -> flush_messages()
    after
      0 -> :ok
    end
  end

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
