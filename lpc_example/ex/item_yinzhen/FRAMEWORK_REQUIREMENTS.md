# item_yinzhen Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used By |
|------------|-------------|---------|
| `Skill.get_level/2` | Query player skill level | `can_use?/1`, `check_skill/1`, `determine_outcome/1` |
| `Skill.has?/2` | Check if player has skill | `check_skill/1` |
| `Skill.improve/3` | Grant skill experience | `heal_outcome/2` |
| `Item.is_handing?/2` | Check if player holds item | `check_handing/1` |
| `Player.alive?/1` | Check if character is alive | `check_target/2` |
| `Player.is_player?/1` | Check if character is player | `check_target/2` |
| `Player.is_npc?/1` | Check if character is NPC | `check_target/2` |
| `Player.busy?/1` | Check if character is busy | `check_busy/1` |
| `Player.start_busy/2` | Set busy state with duration | `consume_resources/1` |
| `Player.get_temp/2` / `put_temp/2` | Temporary per-player storage | `check_cooldown/2`, `apply_cooldown/2` |
| `Player.add_neili/2` | Modify neili (internal energy) | `consume_resources/1` |
| `Player.add_jing/2` | Modify jing (mental energy) | `consume_resources/1` |
| `Player.heal_qi/2` | Heal qi (vital energy) | `heal_outcome/2` |
| `Player.add_eff_qi/2` | Increase effective qi max | `heal_outcome/2` |
| `Player.receive_wound/4` | Apply wound damage | `fail_outcome/2` |
| `Player.eff_qi_pct/1` | Get effective qi percentage | `check_vitals/2` |
| `Skill.get_level/2` | Get skill level | `check_force/2`, `determine_outcome/1` |
| `:rand.uniform/1` | Random number generation | `determine_outcome/1` |
| `System.monotonic_time/1` | High-resolution timer | `check_cooldown/2`, `apply_cooldown/2` |

## Data Model Extensions

### Player Temp Storage Keys
- `last_zhenjiu_<target_id>` - Unix timestamp of last acupuncture on target

### Item Properties
- `verb: "zhenjiu"` - Custom verb for acupuncture action
- `type: "acupuncture_tool"` - Item type classification

## Event Flow

```
Player uses "zhenjiu <target>"
  → can_use? (skill check)
  → execute()
    → check_skill()
    → check_handing()
    → check_target() (alive, not player, force < 300)
    → check_busy()
    → check_force()
    → check_vitals() (eff_qi > 5%)
    → check_cooldown() (60s per target)
    → consume_resources() (neili -30, jing -20, busy 3s)
    → apply_cooldown() (60s per target)
    → determine_outcome() (random(120) vs skill)
    → success: heal_outcome() (heal qi, improve skill)
    → fail: fail_outcome() (wound target)
```

## Configuration Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `@cd_seconds` | 60 | Cooldown per target |
| `@min_skill` | 60 | Minimum zhenjiu-shu level |
| `@player_max_targets` | 1 | Players can only self-acupuncture |
| `@success_threshold` | 120 | Random(120) > skill = fail |

## Integration Notes

- Requires `eff_qi` / `max_qi` dual health bar system
- Requires `start_busy/2` for action lockout
- Requires `receive_wound/4` with attacker tracking
- Requires per-target cooldown storage (temp storage)
- Skill experience uses `improve/3` with fixed amount