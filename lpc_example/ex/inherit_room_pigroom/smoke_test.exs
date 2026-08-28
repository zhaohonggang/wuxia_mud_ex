alias ExKantele.World.Room.BasePigRoom, as: P

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

# suit
ok.("suit0", P.suit(0), 0)
ok.("suit12", P.suit(12), 0)
ok.("suit13", P.suit(13), 1)
ok.("suit51", P.suit(51), 3)

# new_deck / deal
deck = P.new_deck()
ok.("deck_len", length(deck), 52)
hands = P.deal(Enum.to_list(0..51))
ok.("hands_keys", Map.keys(hands) |> Enum.sort(), ["east", "north", "south", "west"])
Enum.each(hands, fn {seat, cards} ->
  ok.("hand_count_#{seat}", length(cards), 13)
end)
ok.("hand_sorted", hands["north"], Enum.sort(hands["north"]))

# empty state
base = %{
  phase: :dealing, pl: %{}, server: nil, round_no: 1, roundcard_count: 0,
  round_order: ["north", "west", "south", "east"],
  roundcards: %{}, cards: P.init_hands(), card_count: %{}, bidcard_str: "",
  allow_playbid: [1, 1, 1, 1]
}

# pl_count
ok.("pl_count_empty", P.pl_count(base), 0)
full = %{base | pl: %{"north" => "A", "west" => "B", "south" => "C", "east" => "D"}}
ok.("pl_count_full", P.pl_count(full), 4)

# valid_play
play_state = %{
  full
  | phase: :playing,
    roundcard_count: 0,
    round_order: ["north", "west", "south", "east"],
    cards: %{"north" => [0, 1, 2], "west" => [13], "south" => [26], "east" => [39]},
    card_count: %{"north" => 3, "west" => 1, "south" => 1, "east" => 1},
    roundcards: %{}
}

# wrong phase
ok.("play_not_turn", P.valid_play?(%{play_state | phase: :bidding}, "north", 0), {:error, "现在不是出牌阶段！"})
# not your turn
ok.("play_wrong_seat", P.valid_play?(play_state, "west", 13), {:error, "还没轮到你出牌！"})
# not in hand
ok.("play_no_card", P.valid_play?(play_state, "north", 13), {:error, "你手里没有这张牌！"})
# valid first play (no lead suit yet)
ok.("play_ok_first", P.valid_play?(play_state, "north", 0), :ok)

# apply_play
after_play = P.apply_play(play_state, "north", 0)
ok.("apply_remove_card", after_play.cards["north"], [1, 2])
ok.("apply_roundcard", after_play.roundcards["north"], 0)
ok.("apply_count", after_play.card_count["north"], 2)
ok.("apply_rc_count", after_play.roundcard_count, 1)

# suit-following: north led spade(0); west holds spade+heart -> cannot play heart
follow_state = %{play_state | roundcard_count: 1, roundcards: %{"north" => 0}, round_order: ["north", "west", "south", "east"], cards: %{play_state.cards | "west" => [0, 13]}}
ok.("play_follow_must", P.valid_play?(follow_state, "west", 13), {:error, "你不能出这张牌！"})
# west with no spade may play off-suit
follow0 = %{play_state | roundcard_count: 1, roundcards: %{"north" => 0}, round_order: ["north", "west", "south", "east"], cards: %{play_state.cards | "west" => [13]}}
ok.("play_no_lead_suit", P.valid_play?(follow0, "west", 13), :ok)
# west with spade plays spade -> ok
follow2 = %{play_state | roundcard_count: 1, roundcards: %{"north" => 0}, round_order: ["north", "west", "south", "east"], cards: %{play_state.cards | "west" => [0, 13]}}
ok.("play_follow_ok", P.valid_play?(follow2, "west", 0), :ok)

# already-sold suit cannot be led first round: north leads heart (13) when heart sold (allow_playbid[1]==0)
sold_state = %{play_state | cards: %{play_state.cards | "north" => [0, 13]}, allow_playbid: [1, 0, 1, 1]}
ok.("play_sold_lead", P.valid_play?(sold_state, "north", 13), {:error, "卖过的牌不能在第一轮出！"})
ok.("play_unsold_lead", P.valid_play?(sold_state, "north", 0), :ok)

# valid_bid dedup
bid_state = %{full | phase: :bidding, cards: %{"north" => [1, 2]}}
ok.("bid_ok", P.valid_bid(bid_state, "north", 1, 0, 4), :ok)
ok.("bid_dup", P.valid_bid(bid_state, "north", 1, 4, 4), {:error, "这张牌已经被卖过了！"})
ok.("bid_not_sellable", P.valid_bid(bid_state, "north", 1, 0, 0), {:error, "这张牌不能被卖！"})
ok.("bid_wrong_phase", P.valid_bid(%{bid_state | phase: :playing}, "north", 1, 0, 4), {:error, "现在不是卖牌的时候！"})

# valid_seat
ok.("seat_ok", P.valid_seat?("north"), true)
ok.("seat_bad", P.valid_seat?("up"), false)

# sit / leave
s1 = P.sit(%{full | pl: %{}}, "A", "north")
ok.("sit_pl", s1.pl["north"], "A")
ok.("sit_server", s1.server, "A")
s2 = P.leave(s1, "north")
ok.("leave", P.pl_count(s2), 0)

# phases
ok.("phase_ok", P.valid_phase?(:playing), true)
ok.("phase_bad", P.valid_phase?(:x), false)
