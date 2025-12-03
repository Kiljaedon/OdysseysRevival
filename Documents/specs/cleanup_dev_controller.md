# Refactoring Specification: DevClientController Cleanup

## 1. Objective
Reduce code bloat and complexity in `dev_client_controller.gd` by removing the "Facade" anti-pattern. The controller currently acts as a middleman, wrapping methods from its child managers (`MapManager`, `MultiplayerManager`, etc.) with identical function signatures.

## 2. Current State Analysis
*   **File:** `dev_client_controller.gd` (~623 lines).
*   **Pattern:** Orchestrator + Facade.
*   **Issue:** Contains numerous "pass-through" functions.
    *   Example: `func spawn_player(data): return map_manager.spawn_player(data)`
*   **Impact:** Violates DRY (Don't Repeat Yourself). Adds maintenance overhead (changing a Manager function requires updating the Controller wrapper).

## 3. Proposed Architecture
*   **Role of Controller:** Pure Orchestrator. It creates and initializes managers but does *not* hide them.
*   **Role of Managers:** Public API providers.
*   **Access Pattern:** External code (e.g., UI, Network) accesses functionality via `controller.specific_manager.function()` instead of `controller.function()`.

## 4. Implementation Plan

### Phase 1: Publicize Managers
*   Ensure all manager variables (`map_manager`, `multiplayer_manager`, etc.) in `dev_client_controller.gd` are public (not starting with `_`) and typed strictly.

### Phase 2: Update Callers (Search & Replace)
*   Search the codebase for calls to the wrapper methods.
*   Replace them with direct calls to the manager.
    *   `controller.spawn_player(...)` -> `controller.map_manager.spawn_player(...)`
    *   `controller.update_player_position(...)` -> `controller.multiplayer_manager.update_player_position(...)`

### Phase 3: Prune Controller
*   Delete the identified wrapper methods from `dev_client_controller.gd`.
*   Aim for a target size of < 300 lines.

## 5. Verification
*   **Build Test:** Ensure the game runs without "Method not found" errors.
*   **Gameplay Test:** Verify key flows managed by these wrappers (Spawning, Movement, Chat).

## 6. List of Wrappers to Remove (Preliminary)
*   `spawn_player` -> `map_manager`
*   `despawn_player` -> `map_manager`
*   `handle_binary_positions` -> `multiplayer_manager`
*   `sync_positions` -> `multiplayer_manager`
*   `handle_chat` -> `chat_manager`
*   (Full list to be confirmed via analysis)
