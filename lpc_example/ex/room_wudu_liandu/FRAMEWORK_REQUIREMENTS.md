# room_wudu_liandu Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used By |
|------------|-------------|---------|
| `Player.faction/1` | Get player faction | `check_faction/1` |
| `Player.get_temp/2` / `put_temp/3` / `delete_temp/2` | Crafting state | All functions |
| `Player.busy?/1` | Check busy state | `check_not_busy/1` |
| `Player.start_busy/2` | Set busy timer | `start_crafting/2` |
| `Player.jing/1` / `qi/1` | Check vitals | `check_vitals/1` |
| `Player.receive_damage/3` | Apply damage during crafting | `liandu_callback/1` |
| `Skill.get_level/2` | Check skill levels | `check_skill_level/1`, `liandu_callback/1` |
| `Skill.improve/3` | Grant skill XP | `liandu_callback/1` |
| `Skill.can_improve?/2` | Check if skill can improve | `liandu_callback/1` |
| `Player.add_exp/2` | Grant combat exp | `liandu_callback/1` |
| `Player.add_score/2` | Grant jianghu score | `liandu_callback/1` |
| `Player.potential/1` / `potential_limit/1` | Check potential | `liandu_callback/1` |
| `Player.improve_potential/2` | Grant potential | `liandu_callback/1` |
| `Player.int/1` | Get intelligence | `liandu_callback/1` |
| `Player.give_item/2` | Give crafted poison | `liandu_callback/1` |
| `Item.has?/2` | Check inventory | `check_ingredients/2` |
| `Item.take/2` / `destroy/1` | Consume ingredients | `consume_ingredients/2` |
| `Player.environment_id/1` | Check room | `liandu_callback/1` |
| `schedule_callback/3` | Delayed callback | `start_crafting/2` |

## Recipe Data

| Recipe | Ingredients | Skill Req | Product | Duration | Level Bonus |
|--------|-------------|-----------|---------|----------|-------------|
| Heding Hong | Du Nang, Shexin Zi, Qianri Zui | 60 | Hedinghong | 15 | 0 |
| Furou Gao | Du Nang, Fugu Cao, Chuanxin Lian | 60 | Furougao | 15 | 0 |
| Kongque Dan | Du Nang, Fugu Cao, Qianri Zui | 60 | Kongquedan | 15 | 0 |
| Chixie Fen | Du Nang, Shexin Zi, Duanchang Cao | 60 | Chixiefen | 15 | 0 |
| Duanchang San | Du Nang, Duanchang Cao, Chuanxin Lian | 60 | Duanchangsan | 15 | 0 |
| Wusheng San | Du Nang + all 5 above + Jinshe Duye | 60 | Wushengsan | 25 | +20 |

## Crafting Flow

```
Player: "lianzhi heding hong"
  → check_faction() (Five Poisons Sect)
  → check_not_crafting() (no liandu/recipe temp)
  → check_not_busy() (not busy)
  → check_skill_level() (wudu-qishu >= 60)
  → check_vitals() (jing >= 80, qi >= 80)
  → get_recipe() + check_ingredients() (3 items)
  → consume_ingredients() (destroy 3 items)
  → set_temp(liandu/recipe = product, liandu/level_bonus, liandu/duration)
  → start_busy(time/2 + 1)
  → schedule_callback(liandu_callback, 15-30 sec)

Callback (after 15-30 sec):
  → receive_damage(jing 50-80, qi 50-80)
  → if random(skill) < 50 and random(3) == 1 → FAIL (delete temp, message)
  → else SUCCESS:
    → create_poison(level = poison/2 + wudu-qishu + 10 + bonus)
    → give_item(poison)
    → add_exp(300-600), add_score(100-200), improve_potential
    → improve_skill(poison, 50+int), improve_skill(wudu-qishu, 50+int)
    → Wusheng San bonus: +exp, +potential, +score if potential at max
```

## Configuration Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `@min_skill` | 60 | Minimum wudu-qishu |
| `@min_jing` | 80 | Minimum jing |
| `@min_qi` | 80 | Minimum qi |
| `@base_time_min` | 15 | Min craft time (sec) |
| `@base_time_max` | 15 | Max additional time |
| `@failure_chance` | 50 | Skill threshold for fail |
| `@failure_roll_max` | 3 | 1 in 3 extra fail chance |
| `Wusheng San level bonus` | +20 | Extra poison level |

## Poison Object Structure

```elixir
%{
  id: "hedinghong",
  name: "Heding Hong",
  type: "poison",
  poison: %{
    level: 100,
    id: "player_id",
    name: "Crane Top Red Poison",
    duration: 15
  }
}
```

## Integration Notes

- Requires `schedule_callback/3` for delayed crafting completion
- Requires `Player.put_temp/3` for multi-step state tracking
- Requires `Item.destroy/1` for ingredient consumption
- Wusheng San is composite recipe requiring all 5 other poisons + Golden Snake Venom
- Damage during crafting (jing/qi loss) simulates concentration cost
- Failure rate: skill < 50 = 33% fail, skill >= 50 = ~11% fail