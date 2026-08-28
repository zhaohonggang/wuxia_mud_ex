# inherit_char_npc Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used By |
|------------|-------------|---------|
| `Player.vitals/1` | `%{qi, jing, eff_qi, eff_jing, max_qi, max_jing, neili, max_neili}` | `accept_fight/2`, `accept_hit/3`, `heal_self/1` |
| `Player.get/3` | Query NPC fields (attitude, can_speak, chat_chance, chat_msg) | accept_* / chat |
| `Player.busy/1` / `Player.fighting/1` | State checks | `heal_self/1`, `chat/2` |
| `Player.exert/2` | Cast force skill (recover/regenerate/heal/inspire) | `heal_self/1` |
| `Player.dazuo/2` | Sit training (cost) | `heal_self/1` |
| `Player.say/2` | Speak to room | accept_* / chat_dispatch |
| `Player.check_enemy/2` | Guarder enemy check | accept_fight/hit/kill |
| `Player.kill_ob/2` | Enter combat | accept_hit/kill |
| `Player.add_temp/3` | `attempt_hit` counter | `accept_hit/3` |
| `Player.get_skill/2` | force level | `heal_self/1` |
| `Skill.get_mapped/2` | Mapped force skill | `exert_function/1` |
| `Player.move/2` | Teleport home | `return_home/2` |
| `:rand.uniform/1` | Random number | chat / accept_hit / random_move |

## NPC UCL Fields

| Field | Type | Description |
|-------|------|-------------|
| `attitude` | string | "friendly" \| "aggressive" \| "killer" \| other |
| `can_speak` | bool | Whether NPC can talk (mute -> no fight dialogue) |
| `is_guarder` | bool | Guard NPC -> `check_enemy` path |
| `is_quester` / `is_waiter` | bool | Quest delegation hooks (QUEST_D / ULTRA_D) |
| `chat_chance` | int | 0-99 probability to chat per heartbeat |
| `chat_msg` | [string] | Chat message pool (idle) |
| `chat_chance_combat` / `chat_msg_combat` | int / [string] | Chat during combat |

## Core Algorithms

### 1. accept_fight/2 - Accept Duel Request
```elixir
perqi  = qi * 100 / max_qi
perjing = jing * 100 / max_jing

if can_speak == false: -> accept (+kill_ob)
if is_guarder: -> check_enemy(who, "fight")

if perqi >= 75 and perjing >= 75:
  friendly   -> refuse
  aggressive/killer -> accept
  default    -> accept
else:
  refuse "今天有些疲惫，改日再战也不迟啊。"
```

### 2. accept_hit/3 - Escalating Hit Response
```elixir
attempt = ++attempt_hit   # temp counter, incremented each hit
perqi/perjing as above

if perqi < 50 or perjing < 50: -> accept (fight back at once)
else by attitude:
  friendly   -> accept "这位朋友，且慢！"
  aggressive -> random(attempt) > 8  -> kill_ob (accept)
                else accept "好个家伙，接招！"
  killer     -> random(attempt) > 2  -> kill_ob (accept)
                else accept "接招吧！"
  default    -> random(attempt) > 7  -> kill_ob (accept)
                else accept "这位朋友，且慢！"
```
Higher attempt count => higher chance to escalate to kill. The `attempt` temp
counter is incremented once per hit, so the threshold (2/7/8) is crossed only
after repeated harassment.

### 3. accept_kill/2 - Always Fights Back
```elixir
if living == false -> accept
if can_speak == false -> accept (+kill_ob)
if is_guarder -> check_enemy(who, "kill")
by attitude -> always accept with threatening line
```

### 4. heal_self/1 - Vitals Recovery Decision Tree
```elixir
guard: not busy, not fighting, not_living==false, force mapped,
       no_exert==false, not drugged, neili >= 50

jing  < eff_jing*8/10            -> exert "regenerate"
qi    < eff_qi*8/10 & force>=150 -> exert "recover"
eff_qi < max_qi                  -> exert "heal"
eff_jing < max_jing              -> exert "inspire"
neili < max_neili - 10           -> dazuo min(max_neili-neili, qi/2)
```

### 5. chat_dispatch/3 - Random Chat
```elixir
if random(100) < chance:
  pick random msg from pool; if string -> say; if function -> evaluate
else: nothing
```

### 6. random_move/1
Pick a random direction from room exits (or none if empty).

### 7. check_family/3
Match `family/family_name` OR (no family but `born_name` matches).

## Integration Notes

- This is a **framework mixin** applied to all NPCs, not per-object data.
  The decision logic above is the pure, testable core.
- Requires the vitals struct shape defined in `lib/kantele/character.ex`.
- `accept_hit` escalation depends on a persistent per-attack `attempt_hit`
  temp counter (needs `Player.add_temp/3` semantics).
- `heal_self` requires `Player.exert/2` + `Player.dazuo/2` + `Skill.get_mapped/2`.
- Chase/guard/quest hooks (`check_enemy`, `is_quester`, ULTRA_D/QUEST_D) are
  framework services; only the decision inputs (booleans/strings) enter UCL.
- Smoke tests in `smoke_test.exs` (18 cases, all PASS).
