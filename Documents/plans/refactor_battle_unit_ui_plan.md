# Refactoring Plan: Split RealtimeBattleUnit

## Phase 1: Create UnitHUD Component
*   [ ] **Create Directory**: `scripts/realtime_battle/components/`.
*   [ ] **Implement `UnitHUD.gd`**:
    *   Move `stats_container`, `health_bar`, `mana_bar`, `damage_label`, `target_indicator` logic here.
    *   Move `_create_visuals` (UI parts), `_style_bar`, `show_damage`, `set_targeted`.
    *   Expose public methods: `initialize_stats(name, hp, mp, ep)`, `update_stats(hp, mp, ep)`, `show_damage(val, type)`, `set_targeted(val)`.

## Phase 2: Integrate into RealtimeBattleUnit
*   [ ] **Refactor `RealtimeBattleUnit.gd`**:
    *   Remove UI variables (`health_bar`, `mana_bar`, etc.).
    *   Remove UI creation methods.
    *   Instantiate `UnitHUD` in `_ready`.
    *   Call `hud.update_stats()` in `apply_server_state`.
    *   Call `hud.show_damage()` in `show_damage` (keep the public method on Unit as a facade or redirect calls).

## Phase 3: Verification
*   [ ] **Test**: Run `tests/test_combat_refactor.gd` (might need updates if it checks internal UI nodes).
*   [ ] **Manual**: Enter combat and verify bars and damage numbers.
