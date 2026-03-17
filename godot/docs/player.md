# Module: player

**Path**: `scenes/player/`
**Files**: `player.gd`, `player.tscn`

## player.gd

**Class name**: `Player`
**Extends**: `CharacterBody2D`
**Scene**: `player.tscn` — CharacterBody2D with AnimatedSprite2D + Camera2D + CollisionShape2D

### Config (from `player.json`)

| Param | Default | Description |
|-------|---------|-------------|
| `speed` | 120.0 | Movement speed (px/s) |
| `zoom_speed` | 0.1 | Camera zoom increment |
| `zoom_min` | 0.5 | Min camera zoom |
| `zoom_max` | 4.0 | Max camera zoom |
| `afk_timeout` | 10.0 | Seconds of idle before AFK animation |
| `move_threshold` | 5.0 | Distance to target to stop mouse movement |

### Movement System

Two input methods, WASD overrides mouse:

1. **WASD** (`_physics_process`):
   - Reads `move_left/right/up/down` axes
   - Normalizes input → `velocity = input * speed`
   - Cancels mouse movement when WASD pressed

2. **Right-click mouse** (`_input`):
   - Sets `move_target` to global mouse position
   - `using_mouse_move = true`
   - Spawns `MoveMarker` at target
   - Holding right-click + dragging updates target continuously
   - Stops when within `move_threshold` distance

### Camera

- Camera2D is child of Player (follows automatically)
- Mouse wheel up/down adjusts zoom (clamped to 0.5–4.0)

### Animation System

**8 directions**: south, south-west, west, north-west, north, north-east, east, south-east

**Sprite sources** (from `assets/sprites/player/wizard/`):
- Walk: `animations/walking-8-frames/{direction}/frame_000..007.png` (10 FPS)
- Idle: `animations/breathing-idle/{direction}/frame_XXX.png` (2 FPS) — only south/north have multi-frame
- Other idle directions: single frame from walk frame 0
- south-east: mirrors south-west frames via `sprite.flip_h`

**Animation selection** (`_update_animation`):
- Moving → `walk_{direction}` (10 FPS, looping)
- Idle + AFK → smoke_sit (once) → smoke_loop (looping)
- Idle → `idle_{direction}`

### Direction Detection

```gdscript
_vec_to_direction(v: Vector2) -> String:
    angle = v.angle()  # [-PI, PI] → [0, TAU]
    sector = round(angle / (TAU/8)) % 8
    # Maps to: east, south-east, south, south-west, west, north-west, north, north-east
```

### AFK System

- `afk_timer` increments when velocity < 1.0
- After `afk_timeout` seconds → `is_afk = true`
- AFK animation sequence:
  1. Force direction to "south", disable flip_h
  2. Play `smoke_sit` (6 FPS, no loop, frames 0–7 from smoke/south/)
  3. On `animation_finished` → play `smoke_loop` (6 FPS, loop, frames 8+ from smoke/south/)
- Any input resets AFK

### Move Marker

- Scene: `scenes/ui/move_marker.tscn`
- Spawned at right-click target position
- Only one active marker at a time (old one freed)
- Removed when destination reached or WASD pressed
