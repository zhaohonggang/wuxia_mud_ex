# feature_damage Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used By |
|------------|-------------|---------|
| `Player.living?/1` | Check if character alive | `unconcious/2`, `die/3`, `heal_up/2` |
| `Player.is_wizard?/1` | Check wizard flag | `unconcious/2` |
| `Player.get_env/2` | Get environment variable | `unconcious/2` |
| `Player.query_competitor/1` | Get competition opponent | `unconcious/2`, `die/3` |
| `Player.is_killing?/2` | Check killing status | `unconcious/2` |
| `Player.win/1` / `Player.lost/1` | Competition result | `unconcious/2`, `die/3` |
| `Player.busy?/1` / `Player.interrupt_me/1` | Busy state | `unconcious/2`, `die/3` |
| `run_override/2` | Call override function | `unconcious/2`, `die/3` |
| `Player.remove_call_out/2` | Cancel scheduled callback | `revive/3` |
| `Player.environment/1` | Get current room | `revive/3` |
| `Player.move/2` | Move character | `revive/3` |
| `Player.delete/2` / `Player.delete_temp/2` | Delete variables | `revive/3`, `die/3` |
| `Player.put_temp/3` | Set temp variable | `revive/3`, `unconcious/2` |
| `Player.enable_player/1` / `Player.write_prompt/1` | Player state | `revive/3` |
| `Player.put/3` / `Player.get/2` | Variable access | Throughout |
| `Player.send_message/2` | Send message to player | `revive/3`, `heal_up/2` |
| `Player.is_player/1` | Check if player | `heal_up/2` |
| `Player.is_character/1` | Check if character | `revive/3` |
| `Player.environment/1` | Get room | `revive/3`, `heal_up/2` |
| `Room.is_chat_room/1` | Check chat room | `heal_up/2` |
| `Room.broadcast/3` | Broadcast message | Not directly used |
| `Player.set_heart_beat/2` | Enable heartbeat | `receive_damage/5`, `receive_wound/5` |
| `Player.add_temp/3` / `Player.put_temp/3` | Temp variables | `heal_up/2`, `unconcious/2` |

| Skill Capability | Description | Used By |
|------------------|-------------|---------|
| `Skill.get_level/2` | Get skill level | `heal_up/2` (force) |
| `Skill.can_improve?/2` | Not directly used | - |

| Combat Capability | Description | Used By |
|-------------------|-------------|---------|
| `Combat.announce/2` | Broadcast event | `revive/3`, `unconcious/2`, `die/3` |
| `Combat.fight/2` | Not directly used | - |

| Character Capability | Description | Used By |
|----------------------|-------------|---------|
| `Player.is_wizard?/1` | Wizard check | `unconcious/2` |
| `Player.is_player/1` | Player check | `heal_up/2` |
| `Player.is_character/1` | Character check | `revive/3` |

## Data Structures

### Damage State (per character)
```elixir
%{
  last_damage_from: pid | nil,
  last_damage_name: str | nil,
  defeated_by: pid | nil,
  defeated_by_who: str | nil,
  ghost: boolean,
  defeat_player: [pid, ...]  # DPS tracking
}
```

## Core Functions

### 1. receive_damage/5 - Apply Damage
```elixir
receive_damage(type, damage, who)
```
- Validates type ("jing" or "qi") and damage >= 0
- Tracks last_damage_from/name
- If who && damage > 150: improve_craze(damage/5)
- current - damage, min 0
- Sets heartbeat

### 2. receive_wound/5 - Apply Wound (eff_*)
```elixir
receive_wound(type, damage, who)
```
- Similar to damage but affects `eff_jing`/`eff_qi`
- If who && damage > 150: improve_craze(damage/3)
- eff_* = max(0, eff_* - damage)
- current_* = min(current_*, new_eff_*)
- Sets heartbeat

### 3. receive_heal/4 - Heal HP
```elixir
receive_heal(type, heal)
```
- Validates type, heal >= 0
- current = min(eff_*, current + heal)

