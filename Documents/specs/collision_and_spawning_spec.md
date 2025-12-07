# Specification: Collision, Spawning, and Persistence System

## 1. Objective
To ensure a robust, cheat-proof, and bug-free movement system where:
1.  **Middle Layer Objects** (e.g., walls, trees placed in Tiled) act as solid collision for Players and NPCs.
2.  **Safe Spawning** prevents entities from spawning inside collision objects or off-map.
3.  **Persistence** guarantees players return to their exact last-known valid position upon login or after battle.

## 2. Collision System Upgrade

### 2.1. Middle Layer Detection
The current system relies on a specific "Collision" tileset GID range. This is brittle.
**Requirement:** The `ServerMapManager` must parse the TMX map and treat **all non-empty tiles** on specific layers as blocked.

**Implementation Logic:**
*   Parse TMX `<layer>` tags.
*   Identify layers by name. Target layers containing: "Collision", "Middle", "Objects", "Structures".
*   For these layers, any tile with ID > 0 is flagged as `BLOCKED` in the server-side collision grid (`map_collision_tiles`).
*   **Robustness:** Use string parsing (or safer regex) to avoid server crashes on malformed TMX data.

### 2.2. Collision Map Caching
*   Store collision data in `map_collision_tiles` dictionary: `map_name -> { Vector2i(x,y): true }`.
*   Lazy-load this data when a map is first requested.

## 3. Safe Spawning System

### 3.1. Validation Function
Implement `validate_spawn_position(map_name, target_position) -> Vector2` in `ServerMapManager`.

**Logic:**
1.  Check if `target_position` is inside a blocked tile (using 2.1 data).
2.  If blocked, start a **Spiral Search** (radius 1 to 20 tiles) to find the nearest free tile.
3.  If free tile found: Return new `safe_position`.
4.  If no free tile found (map full?): Return `target_position` (fail-open) or a default safe spawn point (fail-safe).
5.  **Critical Safety:** Wrap this function in safeguards to ensure it never crashes the server thread (infinite loop protection).

### 3.2. Integration Points
*   **Login:** `PlayerManager.request_spawn_character` must call `validate_spawn_position` before confirming spawn.
*   **Map Transition:** `PlayerManager.update_player_map` must call `validate_spawn_position` for the destination.
*   **NPC Spawn:** `ServerNPCManager` must call `validate_spawn_position` for every NPC spawned at startup.
*   **Battle Spawn:** `BattleMapLoader` must continue using `find_nearest_free_spawn` (which shares logic with validation).

## 4. Battle System Integration

### 4.1. Main World Battles
*   **Current State:** Battles happen on the overworld map coordinates.
*   **Requirement:** Ensure combatants are not pushed into walls during battle.
*   **Solution:** `RealtimeCombatManager` already uses `_clamp_unit_to_arena`. We will enhance this to use `map_manager.is_position_blocked` to prevent units from walking/being knocked into Middle Layer objects during the fight.

### 4.2. Instance Battles
*   **Requirement:** Instance battles (dungeons) must use the same collision logic.
*   **Solution:** Instance maps (TMX) must be loaded via `ServerMapManager` so their collision data is cached. The `BattleInstanceManager` will use `validate_spawn_position` when placing the player at the instance entrance.

## 5. Persistence Verification

### 5.1. Logout Persistence
*   **Mechanism:** `PlayerManager.remove_player` (triggered on disconnect) saves `player_positions[peer_id]` to the database.
*   **Verification:** We will confirm that `player_positions` is updated *continuously* or *reliably* before disconnect.
*   **Gap Analysis:** If the server crashes *before* clean logout, position might be lost.
*   **Improvement:** Implement periodic "Save Pulse" (e.g., every 60 seconds) or save on significant events (Map Transition, Battle End).

### 5.2. Login Restoration
*   **Mechanism:** `request_spawn_character` reads `position_x/y` from DB.
*   **Safety:** This position is then passed to `validate_spawn_position` (Section 3.1) to ensure that even if the map changed while offline (placing a wall on top of the player), they log in safely nearby.

## 6. Execution Plan

1.  **Refactor `ServerMapManager`:** Implement robust Middle Layer parsing.
2.  **Re-implement Validator:** Add `validate_spawn_position` with strict safety checks.
3.  **Update Managers:** Hook up Player, NPC, and Combat managers to the new system.
4.  **Verify:** Test login inside a wall, test NPC spawning, test battle knockback against walls.
