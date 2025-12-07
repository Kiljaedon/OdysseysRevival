# Refactoring Specification: Split RealtimeBattleUnit

## 1. Objective
Separate the UI and visual logic from the core game state and logic in `RealtimeBattleUnit.gd`. This will create a cleaner architecture, reduce file size, and allow for easier UI customization.

## 2. Current State
*   **File:** `scripts/realtime_battle/realtime_battle_unit.gd` (~602 lines)
*   **Responsibilities:**
    *   **Logic:** State (HP, MP), Interpolation, Server Sync, Combat Stats.
    *   **Visuals:** Sprite management, Animation frame logic (atlas loading).
    *   **UI:** Creating and updating Health/Mana bars, floating damage text, target indicators.

## 3. Proposed Architecture

### A. `UnitHUD` (New Component)
*   **Role:** Pure UI handling.
*   **Responsibility:** Creating bars, updating values, showing floating text.
*   **Location:** `scripts/realtime_battle/components/unit_hud.gd` (or `source/client/combat/ui/unit_hud.gd`)
*   **API:**
    *   `setup(unit_name, max_hp, max_mp, max_energy)`
    *   `update_stats(hp, mp, energy)`
    *   `show_damage(amount, type)`
    *   `set_targeted(visible)`

### B. `RealtimeBattleUnit` (Existing, Refactored)
*   **Role:** Core Logic & Visual State (Sprite).
*   **Responsibility:** Interpolation, Server Sync, Animation State, Sprite Frame management.
*   **Dependencies:** Instantiates or has a child `UnitHUD`.
*   **Changes:** Remove all `ProgressBar`, `Label`, `Control` creation code. Delegate to `UnitHUD`.

## 4. Implementation Plan

1.  **Create `UnitHUD` Script**: Copy the UI creation and update logic (`_create_visuals`, `_style_bar`, `update_player_hud`, `show_damage`) into a new class.
2.  **Refactor `RealtimeBattleUnit`**:
    *   Add `@onready var hud: UnitHUD` (or instantiate it).
    *   Replace direct UI calls with `hud.function()`.
    *   Remove deleted UI code.

## 5. Verification
*   Run battle test.
*   Ensure health bars and damage numbers still appear.
