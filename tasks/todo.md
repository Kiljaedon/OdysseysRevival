# Battle System Fix Plan - Three Critical Issues

## Current Status Analysis

Based on codebase investigation:

### Issue 1: Timer Display (TurnInfo Label)
- **Status**: Label exists at `$UIPanel/UIArea/TurnInfo`
- **Current Config**: Font size 20, horizontal alignment center
- **Problem**: Visibility may be OK, but needs verification
- **Required Fix**:
  - Increase font size to 24-28px
  - Add yellow/white color for visibility
  - Ensure z_index is high enough
  - Verify text updates properly during countdown

### Issue 2: Back Row Enemies (Panels 4, 5, 6)
- **Status**: All 6 panels exist in battle_window.tscn
- **Panel Positions**:
  - Front row (1-3): x=380 (ENEMY_FRONT_X)
  - Back row (4-6): x=520 (ENEMY_BACK_X)
- **Problem**: Panels exist BUT may not have sprites/data loading
- **Code shows**: All 6 panels are initialized in setup_battle()
- **Suspected Issue**: `enemy_squad` may only have 3 enemies, not 6
- **Required Fix**: Check enemy spawning logic to ensure 6 enemies are generated

### Issue 3: Target Selection Cursor
- **Status**: TargetCursor node exists, z_index=200, visible=false
- **Current Implementation**:
  - `show_target_cursor()` function exists and works
  - Called from `_on_enemy_panel_clicked()` during TARGET_SELECTION state
  - Uses yellow border (Color(1, 1, 0, 1))
- **Problem**: May be working but needs testing
- **Potential Issue**: Enemy panels may need mouse_filter = MOUSE_FILTER_STOP

## Action Plan

### Task 1: Fix Timer Display Styling
- [x] Read current TurnInfo configuration
- [ ] Update font size to 28px
- [ ] Add yellow color (Color(1, 0.9, 0, 1))
- [ ] Set z_index to 150
- [ ] Verify countdown display works

### Task 2: Investigate Back Row Enemy Spawning
- [x] Confirm all 6 panels exist in scene
- [x] Confirm panels are initialized in code
- [ ] Check enemy squad generation (load_enemy_squad function)
- [ ] Verify enemy_squad.size() == 6
- [ ] If < 6, fix enemy generation to create 6 enemies
- [ ] Test that all 6 enemy sprites appear

### Task 3: Verify Target Selection System
- [x] Confirm TargetCursor node exists
- [x] Confirm show_target_cursor() is called
- [ ] Check enemy panel mouse_filter settings
- [ ] Add visual feedback on enemy panel hover
- [ ] Test clicking Attack → clicking enemy → cursor appears
- [ ] Verify confirmation works

## Implementation Steps

1. First, fix TurnInfo label styling (simple change)
2. Then investigate enemy squad size (check load_enemy_squad)
3. Finally, verify target selection works (may already work)

---

## Next: Wait for User Confirmation

Before proceeding with changes, confirm this plan with the user.
