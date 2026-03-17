# Module: buildings

**Path**: `scenes/buildings/`
**Files**: `building.gd`, `building.tscn`, `throne.gd`, `throne.tscn`, `lich_king.gd`,
`wall_system.gd`, `wall_draw_node.gd`, `wall_segment.gd`

## building.gd

**Class name**: `Building`
**Extends**: `Node2D`
**Scene**: `building.tscn` — Sprite2D + HPBarBG + HPBar (ColorRects)

Base class for all placeable buildings with HP tracking.

### Setup

`setup(type: String)` reads from `Config.buildings[type]`:
- `hp` → max_hp and current hp
- `sprite` → texture path loaded into Sprite2D
- `sprite_offset` → `[x, y]` array applied to sprite position

### HP System

- `take_damage(amount)` → decreases hp, updates bar, triggers `_on_destroyed()` at 0
- HP bar colors: green (>50%), orange (>25%), red (≤25%)
- HP bar hidden when at full health
- `_on_destroyed()` → `queue_free()` (override in subclasses)

---

## throne.gd

**Class name**: `Throne`
**Extends**: `Building`
**Scene**: `throne.tscn` — Building + CollisionShape2D + HP display

The Lich King's core building. Placed at tile `(14, 15)` by `main.gd`.

### Behavior

- Auto-calls `setup("throne")` in `_ready()`
- Config: 500 HP, sprite `lich_king/throne.png`, offset `(0, -84)`
- `_on_destroyed()` emits `throne_destroyed` signal instead of queue_free
- Destruction = game over condition

---

## lich_king.gd

**Extends**: `AnimatedSprite2D` (no class_name)
**Role**: Lich King NPC with 8-directional idle breathing animations.

### Animation Setup

- Loads frames from `assets/sprites/lich_king/animations/breathing-idle/{direction}/frame_XXX.png`
- 5 base directions: south, south-east, east, north-east, north
- West variants (south-west, west, north-west) are copies of east mirrors — flip_h handled elsewhere
- Fallback: if no animation frames found, loads static rotation from `rotations/{direction}.png`
- Animation speed: 2.0 FPS, looping
- Default: plays `idle_south`

---

## wall_system.gd (914 lines)

**Class name**: `WallSystem`
**Extends**: `Node2D`
**Role**: Core wall building system using a node/edge graph. Handles build, demolish, move
modes with procedural 3D isometric wall rendering.

### Data Structures

```
nodes: Dictionary<Vector2i, true>       — grid positions where walls meet (pillars)
edges: Dictionary<StringName, true>     — wall segments, key format "x1,y1-x2,y2" (sorted)
collision_bodies: Dictionary<StringName, StaticBody2D>  — physics bodies per edge
wall_visuals: Dictionary<StringName, WallDrawNode>      — visual per edge
pillar_visuals: Dictionary<Vector2i, WallDrawNode>      — visual per node
```

### Edge Key Format

Always sorted so `_make_edge_key(A, B) == _make_edge_key(B, A)`:
```
if a.x < b.x or (a.x == b.x and a.y < b.y):
    key = "a.x,a.y-b.x,b.y"
```

### Neighbor Directions

8 directions (4 cardinal + 4 diagonal):
```
(1,0), (-1,0), (0,1), (0,-1), (1,-1), (-1,1), (-1,-1), (1,1)
```

Build/move only connect to **4 cardinal** neighbors. Diagonals used for edge counting.

### Config (from `buildings.json → wall`)

| Param | Default | Description |
|-------|---------|-------------|
| `WALL_HEIGHT` | 28.0 | Wall height in pixels |
| `WALL_THICK` | 6.0 | Half-thickness of wall |
| `FADE_RADIUS` | 50.0 | Distance to start fading walls near player |
| `DEMOLISH_SNAP_RADIUS` | 16.0 | Mouse snap radius for demolish/move |
| `col_top/front/side/dark/brick/highlight/merlon` | hex colors | Wall color palette |

### Coordinate Conversion

Delegates to `BuildingGrid.tile_to_world()` / `world_to_tile()` when available,
has fallback math if BuildingGrid not found.

### Build Mode

1. `build_mode = true` enables preview
2. `_update_build_preview()` — tracks mouse → nearest grid pos
3. `_redraw_build_preview()` — draws ghost pillar + wall connections to adjacent existing nodes
   - Green ghost = new placement
   - Yellow ghost = already exists
4. `place_at_preview()` — adds node, connects to all 4 cardinal neighbors that have nodes

### Demolish Mode

1. `demolish_mode = true` enables hover tracking
2. `_update_demolish_hover()` — finds nearest node within DEMOLISH_SNAP_RADIUS
3. Highlights hovered node + connected walls in red tint
4. `demolish_hovered()` — removes all edges connected to node, removes node, cleans up collisions

### Move Mode (2-phase)

1. **Phase "select"**: hover highlights existing nodes in blue. Click calls `move_select()`.
2. **Phase "place"**: shows blue ghost preview at new position. Click calls `move_place()`.
3. `move_place()`:
   - Collects old edges from selected node
   - Removes old node and all its edges + collisions
   - Places new node at target position
   - Connects to adjacent existing nodes (4 cardinal)

### Visual Rebuild

- `_needs_rebuild` flag set by any structural change
- `_rebuild_visuals()` in `_process()` clears all WallDrawNode children, recreates
- Each wall edge: WallDrawNode added to YSort parent, position.y = min(endpoints.y)
- Each pillar: WallDrawNode at node world position

### Wall Drawing (_draw_wall_edge)

Procedural 3D isometric wall:
1. Computes 4 top corners + 4 ground corners using perpendicular vector
2. Determines front/side face based on `perp.y` (camera-facing detection)
3. Draws front face with brick pattern, side face solid
4. Top face always visible (from above)
5. Outlines in `col_dark`
6. Merlons (battlements) along top edge

### Brick Pattern (_draw_brick_lines)

- 4 rows of bricks per face
- 3 random vertical splits per row (seeded from position for consistency)
- Each brick gets slight color variation (±0.06 brightness)
- Horizontal lines between rows, vertical joint lines within rows

### Pillar Drawing (_draw_pillar)

- 12-segment cylinder (front half visible)
- 6 rows of bricks with joint lines
- Shade gradient from front color to side color
- Top ellipse cap
- Single merlon on top (isometric diamond block)
- Bottom ellipse outline + side outlines

### Transparency

- `_update_transparency()` runs every frame
- Finds player node in YSort children
- Walls/pillars with Y > player.Y and within FADE_RADIUS → modulate.a = 0.5
- Only fades walls "in front of" (below) the player

---

## wall_draw_node.gd

**Class name**: `WallDrawNode`
**Extends**: `Node2D`
**Role**: Command buffer for deferred drawing. Stores polygon + line draw commands,
replays them in `_draw()`.

### API

- `add_polygon(points: PackedVector2Array, color: Color)` — stores polygon command
- `add_line(from, to, color, width)` — stores line command
- `_draw()` — replays all stored commands via `draw_colored_polygon()` / `draw_line()`

### Properties

- `edge_key: StringName` — identifies which wall edge this visualizes
- `node_key: Vector2i` — identifies which pillar node this visualizes
