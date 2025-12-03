# Combat System Refactor Plan

## Phase 1: Scene Creation
*   [ ] Create directory `scenes/battle/` if it doesn't exist.
*   [ ] Create `scenes/battle/realtime_battle.tscn` with the structure defined in the Spec.
    *   Root: `RealtimeBattle` (Node2D)
    *   Children: `ArenaRenderer`, `UnitsContainer`, `BattleCamera`, `BattleUI`.
    *   UI Components: `PlayerHUD` with bars and labels.
*   [ ] Save the scene.

## Phase 2: Script Refactoring
*   [ ] **Refactor `realtime_battle_scene.gd`**:
    *   Add `@onready` variables for `arena_renderer`, `units_container`, `camera`, `ui_layer`, `player_hp_bar`, etc.
    *   Delete `_create_scene_structure` and `_create_player_corner_hud`.
    *   Update `_ready` to rely on the scene tree.
*   [ ] **Refactor `realtime_battle_launcher.gd`**:
    *   Change `active_battle_scene = Node2D.new()` to `active_battle_scene = preload("res://scenes/battle/realtime_battle.tscn").instantiate()`.

## Phase 3: Integration & Fixes
*   [ ] **Fix `multiplayer_manager.gd`**:
    *   Update `handle_combat_round_results` to search for `"RealtimeBattle"` instead of `"BattleWindow"`.
    *   Add a fallback check or error log if the node isn't found.

## Phase 4: Verification
*   [ ] **Test Script**: Create `tests/test_combat_refactor.gd`.
    *   Instantiate `RealtimeBattle.tscn`.
    *   Verify all child nodes exist.
    *   Call `update_player_hud` and verify the progress bars update.
    *   Simulate `handle_combat_round_results` call.
*   [ ] **Run Test**: Execute the test script via `godot --headless`.
