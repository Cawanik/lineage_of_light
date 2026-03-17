# Module: ui

**Path**: `scenes/ui/`
**Files**: `build_menu.gd`, `build_menu.tscn`, `placement_grid.gd`, `placement_grid.tscn`,
`move_marker.gd`, `move_marker.tscn`

## build_menu.gd

**Extends**: `PanelContainer`
**Scene**: `build_menu.tscn` — PanelContainer > MarginContainer > VBoxContainer > ItemList

### Role

Building selection menu. Dynamically generates buttons from `Config.buildings`.

### Signal

`building_selected(building_type: String)` — emitted when player clicks a building button.

### Button Generation

In `_ready()`, iterates `Config.buildings`. Only buildings with a `hotkey` field are shown
(throne has no hotkey → excluded from menu).

Button format: `"Name  [cost]  (hotkey)"` — e.g. `"Стена  [10]  (1)"`

Colors from `Config.game.ui`:
- `font_color`: `#e8e0ff` (Ghost White)
- `font_hover_color`: `#f0d060` (Pale Gold)
- `font_pressed_color`: `#9933cc` (Cursed Violet)

### Controls

- **B key** toggles menu visibility
- Click button → emits `building_selected` → main.gd activates build tool

### State

- `is_open: bool` — tracks visibility
- `selected_building: String` — last selected type

---

## placement_grid.gd

**Extends**: `Node2D`
**Scene**: `placement_grid.tscn`

### Role

Visual grid overlay for tower placement mode. Shows highlighted cell under mouse cursor.

**Note**: Uses `CELL_SIZE = 128` and simple cartesian grid (NOT isometric).
This appears to be a legacy/separate system from the isometric BuildingGrid.

### Behavior

- When `placement_mode = false` → hides itself
- When active → tracks mouse position, snaps to 128×128 grid cells
- Draws filled rectangle + border + corner marks at hovered cell
- Colors: purple (valid) / red (invalid) — validity check is placeholder (always true)

### API

| Method | Description |
|--------|-------------|
| `toggle_placement()` | Toggles placement_mode on/off |
| `get_cell_world_center()` | Returns world center of currently hovered cell |

---

## move_marker.gd

**Extends**: `Node2D`
**Scene**: `move_marker.tscn`

### Role

Animated movement target indicator. Spawned by Player on right-click.

### Visual

- Purple isometric ellipse (rx = radius, ry = radius × 0.55 for ~25° top-down perspective)
- Inner cross reticle (30% of radius)
- 20 line segments for ellipse outline

### Animation

- Shrinks from `start_radius` (18px) to 4px over `max_lifetime` (2s)
- Fades from alpha 1.0 to 0.0 linearly
- Self-destructs via `queue_free()` at end of lifetime
- Redraws every frame

### Lifecycle

- Created by `Player._spawn_marker(pos)` — one at a time, old marker freed
- Removed by `Player._remove_marker()` when destination reached or WASD pressed
- Also self-destructs after 2 seconds regardless
