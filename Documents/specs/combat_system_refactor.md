# Combat System Refactoring Specification

## 1. Objective
Refactor the client-side Realtime Battle system to move from code-based node instantiation to a Scene-based architecture (`.tscn`). This will improve maintainability, allow for easier UI editing, and resolve existing bugs regarding node references (specifically the "BattleWindow" error).

## 2. Current State Analysis
*   **Battle Instantiation**: `RealtimeBattleLauncher` creates a `Node2D` and attaches `realtime_battle_scene.gd`. It then manually creates children (`ArenaRenderer`, `UnitsContainer`, `BattleCamera`, `BattleUI`).
*   **UI Construction**: The HUD is built entirely via code in `RealtimeBattleScene._create_player_corner_hud`.
*   **Bug**: `multiplayer_manager.gd` tries to find a node named `"BattleWindow"` to send results, but the actual node is named `"RealtimeBattle"`.
*   **Assets**: No `battle.tscn` exists.

## 3. Proposed Architecture

### 3.1 New Scene: `scenes/battle/realtime_battle.tscn`
A dedicated scene file to define the battle structure.

**Node Structure:**
```text
RealtimeBattle (Node2D) - Script: res://scripts/realtime_battle/realtime_battle_scene.gd
├── ArenaRenderer (Node2D)
├── UnitsContainer (Node2D)
├── BattleCamera (Camera2D)
└── BattleUI (CanvasLayer)
    └── PlayerHUD (Control)
        ├── Background (Panel)
        ├── NameLabel (Label)
        ├── HPBar (ProgressBar)
        ├── MPBar (ProgressBar)
        └── EPBar (ProgressBar)
```

### 3.2 Script Modifications

#### `scripts/realtime_battle/realtime_battle_scene.gd`
*   **Remove**: `_create_scene_structure()`, `_create_player_corner_hud()`.
*   **Add**: `@onready` references to the nodes defined in the `.tscn`.
*   **Refactor**: `update_player_hud` to use the `@onready` UI references.

#### `scripts/realtime_battle/realtime_battle_launcher.gd`
*   **Change**: Instead of `Node2D.new()`, use `load("res://scenes/battle/realtime_battle.tscn").instantiate()`.
*   **Consistency**: Ensure the instantiated scene is named `"RealtimeBattle"`.

#### `source/client/managers/multiplayer_manager.gd`
*   **Fix**: Update `handle_combat_round_results` to locate `"RealtimeBattle"` (or communicate via `RealtimeBattleLauncher`) instead of `"BattleWindow"`.
*   **Improvement**: If `RealtimeBattleLauncher` is a known singleton or globally accessible, use it to route the data.

## 4. Implementation Plan
1.  **Create Scene**: Build `scenes/battle/realtime_battle.tscn` in the editor (or via script for this environment) matching the structure.
2.  **Clean Script**: Strip the manual creation code from `realtime_battle_scene.gd`.
3.  **Update Launcher**: Modify `realtime_battle_launcher.gd` to load the new scene.
4.  **Fix Manager**: Update `multiplayer_manager.gd` target node path.
5.  **Verify**: Run a test battle (or mock test) to ensure the scene loads and the HUD updates without errors.

## 5. Verification Criteria
*   `RealtimeBattle` node exists in the tree during combat.
*   `multiplayer_manager.gd` successfully sends data without "Node not found" errors.
*   Visual elements (Arena, Units, UI) appear correctly.
