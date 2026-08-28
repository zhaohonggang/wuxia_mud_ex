# daemon_combatd Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used In |
|------------|-------------|---------|
| `Combat.Engine.do_attack/4` | Hit/parry/dodge + damage pipeline | Composed engine |
| `Combat.Messages.damage_msg/2` | Damage message text | do_attack result |
| `Combat.Messages.status_msg/1` | Vitals-ratio status text | result |
| `Player.reset_action/1` | Refresh action definition | do_attack |
| `Skill.query_action/2` | Get martial action | do_attack |
| `Skill.query_skill_power/3` | `skill_power` implementation | AP/DP/PP |
| `Skill.hit_ob/4` / `valid_damage/4` | Skill hooks in damage loop | damage |
| `Item.hit_ob/3` / `Item.valid_damage/4` | Weapon/armor hooks | damage loop |
| `Player.receive_damage/3` / `receive_wound/3` | Apply damage/wound | damage |
| `Player.is_busy/1` | busy -> dp/pp /= 3 | hit/parry |
| `Player.query_str/1` / `query_temp/2` | str/temp mods | damage bonus |
| `Player.is_killing/2` | Killing flag for wound chance | damage |
| `:rand.uniform/1` | Random everywhere | all |

## Core Formulas (ported as pure functions in .ex)

### 1. valid_power/1 — combat_exp -> power
```
exp < 2_000_000        -> exp
2M <= exp < 3M         -> 2_000_000 + (exp-2_000_000)/10
exp >= 3M              -> 3_000_000 + (exp-3_000_000)/20
```

### 2. skill_power/5 — attack/defense power
```
power = level^3/10            (level <= 500)
        | (level/10)*level^2  (level > 500)
power += valid_power(combat_exp)
if attack:  power = power/30 * (str + temp_str);  [+ power/100 * fight.attack]
if defense: power = power/30 * (dex + temp_dex);  [+ power/100 * fight.skill]
if level < 1: power = valid_power(exp)/2, then /30 * stat
```

### 3. Hit / Dodge / Parry
```
dodge: random(ap + dp) < dp      -> victim dodges
parry: random(ap + pp) < pp      -> victim parries
busy: dp/=3, pp/=3
skill effect: dp += dp/100 * query_effect_dodge; pp += pp/100 * query_effect_parry
parry delta: victim armed & me unarmed -> +10; me armed & victim unarmed -> -10
```

### 4. Damage
```
base = weapon? apply/damage : apply/unarmed_damage
base = (base + random(base))/2
base += action.damage * base / 100
bonus = query_str + jianu(craze) bonus; if action.force: bonus += action.force*bonus/100
damage += (bonus + random(bonus))/3
vicious (心狠手辣): damage += damage*20/100
str:  damage += damage * str1 / 300       (str1 = str*2 + query_str + random(temp_str/2))
int:  if random(int)>8: damage += damage * (10/7/4)/int  by int<16/<40/else
dex:  if ((dex-10)/4 + 2) > random(100): damage = 0
cap:  >400 -> (d-400)/4+300 ; >200 -> (d-200)/2+200
wound = damage - random(armor); cap same 400/200; <1 -> 0
righteous (光明磊落): wound -= wound*20/100
con:  wound -= wound*(con-10)/100
```

### 5. do_damage caps
```
str<40: x/50 ; <70: ((str-30)/2+20)/50 ; else ((str-60)/4+30)/50
cap: >1500 -> (d-1500)/4+1000 ; >500 -> (d-500)/2+500
debuff/1st,2nd: damage = damage * pct/100
```

## Integration Notes

- C-tier framework-core. The `.ex` ports the **pure numeric formulas**;
  the engine glue (do_attack/do_damage pipelines, message assembly, skill/weapon
  hook drilling) lives in `Kantele.Combat.Engine` + `Messages`.
- `EXP_LIMIT = 200000` gates skill improvement on weak hits (see do_attack
  skill-growth blocks).
- Smoke tests: `smoke_test.exs` (27 cases, all PASS) covering valid_power,
  skill_power (3 branches), parry_delta, base_damage, int/str/vicious bonuses,
  damage_cap/wound_cap, dodge?/parry?.
