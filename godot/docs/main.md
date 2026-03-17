# Module: main

**Path**: `scenes/main/`
**Files**: `main.gd`, `main.tscn`, `building_grid.gd`, `iso_ground.gd`

## main.gd

**Extends**: `Node2D`
**Role**: Top-level game orchestrator. Initializes the world, manages tool lifecycle.

### Dependencies

| Node | Type | Variable |
|------|------|----------|
| `$PlacementGrid` | PlacementGrid | `placement_grid` |
| `$UILayer/BuildMenu` | BuildMenu | `build_menu` |
| `$UILayer/Toolbar/Grid/BuildButton` | TextureButton | `build_button` |
| `$UILayer/Toolbar/Grid/DemolishButton` | TextureButton | `demolish_button` |
| `$UILayer/Toolbar/Grid/MoveButton` | TextureButton | `move_button` |
| `$YSort/WallSystem` | WallSystem | `wall_system` |
| `$YSort/BuildingGrid` | BuildingGrid | `building_grid` |
| `$YSort/LichKing` | AnimatedSprite2D | `lich_king` |

### State

- `active_tool: BaseTool` — currently active tool (null = no tool)
- `tools: Dictionary` — `{"build": BuildTool, "demolish": DemolishTool, "move": MoveTool}`

### Init Sequence (_ready)

1. Creates tool instances (BuildTool, DemolishTool, MoveTool)
2. Connects UI signals (build_menu.building_selected, button presses)
3. Places throne at tile `(14, 15)` via `building_grid.place_building()`
4. Places Lich King at tile `(15, 15)`
5. Builds initial walls: two connected rectangular boxes starting at `(15, 15)`
   - Box 1: 4×4 square
   - Box 2: 3×4 rectangle sharing the east side of box 1

### Tool Management

- `_set_tool(tool_name)` — deactivates current tool, activates new one. Same tool = toggle off.
- Build button → toggles `BuildMenu` visibility (menu selects building type)
- Demolish/Move buttons → direct `_set_tool()` calls
- `_input()` forwards left-click to `active_tool.click()`

### Key Relationships

- `main.gd` does NOT handle rendering — delegates to WallSystem, BuildingGrid, IsoGround
- Tools receive `wall_system` reference on activation
- Building selection flow: BuildMenu → `building_selected` signal → `_on_building_selected("wall")` → `_set_tool("build")`

---

## building_grid.gd

**Class name**: `BuildingGrid`
**Extends**: `Node2D`
**Role**: Single source of truth for isometric tile↔world coordinate conversion and building placement.

### Config (from `game.json → iso`)

| Param | Default | Source |
|-------|---------|--------|
| `CELL_SIZE` | 64 | `Config.game.iso.cell_size` |
| `ISO_RATIO` | 0.5 | `Config.game.iso.iso_ratio` |

### Coordinate Conversion

```
tile_to_world(tile: Vector2i) -> Vector2:
    screen_x = (tile.x - tile.y) * CELL_SIZE * 0.5
    screen_y = (tile.x + tile.y) * CELL_SIZE * ISO_RATIO * 0.5 + 15.0

world_to_tile(world_pos: Vector2) -> Vector2i:
    inverse of above, with adjusted_y = world_pos.y - 15.0
```

The +15.0 Y offset aligns tiles with visual ground.

### Storage

- `buildings: Dictionary` — `Vector2i → Building node`
- `wall_nodes: Dictionary` — `Vector2i → true` (tracks wall pillar positions)

### API

| Method | Description |
|--------|-------------|
| `tile_to_world(tile)` | Tile coords → world pixel position (center of diamond) |
| `world_to_tile(pos)` | World pixel → nearest tile coords |
| `place_building(tile, building)` | Stores building, sets its position |
| `remove_building(tile)` | Removes and returns building node |
| `get_building(tile)` | Lookup by tile |
| `is_occupied(tile)` | True if building or wall node exists |

### Debug Grid

- Press **G** to toggle grid overlay (30×30 diamond grid)
- Arrow keys shift grid offset for alignment tuning
- Yellow = free, Red = occupied

---

## iso_ground.gd

**Class name**: `IsoGround`
**Extends**: `Node2D`
**Role**: Renders the isometric ground plane with weighted random tile placement.

### Config (from `game.json`)

- `iso.*` — grid dimensions, cell size, ISO ratio, seed
- `tile_weights.*` — probability weights per grass variant

### Tile Variants

8 grass tiles loaded from `assets/sprites/tiles/iso_grass_0.png` through `iso_grass_7.png`:
- 0–3: wildflower, mushroom, leaves, sparse (weight 15 each)
- 4–7: dandelion, daisy, clover, twigs (weight 10 each)

### Generation

- Uses seeded RNG (`ground_seed: 42`) for deterministic maps
- Weighted random via cumulative probability distribution
- Grid stored as `Dictionary<Vector2i, int>` (tile index)
- All rendering via `_draw()` using `draw_texture()` at iso-projected positions

### Rendering Formula

```
screen_x = (x - y) * (CELL_SIZE * 0.5)
screen_y = (x + y) * (CELL_SIZE * ISO_RATIO * 0.5) + 20.0
```

Note: +20.0 offset here vs +15.0 in BuildingGrid — slight visual misalignment by design.
