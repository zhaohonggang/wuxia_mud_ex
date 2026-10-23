defmodule Kantele.World.PigGameTest do
  @moduledoc """
  拱猪纯逻辑测试（`Kantele.World.PigGame`）。

  覆盖：
  - 牌面工具（`suit/rank/card_str/is_validcard/is_validbid/is_special/refresh/
    has_suit/order_turn/card_cmp4`）
  - 算分（`count_score/2` 的六条分支）
  - 流程（sit/leave/deal/bid/pass/play/claim/skip）
  - 渲染（`table_str/2`、`scoreboard_str/1`）

  规则来源：`adm/daemons/pigd.c`（PIG_D）+ `inherit/room/pigroom.c`（PIG_ROOM）。
  """

  use ExUnit.Case, async: true

  alias Kantele.World.PigGame

  @seats ["north", "west", "south", "east"]

  # 特殊牌
  @spig 10
  @hace 25
  @dsheep 35
  @ctrans 47

  defp player(id), do: %{id: id, name: String.upcase(id)}

  defp seated(seats) do
    Enum.reduce(seats, PigGame.new(), fn {seat, id}, game ->
      {:ok, game, _events} = PigGame.sit(game, player(id), seat)
      game
    end)
  end

  defp four_players do
    seated([{"north", "p1"}, {"west", "p2"}, {"south", "p3"}, {"east", "p4"}])
  end

  defp empty_seats, do: Map.new(@seats, fn s -> {s, nil} end)
  defp zero_seats, do: Map.new(@seats, fn s -> {s, 0} end)

  # 手动摆牌（不依赖 shuffle 结果），默认直接进 playing 阶段。
  defp game_with(cards, opts \\ []) do
    game = four_players()

    cards = Map.new(@seats, fn s -> {s, Map.get(cards, s, [])} end)

    %{
      game
      | stage: Keyword.get(opts, :stage, :playing),
        round_no: Keyword.get(opts, :round_no, 1),
        cards: cards,
        card_count: Map.new(@seats, fn s -> {s, length(Map.get(cards, s))} end),
        roundcards: Keyword.get(opts, :roundcards, empty_seats()),
        roundcard_count: Keyword.get(opts, :roundcard_count, 0),
        round_order: Keyword.get(opts, :round_order, @seats),
        bid_flag: Keyword.get(opts, :bid_flag, 0),
        allow_playbid: Keyword.get(opts, :allow_playbid, [1, 1, 1, 1]),
        picks: Keyword.get(opts, :picks, Map.new(@seats, fn s -> {s, []} end)),
        pick_count: Keyword.get(opts, :pick_count, zero_seats()),
        tscore: Keyword.get(opts, :tscore, zero_seats()),
        hscore: Keyword.get(opts, :hscore, zero_seats())
    }
  end

  # =========================================================================
  # 牌面工具
  # =========================================================================

  describe "牌面工具" do
    test "suit/rank 与 LPC SUIT/RANK 一致（0..12 = 2..A）" do
      assert PigGame.suit(0) == 0
      assert PigGame.rank(0) == 0
      assert PigGame.suit(12) == 0
      assert PigGame.rank(12) == 12
      assert PigGame.suit(13) == 1
      assert PigGame.suit(51) == 3
      assert PigGame.rank(51) == 12
    end

    test "特殊牌的编码与 include/pig.h 一致" do
      assert @spig == 10
      assert @hace == 25
      assert @dsheep == 35
      assert @ctrans == 47

      assert PigGame.spig() == @spig
      assert PigGame.hace() == @hace
      assert PigGame.dsheep() == @dsheep
      assert PigGame.ctrans() == @ctrans
    end

    test "card_str/1 输出中文牌面，越界返回空串" do
      assert PigGame.card_str(0) == "黑桃２"
      assert PigGame.card_str(@spig) == "黑桃Ｑ"
      assert PigGame.card_str(@hace) == "红心Ａ"
      assert PigGame.card_str(@dsheep) == "方块Ｊ"
      assert PigGame.card_str(@ctrans) == "梅花⒑"
      assert PigGame.card_str(-1) == ""
      assert PigGame.card_str(52) == ""
    end

    test "is_validcard/1 解析花色+点数，非法返回 -1" do
      assert PigGame.is_validcard("S2") == 0
      assert PigGame.is_validcard("s2") == 0
      assert PigGame.is_validcard("SQ") == @spig
      assert PigGame.is_validcard("HA") == @hace
      assert PigGame.is_validcard("DJ") == @dsheep
      assert PigGame.is_validcard("CT") == @ctrans
      assert PigGame.is_validcard("X2") == -1
      assert PigGame.is_validcard("SX") == -1
      assert PigGame.is_validcard("S") == -1
      assert PigGame.is_validcard("") == -1
    end

    test "is_validbid/1 只认四张特殊牌" do
      assert PigGame.is_validbid(@spig) == 1
      assert PigGame.is_validbid(@hace) == 2
      assert PigGame.is_validbid(@dsheep) == 4
      assert PigGame.is_validbid(@ctrans) == 8
      assert PigGame.is_validbid(0) == 0
      assert PigGame.is_validbid(@spig + 1) == 0
    end

    test "is_special/1：猪 / 羊 / 变压器 / 全部红心" do
      assert PigGame.is_special(@spig)
      assert PigGame.is_special(@dsheep)
      assert PigGame.is_special(@ctrans)
      assert PigGame.is_special(13)
      assert PigGame.is_special(@hace)
      refute PigGame.is_special(0)
      refute PigGame.is_special(12)
      refute PigGame.is_special(26)
    end

    test "refresh/1 按花色分行、18 空格缩进、同花色空格分隔" do
      text = PigGame.refresh([0, 1, 13])

      assert text =~ String.duplicate(" ", 18) <> "黑桃：２ ３ "
      assert text =~ String.duplicate(" ", 18) <> "红心：２ "
      # 空手牌返回空串（LPC refresh(b, e) 在 e < 0 时直接返回 ""）
      assert PigGame.refresh([]) == ""
    end

    test "has_suit/2 与 has_card/2" do
      hand = [0, 1, 13]
      assert PigGame.has_suit(hand, 0) == 2
      assert PigGame.has_suit(hand, 1) == 1
      assert PigGame.has_suit(hand, 2) == 0
      assert PigGame.has_card(hand, 13)
      refute PigGame.has_card(hand, 14)
    end

    test "order_turn/1 从给定座位起按 北→西→南→东 轮转" do
      assert PigGame.order_turn("north") == ["north", "west", "south", "east"]
      assert PigGame.order_turn("west") == ["west", "south", "east", "north"]
      assert PigGame.order_turn("south") == ["south", "east", "north", "west"]
      assert PigGame.order_turn("east") == ["east", "north", "west", "south"]
      # 非法座位按 south 处理（LPC order_turn 的默认分支）
      assert PigGame.order_turn("") == ["south", "east", "north", "west"]
    end

    test "card_cmp4/2 取领出花色里最大的一张所在座位" do
      roundcards = %{"north" => 0, "west" => 12, "south" => 1, "east" => 5}

      assert PigGame.card_cmp4(roundcards, 0) == "west"
      # 没有该花色时返回 nil
      assert PigGame.card_cmp4(roundcards, 2) == nil
    end
  end

  # =========================================================================
  # 算分
  # =========================================================================

  describe "count_score/2" do
    test "16 张特殊牌全收 = 1000" do
      all = [@spig] ++ Enum.to_list(13..25) ++ [@dsheep, @ctrans]
      assert length(all) == 16
      assert PigGame.count_score(all, 0) == 1000
    end

    test "单猪 -100；卖过 -200" do
      assert PigGame.count_score([@spig], 0) == -100
      assert PigGame.count_score([@spig], 1) == -200
    end

    test "13 张红心 200；卖过 400" do
      hearts = Enum.to_list(13..25)
      assert PigGame.count_score(hearts, 0) == 200
      assert PigGame.count_score(hearts, 2) == 400
    end

    test "单变压器 50；卖过 100" do
      assert PigGame.count_score([@ctrans], 0) == 50
      assert PigGame.count_score([@ctrans], 8) == 100
    end

    test "单羊 100；卖过 200" do
      assert PigGame.count_score([@dsheep], 0) == 100
      assert PigGame.count_score([@dsheep], 4) == 200
    end

    test "变压器翻倍：猪 + 变压器 = -200" do
      assert PigGame.count_score([@spig, @ctrans], 0) == -200
    end

    test "13 张红心 + 变压器：先加全红心 400 再翻倍 = 800" do
      hearts_and_trans = Enum.to_list(13..25) ++ [@ctrans]
      assert PigGame.count_score(hearts_and_trans, 0) == 400
    end

    test "红心分值表：A=-50 J=-20 5..10=-10" do
      # 25 = 红心A → -50；22 = 红心J → -20；16 = 红心5 → -10
      assert PigGame.count_score([25], 0) == -50
      assert PigGame.count_score([22], 0) == -20
      assert PigGame.count_score([16], 0) == -10
      # 2/3/4 不计分
      assert PigGame.count_score([13], 0) == 0
    end
  end

  # =========================================================================
  # 坐下 / 离座
  # =========================================================================

  describe "sit/3" do
    test "第一个坐下的人是桌长，庄家即该座位" do
      {:ok, game, events} = PigGame.sit(PigGame.new(), player("p1"), "north")

      assert game.server == "p1"
      assert game.dealer == "north"
      assert game.round_order == ["north", "west", "south", "east"]
      assert PigGame.seat_of(game, "p1") == "north"
      assert PigGame.pl_count(game) == 1

      assert {:tell, "p1", "你现在是桌长！\n"} in events
      assert {:vision, "$N坐上了北边的位子。\n"} in events
      assert {:temp, "p1", "north"} in events
    end

    test "第三人坐下提示三缺一" do
      game = seated([{"north", "p1"}, {"west", "p2"}])
      {:ok, game, events} = PigGame.sit(game, player("p3"), "south")

      assert {:room, "现在是三缺一，你们只再需要一个玩家就可以开拱了！\n"} in events
      assert game.stage == :initting
    end

    test "第四人坐下进入发牌阶段并广播成绩表" do
      game = seated([{"north", "p1"}, {"west", "p2"}, {"south", "p3"}])
      {:ok, game, events} = PigGame.sit(game, player("p4"), "east")

      assert game.stage == :dealing
      assert PigGame.pl_count(game) == 4
      assert {:room, "好，人凑齐了！\n"} in events
      assert Enum.any?(events, &match?({:room, _}, &1))
      assert {:room, "桌长请 deal ！\n"} in events
    end

    test "座位非法 / 已有人 / 桌长换座 三种拒绝" do
      game = seated([{"north", "p1"}, {"west", "p2"}])

      assert {:error, "你想坐在哪里？\n"} = PigGame.sit(game, player("p3"), "middle")

      # 目标位有人：失败且**牌局不变**（调用方只在 ok 时落库）
      assert {:error, "这个位子上已经有人了！\n"} = PigGame.sit(game, player("p3"), "west")

      assert {:error, "桌长不能换坐位！\n"} = PigGame.sit(game, player("p1"), "east")
    end

    test "换座位：从旧位挪到新位" do
      game = seated([{"north", "p1"}, {"west", "p2"}])
      {:ok, game, _events} = PigGame.sit(game, player("p2"), "south")

      assert PigGame.seat_of(game, "p2") == "south"
      assert PigGame.seat_of(game, "p1") == "north"
      assert PigGame.pl_count(game) == 2
    end
  end

  describe "leave/2" do
    test "没坐下就 leave" do
      assert {:error, "你现在没有在拱猪！\n"} = PigGame.leave(PigGame.new(), player("p1"))
    end

    test "普通玩家离座只清自己的座位" do
      game = seated([{"north", "p1"}, {"west", "p2"}])
      {:ok, game, events} = PigGame.leave(game, player("p2"))

      assert PigGame.pl_count(game) == 1
      assert PigGame.seat_of(game, "p2") == nil
      assert {:temp, "p2", nil} in events
      assert {:vision, "$N不想再拱了，站了起来！\n"} in events
    end

    test "桌长离座解散整桌并清掉所有人的座位" do
      game = seated([{"north", "p1"}, {"west", "p2"}, {"south", "p3"}])
      {:ok, game, events} = PigGame.leave(game, player("p1"))

      assert PigGame.pl_count(game) == 0
      assert game.server == nil
      assert game.stage == :initting
      assert {:temp, "p2", nil} in events
      assert {:temp, "p3", nil} in events
      assert {:vision, "桌长$N不想再拱下去了！\n"} in events
    end
  end

  # =========================================================================
  # 发牌 / 卖牌 / 停卖
  # =========================================================================

  describe "deal/2" do
    test "非桌长不能发牌" do
      game = %{four_players() | stage: :dealing}
      assert {:error, "你不是桌长！\n"} = PigGame.deal(game, player("p2"))
    end

    test "阶段不对不能发牌" do
      # 四人坐满但还没到发牌阶段（LPC PIG_DEALING）
      assert {:error, "现在不能发牌！\n"} =
               PigGame.deal(%{four_players() | stage: :initting}, player("p1"))
    end

    test "发牌后每家 13 张、共 52 张不重复，进入卖牌阶段" do
      game = %{four_players() | stage: :dealing}
      {:ok, game, events} = PigGame.deal(game, player("p1"))

      assert game.stage == :bidding
      assert game.bid_flag == 0
      assert game.allow_playbid == [1, 1, 1, 1]

      all =
        Enum.flat_map(@seats, fn seat ->
          cards = Map.get(game.cards, seat)
          assert length(cards) == 13
          assert cards == Enum.sort(cards)
          assert Map.get(game.card_count, seat) == 13
          cards
        end)

      assert length(Enum.uniq(all)) == 52

      # 每家都收到自己的手牌
      for seat <- @seats do
        id = game.pl[seat].id
        assert Enum.any?(events, &match?({:tell, ^id, "你得到的牌为：" <> _}, &1))
      end

      assert {:room, "发完牌了，有谁要卖牌的没有？\n"} in events
      assert {:room, "如果你卖完了牌，打一下 pass 。\n"} in events
    end
  end

  describe "bid/3（sell 同一实现）" do
    defp bidding_game(cards) do
      game_with(cards, stage: :bidding)
    end

    test "卖猪：bid_flag 置位、allow_playbid 关掉黑桃" do
      game =
        bidding_game(%{"north" => [@spig, 0], "west" => [13], "south" => [26], "east" => [39]})
      {:ok, game, events} = PigGame.bid(game, player("p1"), "sq")

      assert game.bid_flag == 1
      assert game.allow_playbid == [0, 1, 1, 1]
      assert game.bidcard_str == "黑桃Ｑ（P1）"
      assert {:vision, "$N说道：我卖黑桃Ｑ！\n"} in events
    end

    test "第二家卖牌时卖牌串用逗号分隔" do
      game =
        bidding_game(%{"north" => [@spig], "west" => [@hace], "south" => [26], "east" => [39]})
      {:ok, game, _} = PigGame.bid(game, player("p1"), "sq")
      {:ok, game, _} = PigGame.bid(game, player("p2"), "ha")

      assert game.bid_flag == 3
      assert game.bidcard_str == "红心Ａ（P2），黑桃Ｑ（P1）"
    end

    test "四种卖牌错误" do
      game =
        bidding_game(%{"north" => [@spig, 0], "west" => [13], "south" => [26], "east" => [39]})

      assert {:error, "你没有在拱猪！\n"} = PigGame.bid(game, player("px"), "sq")
      assert {:error, "你想卖什么？\n"} = PigGame.bid(game, player("p1"), "")
      assert {:error, "你手上没有这张牌！\n"} = PigGame.bid(game, player("p1"), "ha")
      assert {:error, "这张牌不能被卖！\n"} = PigGame.bid(game, player("p1"), "s2")

      {:ok, game, _} = PigGame.bid(game, player("p1"), "sq")
      assert {:error, "这张牌已经被卖过了！\n"} = PigGame.bid(game, player("p1"), "sq")

      # 阶段不对
      assert {:error, "现在不是卖牌的时候！\n"} =
               PigGame.bid(%{game | stage: :playing}, player("p1"), "sq")
    end
  end

  describe "pass/2" do
    test "四人全停卖后开拱，庄家先出" do
      game = game_with(%{"north" => [0], "west" => [13], "south" => [26], "east" => [39]},
        stage: :bidding
      )

      {:ok, game, events} = PigGame.pass(game, player("p1"))
      assert {:vision, "$N说道：我停卖！\n"} in events
      assert game.stage == :bidding

      {:ok, game, _} = PigGame.pass(game, player("p2"))
      {:ok, game, _} = PigGame.pass(game, player("p3"))
      {:ok, game, events} = PigGame.pass(game, player("p4"))

      assert game.stage == :playing
      assert game.round_no == 1
      assert game.round_order == ["north", "west", "south", "east"]
      assert PigGame.current_turn(game) == "north"
      assert {:room, "全部停卖，开拱！！\n"} in events
      assert {:room, "这把由P1先出。\n"} in events
      # 轮到庄家出牌，私发提示
      assert Enum.any?(events, &match?({:tell, "p1", _}, &1))
    end

    test "重复停卖与未入座" do
      game = game_with(%{"north" => [0]}, stage: :bidding)

      assert {:error, "你没有在拱猪！\n"} = PigGame.pass(game, player("px"))

      {:ok, game, _} = PigGame.pass(game, player("p1"))
      assert {:error, "你已经停卖了！\n"} = PigGame.pass(game, player("p1"))
    end
  end

  # =========================================================================
  # 出牌
  # =========================================================================

  describe "play/3" do
    test "出牌后手牌与计数同步，并私发牌桌视图" do
      game = game_with(%{"north" => [0, 1], "west" => [13], "south" => [26], "east" => [39]})
      {:ok, game, events} = PigGame.play(game, player("p1"), "s2")

      assert game.cards["north"] == [1]
      assert game.card_count["north"] == 1
      assert game.roundcards["north"] == 0
      assert game.roundcard_count == 1
      assert {:vision, "$N出了一张黑桃２！\n"} in events
      assert PigGame.current_turn(game) == "west"
    end

    test "没轮到你 / 阶段不对 / 牌不在手上" do
      game = game_with(%{"north" => [0], "west" => [13], "south" => [26], "east" => [39]})

      assert {:error, "你没有在拱猪！\n"} = PigGame.play(game, player("px"), "s2")
      assert {:error, "还没轮到你出牌！\n"} = PigGame.play(game, player("p2"), "h2")
      assert {:error, "你手里没有这张牌！\n"} = PigGame.play(game, player("p1"), "s3")
      assert {:error, "你要出哪张牌？\n"} = PigGame.play(game, player("p1"), "")

      assert {:error, "现在不是出牌阶段！\n"} =
               PigGame.play(%{game | stage: :bidding}, player("p1"), "s2")
    end

    test "有领出花色时必须跟牌" do
      # north 出黑桃，west 手里有黑桃却出红心 → 拒绝
      game = game_with(%{"north" => [0], "west" => [1, 13], "south" => [26], "east" => [39]})
      {:ok, game, _} = PigGame.play(game, player("p1"), "s2")

      assert {:error, "你不能出这张牌！\n"} = PigGame.play(game, player("p2"), "h2")
      assert {:ok, game, _} = PigGame.play(game, player("p2"), "s3")
      assert game.roundcard_count == 2
    end

    test "没有领出花色时允许垫牌，文案为「垫了一张」" do
      game = game_with(%{"north" => [0], "west" => [13], "south" => [26], "east" => [39]})
      {:ok, game, _} = PigGame.play(game, player("p1"), "s2")
      {:ok, _game, events} = PigGame.play(game, player("p2"), "h2")

      assert {:vision, "$N垫了一张红心２！\n"} in events
    end

    test "卖过的牌第一轮不能出" do
      game =
        game_with(%{"north" => [@spig, 0], "west" => [13], "south" => [26], "east" => [39]},
          allow_playbid: [0, 1, 1, 1]
        )

      assert {:error, "卖过的牌不能在第一轮出！\n"} = PigGame.play(game, player("p1"), "sq")
      assert {:ok, _game, _} = PigGame.play(game, player("p1"), "s2")
    end

    test "四张出完结算：最大者收特殊牌，下一轮由其领出" do
      game =
        game_with(
          %{"north" => [0, 1], "west" => [13, 14], "south" => [26, 27], "east" => [39, 40]},
          round_no: 1
        )

      {:ok, game, _} = PigGame.play(game, player("p1"), "s2")
      {:ok, game, _} = PigGame.play(game, player("p2"), "h2")
      {:ok, game, _} = PigGame.play(game, player("p3"), "d2")
      {:ok, game, events} = PigGame.play(game, player("p4"), "c2")

      # 领出花色黑桃最大的是 north 的 S2
      assert {:vision, "$N的黑桃２最大！\n"} in events
      # 红心２ 是特殊牌，归 north
      assert game.picks["north"] == [13]
      assert game.pick_count["north"] == 1
      assert game.round_no == 2
      assert game.roundcard_count == 0
      assert PigGame.current_turn(game) == "north"
    end

    test "领出牌型结算后解除该花色的卖牌限制" do
      game =
        game_with(
          %{"north" => [0], "west" => [13], "south" => [26], "east" => [39]},
          allow_playbid: [0, 1, 1, 1]
        )

      {:ok, game, _} = PigGame.play(game, player("p1"), "s2")
      {:ok, game, _} = PigGame.play(game, player("p2"), "h2")
      {:ok, game, _} = PigGame.play(game, player("p3"), "d2")
      {:ok, game, _} = PigGame.play(game, player("p4"), "c2")

      assert game.allow_playbid == [1, 1, 1, 1]
    end

    test "捡到猪：庄家换成收猪的人" do
      game =
        game_with(
          %{"north" => [0], "west" => [@spig], "south" => [26], "east" => [39]},
          round_no: 1
        )

      # north 出黑桃2，west 出黑桃Q（同花色，最大）→ west 收猪
      {:ok, game, _} = PigGame.play(game, player("p1"), "s2")
      {:ok, game, _} = PigGame.play(game, player("p2"), "sq")
      {:ok, game, _} = PigGame.play(game, player("p3"), "d2")
      {:ok, game, events} = PigGame.play(game, player("p4"), "c2")

      assert game.picks["west"] == [@spig]
      assert game.dealer == "west"
      assert {:vision, "$N得到了猪头！！\n"} in events
      assert Enum.any?(events, &match?({:room, "号外号外！" <> _}, &1))
    end
  end

  # =========================================================================
  # 一副牌结束（auto_play + after_hand）
  # =========================================================================

  describe "一手牌结束" do
    test "第 13 轮自动摊牌算分并回到发牌阶段" do
      # 每人剩 2 张，第 12 轮打完后 round_no == 12 触发 auto_play
      game =
        game_with(
          %{
            "north" => [0, 4],
            "west" => [13, 17],
            "south" => [26, 30],
            "east" => [39, 43]
          },
          round_no: 12,
          tscore: %{"north" => 0, "west" => 0, "south" => 0, "east" => 0}
        )

      {:ok, game, _} = PigGame.play(game, player("p1"), "s2")
      {:ok, game, _} = PigGame.play(game, player("p2"), "h2")
      {:ok, game, _} = PigGame.play(game, player("p3"), "d2")
      {:ok, game, events} = PigGame.play(game, player("p4"), "c2")

      # 结算后回到发牌阶段，等桌长 deal
      assert game.stage == :dealing
      assert {:room, "桌长请 deal ！\n"} in events
      assert Enum.any?(events, &match?({:room, "拱猪成绩表(Scoreboard)" <> _}, &1))
    end

    test "有人累计到 -1000 时总分清零并播报「是一头猪」" do
      game =
        game_with(
          %{"north" => [0, 4], "west" => [13, 17], "south" => [26, 30], "east" => [39, 43]},
          round_no: 12,
          tscore: %{"north" => -1000, "west" => 0, "south" => 0, "east" => 0}
        )

      {:ok, game, _} = PigGame.play(game, player("p1"), "s2")
      {:ok, game, _} = PigGame.play(game, player("p2"), "h2")
      {:ok, game, _} = PigGame.play(game, player("p3"), "d2")
      {:ok, game, events} = PigGame.play(game, player("p4"), "c2")

      assert Enum.any?(events, &match?({:room, "P1是一头猪！\n"}, &1))
      # 有人当猪 → 总分清零
      assert game.tscore == %{"north" => 0, "west" => 0, "south" => 0, "east" => 0}
    end
  end

  # =========================================================================
  # claim / skip / refresh
  # =========================================================================

  describe "claim/3" do
    test "发起全收后其他人收到私信" do
      game = game_with(%{"north" => [0], "west" => [13], "south" => [26], "east" => [39]})
      {:ok, game, events} = PigGame.claim(game, player("p1"), "")

      assert game.claimer == "north"
      assert game.agreed["north"] == 1
      assert {:tell, "p1", "你发出全收的要求！等待回音……\n"} in events
      assert Enum.any?(events, &match?({:tell, "p2", "P1认为他手中的牌都是大的了！" <> _}, &1))
    end

    test "全员同意后直接结算这一手" do
      game = game_with(%{"north" => [0], "west" => [13], "south" => [26], "east" => [39]})
      {:ok, game, _} = PigGame.claim(game, player("p1"), "")
      {:ok, game, _} = PigGame.claim(game, player("p2"), "yes")
      {:ok, game, _} = PigGame.claim(game, player("p3"), "yes")
      {:ok, game, events} = PigGame.claim(game, player("p4"), "yes")

      assert game.stage == :dealing
      assert Enum.any?(events, &match?({:room, "P1的要求被通过了！！\n"}, &1))
      # 手上与桌面上的特殊牌都归发起者（这里只有 west 的红心２）
      assert game.picks["north"] == [13]
    end

    test "有人否决则继续出牌" do
      game = game_with(%{"north" => [0], "west" => [13], "south" => [26], "east" => [39]})
      {:ok, game, _} = PigGame.claim(game, player("p1"), "")
      {:ok, game, events} = PigGame.claim(game, player("p2"), "no")

      assert game.claimer == ""
      assert game.agreed == %{"north" => 0, "west" => 0, "south" => 0, "east" => 0}
      assert Enum.any?(events, &match?({:room, "P2否决了P1的要求！！继续出牌！\n"}, &1))
    end

    test "未坐满 / 重复 claim / 无人发起" do
      game = game_with(%{"north" => [0]})

      assert {:error, "你没有在拱猪！\n"} = PigGame.claim(game, player("px"), "")

      short = %{game | pl: %{"north" => %{id: "p1", name: "P1"}}}
      assert {:error, "现在桌子上没坐满！\n"} = PigGame.claim(short, player("p1"), "")

      assert {:error, "没有人想全收！\n"} = PigGame.claim(game, player("p1"), "yes")

      {:ok, game, _} = PigGame.claim(game, player("p1"), "")
      assert {:error, "一次就够了！\n"} = PigGame.claim(game, player("p1"), "")
    end
  end

  describe "skip/2" do
    test "桌长跳过这副牌回到发牌" do
      game = game_with(%{"north" => [0]}, stage: :playing)
      {:ok, game, events} = PigGame.skip(game, player("p1"))

      assert game.stage == :dealing
      assert {:vision, "桌长$N决定跳过这副牌！！\n"} in events
      assert {:room, "桌长请 deal ！\n"} in events
    end

    test "非桌长 / 未入座 / 牌都没发" do
      game = game_with(%{"north" => [0]}, stage: :playing)

      assert {:error, "你没有在拱猪！\n"} = PigGame.skip(game, player("px"))
      assert {:error, "只有桌长才能跳过这副牌！\n"} = PigGame.skip(game, player("p2"))
      assert {:error, "牌都没有，跳什么？\n"} = PigGame.skip(%{game | stage: :dealing}, player("p1"))
    end
  end

  describe "refresh_hand/2" do
    test "私发手牌" do
      game = game_with(%{"north" => [0, 13]})
      {:ok, _game, events} = PigGame.refresh_hand(game, player("p1"))

      assert Enum.any?(events, &match?({:tell, "p1", "你手上有这些牌：\n" <> _}, &1))
    end

    test "没牌 / 未入座" do
      game = game_with(%{"north" => []})

      assert {:error, "你没有在拱猪！\n"} = PigGame.refresh_hand(game, player("px"))
      assert {:error, "你手上没有牌！\n"} = PigGame.refresh_hand(game, player("p1"))
    end
  end

  # =========================================================================
  # 渲染
  # =========================================================================

  describe "table_str/2" do
    test "非出牌阶段显示座位表与空位提示" do
      game = seated([{"north", "p1"}, {"west", "p2"}])
      text = PigGame.table_str(game, "")

      assert text =~ "这是一张专门用于拱猪的四方桌。"
      assert text =~ "没有人卖牌。"
      assert text =~ "北边的椅子上坐的是：P1(桌长)。"
      assert text =~ "西边的椅子上坐的是：P2。"
      assert text =~ "南边的椅子是空的。 想玩可用 sit south 坐上去。"
      assert text =~ "东边的椅子是空的。 想玩可用 sit east 坐上去。"
    end

    test "出牌阶段按观察者座位旋转牌桌视角" do
      game =
        game_with(
          %{"north" => [0], "west" => [13], "south" => [26], "east" => [39]},
          roundcards: %{"north" => 0, "west" => nil, "south" => nil, "east" => nil},
          roundcard_count: 1
        )

      # 北家视角：南家在上、北家在下
      north_view = PigGame.table_str(game, "north")
      assert north_view =~ "现在是第一轮，该由P2出牌。"
      assert north_view =~ "（P3）"
      assert north_view =~ "（P1）"

      # 东家视角：视角旋转后布局不同
      east_view = PigGame.table_str(game, "east")
      refute east_view == north_view
      assert east_view =~ "现在是第一轮，该由P2出牌。"
    end

    test "未入座看牌桌按北家视角" do
      # 北家手上没牌时，`table_str(game, "")` 与 `table_str(game, "north")` 完全一致
      # （LPC 只差在 `if (card_count[dir] > 0)` 那段手牌渲染）
      game = game_with(%{"north" => [], "west" => [13], "south" => [26], "east" => [39]})

      assert PigGame.table_str(game, "") == PigGame.table_str(game, "north")
    end

    test "捡牌记录出现在牌桌视图里" do
      game =
        game_with(
          %{"north" => [0], "west" => [13], "south" => [26], "east" => [39]},
          picks: %{"north" => [13], "west" => [], "south" => [], "east" => []},
          pick_count: %{"north" => 1, "west" => 0, "south" => 0, "east" => 0}
        )

      assert PigGame.table_str(game, "north") =~ "P1捡了下面这些牌："
    end
  end

  describe "scoreboard_str/1" do
    test "表头 + 每个座位一行 + 结尾分隔线" do
      game =
        game_with(
          %{"north" => [0]},
          hscore: %{"north" => -100, "west" => 0, "south" => 0, "east" => 0}
        )
      text = PigGame.scoreboard_str(game)

      assert text =~ "拱猪成绩表(Scoreboard)"
      assert text =~ "姓名"
      assert text =~ "P1"
      assert text =~ "-100"
      assert String.ends_with?(text, "－－－－－－－－－－－－－－－－－\n")
    end
  end

  describe "chinese_number/1" do
    test "1..10 中文数字，11..19 十X，其余回落数字" do
      assert PigGame.chinese_number(0) == "零"
      assert PigGame.chinese_number(1) == "一"
      assert PigGame.chinese_number(10) == "十"
      assert PigGame.chinese_number(11) == "十一"
      assert PigGame.chinese_number(13) == "十三"
      assert PigGame.chinese_number(20) == "20"
    end
  end
end
