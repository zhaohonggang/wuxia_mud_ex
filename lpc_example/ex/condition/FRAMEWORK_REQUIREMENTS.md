# condition Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used In |
|------------|-------------|---------|
| `Player.id/1` | Get character ID | `apply_condition/3` (applyer tracking) |
| `Player.name/1` | Get display name | `apply_condition/3` (applyer tracking) |
| `Player.this_player/0` | Get initiating player | `apply_condition/3` |
| `Player.this_object/0` | Get target object | `apply_condition/3` |
| `Player.is_player?/1` | Check if player | `apply_condition/3` |
| `Player.set_heart_beat/2` | Enable heartbeat | `apply_condition/3` |
| `Player.get_temp/2` | Get temp variable | `affect_by/3` (para) |
| `Player.has_special_skill?/2` | Check special skill | `affect_by/3` (piyi) |
| `Player.set_heart_beat/2` | Enable heartbeat | `apply_condition/3` |

| Room Capability | Description | Used In |
|-----------------|-------------|---------|
| `Room.broadcast/3` | Broadcast message | Not directly used |

| Condition Capability | Description | Used In |
|----------------------|-------------|---------|
| `ConditionDaemon.get/1` | Get condition daemon | `apply_condition/3`, `update_condition/1`, `dispel_condition/2`, `affect_by/3` |
| `ConditionDaemon.update/3` | Update condition | `update_condition/1` |
| `ConditionDaemon.dispel/3` | Dispel condition | `dispel_condition/2` |
| `ConditionDaemon.do_effect/4` | Apply effect | `affect_by/3` |

| Character Capability | Description | Used In |
|----------------------|-------------|---------|
| `Player.is_player?/1` | Check if player | `apply_condition/3` |

## Data Structures

### Condition State (per character)
```elixir
%{
  conditions: %{"poison" => %{level: 10, duration: 100}, "drunk" => %{level: 5}},
  applyers: %{"poison" => [%{id: "player:123", name: "Attacker"}]},
  last_applyer_name: "Attacker",
  last_applyer_id: "player:123"
}
```

### Condition Info (per condition)
```elixir
%{
  level: 10,           # Condition intensity
  duration: 100,       # Remaining ticks
  # ... daemon-specific fields
}
```

### Applyer Info
```elixir
%{id: "player:123", name: "Attacker"}
```

## Core Functions

### 1. apply_condition/3 - Apply Condition
```elixir
apply_condition(cnd, info)
```
- Validates `cnd` is binary
- Stores `info` in `conditions[cnd]`
- Tracks applyer (if player, not self) in `applyers[cnd]`
- Sets `last_applyer_name/id`
- Enables heartbeat (`set_heart_beat(true)`)

### 2. query_condition/2 - Query Condition
```elixir
query_condition(cnd)      # Returns info for specific condition
query_condition(nil)      # Returns all conditions map
```

### 3. clear_condition/2 - Clear Condition
```elixir
clear_condition(cnd)      # Removes specific condition
clear_condition(nil)      # Clears all conditions + applyers + last_applyer
```

### 4. update_condition/1 - Heartbeat Update
```elixir
update_condition()
```
- Called from heartbeat
- Iterates all conditions
- Loads condition daemon (`ConditionDaemon.get/1`)
- Sets `last_applyer` from `applyers`
- Calls daemon `update_condition/3`:
  - Returns `{flag, new_info}`
  - `flag & CND_CONTINUE == 0` → clear condition
  - `flag == 0` → clear condition
  - Otherwise updates `info` and continues
- Returns update flag

### 5. dispel_condition/2 - Dispel Condition
```elixir
dispel_condition(cnd)
```
- Loads daemon, calls `dispel/3`
- If successful, clears condition
- Returns result (0 = fail, non-zero = success)

### 6. affect_by/3 - Apply Effect
```elixir
affect_by(cnd, para)
```
- Loads daemon
- Checks `special_skill/piyi` (immunity)
- Uses `para` from temp or argument
- Calls daemon `do_effect/4`
- Returns result

### 7. query_last_applyer/2 - Get Applyer
```elixir
query_last_applyer(cnd)   # Returns applyer info for condition
query_last_applyer(nil)   # Returns all applyers
```

### 8. last_applyer_name/id/1 - Convenience
```elixir
last_applyer_name(cnd)
last_applyer_id(cnd)
```

### 9. query_condition_name/1 - Get Daemon Name
```elixir
query_condition_name(cnd)  # Returns daemon's cnd_name()
```

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `CND_CONTINUE` | 1 | Condition continues |
| `CND_FLAG` | 2 | Additional flag |

## Condition Daemon Interface

Each condition type (poison, drunk, etc.) has a daemon module implementing:

```elixir
defmodule MyPoisonDaemon do
  @doc "Condition name"
  def cnd_name(), do: "poison"

  @doc "Heartbeat update: returns {flag, new_info}"
  def update(state, info) do
    # Decrease duration, apply damage, etc.
    if info.duration <= 1 do
      {0, info}  # Expire
    else
      {@cnd_continue, %{info | duration: info.duration - 1}}
    end
  end

  @doc "Dispel: returns non-zero on success"
  def dispel(state, caster, info), do: 1

  @doc "Effect application: returns non-zero on success"
  def do_effect(state, cnd, para), do: 1
end
```

## Integration Notes

- Requires `ConditionDaemon` registry (like `Kantele.Combat.Skills`) mapping condition name → daemon module
- Heartbeat calls `update_condition/1` automatically (via `Scheduler` or `heart_beat`)
- `apply_condition` enables heartbeat to ensure `update_condition` runs
- Condition daemons are loaded on-demand (lazy), cached in registry
- Piyi special skill grants immunity to `affect_by`

## Smoke Tests

`smoke_test.exs` (17 tests):
1. init_feature
2. apply_condition / query_condition
3. multiple conditions
4. query_condition(nil) returns all
5. clear_condition single
6. clear_condition all
7. applyer tracking
8. update_condition clears unknown condition
9. update_condition continues known condition
10. dispel_condition
11. affect_by
12. affect_by blocked by piyi
11. query_condition_name (skipped)
12. clear_condition preserves other conditions
13. last_applyer cleared with condition
14. update_condition sets last_applyer
15. update_condition clears expired condition (flag=0)