# Module: globals (autoload + data)

**Path**: `scripts/autoload/`, `scripts/data/`, `config/`

## Autoload Singletons

Registered in `project.godot` under `[autoload]`.

### Config (scripts/autoload/config.gd)

**Extends**: `Node`
**Role**: Loads JSON config files at startup, exposes as dictionaries.

```gdscript
Config.player    → Dictionary from config/player.json
Config.buildings → Dictionary from config/buildings.json
Config.game      → Dictionary from config/game.json
```

Loads via `FileAccess.open()` + `JSON.parse()`. Errors pushed to console on missing/invalid files.

Usage pattern throughout codebase:
```gdscript
var speed = Config.player.get("speed", 120.0)
var iso = Config.game.get("iso", {})
```

---

### GameManager (scripts/autoload/game_manager.gd)

**Extends**: `Node`
**Role**: Central game state — resources, win/loss conditions, grid occupation.

#### Signals

| Signal | Emitted when |
|--------|-------------|
| `gold_changed(new_amount)` | Gold value changes |
| `lives_changed(new_amount)` | Lives value changes |
| `game_over` | Lives reach 0 |
| `game_won` | All waves completed |

#### State

| Variable | Default | Description |
|----------|---------|-------------|
| `gold` | 150 | Player currency (setter emits signal) |
| `lives` | 20 | Player health (setter emits signal, 0 triggers game_over) |
| `current_epoch` | 1 | Current wave epoch (1–5) |
| `is_game_active` | true | False after game_over |
| `occupied_cells` | {} | `Vector2i → tower_ref` for tower placement |

#### API

| Method | Description |
|--------|-------------|
| `can_afford(cost)` | Returns `gold >= cost` |
| `spend_gold(amount)` | Deducts gold, returns success bool |
| `earn_gold(amount)` | Adds gold |
| `lose_life(amount)` | Reduces lives (clamped to 0) |
| `world_to_grid(pos)` | World → grid (32px cells, separate from iso grid) |
| `grid_to_world(pos)` | Grid → world center |
| `is_cell_free(pos)` | Check tower placement availability |
| `occupy_cell(pos, tower)` | Register tower at cell |
| `free_cell(pos)` | Remove tower registration |
| `reset_game()` | Reset all state to defaults |

**Note**: GameManager uses `GRID_SIZE = 32` for tower placement, separate from BuildingGrid's
isometric `CELL_SIZE = 64`. These are two different grid systems.

---

### WaveManager (scripts/autoload/wave_manager.gd)

**Extends**: `Node`
**Role**: Controls enemy wave spawning across 5 epochs (15 waves total).

#### Signals

| Signal | Emitted when |
|--------|-------------|
| `wave_started(wave_number)` | New wave begins |
| `wave_completed(wave_number)` | All enemies from wave dead/reached end |
| `all_waves_completed` | All 15 waves done |
| `enemy_spawned(enemy)` | Individual enemy created |

#### Wave Structure

```
Epoch I   (waves 1–3):   Barbarians only
Epoch II  (waves 4–6):   Barbarians + Knights
Epoch III (waves 7–9):   Knights + Mages
Epoch IV  (waves 10–12): Alchemists + Mages
Epoch V   (waves 13–15): Heirs + mixed (final boss waves)
```

Each wave = array of groups: `{type: String, count: int, delay: float}`
Groups are flattened, shuffled, spawned sequentially with per-enemy delay.

#### API

| Method | Description |
|--------|-------------|
| `start_next_wave()` | Increments wave counter, updates epoch, spawns |
| `on_enemy_died()` | Decrements alive count, checks wave completion |
| `on_enemy_reached_end()` | Same as died (enemy still "gone") |

#### Spawning Flow

1. `start_next_wave()` → sets epoch, emits `wave_started`
2. `_spawn_wave(groups)` → flatten + shuffle → async loop with timer delays
3. `_spawn_enemy(type)` → instantiates enemy_base.tscn, calls `setup(type)`
4. Calls `main.add_enemy(enemy)` if method exists on current_scene

---

## Static Data

### EnemyData (scripts/data/enemy_data.gd)

**Class name**: `EnemyData`
**Extends**: `RefCounted`

`const ENEMIES: Dictionary` — keyed by type string. Each entry:
`{name, epoch, hp, speed, reward, damage_to_base, color, accent}`

See [combat.md](combat.md) for full table.

### TowerData (scripts/data/tower_data.gd)

**Class name**: `TowerData`
**Extends**: `RefCounted`

`const TOWERS: Dictionary` — keyed by type string. Each entry:
`{name, cost, damage, attack_speed, range, projectile_speed, color, accent, description, type}`

Optional fields: `slow_factor`, `slow_duration` (MAGIC), `aoe_radius` (ATTACK_AOE).

See [combat.md](combat.md) for full table.

---

## Config Files

### config/game.json

| Section | Keys | Used by |
|---------|------|---------|
| `iso` | cell_size, iso_ratio, grid_width/height, ground_seed, offsets | BuildingGrid, IsoGround, WallSystem |
| `tile_weights` | 8 grass variant weights | IsoGround |
| `move_marker` | lifetime, radius, colors | MoveMarker |
| `ui` | font colors, button sizes | BuildMenu |

### config/buildings.json

| Building | Keys | Used by |
|----------|------|---------|
| `throne` | name, cost=0, hp=500, sprite, sprite_offset | Throne |
| `wall` | name, cost=10, hotkey, height/thickness, colors, merlon/pillar/brick params | WallSystem, BuildMenu |

### config/player.json

| Key | Default | Used by |
|-----|---------|---------|
| speed | 120.0 | Player |
| zoom_speed/min/max | 0.1/0.5/4.0 | Player camera |
| afk_timeout | 10.0 | Player AFK system |
| move_threshold | 5.0 | Player mouse movement |
| walk/idle/smoke_anim_speed | 10/2/6 | Player animations |
