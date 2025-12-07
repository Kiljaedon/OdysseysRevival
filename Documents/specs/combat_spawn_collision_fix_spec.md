# Combat, Spawn, and Collision System Fix Specification

## Overview
This document specifies fixes for multiple interconnected bugs affecting combat flow, NPC behavior, and spawn positioning.

## Bug Analysis

### Bug 1: Battle Units Spawn Inside Collision Zones
**Symptom:** NPCs walk in place, player hits invisible walls during combat.
**Root Cause:** `RealTimeCombatSpawner.gd` calculates spawn positions but does NOT validate them against map collision tiles. It only clamps to map edges.
**Files Affected:**
- `source/server/managers/combat/realtime_combat_spawner.gd`
- `source/server/managers/realtime_combat_manager.gd`

**Evidence:** Lines 78-81 of `realtime_combat_spawner.gd`:
```gdscript
spawn_pos.x = clamp(spawn_pos.x, MAP_EDGE_PADDING, map_width - MAP_EDGE_PADDING)
spawn_pos.y = clamp(spawn_pos.y, MAP_EDGE_PADDING, map_height - MAP_EDGE_PADDING)
# NO collision validation - spawns directly at calculated position
unit.position = spawn_pos
```

### Bug 2: NPC World Movement Issues
**Symptom:** Many NPCs don't move, some barely animate/walk in place.
**Root Cause:** While `npc_manager.gd` has collision checks, NPCs may:
1. Spawn correctly but have no valid wander targets
2. Be stuck due to StaticBody2D collision shapes from objectgroup
3. Movement validator rejecting all movement attempts

**Evidence:** Lines 186-208 try 10 random targets - if all blocked, NPC stays idle.

### Bug 3: Combat Targeting Works But Attacks Don't Execute
**Symptom:** Player can target NPCs (space key) but attacks never execute.
**Potential Causes:**
1. Units stuck in collision zones have wrong positions
2. Server-side range checks fail due to position desync
3. Attack state machine stuck (unit already in attack_state)
4. Max attackers check preventing attacks

## Fix Implementation

### Fix 1: Add Collision Validation to Battle Spawner

**File:** `source/server/managers/combat/realtime_combat_spawner.gd`

**Change:** Add map_manager reference and validate all spawn positions.

```gdscript
# Add static variable for map_manager reference
static var _map_manager = null

static func set_map_manager(map_mgr) -> void:
    _map_manager = map_mgr

# Modify spawn functions to validate positions
static func _validate_spawn_position(position: Vector2, map_name: String, map_width: int, map_height: int) -> Vector2:
    """Validate spawn position is not in collision zone, find free spot if blocked"""
    # Clamp to bounds first
    position.x = clamp(position.x, MAP_EDGE_PADDING, map_width - MAP_EDGE_PADDING)
    position.y = clamp(position.y, MAP_EDGE_PADDING, map_height - MAP_EDGE_PADDING)

    # If map_manager available, find nearest free spawn
    if _map_manager:
        position = _map_manager.find_nearest_free_spawn(map_name, position)

    return position
```

### Fix 2: Pass Map Manager to Spawner on Battle Creation

**File:** `source/server/managers/realtime_combat_manager.gd`

**Change:** In `initialize()` or `create_battle()`, pass map_manager to spawner.

```gdscript
func initialize(p_server_world, p_player_manager, p_npc_manager) -> void:
    # ... existing code ...

    # Pass map_manager to spawner for collision validation
    if server_world and server_world.has_method("get_map_manager"):
        var map_mgr = server_world.get_map_manager()
        if map_mgr:
            RealTimeCombatSpawner.set_map_manager(map_mgr)
            print("[RT_COMBAT] Map manager set for spawn collision validation")
```

### Fix 3: Update All Spawn Functions to Validate Positions

**File:** `source/server/managers/combat/realtime_combat_spawner.gd`

Update `spawn_player_unit`, `spawn_squad_units`, and `spawn_enemy_units`:

```gdscript
static func spawn_player_unit(battle: Dictionary, peer_id: int, player_data: Dictionary, player_world_pos: Vector2) -> void:
    # ... create unit ...

    # VALIDATE spawn position against collision
    var map_name = battle.get("battle_map_name", "sample_map")
    player_world_pos = _validate_spawn_position(player_world_pos, map_name, battle.map_width, battle.map_height)

    unit.position = player_world_pos
    # ... rest of function ...

static func spawn_squad_units(battle: Dictionary, peer_id: int, squad_data: Array, player_world_pos: Vector2, map_width: int, map_height: int) -> void:
    # ... for each squad member ...
    var map_name = battle.get("battle_map_name", "sample_map")
    spawn_pos = _validate_spawn_position(spawn_pos, map_name, map_width, map_height)
    unit.position = spawn_pos
    # ...

static func spawn_enemy_units(battle: Dictionary, enemy_data: Array, player_world_pos: Vector2, map_width: int, map_height: int) -> void:
    # ... for each enemy ...
    var map_name = battle.get("battle_map_name", "sample_map")
    spawn_pos = _validate_spawn_position(spawn_pos, map_name, map_width, map_height)
    unit.position = spawn_pos
    # ...
```

### Fix 4: Add Getter for Map Manager in ServerWorld

**File:** `source/server/server_world.gd`

```gdscript
func get_map_manager() -> ServerMapManager:
    return map_manager
```

### Fix 5: Improve NPC Wander Target Finding

**File:** `source/server/managers/npc_manager.gd`

Current code tries 10 random positions. If map has many blocked tiles, increase attempts and use smarter search:

```gdscript
# Increase from 10 to 20 attempts
for _attempt in range(20):
    # ... existing random target code ...

# If still no valid target, use spiral search from spawn position
if not found_valid_target and map_manager:
    var free_pos = map_manager.find_nearest_free_spawn("sample_map", npc.spawn_position, 3)
    if free_pos != npc.spawn_position:
        npc.target = free_pos
        npc.state = "moving"
        found_valid_target = true
```

### Fix 6: Add Debug Logging for Attack Rejections

**File:** `source/server/managers/combat/realtime_combat_input.gd`

Already has logging - verify logs are reaching console when attacks fail.

## Validation Tests

After implementing fixes:

1. **Spawn Position Test:**
   - Start server
   - Note spawn positions in console
   - Verify no units spawn at collision tile coordinates

2. **NPC Movement Test:**
   - Observe NPCs for 30 seconds
   - All NPCs should move periodically
   - No NPCs should walk in place (stuck animation)

3. **Combat Test:**
   - Engage NPC in battle
   - Press SPACE to attack
   - Verify attack executes (check console for "[RT_COMBAT] Attack started")
   - Damage should be applied and broadcast

4. **Invisible Wall Test:**
   - Move around battle area
   - No unexpected collision zones
   - Player movement smooth within arena bounds

## File Changes Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `realtime_combat_spawner.gd` | MODIFY | Add collision validation for all spawn positions |
| `realtime_combat_manager.gd` | MODIFY | Pass map_manager to spawner on init |
| `server_world.gd` | MODIFY | Add get_map_manager() helper |
| `npc_manager.gd` | MODIFY | Improve wander target finding |

## Priority Order

1. **HIGH:** Fix battle spawner collision validation (causes combat to break)
2. **HIGH:** Pass map_manager to spawner
3. **MEDIUM:** Improve NPC wander target finding
4. **LOW:** Add additional debug logging
