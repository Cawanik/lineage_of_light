# Module: tools

**Path**: `scripts/tools/`
**Files**: `base_tool.gd`, `build_tool.gd`, `demolish_tool.gd`, `move_tool.gd`

## Pattern: Strategy

Tools implement a Strategy pattern. `main.gd` holds one `active_tool: BaseTool` and
delegates input to it. All tools are `RefCounted` (not Nodes), instantiated once at startup.

## base_tool.gd

**Class name**: `BaseTool`
**Extends**: `RefCounted`

### Lifecycle

```
activate(ws: WallSystem)  → sets wall_system, is_active=true, calls _on_activate()
deactivate()              → calls _on_deactivate(), is_active=false
update()                  → calls _on_update() if active
click()                   → calls _on_click() if active
```

### Virtual Methods (override in subclasses)

| Method | Called when |
|--------|-----------|
| `_on_activate()` | Tool becomes active |
| `_on_deactivate()` | Tool is deactivated |
| `_on_update()` | Every frame while active |
| `_on_click()` | Left mouse click while active |

---

## build_tool.gd

**Class name**: `BuildTool`
**Extends**: `BaseTool`

### Behavior

| Method | Action |
|--------|--------|
| `_on_activate()` | Sets `wall_system.build_mode = true` |
| `_on_deactivate()` | Calls `wall_system.clear_build_mode()` |
| `_on_update()` | Calls `wall_system._update_build_preview()` |
| `_on_click()` | Calls `wall_system.place_at_preview()` |

Places a new wall node at the mouse position. Automatically connects to adjacent
existing nodes in 4 cardinal directions. Shows green/yellow ghost preview.

---

## demolish_tool.gd

**Class name**: `DemolishTool`
**Extends**: `BaseTool`

### Behavior

| Method | Action |
|--------|--------|
| `_on_activate()` | Sets `wall_system.demolish_mode = true` |
| `_on_deactivate()` | Calls `wall_system.clear_demolish_mode()` |
| `_on_update()` | Calls `wall_system._update_demolish_hover()` |
| `_on_click()` | Calls `wall_system.demolish_hovered()` |

Snaps to nearest wall node within `DEMOLISH_SNAP_RADIUS` (16px).
Highlights hovered node and all connected wall segments in red.
Click removes the node and all its edges.

---

## move_tool.gd

**Class name**: `MoveTool`
**Extends**: `BaseTool`

### Behavior

| Method | Action |
|--------|--------|
| `_on_activate()` | Sets `wall_system.move_mode = true` |
| `_on_deactivate()` | Calls `wall_system.clear_move_mode()` |
| `_on_update()` | Calls `wall_system._update_move_preview()` |
| `_on_click()` | Phase-dependent: select or place |

### Two-Phase Flow

1. **Select** (`wall_system.move_phase == "select"`):
   Click calls `wall_system.move_select()` — locks the hovered node as selected (blue highlight).

2. **Place** (`wall_system.move_phase == "place"`):
   Click calls `wall_system.move_place()` — removes old node/edges, creates new node,
   connects to adjacent existing nodes at new position.

---

## Integration with main.gd

```gdscript
# main.gd creates tools once:
tools = {"build": BuildTool.new(), "demolish": DemolishTool.new(), "move": MoveTool.new()}

# Activation:
_set_tool("build")  → deactivates current, activates new
_set_tool("build")  → same tool = toggle off (deactivate only)

# Input forwarding:
func _input(event):
    if active_tool and left_click:
        active_tool.click()
```

Build tool is special: activated via BuildMenu selection, not directly.
Demolish and Move are activated via toolbar buttons.
