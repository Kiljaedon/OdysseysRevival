# Sprite Maker Refactor Plan

## Goal
Reduce `odyssey_sprite_maker.gd` from 1852 lines to ~450 lines by extracting components.

## Current File Analysis

```
odyssey_sprite_maker.gd (1852 lines)
├── Lines 1-91: Variables, constants, @onready refs
├── Lines 93-206: _ready() + admin check
├── Lines 207-500: create_stat_display_ui() - EXTRACT
├── Lines 502-535: upload button setup (small, keep)
├── Lines 536-708: stat calculations + role handlers - EXTRACT
├── Lines 710-722: _process() + visibility check
├── Lines 724-948: sprite grid, selection, loading - EXTRACT
├── Lines 950-968: single click handler - EXTRACT
├── Lines 978-1118: _on_save_character_pressed() - EXTRACT
├── Lines 1120-1276: upload functions - EXTRACT
├── Lines 1278-1410: _on_load_character_pressed() - EXTRACT (duplicate code)
├── Lines 1412-1490: populate_class_list/npc_list (keep, uses UI)
├── Lines 1492-1649: list selection + load_character_from_path - EXTRACT
├── Lines 1651-1663: update_character_preview (keep)
├── Lines 1665-1697: delete handlers (keep, small)
├── Lines 1699-1852: type buttons, pagination, back button (keep)
```

## Target Structure

```
odyssey_sprite_maker.gd          (~450 lines) - Main coordinator
components/
├── sprite_grid.gd               (~250 lines) - Grid display, selection, pagination
├── stats_panel.gd               (~280 lines) - Stat UI creation, calculations
└── character_io.gd              (~320 lines) - Save, load, upload functions
```

## Extraction Details

### 1. sprite_grid.gd (~250 lines)

**Class**: `SpriteMakerGrid extends RefCounted`

**Move these functions:**
- `load_character_sprites()` (lines 757-792)
- `display_sprite_grid()` (lines 795-832)
- `load_visible_sprites()` (lines 834-872)
- `get_sprite_texture()` (lines 874-900)
- `get_sprite_texture_from_data()` (lines 1804-1826)
- `_on_sprite_gui_input()` (lines 902-948)
- `_on_sprite_single_click()` (lines 950-968)
- `update_selected_sprites_list()` (lines 724-755)

**Move these variables:**
- `sprite_regions: Array[Dictionary]`
- `atlas_textures: Array[Texture2D]`
- `sprite_cache: Dictionary`
- `loaded_buttons: Dictionary`
- `selection_start: int`
- `selected_sprites: Array`
- `current_page: int`
- `rows_per_page: int`
- `total_pages: int`

**Move these constants:**
- `CHARACTER_ROWS`
- `SPRITE_SIZE`
- `COLS_PER_ROW`
- `ROWS_PER_ATLAS`
- `PREVIEW_COL`
- `CROP_EDGE`

**Signals to emit:**
- `sprite_row_selected(row: int, sprites: Array)`
- `status_changed(message: String)`

**Dependencies needed:**
- Reference to `grid_container: GridContainer`
- Reference to `scroll_container: ScrollContainer`

---

### 2. stats_panel.gd (~280 lines)

**Class**: `SpriteMakerStats extends RefCounted`

**Move these functions:**
- `create_stat_display_ui()` (lines 207-500)
- `_on_element_changed()` (line 536-538)
- `_on_edit_mode_toggled()` (lines 540-580)
- `_on_manual_stat_changed()` (lines 582-588)
- `_calculate_hp()` (lines 589-606)
- `_calculate_mp()` (lines 608-622)
- `_calculate_ep()` (lines 624-630)
- `_on_role_dropdown_selected()` (lines 632-645)
- `_on_add_role_pressed()` (lines 647-666)
- `update_combat_role_display()` (lines 668-674)
- `_on_stats_changed()` (lines 676-708)

