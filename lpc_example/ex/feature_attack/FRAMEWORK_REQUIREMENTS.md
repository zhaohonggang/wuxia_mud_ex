# feature_attack Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used By |
|------------|-------------|---------|
| `Player.id/1` | Get player ID | `is_killing/2`, `kill_ob/3`, `want_kill/3` |
| `Player.name/1` | Get display name | `trigger_guarded_allies/3` |
| `Player.living?/1` | Check if alive | `fight_ob/3`, `kill_ob/3`, `trigger_guarded_allies/3` |
| `Player.is_player?/1` | Check if player | `trigger_guarded_allies/3` |
| `Player.is_guarder?/1` | Check if guarder | `fight_ob/3` |
| `Player.environment/1` | Get room | `fight_ob/3`, `kill_ob/3`, `trigger_guarded_allies/3` |
| `Player.this_player/0` | Get initiating player | `init/2` |
| `Player.entire_dbase/1` | Get full dbase | `init/2` |
| `Player.get_temp/2` / `put_temp/3` / `delete_temp/2` | Temp storage | `trigger_guarded_allies/3`, `reset_action/2` |
| `Player.set_heart_beat/2` | Enable heartbeat | `fight_ob/3` |
| `Player.get_temp/2` | Get temp | `reset_action/2` |
| `Player.set_temp/3` | Set temp | Not directly used |
| `Player.add_temp/3` | Increment temp | Not directly used |
| `Player.delete_temp/2` | Delete temp | `remove_all_enemy/3` |
| `Player.get_state/1` | Get player state | `trigger_guarded_allies/3` |
| `Player.set_state/2` | Update player state | Throughout |
| `Player.send_message/2` | Send message | `trigger_guarded_allies/3`, `kill_ob/3` |
| `Player.interactive?/1` | Check if player | `init/2` |
| `Player.is_guarder?/1` | Check guarder flag | `fight_ob/3` |
| `Player.faction/1` | Not directly used | - |

| Room Capability | Description | Used By |
|-----------------|-------------|---------|
| `Room.no_fight?/1` | Check no_fight flag | `fight_ob/3`, `kill_ob/3` |
| `Room.broadcast/3` | Broadcast message | Not directly used |

| Combat Capability | Description | Used By |
|-------------------|-------------|---------|
| `Combat.fight/2` | Process fight round | `attack/2`, `fight_ob/3` |
| `Combat.auto_fight/3` | Start auto-fight | `init/2` |

| Skill Capability | Description | Used By |
|------------------|-------------|---------|
| `Skill.get_prepared/1` | Get prepared skills | `reset_action/2` |
| `Skill.get_mapped/2` | Get mapped skill | `reset_action/2` |
| `Skill.get_level/2` | Get skill level | `reset_action/2` |
| `Skill.query_action/2` | Get skill action | `reset_action/2` |

| Item Capability | Description | Used By |
|-----------------|-------------|---------|
| `Item.get_skill_type/1` | Get weapon skill type | `reset_action/2` |
| `Item.get_actions/1` | Get item actions | `reset_action/2` |
| `Item.get_skill_type/1` | Get weapon skill type | `reset_action/2` |

| Room Capability | Description | Used By |
|-----------------|-------------|---------|
| `Room.broadcast/3` | Broadcast message | `trigger_guarded_allies/3` |

| Misc | Description | Used By |
|------|-------------|---------|
| `run_override/2` | Call override | `win/1`, `lost/1` |
| `:rand.uniform/1` | Random number | `trigger_guarded_allies/3` |

## Data Structures

### Attack State (per character)
```elixir
%{
  killer: ["player_id", ...],      # Active killers
  want_kills: ["player_id", ...],  # Want-to-kill list
  enemy: [enemy_obj, ...],         # Current combat enemies
  next_action: fn | map | nil,     # Next combat action
  default_object: obj | nil,       # Default action object
  default_function: str | nil,     # Default action function
  competitor: obj | nil            # Competition opponent
}
```

## Core Functions

### Enemy Management
- `fight_ob/3` - Start fight (adds to enemy list, reciprocal)
- `kill_ob/3` - Start killing (adds to killer, triggers guards)
- `clean_up_enemy/2` - Remove invalid enemies
- `select_opponent/2` - Random enemy selection
- `remove_enemy/3` - Remove single enemy
- `remove_killer/3` - Remove killer + enemy
- `remove_all_enemy/3` - Clear all enemies (optionally force)
- `remove_all_want/1` - Clear want_kills
- `remove_all_killer/1` - Clear all combat state

### Killer/Want System
- `is_killing/2` - Check if killing target
- `is_want_kill/2` - Check want-to-kill
- `want_kill/3` - Add to want_kills
- `update_killer/1` - Clean offline entries

### Combat Actions
- `attack/2` - Heartbeat attack (select opponent, call Combat.fight)
- `reset_action/2` - Recalculate action based on weapon/prepare
- `set_action/3` / `set_default_action/3` - Action management
- `query_action/2` - Get next action

### Competitor System
- `competition_with/3` - Start duel
- `query_competitor/1` / `set_competitor/2`
- `win/1` / `lost/1` - End competition

### Auto-fight (init/2)
- Hatred (player killing player)
- Vendetta (vendetta_mark match)
- Aggressive (NPC attitude)

### Guarded Allies
- `kill_ob` triggers `trigger_guarded_allies`
- Guarded allies join fight, may want_kill

## Data Flow

```
init() 
  → check hatred/vendetta/aggressive
  → Combat.auto_fight()

heart_beat()
  → attack()
    → clean_up_enemy()
    → select_opponent()
    → Combat.fight()

fight_ob()
  → add to enemy[]
  → reciprocal fight_ob()
  → if guarder & killing -> kill_enemy()

kill_ob()
  → check guarded
  → add to killer[]
  → trigger_guarded_allies()
  → fight_ob()
```

## Configuration

| Constant | Value | Description |
|----------|-------|-------------|
| `@max_opponents` | 4 | Max simultaneous enemies |

## Integration Notes

- Requires `Combat.fight/2` for actual combat resolution
- Requires `Combat.auto_fight/3` for auto-fight initiation
- Requires `run_override/2` for win/lost callbacks
- Requires `Room.broadcast/3` for guard messages
- Requires `Player.get_state/1` for accessing other player states
- State updates are functional (return new state)