### 4. receive_curing/4 - Cure Wounds (eff_*)
```elixir
receive_curing(type, heal)
```
- Validates type, heal >= 0
- eff_* = min(max_*, eff_* + heal)
- Returns actual healed amount

### 5. DPS Tracking
```elixir
dps_count() -> count of living defeated players
record_dp(ob) -> add to defeat_player if want_kill
remove_dp(ob) -> remove from list (nil = clear all)
```

### 6. unconcious/2 - Knock Out
```elixir
unconcious()
```
- Check wizard/immortal
- Competition handling (win/lost)
- Interrupt if busy
- Run override
- Handle death tracking:
  - last_damage_from -> defeated_by/who
  - DPS recording for user kills
  - craze_of_defeated
- Clear enemies, block messages, disable player
- Set jing/qi = 0, block_msg/all = 1
- Schedule revive (30 + random(100 - con))
- COMBAT_D.announce("unconcious")
- player_escape check
- UPDATE_D.global_destruct_player

### 7. revive/3 - Wake Up
```elixir
revive(quiet)
```
- Remove revive callback
- Find valid room (exit character chain)
- Move to room if needed
- Clear disable_type, block_msg/all
- Enable player, write prompt
- Clear defeated_by DP
- If not quiet: clear defeated_by, announce revive, message
- Clear last_damage_from/name

### 8. die/3 - Death
```elixir
die(killer)
```
- Clear sleep flags
- Competition handling
- Interrupt if busy
- Run override
- Handle death tracking:
  - Determine killer/killer_name
  - direct_die flag (if already unconcious -> revive(1))
  - If direct_die && killer -> COMBAT_D.winner_reward
  - Handle mount dismount
  - Set die_reason (based on damage_type)
  - player_escape check
  - COMBAT_D.announce("dead")
  - Set my_killer temp
  - COMBAT_D.killer_reward(killer, player)
  - UPDATE_D.global_destruct_player
  - combat/dietimes++
  - CHAR_D.make_corpse
  - Clear defeated_by/killer
  - Remove all killers
  - If player:
    - Interrupt if busy
    - jing/qi/eff_jing/eff_qi = 1
    - ghost = true
    - Move to DEATH_ROOM
    - DEATH_ROOM.start_death
    - clear die_reason
    - craze_of_die
  - Else: destruct

### 9. reincarnate/2 - Resurrection
```elixir
reincarnate()
```
- ghost = false
- eff_jing = max_jing, eff_qi = max_qi

### 9. Capacity Calculations
```elixir
max_food_capacity() -> str*10 + 100 + bonuses
max_water_capacity() -> str*10 + 100 + bonuses
```
Bonuses: skybook tianshu2 +300, greedy +500

### 10. heal_up/2 - Heartbeat Recovery
```elixir
heal_up()
```
- Clear nopoison temp
- Prison handling
- Scale: living=1, user=4, NPC=8
- Food/water consumption (non-user or specific conditions)
- Guard duty jing drain + messages
- Jing recovery: (con + max_jingli/10)/scale
- Qi recovery: (con*2 + max_neili/20)/scale (if not busy)
- Jingli recovery: con + force/6
- Neili recovery: con*2 + force/3

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| Revive delay | 30 + random(100 - con) | Seconds until auto-revive |
| Craze from damage | damage/5 | receive_damage > 150 |
| Craze from wound | damage/3 | receive_wound > 150 |
| Food/Water base | str*10 + 100 | Base capacity |
| Skybook bonus | +300 | skybook/item/tianshu2 |
| Greedy bonus | +500 | special_skill/greedy |

## Integration Notes

- Requires `Combat.announce/2` for death/unconcious/revive messages
- Requires `player_escape/2` for death protection
- Requires `UPDATE_D.global_destruct_player/2` for cleanup
- Requires `CHAR_D.make_corpse/2` for corpse creation
- Requires `DEATH_ROOM.start_death/1` for death processing
- Requires `craze_of_defeated/dead` for PK tracking
- Requires `improve_craze/2` for combat rage
- Heartbeat calls `heal_up/2` automatically
- `receive_damage/wound` trigger `set_heart_beat(true)`