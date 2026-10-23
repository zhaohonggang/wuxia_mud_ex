defmodule Kantele.World.PigGame do
  @moduledoc """
  拱猪（Pig）牌局：纯逻辑状态机 + 牌面工具。

  移植自 LPC：

  - `adm/daemons/pigd.c`（`PIG_D`）—— 牌面字符串、发牌、比大小、算分
  - `inherit/room/pigroom.c`（`PIG_ROOM`）—— 座位 / 阶段 / 出牌流程
  - `d/city/{eproom,nproom,sproom,wproom}.c` —— 四间拱猪房（仅 `look_table`）

  ## 与 LPC 的映射

  LPC 把牌局状态存在房间对象的私有变量里（`pig_stage`/`pl`/`cards`/…）。
  本移植把整份状态收进**一个 map**，由 `Kantele.World.Room.put_state_by_id/3`
  存在房间 `state["pig_game"]`（仅内存，不落库）。

  座位归属同时写进**玩家** `meta.temp["pigging_seat"]`（对应 LPC
  `set_temp("pigging_seat", ...)`），`look_table` 与 `valid_leave` 都读它。

  ## 阶段（对应 `PIG_INITTING` … `PIG_PLAYING`）

      :initting -> :dealing -> :bidding -> :playing -> (:dealing …)

  ## 牌编码（与 LPC 完全一致）

  0..51；`suit = div(card, 13)`（0 黑桃 / 1 红心 / 2 方块 / 3 梅花），
  `rank = rem(card, 13)`（0..12 = 2,3,4,5,6,7,8,9,10,J,Q,K,A）。

  特殊牌：猪 = 黑桃Q = 10、羊 = 方块J = 35、变压器 = 梅花10 = 47、红心A = 25。

  ## 事件（返回值）

  所有动作返回 `{:ok, game, events}` 或 `{:error, message}`。`events` 由调用方
  （`RoomActions.City.PigRoom`）落到真实世界：

  - `{:vision, text}` —— 房间 `message_vision`（`$N` = 行动者）
  - `{:room, text}` —— 房间 `tell_room`（纯文本，名字已内联）
  - `{:tell, player_id, text}` —— 私发某玩家（`tell_object`）
  - `{:temp, player_id, seat_or_nil}` —— 设置/清除 `pigging_seat`

  ## 与 LPC 的呈现差异（仅文案，不影响牌局）

  - 座位行不显示 `query("id")`：本移植的玩家 id 是内部 `player:<uuid>`，
    直接展示没有意义（LPC 显示的是拼音登录名，用于同名区分）。
  - 出牌区未出牌的位置显示 `-`（LPC 传 -1 给 `card_str` 得到空串）。
  """
  import Bitwise, only: [band: 2, bor: 2]

  @seats ["north", "west", "south", "east"]

  @suit_char ["S", "H", "D", "C"]
  @suit_str ["黑桃", "红心", "方块", "梅花"]
  @rank_char ["2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"]
  @rank_str ["２", "３", "４", "５", "６", "７", "８", "９", "⒑", "Ｊ", "Ｑ", "Ｋ", "Ａ"]

  # 红心各点数的分值（索引 = rank）
  @heart_score [0, 0, 0, -10, -10, -10, -10, -10, -10, -20, -30, -40, -50]

  @heart 1

  @spig 10
  @hace 25
  @dsheep 35
  @ctrans 47

  @bid_spig 1
  @bid_hace 2
  @bid_dsheep 4
  @bid_ctrans 8

  @chinese_seat %{
    "north" => "北边",
    "west" => "西边",
    "south" => "南边",
    "east" => "东边"
  }

  def seats, do: @seats
  def spig, do: @spig
  def hace, do: @hace
  def dsheep, do: @dsheep
  def ctrans, do: @ctrans

  # ===========================================================================
  # 牌面工具（PIG_D）
  # ===========================================================================

  @doc "花色：0 黑桃 / 1 红心 / 2 方块 / 3 梅花。"
  def suit(card), do: div(card, 13)

  @doc "点数索引：0..12 对应 2,3,4,5,6,7,8,9,10,J,Q,K,A。"
  def rank(card), do: rem(card, 13)

  @doc """
  `PIG_D->is_validcard/1`：把 `"S2"`/`"hA"` 解析成 0..51，非法返回 `-1`。

  LPC 用 `capitalize` 归一大小写，这里用 `String.upcase/1`。
  """
  def is_validcard(str) when is_binary(str) do
    case String.upcase(str) do
      <<s::binary-size(1), r::binary-size(1)>> ->
        st = Enum.find_index(@suit_char, &(&1 == s))
        rk = Enum.find_index(@rank_char, &(&1 == r))

        if is_integer(st) and is_integer(rk), do: st * 13 + rk, else: -1

      _ ->
        -1
    end
  end

  def is_validcard(_), do: -1

  @doc "`PIG_D->is_validbid/1`：卖牌位掩码（0 = 不能卖）。"
  def is_validbid(@spig), do: @bid_spig
  def is_validbid(@hace), do: @bid_hace
  def is_validbid(@dsheep), do: @bid_dsheep
  def is_validbid(@ctrans), do: @bid_ctrans
  def is_validbid(_), do: 0

  @doc "`PIG_D->is_special/1`：猪 / 羊 / 变压器 / 全部红心。"
  def is_special(card) do
    card in [@spig, @dsheep, @ctrans] or suit(card) == @heart
  end

  @doc "`PIG_D->card_str/1`：`\"黑桃Ｑ\"` 这类中文牌面。"
  def card_str(card) when is_integer(card) and card >= 0 and card <= 51 do
    Enum.at(@suit_str, suit(card)) <> Enum.at(@rank_str, rank(card))
  end

  def card_str(_), do: ""

  @doc "`PIG_D->refresh/3`：一手牌按花色分行（同花色点数空格分隔，18 空格缩进）。"
  def refresh(cards) when is_list(cards) do
    cards
    |> Enum.filter(&(is_integer(&1) and &1 >= 0 and &1 <= 51))
    |> Enum.sort()
    |> Enum.chunk_by(&suit/1)
    |> Enum.map_join("", fn chunk ->
      s = suit(hd(chunk))
      ranks = Enum.map_join(chunk, " ", &Enum.at(@rank_str, rank(&1)))
      String.duplicate(" ", 18) <> Enum.at(@suit_str, s) <> "：" <> ranks <> " \n"
    end)
  end

  def refresh(_), do: ""

  @doc "`PIG_D->has_suit/4`：手里某花色的张数。"
  def has_suit(cards, s), do: Enum.count(cards, &(suit(&1) == s))

  @doc "`PIG_D->has_card/4`：手里是否有这张牌。"
  def has_card(cards, card), do: card in cards

  @doc "洗牌。"
  def new_deck, do: Enum.shuffle(Enum.to_list(0..51))

  @doc "`PIG_D->order_turn/1`：以 `rw` 为起点的出手顺序（北→西→南→东）。"
  def order_turn("east"), do: ["east", "north", "west", "south"]
  def order_turn("north"), do: ["north", "west", "south", "east"]
  def order_turn("west"), do: ["west", "south", "east", "north"]
  def order_turn(_), do: ["south", "east", "north", "west"]

  @doc "`PIG_D->card_cmp4/2`：`s` 花色最大者所在座位。"
  def card_cmp4(roundcards, s) do
    Enum.reduce(@seats, nil, fn seat, best ->
      card = Map.get(roundcards, seat)

      cond do
        not is_integer(card) or card < 0 -> best
        suit(card) != s -> best
        is_nil(best) -> seat
        card > Map.get(roundcards, best, -1) -> seat
        true -> best
      end
    end)
  end

  @doc """
  `PIG_D->count_score/2`：按捡到的牌算分（支持单猪）。

  16 张特殊牌全收 = 1000；单猪 -100（卖过 -200）；13 张红心 200（卖过 400）；
  变压器 50（卖过 100）；羊 100（卖过 200）；其余按红心表累加再乘变压器倍数。
  """
  def count_score(picks, bid_flag) do
    cl =
      picks
      |> Enum.filter(fn c -> c in [@spig, @dsheep, @ctrans] or suit(c) == @heart end)
      |> Enum.sort()

    pc = length(cl)

    cond do
      pc == 16 ->
        1000

      pc == 1 and hd(cl) == @spig ->
        if band(bid_flag, @bid_spig) != 0, do: -200, else: -100

      pc == 13 and hd(cl) >= 13 and List.last(cl) <= 25 ->
        if band(bid_flag, @bid_hace) != 0, do: 400, else: 200

      pc == 1 and hd(cl) == @ctrans ->
        if band(bid_flag, @bid_ctrans) != 0, do: 100, else: 50

      pc == 1 and hd(cl) == @dsheep ->
        if band(bid_flag, @bid_dsheep) != 0, do: 200, else: 100

      true ->
        {score, doubler, hearts} =
          Enum.reduce(cl, {0, 1, 0}, fn card, {acc, mult, hearts} ->
            cond do
              card >= 13 and card <= 25 ->
                base = Enum.at(@heart_score, rem(card, 13))
                base = if band(bid_flag, @bid_hace) != 0, do: base * 2, else: base
                {acc + base, mult, hearts + 1}

              card == @spig ->
                {acc + if(band(bid_flag, @bid_spig) != 0, do: -200, else: -100), mult, hearts}

              card == @dsheep ->
                {acc + if(band(bid_flag, @bid_dsheep) != 0, do: 200, else: 100), mult, hearts}

              card == @ctrans ->
                {acc, if(band(bid_flag, @bid_ctrans) != 0, do: 4, else: 2), hearts}

              true ->
                {acc, mult, hearts}
            end
          end)

        all_hearts =
          if hearts == 13 do
            if band(bid_flag, @bid_hace) != 0, do: 800, else: 400
          else
            0
          end

        (score + all_hearts) * doubler
    end
  end

  # ===========================================================================
  # 状态
  # ===========================================================================

  @doc "初始牌局状态（对应 LPC `pig_init()`，`pl` 为空）。"
  def new do
    %{
      stage: :initting,
      round_no: 0,
      roundcard_count: 0,
      round_order: [],
      bid_flag: 0,
      bidcard_str: "",
      server: nil,
      dealer: "north",
      pl: %{},
      cards: seats_map([]),
      card_count: seats_map(0),
      roundcards: seats_map(nil),
      picks: seats_map([]),
      pick_count: seats_map(0),
      passed: seats_map(0),
      agreed: seats_map(0),
      hscore: seats_map(0),
      tscore: seats_map(0),
      allow_playbid: [1, 1, 1, 1],
      claimer: ""
    }
  end

  defp seats_map(value), do: Map.new(@seats, fn seat -> {seat, value} end)

  @doc "已入座人数。"
  def pl_count(game), do: map_size(game.pl)

  @doc "玩家所在座位；未入座返回 `nil`。"
  def seat_of(game, player_id) do
    Enum.find_value(@seats, fn seat ->
      case Map.get(game.pl, seat) do
        %{id: ^player_id} -> seat
        _ -> nil
      end
    end)
  end

  @doc "座位玩家信息；空位返回 `nil`。"
  def player_at(game, seat), do: Map.get(game.pl, seat)

  @doc "座位玩家名；空位回落到中文方位。"
  def name_of(game, seat) do
    case Map.get(game.pl, seat) do
      %{name: name} when is_binary(name) and name != "" -> name
      _ -> chinese_seat(seat)
    end
  end

  @doc "座位中文名。"
  def chinese_seat(seat), do: Map.get(@chinese_seat, seat, seat)

  @doc "当前该谁出牌。"
  def current_turn(game), do: Enum.at(game.round_order, game.roundcard_count)

  # ===========================================================================
  # 坐下 / 离座
  # ===========================================================================

  @doc "`do_sit`：坐下。`player` 为 `%{id: , name: }`。"
  def sit(game, player, seat) do
    cond do
      seat not in @seats ->
        {:error, "你想坐在哪里？\n"}

      game.server == player.id ->
        {:error, "桌长不能换坐位！\n"}

      true ->
        # LPC 先 `map_delete(pl, me->query_temp("pigging_seat"))` 再判断目标位是否有人，
        # 目标位被占时直接 `notify_fail` 返回 —— 此时玩家已从 pl 里被删掉、temp 却还
        # 留着（原版 bug）。本实现失败一律返回 `{:error, msg}` 且**不落库**
        # （调用方只在 `{:ok, ...}` 时写回房间状态），等价于整笔操作回滚。
        game = remove_player(game, player.id)

        if occupied?(game, seat) do
          {:error, "这个位子上已经有人了！\n"}
        else
          do_sit(game, player, seat)
        end
    end
  end

  defp do_sit(game, player, seat) do
    {game, events} =
      if pl_count(game) == 0 do
        {%{new() | server: player.id, dealer: seat, round_order: order_turn(seat)},
         [{:tell, player.id, "你现在是桌长！\n"}]}
      else
        {game, []}
      end

    game = %{game | pl: Map.put(game.pl, seat, %{id: player.id, name: player.name})}

    events =
      events ++
        [
          {:vision, "$N坐上了#{chinese_seat(seat)}的位子。\n"},
          {:temp, player.id, seat}
        ]

    case pl_count(game) do
      3 ->
        {:ok, game, events ++ [{:room, "现在是三缺一，你们只再需要一个玩家就可以开拱了！\n"}]}

      4 ->
        game = %{game | stage: :dealing}

        {:ok, game,
         events ++
           [
             {:room, "好，人凑齐了！\n"},
             {:room, scoreboard_str(game)},
             {:room, "桌长请 deal ！\n"}
           ]}

      _ ->
        {:ok, game, events}
    end
  end

  defp occupied?(game, seat) do
    is_map(Map.get(game.pl, seat))
  end

  defp remove_player(game, player_id) do
    case seat_of(game, player_id) do
      nil -> game
      seat -> %{game | pl: Map.delete(game.pl, seat)}
    end
  end

  @doc "`do_leave`：离座；桌长离座则整桌解散。"
  def leave(game, player) do
    cond do
      seat_of(game, player.id) == nil ->
        {:error, "你现在没有在拱猪！\n"}

      game.server == player.id ->
        events =
          [{:vision, "桌长$N不想再拱下去了！\n"}] ++
            Enum.flat_map(@seats, fn seat ->
              case Map.get(game.pl, seat) do
                %{id: id, name: name} -> [{:room, "#{name}站了起来。\n"}, {:temp, id, nil}]
                _ -> []
              end
            end)

        {:ok, new(), events}

      true ->
        {:ok, remove_player(game, player.id),
         [{:vision, "$N不想再拱了，站了起来！\n"}, {:temp, player.id, nil}]}
    end
  end

  # ===========================================================================
  # 发牌 / 卖牌 / 停卖
  # ===========================================================================

  @doc "`do_deal`：桌长发牌。"
  def deal(game, player) do
    cond do
      player.id != game.server ->
        {:error, "你不是桌长！\n"}

      game.stage != :dealing or pl_count(game) != 4 ->
        {:error, "现在不能发牌！\n"}

      true ->
        cards = assign_cards(new_deck())

        game = %{
          game
          | cards: cards,
            card_count: seats_map(13),
            stage: :bidding,
            bid_flag: 0,
            bidcard_str: "",
            allow_playbid: [1, 1, 1, 1],
            passed: seats_map(0),
            roundcards: seats_map(nil),
            roundcard_count: 0
        }

        tells =
          Enum.flat_map(@seats, fn seat ->
            case Map.get(game.pl, seat) do
              %{id: id} -> [{:tell, id, "你得到的牌为：\n" <> refresh(Map.get(cards, seat))}]
              _ -> []
            end
          end)

        {:ok, game,
         tells ++
           [
             {:room, "发完牌了，有谁要卖牌的没有？\n"},
             {:room, "如果你卖完了牌，打一下 pass 。\n"}
           ]}
    end
  end

  # LPC：for i in 0..12, for j in 0..3: cards[seat[j]][i] = newcards[k++]
  # 即四家轮流各拿一张，拿完各自排序。
  defp assign_cards(deck) do
    @seats
    |> Enum.with_index()
    |> Map.new(fn {seat, idx} ->
      cards =
        deck
        |> Enum.with_index()
        |> Enum.filter(fn {_card, pos} -> rem(pos, 4) == idx end)
        |> Enum.map(fn {card, _pos} -> card end)
        |> Enum.sort()

      {seat, cards}
    end)
  end

  @doc "`do_bid` / `do_sell`：卖牌。"
  def bid(game, player, arg) do
    seat = seat_of(game, player.id)

    cond do
      seat == nil ->
        {:error, "你没有在拱猪！\n"}

      game.stage != :bidding ->
        {:error, "现在不是卖牌的时候！\n"}

      arg in [nil, ""] ->
        {:error, "你想卖什么？\n"}

      true ->
        card = is_validcard(arg)
        hand = Map.get(game.cards, seat, [])
        mask = is_validbid(card)

        cond do
          card == -1 or not has_card(hand, card) ->
            {:error, "你手上没有这张牌！\n"}

          mask == 0 ->
            {:error, "这张牌不能被卖！\n"}

          band(game.bid_flag, mask) != 0 ->
            {:error, "这张牌已经被卖过了！\n"}

          true ->
            idx =
              case mask do
                @bid_spig -> 0
                @bid_hace -> 1
                @bid_dsheep -> 2
                @bid_ctrans -> 3
              end

            allow = List.replace_at(game.allow_playbid, idx, 0)
            sep = if game.bidcard_str == "", do: "", else: "，"
            bid_str = card_str(card) <> "（" <> player.name <> "）" <> sep <> game.bidcard_str

            {:ok,
             %{
               game
               | bid_flag: bor(game.bid_flag, mask),
                 allow_playbid: allow,
                 bidcard_str: bid_str
             }, [{:vision, "$N说道：我卖" <> card_str(card) <> "！\n"}]}
        end
    end
  end

  @doc "`do_pass`：停卖；四人全停则开打。"
  def pass(game, player) do
    seat = seat_of(game, player.id)

    cond do
      seat == nil ->
        {:error, "你没有在拱猪！\n"}

      game.stage != :bidding ->
        {:error, "你想干什么？\n"}

      Map.get(game.passed, seat, 0) == 1 ->
        {:error, "你已经停卖了！\n"}

      true ->
        passed = Map.put(game.passed, seat, 1)
        game = %{game | passed: passed}
        events = [{:vision, "$N说道：我停卖！\n"}]

        if Enum.all?(@seats, &(Map.get(passed, &1, 0) == 1)) do
          game = play_init(%{game | passed: seats_map(0)})

          {:ok, game,
           events ++
             [
               {:room, "全部停卖，开拱！！\n"},
               {:room, "这把由" <> name_of(game, game.dealer) <> "先出。\n"}
             ] ++ round_prompt(game)}
        else
          {:ok, game, events}
        end
    end
  end

  defp play_init(game) do
    game
    |> Map.merge(%{
      stage: :playing,
      round_no: 1,
      picks: seats_map([]),
      pick_count: seats_map(0),
      claimer: "",
      agreed: seats_map(0)
    })
    |> round_init(game.dealer)
  end

  defp round_init(game, rw) do
    %{game | roundcards: seats_map(nil), roundcard_count: 0, round_order: order_turn(rw)}
  end

  defp round_prompt(game) do
    case game.round_order do
      [first | _] ->
        case Map.get(game.pl, first) do
          %{id: id} -> [{:tell, id, refresh(Map.get(game.cards, first, [])) <> "现在轮到你出牌！\n"}]
          _ -> []
        end

      _ ->
        []
    end
  end

  # ===========================================================================
  # 出牌
  # ===========================================================================

  @doc "`do_play`：出牌。"
  def play(game, player, arg) do
    seat = seat_of(game, player.id)

    cond do
      seat == nil ->
        {:error, "你没有在拱猪！\n"}

      game.stage != :playing ->
        {:error, "现在不是出牌阶段！\n"}

      current_turn(game) != seat ->
        {:error, "还没轮到你出牌！\n"}

      arg in [nil, ""] ->
        {:error, "你要出哪张牌？\n"}

      true ->
        card = is_validcard(arg)
        hand = Map.get(game.cards, seat, [])

        cond do
          card == -1 ->
            {:error, "你要出哪张牌？\n"}

          not has_card(hand, card) ->
            {:error, "你手里没有这张牌！\n"}

          follow_suit_violation?(game, hand, card) ->
            {:error, "你不能出这张牌！\n"}

          sold_card_violation?(game, hand, card) ->
            {:error, "卖过的牌不能在第一轮出！\n"}

          true ->
            apply_play(game, seat, card)
        end
    end
  end

  defp lead_card(game) do
    case Enum.at(game.round_order, 0) do
      nil -> nil
      lead -> Map.get(game.roundcards, lead)
    end
  end

  defp follow_suit_violation?(game, hand, card) do
    lead = lead_card(game)

    if game.roundcard_count > 0 and is_integer(lead) and lead >= 0 do
      has_suit(hand, suit(lead)) > 0 and suit(card) != suit(lead)
    else
      false
    end
  end

  # LPC：`if (roundcard_count == 0 || sc > 1)` —— 第一张牌，或手里还有不止一张本门花色时，
  # 卖过的牌不许先出。
  defp sold_card_violation?(game, hand, card) do
    lead = lead_card(game)

    sc =
      if is_integer(lead) and lead >= 0 do
        has_suit(hand, suit(lead))
      else
        0
      end

    if game.roundcard_count == 0 or sc > 1 do
      case card do
        @spig -> Enum.at(game.allow_playbid, 0) == 0
        @hace -> Enum.at(game.allow_playbid, 1) == 0
        @dsheep -> Enum.at(game.allow_playbid, 2) == 0
        @ctrans -> Enum.at(game.allow_playbid, 3) == 0
        _ -> false
      end
    else
      false
    end
  end

  defp apply_play(game, seat, card) do
    hand = List.delete(Map.get(game.cards, seat, []), card)
    lead = lead_card(game)

    padded =
      game.roundcard_count > 0 and is_integer(lead) and lead >= 0 and suit(card) != suit(lead)

    game = %{
      game
      | cards: Map.put(game.cards, seat, hand),
        card_count: Map.update!(game.card_count, seat, &(&1 - 1)),
        roundcards: Map.put(game.roundcards, seat, card),
        roundcard_count: game.roundcard_count + 1
    }

    event =
      if padded do
        {:vision, "$N垫了一张" <> card_str(card) <> "！\n"}
      else
        {:vision, "$N出了一张" <> card_str(card) <> "！\n"}
      end

    tells =
      Enum.flat_map(@seats, fn s ->
        case Map.get(game.pl, s) do
          %{id: id} ->
            if Map.get(game.card_count, s, 0) > 0, do: [{:tell, id, table_str(game, s)}], else: []

          _ ->
            []
        end
      end)

    if game.roundcard_count > 3 do
      after_round(game, [event] ++ tells)
    else
      {:ok, game, [event] ++ tells}
    end
  end

  defp after_round(game, events) do
    lead = lead_card(game)

    if is_integer(lead) and lead >= 0 do
      s = suit(lead)
      game = %{game | allow_playbid: List.replace_at(game.allow_playbid, s, 1)}
      winner = card_cmp4(game.roundcards, s)
      {game, winner_events} = after_winner(game, winner)
      game = round_init(game, winner)
      round_no = game.round_no
      game = %{game | round_no: round_no + 1}
      events = events ++ winner_events ++ round_prompt(game)

      if round_no == 12 do
        auto_play(game, events)
      else
        {:ok, game, events}
      end
    else
      {:ok, game, events}
    end
  end

  defp after_winner(game, nil), do: {game, []}

  defp after_winner(game, winner) do
    card = Map.get(game.roundcards, winner)
    events = [{:vision, "$N的" <> card_str(card) <> "最大！\n"}]

    Enum.reduce(@seats, {game, events}, fn seat, {g, evs} ->
      seat_card = Map.get(g.roundcards, seat)

      if is_integer(seat_card) and seat_card >= 0 and is_special(seat_card) do
        g = %{
          g
          | picks: Map.update!(g.picks, winner, fn list -> Enum.sort([seat_card | list]) end),
            pick_count: Map.update!(g.pick_count, winner, &(&1 + 1))
        }

        if seat_card == @spig do
          g = %{g | dealer: winner}

          {g,
           evs ++
             [
               {:vision, "$N得到了猪头！！\n"},
               {:room, "号外号外！" <> name_of(g, winner) <> "喜得猪头！\n"}
             ]}
        else
          {g, evs}
        end
      else
        {g, evs}
      end
    end)
  end

  defp auto_play(game, events) do
    roundcards =
      Map.new(@seats, fn seat ->
        case Map.get(game.cards, seat, []) do
          [first | _] -> {seat, first}
          _ -> {seat, nil}
        end
      end)

    game = %{game | roundcards: roundcards, roundcard_count: 4, card_count: seats_map(0)}

    tells =
      Enum.flat_map(@seats, fn seat ->
        case Map.get(game.pl, seat) do
          %{id: id} -> [{:tell, id, table_str(game, seat)}]
          _ -> []
        end
      end)

    events = events ++ tells
    lead = lead_card(game)

    if is_integer(lead) and lead >= 0 do
      {game, winner_events} = after_winner(game, card_cmp4(roundcards, suit(lead)))
      after_hand(game, events ++ winner_events)
    else
      after_hand(game, events)
    end
  end

  defp after_hand(game, events) do
    hscore =
      Map.new(@seats, fn seat ->
        if Map.has_key?(game.pl, seat) do
          {seat, count_score(Map.get(game.picks, seat, []), game.bid_flag)}
        else
          {seat, Map.get(game.hscore, seat, 0)}
        end
      end)

    game = %{game | hscore: hscore}
    collect_all = Enum.find(@seats, fn seat -> Map.get(hscore, seat, 0) == 1000 end)

    events =
      if collect_all do
        events ++ [{:room, name_of(game, collect_all) <> "全收了！\n"}]
      else
        events
      end

    game =
      if collect_all == nil do
        tscore =
          Map.new(@seats, fn seat ->
            {seat, Map.get(game.tscore, seat, 0) + Map.get(hscore, seat, 0)}
          end)

        %{game | tscore: tscore}
      else
        game
      end

    pigs =
      Enum.filter(@seats, fn seat ->
        Map.has_key?(game.pl, seat) and Map.get(game.tscore, seat, 0) <= -1000
      end)

    events = events ++ Enum.map(pigs, fn seat -> {:room, name_of(game, seat) <> "是一头猪！\n"} end)

    # LPC 只有「有人当了猪」（tscore <= -1000）时才 `score_reset()` 把总分清零；
    # 没人当猪时总分要一直累加（成绩表的「总分」列就是这个累计值）。
    # LPC 同时在此时给其余人 `improve_skill("feed-power", 10000 * pig)`，见 TODO。
    game =
      if pigs == [] do
        %{game | stage: :dealing}
      else
        %{game | tscore: seats_map(0), stage: :dealing}
      end

    {:ok, game,
     events ++
       [
         {:room, scoreboard_str(game)},
         {:room, "桌长请 deal ！\n"}
       ]}
  end

  @doc "`do_refresh`：看自己手上的牌。"
  def refresh_hand(game, player) do
    seat = seat_of(game, player.id)

    cond do
      seat == nil ->
        {:error, "你没有在拱猪！\n"}

      Map.get(game.card_count, seat, 0) < 1 ->
        {:error, "你手上没有牌！\n"}

      true ->
        {:ok, game,
         [{:tell, player.id, "你手上有这些牌：\n" <> refresh(Map.get(game.cards, seat, []))}]}
    end
  end

  @doc "`do_skip`：桌长跳过这副牌（重新发牌）。"
  def skip(game, player) do
    cond do
      seat_of(game, player.id) == nil ->
        {:error, "你没有在拱猪！\n"}

      player.id != game.server ->
        {:error, "只有桌长才能跳过这副牌！\n"}

      game.stage in [:initting, :dealing] ->
        {:error, "牌都没有，跳什么？\n"}

      true ->
        events = [{:vision, "桌长$N决定跳过这副牌！！\n"}]

        if pl_count(game) == 4 do
          game = %{game | stage: :dealing}
          {:ok, game, events ++ [{:room, scoreboard_str(game)}, {:room, "桌长请 deal ！\n"}]}
        else
          {:ok, game, events}
        end
    end
  end

  @doc "`do_claim`：全收（`claim` / `claim yes` / `claim no`）。"
  def claim(game, player, arg) do
    seat = seat_of(game, player.id)

    cond do
      seat == nil ->
        {:error, "你没有在拱猪！\n"}

      pl_count(game) != 4 ->
        {:error, "现在桌子上没坐满！\n"}

      game.stage != :playing ->
        {:error, "你想干什么？\n"}

      game.claimer == seat ->
        {:error, "一次就够了！\n"}

      arg in [nil, ""] ->
        if game.claimer != "" do
          {:error, "claim yes|no ？\n"}
        else
          game = %{game | claimer: seat, agreed: Map.put(game.agreed, seat, 1)}

          tells =
            Enum.flat_map(@seats, fn s ->
              case Map.get(game.pl, s) do
                %{id: id} when s != seat ->
                  [{:tell, id,
                    player.name <>
                      "认为他手中的牌都是大的了！\n" <>
                      refresh(Map.get(game.cards, seat, [])) <>
                      "请用 claim yes 通过，或者 claim no 否决。\n"}]

                _ ->
                  []
              end
            end)

          {:ok, game, [{:tell, player.id, "你发出全收的要求！等待回音……\n"} | tells]}
        end

      arg == "yes" ->
        cond do
          game.claimer == "" ->
            {:error, "没有人想全收！\n"}

          Map.get(game.agreed, seat, 0) == 1 ->
            {:error, "你已经同意了！\n"}

          true ->
            game = %{game | agreed: Map.put(game.agreed, seat, 1)}

            if Enum.all?(@seats, &(Map.get(game.agreed, &1, 0) == 1)) do
              after_claim(game, [
                {:room, name_of(game, game.claimer) <> "的要求被通过了！！\n"}
              ])
            else
              {:ok, game,
               [
                 {:room,
                  name_of(game, seat) <> "同意" <> name_of(game, game.claimer) <> "的牌都是大的了！\n"}
               ]}
            end
        end

      arg == "no" ->
        if game.claimer == "" do
          {:error, "没有人想全收！\n"}
        else
          claimer_name = name_of(game, game.claimer)
          game = %{game | claimer: "", agreed: seats_map(0)}

          {:ok, game,
           [{:room, name_of(game, seat) <> "否决了" <> claimer_name <> "的要求！！继续出牌！\n"}]}
        end

      true ->
        {:error, "claim 什么？\n"}
    end
  end

  defp after_claim(game, events) do
    claimer = game.claimer

    round_picks =
      @seats
      |> Enum.map(fn seat -> Map.get(game.roundcards, seat) end)
      |> Enum.filter(&(is_integer(&1) and &1 >= 0 and is_special(&1)))

    hand_picks =
      @seats
      |> Enum.flat_map(fn seat -> Map.get(game.cards, seat, []) end)
      |> Enum.filter(&(is_integer(&1) and &1 >= 0 and is_special(&1)))

    picks = Enum.sort(round_picks ++ hand_picks)
    count = length(picks)

    game = %{
      game
      | picks: Map.put(game.picks, claimer, picks),
        pick_count: Map.put(game.pick_count, claimer, count),
        cards: seats_map([]),
        card_count: seats_map(0)
    }

    after_hand(game, events)
  end

  # ===========================================================================
  # 渲染
  # ===========================================================================

  @doc "`look_table`：牌桌视图。`seat` 为观察者座位，`\"\"` 表示未入座。"
  def table_str(game, seat) do
    if game.stage == :playing and pl_count(game) == 4 do
      render_playing(game, seat)
    else
      render_seats(game)
    end
  end

  defp render_seats(game) do
    status =
      Enum.map_join(@seats, "", fn seat ->
        case Map.get(game.pl, seat) do
          %{name: name, id: id} ->
            suffix = if game.server == id, do: "(桌长)", else: ""
            "#{chinese_seat(seat)}的椅子上坐的是：#{name}#{suffix}。\n"

          _ ->
            "#{chinese_seat(seat)}的椅子是空的。 想玩可用 sit #{seat} 坐上去。\n"
        end
      end)

    sold = if game.bidcard_str == "", do: "没有人卖牌。\n", else: "卖了的牌：#{game.bidcard_str}\n"

    "这是一张专门用于拱猪的四方桌。\n" <> sold <> status
  end

  defp render_playing(game, seat) do
    order = order_turn(if seat in @seats, do: seat, else: "north")
    [s0, s1, s2, s3] = order

    intro =
      if game.roundcard_count < 4 do
        "现在是第#{chinese_number(game.round_no)}轮，该由#{name_of(game, current_turn(game))}出牌。\n"
      else
        ""
      end

    sold = if game.bidcard_str == "", do: "没有人卖牌。\n", else: "卖了的牌：#{game.bidcard_str}\n"

    cards =
      String.duplicate(" ", 24) <> "（#{name_of(game, s2)}）\n" <>
        (String.duplicate(" ", 26) <> round_card_str(game, s2) <> "\n") <>
        (String.duplicate(" ", 4) <>
           "（#{name_of(game, s3)}）" <>
           String.duplicate(" ", 16) <>
           round_card_str(game, s3) <>
           String.duplicate(" ", 6) <>
           round_card_str(game, s1) <> "（#{name_of(game, s1)}）\n") <>
        (String.duplicate(" ", 26) <> round_card_str(game, s0) <> "\n") <>
        (String.duplicate(" ", 24) <> "（#{name_of(game, s0)}）\n")

    hand =
      if seat in @seats and Map.get(game.card_count, seat, 0) > 0 do
        refresh(Map.get(game.cards, seat, []))
      else
        ""
      end

    intro <> sold <> cards <> hand <> picks_str(game)
  end

  defp round_card_str(game, seat) do
    case Map.get(game.roundcards, seat) do
      card when is_integer(card) and card >= 0 -> card_str(card)
      _ -> "-"
    end
  end

  defp picks_str(game) do
    Enum.map_join(@seats, "", fn seat ->
      case Map.get(game.pl, seat) do
        %{name: name} ->
          if Map.get(game.pick_count, seat, 0) > 0 do
            name <> "捡了下面这些牌：\n" <> refresh(Map.get(game.picks, seat, []))
          else
            ""
          end

        _ ->
          ""
      end
    end)
  end

  @doc "`look_scoreboard`：成绩表。"
  def scoreboard_str(game) do
    header =
      "拱猪成绩表(Scoreboard)\n－－－－－－－－－－－－－－－－－\n姓名　　　　　　　　盘分　　　总分\n－－－－－－－－－－－－－－－－－\n"

    rows =
      Enum.map_join(@seats, "", fn seat ->
        case Map.get(game.pl, seat) do
          %{name: name} ->
            pad = String.duplicate("　", max(0, 7 - String.length(name)))

            name <>
              pad <>
              String.pad_leading(to_string(Map.get(game.hscore, seat, 0)), 10) <>
              String.pad_leading(to_string(Map.get(game.tscore, seat, 0)), 10) <> "\n"

          _ ->
            ""
        end
      end)

    header <> rows <> "－－－－－－－－－－－－－－－－－\n"
  end

  @doc "1..13 的中文数字（LPC `chinese_number`）。"
  def chinese_number(n) when is_integer(n) and n >= 0 and n <= 10 do
    Enum.at(~w(零 一 二 三 四 五 六 七 八 九 十), n)
  end

  def chinese_number(n) when is_integer(n) and n > 10 and n < 20 do
    "十" <> chinese_number(n - 10)
  end

  def chinese_number(n) when is_integer(n), do: to_string(n)
end
