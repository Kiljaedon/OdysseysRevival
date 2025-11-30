# Manual Battle Positioning System

## Goal
Enable manual positioning and animation setup for battle system with:
- Draggable panels
- Resizable panels (bottom-right corner drag)
- Sprite scales when panel resizes
- WASD to cycle animations when panel is selected
- Save all positions/animations for camera panning system

## Tasks

### 1. Create draggable_panel.gd script
- [ ] Drag panel by clicking anywhere inside
- [ ] Bottom-right corner resize handle (10x10 pixel zone)
- [ ] When resizing, scale the sprite inside proportionally
- [ ] Click detection to "select" a panel
- [ ] When selected, WASD cycles through character animations
- [ ] Save/load layout data (position, size, current animation)

### 2. Update battle_window.gd
- [ ] Attach draggable_panel.gd to all 5 panels (3 enemies, 1 player, 1 UI)
- [ ] Track which panel is currently selected
- [ ] Display selected panel with highlight border
- [ ] Add "Save Positions" button to export all data to JSON
- [ ] Load positions/animations on battle start

### 3. Animation cycling system
- [x] W = cycle up through animations (idle_up → walk_up → attack_up)
- [x] A = cycle left through animations (idle_left → walk_left → attack_left)
- [x] S = cycle down through animations (idle_down → walk_down → attack_down)
- [x] D = cycle right through animations (idle_right → walk_right → attack_right)
- [x] Console prints current animation name (e.g., "EnemyPanel1 -> up animation #2: walk_up")

### 4. Position export system
- [ ] Export JSON with: panel name, position, size, sprite animation, sprite scale
- [ ] Save to `user://battle_positions.json`
- [ ] You can review and explain each position's purpose

## Implementation Notes
- Keep dragging/resizing simple (no constraints)
- All panels use absolute positioning (layout_mode = 0)
- Sprite scaling: maintain aspect ratio
- Selected panel gets colored border overlay
