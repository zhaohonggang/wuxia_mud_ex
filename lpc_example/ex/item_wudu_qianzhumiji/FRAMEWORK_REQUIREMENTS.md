# item_wudu_qianzhumiji Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used By |
|------------|-------------|---------|
| `Skill.has?/2` | Check if player has skill | `check_literate/1`, `check_prerequisites/2` |
| `Skill.get_level/2` | Query skill level | `check_prerequisites/2`, `attempt_unlock/2` |
| `Skill.improve/3` | Grant skill experience | `grant_perform/2` |
| `Skill.has?/2` | Check if player has perform | `check_prerequisites/2` |
| `Player.has_perform?/2` | Check if player has perform unlocked | `check_prerequisites/2`, `next_locked_technique/1` |
| `Player.grant_perform/2` | Grant perform/unlock | `grant_perform/2` |
| `Player.potential/1` | Get available potential | `check_resources/2` |
| `Player.add_potential/2` | Spend potential | `consume_resources/2` |
| `Player.jing/1` | Get current jing | `check_resources/2` |
| `Player.add_jing/2` | Spend jing | `consume_resources/2` |
| `Player.qi/1` | Get current qi | `check_resources/2` |
| `Player.add_qi/2` | Spend qi | `consume_resources/2` |
| `Player.start_busy/2` | Set busy state | `apply_busy/2` |
| `Player.max_neili/1` | Get max neili | `check_prerequisites/2` |
| `Skill.get_level/2` | Get skill level | `check_prerequisites/2`, `attempt_unlock/2` |
| `:rand.uniform/1` | Random roll | `attempt_unlock/2` |
| `Skill.improve/3` | Grant skill XP | `grant_perform/2` |

## Data Model

### Technique Unlocks (Perform Keys)
- `qianzhu-wandushou/suck` - Absorb Poison Cultivation
- `qianzhu-wandushou/zhugu` - Spider Gu Decision  
- `qianzhu-wandushou/wan` - Ten Thousand Gu Devour Heaven

### Technique Requirements

| Technique | Skill | Min Skill | Min Hand | Min Poison | Min Force | Min Neili | Success Rate |
|-----------|-------|-----------|----------|------------|-----------|-----------|--------------|
| suck | qianzhu-wandushou | 100 | 100 | 100 | 150 | 1000 | 5% base |
| zhugu | qianzhu-wandushou | 130 | 130 | 130 | 200 | 1500 | 5% base |
| wan | qianzhu-wandushou | 220 | 220 | 200 | 300 | 3500 | 5% base |

### Costs (per attempt)
- Potential: 1
- Jing: 30
- Qi: 30
- Busy: 2 seconds

### Success Formula
```
chance = min(base_rate + (skill - min_skill) / 10 * 2, 100)
```

## Event Flow

```
Player: "yanjiu suck from qianzhu miji"
  → can_read? (literate check)
  → execute()
    → check_verb() (yanjiu/research/du)
    → check_technique() (suck/zhugu/wan)
    → get_technique()
    → check_prerequisites() (literate, skill levels, not already known)
    → check_resources() (potential >= 1, jing >= 30, qi >= 30)
    → consume_resources() (-1 potential, -30 jing, -30 qi)
    → apply_busy() (2 seconds)
    → attempt_unlock() (random roll vs calculated chance)
    → success: grant_perform() (unlock perform, +5M skill XP)
    → fail: return error, resources still consumed
```

## Configuration

| Constant | Value | Description |
|----------|-------|-------------|
| `@techniques` | Map | Technique definitions |
| `@order` | List | Unlock order: suck → zhugu → wan |
| Success rates | 5% base | Scales with skill over minimum |
| Costs | 1 pot, 30 jing, 30 qi | Per attempt |
| Busy time | 2 seconds | Action lockout |

## Data Model

### Item Properties
- `id: "qianzhu_miji"`
- `type: "secret_manual"`
- `verbs: ["yanjiu", "research", "du"]`
- `no_sell: true`

### Player State
- `perform_keys` - Set of unlocked perform keys (e.g., "qianzhu-wandushou/suck")
- Skill: `qianzhu-wandushou` - Main skill for this manual
- Skill: `literate` - Required to read manual
- Skills: `hand`, `poison`, `force` - Prerequisite skills

## Integration Notes

- Requires `Player.has_perform?/2` for checking unlocked techniques
- Requires `Player.grant_perform/2` for unlocking new techniques
- Requires `Skill.get_level/2` for prerequisite checks
- Requires `Player.start_busy/2` for action lockout
- Requires resource deduction (potential, jing, qi)
- Sequential unlock order enforced by `@order`