# inherit_room_pigroom Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used By |
|------------|-------------|---------|
| `Room.add_action/2` | Register custom verbs (sit/leave/deal/bid/pass/play/refresh/skip/claim) | Room init |
| `Room.tell_room/2` | Broadcast to all players in room | deal/play/round messages |
| `Room.message_vision/1` | Vision message | do_sit/do_play/after_winner |
| `Player.get_temp/2` / `set_temp/3` / `delete_temp/2` | Player's `pigging_seat` | do_sit/do_leave/do_play |
| `Player.query_ip_number/1` | Same-IP check | do_sit |
| `Room.pig_server/1` (PIG_D) | Card engine: shuffle, deal, sort, card_str, refresh | deal/play/table_str |
| `PIG_D.card_cmp4/2` | Determine round winner among 4 cards | after_round/after_hand |
| `PIG_D.count_score/2` | Score picks against bid flags | after_hand |
| `PIG_D.is_special/1` | Detect special ("Pig" scoring) cards | after_claim/after_winner |
| `PIG_D.has_suit/4` | Whether hand has a given suit | do_play |
| `PIG_D.is_validcard/1` / `is_validbid/1` / `has_card/3` | Card validation | do_bid/do_play |
| `PIG_D.order_turn/1` | Rotation order from dealer | round_init/do_sit |
| `CHANNEL_D.do_channel/3` | rumor channel broadcasts | after_winner/after_hand |
| `Channel.broadcast/3` | Equivalent rumor channel | after_winner/after_hand |

## Card Model

Assumed card layout (pig.h / PIG_D convention, not present in repo):
```
card  0..51
suit = card div 13:  0=♠黑桃 1=♥红桃 2=♦方块 3=♣梅花
rank = card rem 13
special scoring cards (拱猪): 猪头(黑桃Q)、红桃/变压器等由 PIG_D 定义
```

## Room State Machine (portable core ported to .ex)

```
initting -> dealing -> bidding -> playing(i=1..13 rounds) -> after_hand -> dealing
```

Key self-contained functions ported:
- `deal/1` — deal 52 cards 4 per round, sort each hand
- `suit/1` — card -> suit
- `valid_play?/3` — turn order / has-card / suit-following / sold-first-round
- `apply_play/3` — execute a play, mutate hand/round/roundcard_count
- `valid_bid/5` — bid-phase dedup (`bid_flag` bitmask) + hand check
- `valid_seat?/1`, `sit/3`, `leave/2`
- `table_str/2`, `scoreboard_str/1`, `pl_count/1`, `name_of/2`
- `valid_phase?/1`

## Core Algorithms

### 1. do_play / valid_play? — Card Play Validation
```elixir
reject if:
  - not seated, phase != :playing
  - turn != round_order[roundcard_count]
  - card not in hand
follow-suit: if roundcard_count > 0 AND lead suit fixed AND
             player holds lead suit AND played suit != lead suit  -> reject
sold-lead:   if roundcard_count == 0 AND allow_playbid[suit(card)] == 0 -> reject
```

### 2. do_bid / valid_bid — Selling Dedup
```elixir
b = PIG_D.is_validbid(card)        # 0 = not sellable
reject if b == 0 or (bid_flag & b) != 0 or card not in hand
bid_flag |= b
allow_playbid[SUIT of b] = 0       # that suit can't lead first round
```

### 3. bidding -> playing (do_pass)
All 4 players pass -> `play_init`: dealer leads round 1; `round_order = order_turn(dealer)`.

### 4. after_round / after_winner
Winner = `card_cmp4(roundcards, lead_suit)`; collect special cards into picks;
猪头 (SPIG) winner becomes new dealer; hearts/diamonds/clubs specials feed scoring.

### 5. after_hand — Scoring
`hscore = PIG_D.count_score(picks, bid_flag)`; sum into tscore;
`tscore <= -1000` => 猪 (pig) head; those who became pigs award `feed-power`
skill to the rest; score_reset then back to :dealing.

## Integration Notes

- This is a **framework room mixin** (multi-player card game room), C-tier.
- The card engine (`PIG_D` shuffle/cmp4/count_score) is external and must be
  provided by the framework; this module ports the self-contained validation,
  phase transitions, turn order, and display logic.
- Requires `Room.add_action` verb registration + `Player` temp-state + same-IP
  filtering for real play.
- Smoke tests: `smoke_test.exs` (36 cases, all PASS) cover suit/deal/
  valid_play (follow-suit, sold-lead) / apply_play / valid_bid / sit/leave.
