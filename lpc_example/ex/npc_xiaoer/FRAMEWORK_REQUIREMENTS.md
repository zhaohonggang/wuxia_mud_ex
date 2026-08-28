# npc_xiaoer Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used By |
|------------|-------------|---------|
| `Player.add_temp/3` / `get_temp/2` | Temporary player storage | `handle_money/2` (rent_paid) |
| `Room.move_object/2` | Move objects between rooms | `handle_corpse/2`, `handle_drop/2`, `heart_beat/0` |
| `Item.is_currency?/1` | Check if item is money | `accept_object/2` |
| `Item.is_corpse?/1` | Check if item is corpse | `accept_object/2`, `handle_drop/2` |
| `Item.currency_amount/1` | Get money value | `handle_money/2` |
| `Item.create/1` | Create item from template | `exchange/2` |
| `Player.give_item/2` | Give item to player | `exchange/2` |
| `Player.points/1` | Get player points | `check_points/2`, `exchange/2` |
| `Player.add_points/2` | Deduct/add points | `exchange/2` |
| `Room.get_objects/1` | List objects in room | `heart_beat/0` |
| `Player.is_player?/1` | Check if object is player | `heart_beat/0` |
| `Player.is_idle?/1` | Check if player is idle | `heart_beat/0` |
| `Room.move_object/2` | Move player/object | `heart_beat/0` |

## Event Flow

```
Player enters room
  → greet() → random welcome message

Player gives money
  → accept_object() → handle_money() → set rent_paid temp

Player gives corpse
  → accept_object() → handle_corpse() → move to discard_room

Player drops corpse
  → handle_drop() → move to discard_room

Player: "exchange blood_bodhi"
  → exchange() → check_points() → deduct points → give item

Heartbeat (periodic)
  → heart_beat() → scan main_hall → move idle players to outside
```

## Data Structures

### NPC Data
```elixir
%{
  id: "xiaoer",
  name: "Waiter",
  greetings: [...],
  exchange_items: %{
    "blood_bodhi" => [cost: 5, item: "pill/puti1", name: "Blood Bodhi"],
    ...
  }
}
```

### Exchange Items
| Key | Cost | Item Template | Display Name |
|-----|------|---------------|--------------|
| blood_bodhi | 5 | pill/puti1 | Blood Bodhi |
| sarira | 5 | pill/sheli1 | Sarira |
| haotian_fruit | 5 | pill/linghui1 | Haotian Fruit |
| bone_strength | 5 | gift/con1 | Bone Strength Powder |
| longevity_paste | 5 | gift/dex1 | Longevity Paste |
| wisdom_pill | 5 | gift/int1 | Wisdom Pill |
| strength_pill | 5 | gift/str1 | Strength Pill |
| rebirth_pill | 50 | gift/con3 | Rebirth Pill |

### Player Temp Storage
- `rent_paid` - Amount of money given for room rent

## Configuration

| Constant | Value | Description |
|----------|-------|-------------|
| `@greetings` | List | 4 random welcome messages |
| `@exchange_items` | Map | 8 redeemable items with costs |

## Integration Notes

- Requires `Room.move_object/2` for corpse disposal and idle player removal
- Requires `Player.add_temp/3` for rent tracking
- Requires points system (`Player.points/1`, `add_points/2`)
- Requires corpse detection (`Item.is_corpse?/1`)
- Heartbeat runs periodically (configurable interval)
- Exchange items created via `Item.create/1` from template IDs