**Move these variables:**
- `stat_display_container: VBoxContainer`
- `element_option: OptionButton`
- `ai_option: OptionButton`
- `min_level_spin, max_level_spin: SpinBox`
- `xp_spin, gold_spin: SpinBox`
- `selected_combat_role: String`
- `level_spin, str_spin, dex_spin, int_spin, vit_spin, wis_spin, cha_spin: SpinBox`
- `total_label, hp_label, mp_label, ep_label: Label`
- `hp_spin, mp_spin, ep_spin: SpinBox`
- `edit_mode_button: Button`
- `is_edit_mode: bool`
- `manual_hp, manual_mp, manual_ep: int`
- `desc_text: TextEdit`

**Signals to emit:**
- `stats_changed(stats: Dictionary)`

**Dependencies needed:**
- Reference to `control_panel: VBoxContainer`
- Reference to role UI elements
- `current_type: String` (to know class vs npc formula)

---

### 3. character_io.gd (~320 lines)

**Class**: `SpriteMakerIO extends RefCounted`

**Move these functions:**
- `_on_save_character_pressed()` (lines 978-1118) → `save_character()`
- `_on_upload_button_pressed()` (lines 1120-1157) → `upload_character()`
- `_prepare_character_data_for_upload()` (lines 1159-1261)
- `_on_load_character_pressed()` (lines 1278-1410) - DELETE (duplicate)
- `load_character_from_path()` (lines 1522-1649)

**Dependencies needed:**
- `character_data: Dictionary`
- `current_type: String`
- Stats panel reference (to read stat values)
- Grid reference (to get textures)
- `animation_names: Array`

**Signals to emit:**
- `character_saved(name: String, type: String)`
- `character_loaded(data: Dictionary)`
- `upload_started(name: String)`
- `error(message: String)`

---

## Main File After Refactor (~450 lines)

**Keep in odyssey_sprite_maker.gd:**
- All `@onready` variable declarations
- `animation_names` array
- `character_data` dictionary
- `current_type` and `current_animation`
- `_ready()` function (modified to init components)
- `create_upload_button()` and `_update_upload_button_text()`
- `_process()` (modified to call grid.load_visible_sprites())
- `update_frames_display()`
- `populate_class_list()` and `populate_npc_list()`
- `_on_class_list_selected()` and `_on_npc_list_selected()`
- `update_character_preview()`
- `_on_delete_class_pressed()` and `_on_delete_npc_pressed()`
- `update_type_buttons()`
- `reset_template()`
- `_on_set_class_type_pressed()` and `_on_set_npc_type_pressed()`
- `_on_auto_assign_pressed()`
- `update_page_indicator()`
- `_on_next_page_pressed()` and `_on_prev_page_pressed()`
- `_on_back_button_pressed()`
- Signal handlers for components

---

## Implementation Steps

### Step 1: Git Commit
```bash
cd /c/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev
git add -A
git commit -m "Backup: Sprite Maker before refactor (1852 lines)"
```

### Step 2: Create components folder
```bash
mkdir -p components/sprite_maker
```

### Step 3: Create sprite_grid.gd
- Copy relevant functions
- Add class definition
- Add signals
- Add initialization method that takes UI references
- Test file compiles

### Step 4: Create stats_panel.gd
- Copy relevant functions
- Add class definition
- Add signals
- Add initialization method
- Test file compiles

### Step 5: Create character_io.gd
- Copy relevant functions
- Remove duplicate load function
- Add class definition
- Add signals
- Test file compiles

### Step 6: Modify odyssey_sprite_maker.gd
- Add component instance variables
- Initialize components in _ready()
- Replace direct function calls with component calls
- Connect component signals
- Remove extracted code
- Test file compiles

### Step 7: Full Test
- Run Godot syntax check: `Godot --check-only --headless --path .`
- Launch game
- Open Sprite Maker
- Test: Load existing NPC
- Test: Create new NPC
- Test: Save NPC
- Test: Pagination
- Test: All stat controls

---

## Verification Checklist

After each extraction, verify:
- [ ] File compiles without errors
- [ ] No undefined references
- [ ] Signals connected properly
- [ ] UI elements still accessible
- [ ] Feature still works in-game

After full refactor:
- [ ] Total lines < 1400 (was 1852)
- [ ] No file > 450 lines
- [ ] All original features work
- [ ] No regression in functionality

---

## Rollback Plan

If refactor breaks things:
```bash
git checkout -- odyssey_sprite_maker.gd
git clean -fd components/sprite_maker/
```

This restores the original file and removes the new components folder.
