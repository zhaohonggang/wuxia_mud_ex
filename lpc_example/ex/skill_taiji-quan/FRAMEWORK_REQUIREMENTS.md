# skill_taiji-quan Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used By |
|------------|-------------|---------|
| `Player.get_temp/2` / `Player.put_temp/3` / `Player.delete_temp/2` | Temp state | `hit_ob/3` (action_flag, combat_time, apply/*) |
| `Player.send_message/2` | Send message | `hit_ob/3` (power-up message) |
| `Player.add/3` / `Player.put/3` | Modify attributes | `hit_ob/3` (temp apply modifiers) |
| `Player.qi/1` / `Player.neili/1` | Vitals check | `practice_skill/2` |
| `Player.receive_damage/3` | Take damage | `practice_skill/2` |
| `Player.add/3` | Modify resource | `practice_skill/2` (neili -59) |
| `Skill.get_level/2` | Skill level | Many functions |
| `Skill.get_prepared/1` | Prepared skills | `reset_action/2` |
| `Skill.get_mapped/2` | Mapped skill | `reset_action/2` |
| `Skill.query_action/2` | Get skill action | `reset_action/2` |
| `Item.get_skill_type/1` | Weapon skill type | `reset_action/2` |
| `Item.get_actions/1` | Item actions | `reset_action/2` |
| `Combat.do_attack/4` | Execute attack | `hit_ob/3` (power-up extra attack) |
| `Combat.set_bhinfo/2` | Battle hint info | `valid_damage/5` (mp >= 100) |
| `:rand.uniform/1` | Random number | Many functions |

## Data Structures

### Skill State
```elixir
%{
  actions: [...],           # 25 action definitions
  valid_combine: [...]      # Combinable skills
}
```

### Action Definition
```elixir
%{
  action: "description with $N $n $l $w",
  force: int,
  dodge: int,
  parry: int,
  skill_name: "Chinese name",
  lvl: int,              # Minimum level to use
  damage_type: "瘀伤"
}
```
Special "极意" action uses dynamic functions for stats.

## Core Algorithms

### 1. query_action/3 - Weighted Random Selection
```elixir
eligible = filter actions where action.lvl <= player_level
weights = map eligible, fn a -> a.lvl * 5 + 5 end
pick weighted random
```
Higher level actions have exponentially higher weight.

### 2. valid_damage/5 - Parry Hook
```elixir
# Requirements: taiji-quan >= 100, defender living, no weapon
mp = attacker.count_skill
ap = attacker.force + mp
dp = defender.parry/2 + defender.taiji_quan

if ap/2 + random(ap) < dp:
  # Successful parry - negate damage
  return [damage: -damage, msg: one_of_3_messages]
else if mp >= 100:
  # Counter-messages to attacker
  Combat.set_bhinfo(message)
```

### 3. hit_ob/3 - Power-up Attack
```elixir
# Trigger: combat_time > 10, random(5) != 1, no action_flag
# Effects:
# - Send "太极蓄力，借力打力" message
# - action_flag = 1
# - apply/attack += time * 10
# - apply/parry += time * 10
# - apply/unarmed_damage += time * 3
# - Extra Combat.do_attack (type 10 or 30)
# - Remove all temp buffs
# - Clear action_flag
```

### 4. query_effect_parry/3 - Passive Parry Bonus
```elixir
if weapon equipped: 0
else:
  lvl = taiji-quan level
  lvl < 80: 0
  lvl < 200: 50
  lvl < 280: 80
  lvl < 350: 100
  else: 120
```

### 5. practice_skill/2 - Training Costs
```elixir
requires: qi >= 70, neili >= 70
costs: qi -35, neili -59
```

### 6. valid_learn/2 - Learning Requirements
```elixir
int >= 26
empty hands (no weapon/secondary_weapon)
force skill >= 180
max_neili >= 1000
unarmed skill >= 100
unarmed >= taiji-quan
```

### 7. valid_enable/2
```elixir
usage == "unarmed" || usage == "parry"
```

### 8. valid_combine/2
```elixir
combo in ["wudang-zhang", "paiyun-shou"]
```

### 9. query_skill_name/2
Returns highest-level action name <= current level.

### 10. perform_action_file/2
Delegates to `taiji-quan/<action>` files.

### 11. Extreme Action "极意"
Dynamic stats computed at runtime:
```elixir
force: force_skill/4 + random(force_skill/3)
attack: unarmed/5 + random(unarmed/3)
dodge: dodge/4 + random(force/2)
parry: parry/3 + random(parry)
damage: force/4 + random(unarmed/4)
```

## Configuration

| Constant | Value | Description |
|----------|-------|-------------|
| Practice qi cost | 35 | Per practice |
| Practice neili cost | 59 | Per practice |
| Practice min qi | 70 | Minimum to practice |
| Practice min neili | 70 | Minimum to practice |
| Weight base | lvl * 5 + 5 | Action selection weight |
| Parry bonus | 50-120 | Based on level |

## Integration Notes

- Requires `Combat.do_attack/4` for `hit_ob` extra attack
- Requires `Combat.set_bhinfo/2` for `valid_damage` mp >= 100 messages
- Requires `Skill.get_level/2`, `Skill.get_mapped/2`, `Skill.get_prepared/1`
- Requires `Item.get_skill_type/1`, `Item.get_actions/1`
- Requires `run_override/2` not used but available
- Action "极意" uses dynamic stat calculation
- `perform_action_file/2` delegates to `taiji-quan/<action>` directory
- `NewRandom` equivalent implemented via weighted random
- Red color code `RED`/`NOR` in action text for "极意"