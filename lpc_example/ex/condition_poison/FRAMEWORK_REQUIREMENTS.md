# condition_poison Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used By |
|------------|-------------|---------|
| `Player.alive?/1` | Check if character alive | `update_condition/2` |
| `Player.jing/1` / `qi/1` / `eff_jing/1` / `eff_qi/1` | Get vitals | `update_condition/2` |
| `Player.receive_damage/3` | Apply damage | `update_condition/2` |
| `Player.receive_wound/3` | Apply wound | `update_condition/2` |
| `Player.die/1` | Kill character | `update_condition/2` |
| `Player.set_temp/3` / `get_temp/2` / `delete_temp/2` | Condition state | `do_effect/3`, `dispel/3`, `update_condition/2` |
| `Player.apply_condition/2` | Apply condition | `do_effect/3` |
| `Player.get_condition/1` | Get condition | `do_effect/3` |
| `Player.clear_condition/1` | Clear condition | `dispel/3`, `update_condition/2` |
| `Player.immunity_poison/1` | Poison immunity | `update_condition/2`, `check_immunity/2` |
| `Player.neili/1` | Get neili | `check_neili/1`, `calculate_cost/3` |
| `Player.add_neili/2` | Modify neili | `apply_dispel/3` |
| `Player.start_busy/2` | Set busy | `apply_dispel/3` |
| `Player.send_message/2` | Send message | `apply_dispel/3`, `broadcast_recovery/2` |
| `Player.environment_id/1` | Get room ID | `update_condition/2` |
| `Player.faction/1` | Get faction | Not used directly |
| `Player.id/1` | Get player ID | `dispel/3`, `apply_dispel/3` |
| `Player.name/1` | Get name | `broadcast_recovery/2` |
| `Player.breakup?/1` | Breakup trait | `check_level/3`, `calculate_dispel_amount/3` |
| `Player.special_divine?/1` | Divine trait | `check_level/3`, `calculate_dispel_amount/3` |
| `Player.temp_apply/2` | Temp apply bonus | `check_level/3`, `calculate_dispel_amount/3` |
| `Room.broadcast/3` | Broadcast message | `broadcast_message/2`, `broadcast_recovery/2` |

| Skill Capability | Description | Used By |
|------------------|-------------|---------|
| `Skill.get_level/2` | Skill level | `check_level/3`, `update_condition/2`, `power/2` |
| `Skill.can_improve?/2` | Can improve | Not used |

## Poison Data Structure

```elixir
%{
  "level" => 100,      # Poison level
  "remain" => 1500,    # Remaining poison amount
  "id" => "player_id", # Poisoner ID
  "name" => "Poison",  # Poison name
  "duration" => 15     # Duration per tick
}
```

## Core Algorithms

### 1. mixed_poison/2 - Merge Two Poisons
```
remain = (p1.remain || p1.level * p1.duration) + (p2.remain || p2.level * p2.duration)
level = max(p1.level, p2.level)
id = if p1.id != p2.id -> "..." else p1.id
name = if p1.name != p2.name -> (level >= 100 ? "Deadly Poison" : "Poison") else p1.name
remain = r1 + r2
```

### 2. do_effect/3 - Apply Poison
1. Validate params (level, duration, id integers)
2. Set default name
3. Merge with existing condition via `mixed_poison/2`
4. Apply condition to target
5. If level > 200 and NPC, 50% chance apply `exert_drug`

### 3. dispel/3 - Dispel Poison
1. Validate condition
2. Check neili >= 200
3. Calculate `need_lvl`:
   - base = cnd.level + 10
   - breakup: *0.7, divine: *0.7
   - immunity: -immune_poison (if -1, need=1)
   - other: +20%
   - self: need = 50
4. Calculate my_lvl = force + poison/5 + dispel-poison/5 + medical/5 + temp_apply
5. If need > my_lvl -> fail
6. Calculate power = force + dispel-poison/5 + temp_apply
7. Calculate dispel amount based on self/other, own_poison/other_poison
8. Apply dispel: reduce remain, cost neili, start busy

### 4. Damage Formulas
```
jing_damage(level):
  if level >= 64: 24 + (level-64)/8
  elif level >= 32: 16 + (level-32)/4
  else: level/2
  min 10
  return d/2 + random(d)

qi_damage(level):
  if level > 300: 100 + (level-300)/12
  elif level > 60: 60 + (level-60)/6
  else: level
  min 10
  return d/2 + random(d)
```

### 5. update_condition/2 - Poison Tick
1. Validate condition
2. If dead and damage would kill -> die with poison reason
3. Calculate jd, qd (jing/qi damage)
4. Calculate jw, qw (wounds = dmg/2, capped at eff_jing/eff_qi)
5. If not immune:
   - receive_damage(jing, jd), receive_wound(jing, jw)
   - receive_damage(qi, qd), receive_wound(qi, qw)
6. Resistance check:
   - nature poison OR immune (-1) OR level/2 + random(level) < force + improve
   - If resist: reduce remain by improve (or set 0 if immune)
   - If remain <= level: recovery message, halt
   - Normal decay: remain -= level, reapply condition
7. Broadcast messages

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `@min_dispel_neili` | 200 | Minimum neili to dispel |
| `@base_dispel_neili_cost` | 100 | Base neili cost self-dispel |
| `@self_dispel_neili_cost` | 150 | Self-dispel cost (own poison) |
| `@other_dispel_neili_cost_multiplier` | 1.25 | Other's poison cost multiplier |

## Flags Returned by update_condition

| Flag | Value | Description |
|------|-------|-------------|
| `CND_NO_HEAL_UP` | 1 | Prevent normal healing this tick |
| `CND_CONTINUE` | 2 | Continue condition next tick |

## Integration Notes

- Requires `CND_NO_HEAL_UP` and `CND_CONTINUE` constants
- Requires poison tick system (heartbeat or scheduler)
- Requires `exert_drug` condition for high-level poison
- Poison merge logic handles multiple sources
- Self-dispel cheaper than other-dispel
- Immune characters (immunity = -1) auto-resist
- High-level poison (>200) applies `exert_drug` to NPCs
- Death message uses `die_reason/1`