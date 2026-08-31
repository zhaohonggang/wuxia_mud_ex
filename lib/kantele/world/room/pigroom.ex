defmodule Kantele.World.Room.Pigroom do
  @moduledoc """
  拱猪房（对应 ExKantele.World.Room.BasePigRoom / inherit_room_pigroom.ex）

  功能：
  - 拱猪牌局状态机（:initting -> :dealing -> :bidding -> :playing）
  - 座位管理（north/west/south/east）
  - 发牌、叫牌、出牌校验
  - 牌局显示
  """
  require Bitwise
  alias Kantele.World.Room
  alias Kantele.Scheduler

  @seats ["north", "west", "south", "east"]
  @phases [:initting, :dealing, :bidding, :playing]

  @chinese_seat %{
    "north" => "北边",
    "west" => "西边",
    "south" => "南边",
    "east" => "东边"
  }

  defstruct [
    :id,
    :key,
    :zone_id,
    :name,
    :description,
    :map_color,
    :map_icon,
    :x,
    :y,
    :z,
    exits: [],
    features: [],
    flags: [],
    # 拱猪专用字段
    phase: :initting,
    round_no: 0,
    roundcards: %{},
    roundcard_count: 0,
    round_order: [],
    cards: %{"north" => [], "west" => [], "south" => [], "east" => []},
    card_count: %{"north" => 0, "west" => 0, "south" => 0, "east" => 0},
    bidcard_str: "",
    allow_playbid: [1, 1, 1, 1],
    pl: %{}
  ]

  @doc "初始化拱猪房状态"
  def init_room do
    %{
      phase: :initting,
      round_no: 0,
      roundcards: %{"north" => 0, "west" => 0, "south" => 0, "east" => 0},
      roundcard_count: 0,
      round_order: [],
      cards: %{"north" => [], "west" => [], "south" => [], "east" => []},
      card_count: %{"north" => 0, "west" => 0, "south" => 0, "east" => 0},
      bidcard_str: "",
      allow_playbid: [1, 1, 1, 1],
      pl: %{}
    }
  end

  @doc "初始化 52 张牌"
  def new_deck, do: Enum.to_list(0..51)

  @doc "初始化四人手牌"
  def init_hands, do: %{"north" => [], "west" => [], "south" => [], "east" => []}

  @doc "发牌：把洗好的牌按顺序发给四个座位，再各自排序"
  def deal(newcards) do
    hands =
      @seats
      |> Enum.with_index()
      |> Map.new(fn {seat, s} ->
        {seat,
         newcards
         |> Enum.with_index()
         |> Enum.filter(fn {_, i} -> rem(i, 4) == s end)
         |> Enum.map(&elem(&1, 0))}
      end)

    Map.new(hands, fn {seat, cards} -> {seat, Enum.sort(cards)} end)
  end

  @doc "牌 -> 花色"
  def suit(card), do: div(card, 13)

  @doc "发牌入口：洗牌 -> 发牌 -> 更新状态 -> 进入叫牌阶段"
  def do_deal(room, dealer) do
    cond do
      room.phase != :dealing ->
        {:error, "现在不是发牌阶段"}

      room.seats["dealer"] != dealer ->
        {:error, "只有庄家可以发牌"}

      true ->
        deck = new_deck() |> Enum.shuffle()
        cards = deal(deck)
        round_order = order_turn(room.seats["dealer"])

        new_room = %{
          room
          | phase: :bidding,
            round_no: room.round_no + 1,
            cards: deal(deck),
            card_count: %{"north" => 13, "west" => 13, "south" => 13, "east" => 13},
            round_order: round_order,
            roundcards: %{"north" => 0, "west" => 0, "south" => 0, "east" => 0},
            roundcard_count: 0,
            bidcard_str: "",
            allow_playbid: [1, 1, 1, 1]
        }

        {:ok, new_room,
         [
           %{
             type: :vision,
             target: :room,
             text: "庄家 #{dealer} 发牌完毕，进入叫牌阶段。"
           }
         ]}
    end
  end

  @doc "叫牌"
  def bid(room, player, card) do
    cond do
      room.phase != :bidding ->
        {:error, "现在不是叫牌阶段"}

      room.pl[player.id] == nil ->
        {:error, "你没有坐在牌桌上"}

      true ->
        # 这里需要根据牌的卖牌位掩码判断
        {:ok, room,
         [
           %{
             type: :vision,
             target: :room,
             text: "#{player.name} 叫了牌。"
           }
         ]}
    end
  end

  @doc "出牌"
  def play(room, player, card) do
    cond do
      room.phase != :playing ->
        {:error, "现在不是出牌阶段"}

      room.pl[player.id] == nil ->
        {:error, "你没有坐在牌桌上"}

      true ->
        case valid_play?(room, player, card) do
          {:error, msg} ->
            {:error, msg}

          :ok ->
            room = apply_play(room, player, card)

            {:ok, room,
             [
               %{
                 type: :vision,
                 target: :room,
                 text: "Player #{player.name} plays card #{card}."
               }
             ]}
        end
    end
  end

  @doc "坐下"
  def sit(room, player, seat) do
    cond do
      not valid_seat?(seat) ->
        {:error, "无效座位"}

      room.seats[seat] != nil ->
        {:error, "座位已被占用"}

      player.id in Map.values(room.seats) ->
        {:error, "你已经坐在另一位置了"}

      true ->
        new_room = %{room | seats: Map.put(room.seats, seat, player.id)}

        {:ok, new_room,
         [
           %{
             type: :vision,
             target: :room,
             text: "#{player.name} 在 #{seat} 位坐下了。"
           }
         ]}
    end
  end

  @doc "离座"
  def leave(room, player) do
    seat = Enum.find(Map.keys(room.seats), fn seat -> room.seats[seat] == player.id end)

    if seat do
      new_room = %{room | seats: Map.put(room.seats, seat, nil)}

      {:ok, new_room,
       [
         %{
           type: :vision,
           target: :room,
           text: "#{player.name} 站了起来。"
         }
       ]}
    else
      {:error, "你没坐在牌桌上"}
    end
  end

  @doc "显示牌桌"
  def table_str(room, _dir \\ "north") do
    phase = room.phase

    if phase == :playing and pl_count(room) == 4 do
      order = room.round_order
      rc = room.roundcards

      intro =
        if room.roundcard_count < 4 do
          now = Enum.at(order, room.roundcard_count)
          "现在是第#{room.round_no}轮，该由#{name_of(room, now)}出牌。"
        else
          ""
        end

      sold =
        if room.bidcard_str == "" do
          "没有人卖牌。"
        else
          "卖了的牌：" <> room.bidcard_str
        end

      Enum.join(
        [
          intro,
          sold,
          "      （" <> name_of(room, Enum.at(order, 2)) <> "）",
          card_text(room.roundcards, Enum.at(order, 2)),
          card_row(room, order),
          card_text(room.roundcards, Enum.at(order, 0)),
          "      （" <> name_of(room, Enum.at(order, 0)) <> "）"
        ],
        "\n"
      )
    else
      status =
        Enum.reduce(@seats, "", fn seat, acc ->
          cond do
            not Map.has_key?(room.pl, seat) ->
              acc <> "#{chinese_seat(seat)}的椅子是空的。 想玩可用 sit #{seat} 坐上去。\n"

            room.pl[seat] == room.server ->
              acc <> "#{chinese_seat(seat)}的椅子上坐的是：#{name_of(room, seat)}(桌长)。\n"

            true ->
              acc <> "#{chinese_seat(seat)}的椅子上坐的是：#{name_of(room, seat)}。\n"
          end
        end)

      "这是一张专门用于拱猪的四方桌。\n" <> status
    end
  end

  # ==================== 内部辅助 ====================

  @seats ["north", "west", "south", "east"]
  @chinese_seat %{
    "north" => "北边",
    "west" => "西边",
    "south" => "南边",
    "east" => "东边"
  }

  defp valid_seat?(arg), do: arg in @seats

  defp order_turn(dealer) do
    idx = Enum.find_index(@seats, &(&1 == dealer))
    Enum.slice(@seats, idx..-1) ++ Enum.take(@seats, idx)
  end

  defp pl_count(state), do: state.pl |> Map.keys() |> length()

  defp following_lead_suit?(state, dir, card) do
    lead_suit = suit(Map.get(state.roundcards, Enum.at(state.round_order, 0)))

    Enum.any?(state.cards[dir], fn c -> suit(c) == lead_suit end) and
      suit(card) != lead_suit
  end

  defp following_card_sold?(state, _dir, card) do
    flag = Enum.at(state.allow_playbid, suit(card), 1)
    flag == 0
  end

  defp apply_play(state, dir, card) do
    cards = %{state.cards | dir => List.delete(state.cards[dir], card)}

    %{
      state
      | cards: cards,
        roundcards: Map.put(state.roundcards, dir, card),
        card_count: Map.update!(state.card_count, dir, &(&1 - 1)),
        roundcard_count: state.roundcard_count + 1
    }
  end

  defp name_of(state, dir) when is_binary(dir) do
    case Map.get(state.pl, dir) do
      nil -> @chinese_seat[dir]
      name when is_binary(name) -> name
      _ -> @chinese_seat[dir]
    end
  end

  defp card_row(state, order) do
    l = name_of(state, Enum.at(order, 3))
    r = name_of(state, Enum.at(order, 1))
    c3 = card_text(state.roundcards, Enum.at(order, 3))
    c1 = card_text(state.roundcards, Enum.at(order, 1))
    "    #{"（" <> l <> "）"}        #{c3}        #{c1} #{"（" <> r <> "）"}"
  end

  defp card_text(roundcards, dir), do: Map.get(roundcards, dir, "-")

  @doc "获取座位中文名"
  def chinese_seat(seat), do: Map.get(@chinese_seat, seat, seat)

  @doc "出牌合法性校验"
  def valid_play?(room, player, card) do
    cond do
      room.phase != :playing ->
        {:error, "现在不是出牌阶段"}

      room.pl[player.id] == nil ->
        {:error, "你没有坐在牌桌上"}

      Enum.at(room.round_order, room.roundcard_count) != player.id ->
        {:error, "还没轮到你出牌！"}

      card < 0 or card > 51 ->
        {:error, "你要出哪张牌？"}

      not Enum.member?(room.cards[player.id], card) ->
        {:error, "你手里没有这张牌！"}

      true ->
        cond do
          room.roundcard_count > 0 and following_lead_suit?(room, player.id, card) ->
            {:error, "你不能出这张牌！"}

          room.roundcard_count == 0 and following_card_sold?(room, player.id, card) ->
            {:error, "卖过的牌不能在第一轮出！"}

          true ->
            :ok
        end
    end
  end
end
