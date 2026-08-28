# npc_horseboss Framework Requirements

## Required Framework Capabilities

| Capability | Description | Used By |
|------------|-------------|---------|
| `Player.get_temp/2` / `put_temp/3` / `delete_temp/2` | Wizard state storage | All wizard steps (`choose_species`, `choose_gender`, `choose_id`, `choose_name`, `choose_desc`) |
| `Skill.get_level/2` | Check training skill | `greet/1`, `start_purchase/1` |
| `Player.give_mount/2` | Assign mount to player | `build_pet/2` |
| `Player.item_exists?/1` | Check ID uniqueness | `choose_id/2` |
| `Item.create/1` | Create mount item | `build_pet/2` (via `create_mount/7`) |
| `Player.give_mount/2` | Assign mount to player | `build_pet/2` |
| `Player.delete_temp/2` | Cleanup wizard state | `build_pet/2` |
| `Player.temp` access | Read wizard state | All wizard steps |
| `Skill.get_level/2` | Check training skill | `greet/1`, `start_purchase/1` |

## Data Structures

### Species Definitions
19 species with base stats, ID suffix, and unit:
| Key | Name | Suffix | Unit | Base Stats |
|-----|------|--------|------|------------|
| horse | Horse | ma | match | str:30, con:25, dex:20, int:10 |
| donkey | Donkey | lv | head | str:25, con:30, dex:15, int:10 |
| mule | Mule | luo | head | str:35, con:35, dex:10, int:10 |
| camel | Camel | tuo | head | str:40, con:40, dex:10, int:10 |
| ox | Ox | niu | head | str:45, con:45, dex:5, int:10 |
| elephant | Elephant | xiang | head | str:60, con:50, dex:5, int:15 |
| lion | Lion | shi | head | str:50, con:40, dex:30, int:15 |
| tiger | Tiger | hu | head | str:55, con:40, dex:35, int:15 |
| leopard | Leopard | bao | head | str:45, con:35, dex:40, int:15 |
| deer | Deer | lu | head | str:25, con:30, dex:45, int:15 |
| crane | Crane | he | head | str:20, con:25, dex:50, int:20 |
| eagle | Eagle | diao | head | str:30, con:25, dex:55, int:20 |
| goat | Goat | yang | head | str:20, con:25, dex:30, int:10 |
| monkey | Monkey | hou | head | str:25, con:25, dex:50, int:25 |
| bear | Bear | xiong | head | str:55, con:50, dex:15, int:10 |
| wolf | Wolf | lang | head | str:40, con:35, dex:40, int:15 |
| fox | Fox | hu | head | str:30, con:30, dex:45, int:20 |
| marten | Marten | diao | head | str:20, con:25, dex:50, int:20 |
| foal | Foal | ju | match | str:15, con:15, dex:20, int:10 |
| beast | Beast | shou | head | str:50, con:50, dex:20, int:10 |

### Mount Instance Structure
```elixir
%{
  id: "unique_id",
  name: "Display Name",
  type: "mount",
  species: "Horse",
  gender: "male" | "female",
  unit: "match" | "head",
  stats: %{str: 30, con: 25, dex: 20, int: 10},
  description: "Description text",
  owner: "player_id",
  owner_name: "Player Name",
  summon_id: "unique_id",
  rideable: true,
  trained: true
}
```

## Wizard Flow

```
Player talks to Horseboss
  → greet() → checks training (>=30) → shows price (100 gold)
Player: "buy mount"
  → start_purchase() → shows species list
Player chooses species
  → choose_species() → stores species in temp
Player chooses gender
  → choose_gender() → stores gender
Player enters ID base
  → choose_id() → validates format, uniqueness
Player enters name
  → choose_name() → validates Chinese chars, length
Player enters description
  → choose_desc() → build_pet()
    → generates random stats (±10 variance)
    → creates mount instance
    → gives mount to player
    → clears temp state
    → returns mount info + whistle command
```

## Configuration

| Constant | Value | Description |
|----------|-------|-------------|
| `@price` | 1,000,000 copper (100 gold) | Mount purchase price |
| `@training_req` | 30 | Minimum training skill |
| Species count | 19 | Available mount types |
| Stat variance | ±10 | Random stat variation |

## Player Temp Storage (Wizard State)

| Key | Stage | Description |
|-----|-------|-------------|
| `chosen_species` | After species selection | Species key (e.g., `:horse`) |
| `pet_gender` | After gender selection | "male" or "female" |
| `pet_id` | After ID input | Base ID (without suffix) |
| `pet_name` | After name input | Chinese name |

## Mount Instance Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique mount ID (base + suffix) |
| `name` | String | Display name (Chinese + species) |
| `type` | String | "mount" |
| `species` | String | Species name |
| `gender` | String | "male" or "female" |
| `unit` | String | Measure word (match/head) |
| `stats` | Map | str, con, dex, int |
| `description` | String | Player description + owner info |
| `owner` | String | Player ID |
| `owner_name` | String | Player name |
| `summon_id` | String | ID for whistle command |
| `rideable` | Boolean | Can be ridden |
| `trained` | Boolean | Pre-trained |

## Integration Notes

- Requires `Player.get_temp/2`, `put_temp/3`, `delete_temp/2` for wizard state
- Requires `Player.give_mount/2` for mount assignment
- Requires `Player.item_exists?/1` for ID collision check
- Requires random stat generation (±10 from base)
- Chinese name validation via regex `[\u{4e00}-\u{9fff}]`
- ID format: lowercase letters + underscore, 3-20 chars
- Name length: 2-12 chars, must contain Chinese
- Description max 60 chars
- Mount summoning via `whistle <summon_id>`