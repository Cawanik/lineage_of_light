# Lineage of Light — Architecture

## Overview

Reverse tower defense on an isometric grid. The player is the Lich King defending a throne
against waves of heroes. Build walls, place towers, survive 15 waves across 5 epochs.

**Engine**: Godot 4.6 | **Renderer**: GL Compatibility | **Resolution**: 1280×720 (stretch)

## Scene Tree

```
Main (Node2D)                         ← scenes/main/main.gd — orchestrator
├── Ground (IsoGround)                ← scenes/main/iso_ground.gd — tile rendering
├── YSort (Node2D, y_sort_enabled)    ← depth ordering
│   ├── Player (CharacterBody2D)      ← scenes/player/player.gd
│   │   └── Camera2D
│   ├── BuildingGrid (Node2D)         ← scenes/main/building_grid.gd — grid math
│   ├── LichKing (AnimatedSprite2D)   ← scenes/buildings/lich_king.gd
│   └── WallSystem (Node2D)           ← scenes/buildings/wall_system.gd — wall graph
├── PlacementGrid                     ← scenes/ui/placement_grid.gd
├── PerspectiveLayer (CanvasLayer 10) ← shader overlay
│   └── PerspectiveRect (ColorRect)
└── UILayer (CanvasLayer 11)
    ├── BuildMenu                     ← scenes/ui/build_menu.gd
    └── Toolbar (PanelContainer)
        └── Grid → BuildButton, DemolishButton, MoveButton
```

## Module Map

| Module | Path | Purpose |
|--------|------|---------|
| **main** | `scenes/main/` | Game orchestration, grid system, ground rendering |
| **buildings** | `scenes/buildings/` | Wall graph, building base class, throne, lich king NPC |
| **tools** | `scripts/tools/` | Build/Demolish/Move tool pattern (Strategy) |
| **player** | `scenes/player/` | Player movement, camera, 8-dir animations, AFK |
| **enemies** | `scenes/enemies/` | PathFollow2D enemies with HP/slow/death |
| **towers** | `scenes/towers/` | Tower targeting, 3 attack types |
| **ui** | `scenes/ui/` | Build menu, placement grid, move marker |
| **autoload** | `scripts/autoload/` | Config, GameManager, WaveManager (singletons) |
| **data** | `scripts/data/` | EnemyData, TowerData (static dictionaries) |
| **config** | `config/` | JSON: game.json, buildings.json, player.json |

## Key Patterns

1. **Isometric Grid** — `BuildingGrid` is the single source of truth for tile↔world conversion.
   All modules use `tile_to_world()` / `world_to_tile()`. Cell size 64, ISO ratio 0.5.

2. **Config-Driven** — `Config` autoload reads JSON files at startup. Building stats, wall
   colors, tile weights, player speed — all from `config/*.json`.

3. **Tool Pattern** — `BaseTool` (RefCounted) defines activate/deactivate/click lifecycle.
   `BuildTool`, `DemolishTool`, `MoveTool` delegate to `WallSystem` methods.
   Main.gd manages one `active_tool` at a time.

4. **Wall Graph** — `WallSystem` stores walls as a node/edge graph (`Dictionary<Vector2i, true>`
   for nodes, `Dictionary<StringName, true>` for edges). Edge keys are sorted `"x1,y1-x2,y2"`.
   Visual rebuild is deferred via `_needs_rebuild` flag.

5. **Y-Sort Rendering** — The YSort node handles depth ordering. WallDrawNode instances
   are added to YSort with position.y controlling draw order.

6. **Signal Architecture** — `GameManager` broadcasts state changes (gold_changed,
   lives_changed, game_over). `WaveManager` emits wave_started/completed.

7. **Procedural Drawing** — Walls/pillars are drawn via WallDrawNode command buffers
   (polygon + line arrays replayed in `_draw()`). No sprites for walls.

## Input Map

| Key | Action |
|-----|--------|
| WASD | Player movement |
| Right-click | Move to point |
| Mouse wheel | Camera zoom (0.5–4.0×) |
| B | Toggle build menu |
| G | Toggle debug grid overlay |
| 1 | Wall hotkey (in build menu) |
| Left-click | Tool action (build/demolish/move) |

## Data Flow

```
JSON configs → Config autoload → All modules read on _ready()
                                    ↓
GameManager ← → EnemyBase (gold/lives on kill/reach end)
WaveManager → spawns EnemyBase → PathFollow2D along path
TowerBase → detects enemies in Area2D → fires projectiles / AoE
Main.gd → manages Tool lifecycle → delegates to WallSystem
```
