# Module: combat (enemies + towers)

## Enemies

**Path**: `scenes/enemies/`
**Files**: `enemy_base.gd`, `enemy_base.tscn`

### enemy_base.gd

**Class name**: `EnemyBase`
**Extends**: `PathFollow2D`
**Scene**: `enemy_base.tscn` — PathFollow2D with Body (CharacterBody2D) containing Sprite,
AccentSprite, HPBarBG, HPBar (all ColorRects)

### Setup

`setup(type: String)` reads from `EnemyData.ENEMIES[type]`:
- hp, speed, reward, damage_to_base, color, accent

`_ready()` applies visual colors and sets collision layer 2 (for tower Area2D detection).

### Movement

- Moves along parent Path2D via `progress += current_speed * delta`
- `path_progress = progress_ratio` (0.0–1.0) used for tower targeting priority
- Syncs `body.global_position = global_position` each frame for Area2D collision

### Combat

| Method | Description |
|--------|-------------|
| `take_damage(amount)` | Reduces HP, flash white, die at 0 |
| `apply_slow(factor, duration)` | Sets slow_factor and timer; blue tint while active |
| `die()` | Awards gold, notifies WaveManager, fade-out animation, queue_free |
| `_reached_end()` | Damages base (lives), notifies WaveManager, queue_free |

### HP Bar

Same color scheme as Building: green (>50%) → orange (>25%) → red (≤25%).
Hidden at full HP.

### Enemy Types (from scripts/data/enemy_data.gd)

| Type | Name | Epoch | HP | Speed | Reward | Base Damage |
|------|------|-------|----|-------|--------|-------------|
| `hero_barbarian` | Варвар | 1 | 80 | 60 | 10 | 1 |
| `hero_knight` | Рыцарь | 2 | 200 | 40 | 20 | 2 |
| `hero_mage` | Маг | 3 | 100 | 50 | 25 | 3 |
| `hero_alchemist` | Алхимик | 4 | 120 | 55 | 20 | 2 |
| `hero_heir` | Наследник | 5 | 300 | 45 | 50 | 5 |

---

## Towers

**Path**: `scenes/towers/`
**Files**: `tower_base.gd`, `tower_base.tscn`

### tower_base.gd

**Class name**: `TowerBase`
**Extends**: `Node2D`
**Scene**: `tower_base.tscn` — Node2D with AttackTimer (Timer), RangeArea (Area2D + CircleShape2D),
Sprite + AccentSprite (ColorRects — visual placeholders)

### Setup

`setup(type: String)` reads from `TowerData.TOWERS[type]`:
- Sets CircleShape2D radius = `range`
- AttackTimer wait_time = `1.0 / attack_speed`
- Sprite colors from `color` and `accent`

### Targeting

- `RangeArea` (Area2D) detects `EnemyBase` entering/exiting range
- `enemies_in_range: Array` maintained via body_entered/exited signals
- Target selection: **furthest progress** along path (highest `path_progress`)
- Dead/invalid enemies cleaned up on each attack tick

### Attack Types

| Type | Behavior |
|------|----------|
| `ATTACK` | Fires single projectile at target |
| `MAGIC` | Fires projectile + applies slow (factor 0.5, duration 2.0s) |
| `ATTACK_AOE` | Damages ALL enemies in range, accent sprite flash feedback |

### Projectile

- Loaded from `scenes/projectiles/projectile.tscn`
- Fired from `global_position + Vector2(0, -16)` (top of tower)
- `proj.setup(target, damage, speed, color)`

### Tower Types (from scripts/data/tower_data.gd)

| Type | Name | Cost | Damage | Rate | Range | Special |
|------|------|------|--------|------|-------|---------|
| `tower_arrow` | Башня лучников | 50 | 15 | 1.0/s | 150 | Single target |
| `tower_necro` | Обелиск некроманта | 75 | 8 | 0.5/s | 120 | Slow 50% for 2s |
| `tower_fire` | Адский алтарь | 100 | 25 | 0.3/s | 100 | AoE radius 80 |
