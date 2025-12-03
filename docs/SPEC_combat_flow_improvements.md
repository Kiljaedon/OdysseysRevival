# SPEC: Combat Flow Improvements
**Version:** 1.0
**Date:** 2025-12-02
**Status:** Planning
**Author:** Combat Flow Research Analysis

---

## Executive Summary

This specification outlines improvements to the Golden Sun MMO real-time combat system to achieve fast, fluid, and responsive gameplay. Implementation uses **extraction-first refactoring** to avoid code bloat and prevent god files.

**Goals:**
- Make combat feel responsive (instant feedback, no input loss)
- Eliminate clunky feeling (movement lockout, static combat)
- Add tactical depth (positioning, combos, telegraphs)
- **REFACTOR existing files via extraction** (reduce bloat, no god files)

**Strategy:**
- **Extract before adding** - Pull logic into focused components first
- **Shrink existing files** - combat_rules.gd: 486→350, controller: 614→450
- **Max file size: 400 lines** - Every new file stays focused
- **Single responsibility** - One concern per file

---

## Anti-God-File Protocol

### File Size Limits (ENFORCED)
```
Maximum file size: 400 lines (strict)
Warning threshold: 350 lines (plan extraction)
Critical threshold: 450 lines (must refactor)
```

### Pre-Commit Checks
```bash
# .git/hooks/pre-commit (auto-installed Phase 0)
#!/bin/bash
files=$(git diff --cached --name-only --diff-filter=ACM | grep '\.gd$')
for file in $files; do
    lines=$(wc -l < "$file")
    if [ "$lines" -gt 450 ]; then
        echo "ERROR: $file exceeds 450 lines ($lines)"
        echo "Extract logic before committing!"
        exit 1
    elif [ "$lines" -gt 350 ]; then
        echo "WARNING: $file approaching limit ($lines/400)"
    fi
done
```

### Extraction Checklist (Per Phase)
- [ ] Identify files >400 lines
- [ ] Extract cohesive logic blocks into new components
- [ ] Verify original file shrinks
- [ ] New components are <400 lines
- [ ] Update dependency injection

---

## Architecture Overview

### New Component Files (Focused, <400 lines each)

```
source/server/managers/combat/
├── realtime_combat_manager.gd          [EXISTING - 500 lines, AT CAPACITY]
├── combat_rules.gd                     [REFACTOR: 486→350 lines via extraction]
├── combat_timing.gd                    [NEW - Phase 1 - 300 lines]
├── combat_combo_system.gd              [NEW - Phase 1 - 250 lines, EXTRACTED]
├── combat_dodge_system.gd              [NEW - Phase 1 - 200 lines, EXTRACTED]
├── combat_input_buffer.gd              [NEW - Phase 2 - 300 lines]
└── combat_feedback_events.gd           [NEW - Phase 3 - 350 lines]

source/client/combat/
├── combat_hit_freeze.gd                [NEW - Phase 3 - 180 lines]
├── combat_screen_shake.gd              [NEW - Phase 3 - 150 lines]
├── combat_damage_numbers.gd            [NEW - Phase 3 - 220 lines]
├── combat_particles.gd                 [NEW - Phase 3 - 180 lines]
└── entity_interpolator.gd              [NEW - Phase 5 - 350 lines]

scripts/realtime_battle/
├── realtime_battle_controller.gd       [REFACTOR: 614→450 lines]
├── battle_input_handler.gd             [NEW - Phase 2 - 350 lines, EXTRACTED]
└── realtime_battle_unit.gd             [MODIFY: 300→380 lines]
```

### File Size Budget (Before/After)

| File | Before | After | Change | Strategy |
|------|--------|-------|--------|----------|
| combat_rules.gd | 486 | 350 | **-136** | Extract combo+dodge |
| realtime_battle_controller.gd | 614 | 450 | **-164** | Extract input handler |
| realtime_combat_manager.gd | 500 | 500 | **0** | No changes (at capacity) |
| All new files | 0 | ~2,800 | **+2,800** | 10 focused components |

**Net Result:** 2 files shrunk, 10 new focused files added

---

## Phase 0: Pre-Refactor Setup
**Effort:** 1 hour
**Risk:** None
**Dependencies:** None

### 0.1 Install Git Hooks

```bash
# Install pre-commit hook for file size enforcement
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "Checking file sizes..."
files=$(git diff --cached --name-only --diff-filter=ACM | grep '\.gd$')
failed=0
for file in $files; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        if [ "$lines" -gt 450 ]; then
            echo "❌ ERROR: $file = $lines lines (MAX: 450)"
            failed=1
        elif [ "$lines" -gt 350 ]; then
            echo "⚠️  WARNING: $file = $lines lines (approaching limit)"
        fi
    fi
done
if [ "$failed" -eq 1 ]; then
    echo ""
    echo "COMMIT BLOCKED: Files exceed 450 line limit"
    echo "Extract logic into components before committing"
    exit 1
fi
echo "✅ File size check passed"
EOF

chmod +x .git/hooks/pre-commit
```

### 0.2 Create Feature Branch

```bash
git checkout -b feature/combat-flow-improvements
git commit --allow-empty -m "Phase 0: Setup feature branch for combat flow

Anti-god-file protocol:
- Max file size: 400 lines (strict)
- Pre-commit hook installed
- Extraction-first strategy

Refs: SPEC_combat_flow_improvements.md"
```

### 0.3 Baseline Audit

```bash
# Document current file sizes
echo "Baseline file sizes:" > docs/combat_refactor_baseline.txt
wc -l source/server/managers/combat/*.gd >> docs/combat_refactor_baseline.txt
wc -l scripts/realtime_battle/*.gd >> docs/combat_refactor_baseline.txt
git add docs/combat_refactor_baseline.txt
git commit -m "Phase 0: Document baseline file sizes"
```

**Acceptance Criteria:**
- [ ] Pre-commit hook blocks files >450 lines
- [ ] Feature branch created
- [ ] Baseline documented

---

## Phase 1: Extract & Refactor Core Systems
**Effort:** 6 hours
**Risk:** Medium (refactoring existing code)
**Dependencies:** Phase 0 complete

**Strategy:** Extract before adding. Shrink bloated files first.

### 1.1 Extract Timing System

**Create:** `combat_timing.gd` (~300 lines)

```gdscript
## combat_timing.gd - Combat Timing Configuration
## EXTRACTED FROM: combat_rules.gd (lines 10-60, 150-250)
## PURPOSE: Centralized timing constants and calculations
## DEPENDENCIES: None (pure data + static functions)

class_name CombatTiming
extends RefCounted

## ========== ATTACK TIMING (Improved) ==========
const WIND_UP_TIME: float = 0.12      # Reduced from 0.15
const ATTACK_TIME: float = 0.05
const RECOVERY_TIME: float = 0.08     # Reduced from 0.2
const TOTAL_ATTACK_DURATION: float = 0.25

## ========== DODGE TIMING (Enhanced) ==========
const DODGE_ROLL_DURATION: float = 0.35
const DODGE_ROLL_DISTANCE: float = 500.0
const DODGE_ROLL_IFRAMES: float = 0.35
const DODGE_ROLL_COOLDOWN: float = 0.8
const DODGE_ROLL_ENERGY_COST: int = 15

## ========== MOVEMENT RULES ==========
const MOVEMENT_ALLOWED_DURING_RECOVERY: bool = true
const ATTACK_MOVE_SPEED_MULT: float = 0.5

## Static helper functions (calculation utilities)
## ... (~200 lines of timing calculations)
```

**Extraction Map:**
- Lines 10-18 from combat_rules.gd → Timing constants
- Lines 52-58 from combat_rules.gd → Dodge constants
- Lines 181-210 from combat_rules.gd → Attack state helpers

**Git Commit:**
```bash
git add source/server/managers/combat/combat_timing.gd
git commit -m "Phase 1.1: Extract timing system from combat_rules.gd

EXTRACTION:
- Combat timing constants → combat_timing.gd
- Attack state helpers → combat_timing.gd
- Dodge roll timings → combat_timing.gd

New file: combat_timing.gd (300 lines)
Refs: SPEC_combat_flow_improvements.md Phase 1.1"
```

### 1.2 Extract Combo System

**Create:** `combat_combo_system.gd` (~250 lines)

```gdscript
## combat_combo_system.gd - Combo Chain Management
## NEW SYSTEM: 3-hit progressive combo chains
## PURPOSE: Track combo state, apply speed scaling
## DEPENDENCIES: CombatTiming

class_name CombatComboSystem
extends RefCounted

## ========== COMBO CONFIGURATION ==========
const COMBO_CHAIN_WINDOW: float = 0.5
const MAX_COMBO_COUNT: int = 3
const COMBO_WIND_UP_SCALES: Array = [1.0, 0.85, 0.7]
const COMBO_RECOVERY_SCALES: Array = [1.0, 0.9, 0.8]

## ========== STATE MANAGEMENT ==========
static func init_combo_fields(unit: Dictionary) -> void:
    unit["attack_combo_count"] = 0
    unit["combo_window_timer"] = 0.0

static func process_combo_window(unit: Dictionary, delta: float) -> void:
    if unit.get("combo_window_timer", 0.0) > 0:
        unit["combo_window_timer"] -= delta
        if unit["combo_window_timer"] <= 0:
            unit["attack_combo_count"] = 0

static func advance_combo(unit: Dictionary) -> int:
    var current = unit.get("attack_combo_count", 0)
    unit["attack_combo_count"] = (current + 1) % MAX_COMBO_COUNT
    unit["combo_window_timer"] = COMBO_CHAIN_WINDOW
    return unit["attack_combo_count"]

static func get_scaled_timing(combo_count: int, base_time: float, is_recovery: bool) -> float:
    var scales = COMBO_RECOVERY_SCALES if is_recovery else COMBO_WIND_UP_SCALES
    var index = clamp(combo_count, 0, scales.size() - 1)
    return base_time * scales[index]

## ... (~150 more lines of combo logic)
```

**Git Commit:**
```bash
git add source/server/managers/combat/combat_combo_system.gd
git commit -m "Phase 1.2: Create combo chain system

NEW FEATURE:
- 3-hit progressive combo
- Speed scaling per hit (1.0 → 0.85 → 0.7)
- 0.5s combo window
- Combo state management

New file: combat_combo_system.gd (250 lines)
Refs: SPEC_combat_flow_improvements.md Phase 1.2"
```

### 1.3 Extract Dodge System

**Create:** `combat_dodge_system.gd` (~200 lines)

```gdscript
## combat_dodge_system.gd - Dodge Roll Mechanics
## EXTRACTED FROM: combat_rules.gd (lines 52-58, 240-290)
## PURPOSE: Dodge roll state, i-frames, cooldown management
## DEPENDENCIES: CombatTiming

class_name CombatDodgeSystem
extends RefCounted

## ========== DODGE STATE ==========
static func init_dodge_fields(unit: Dictionary) -> void:
    unit["is_dodge_rolling"] = false
    unit["dodge_roll_timer"] = 0.0
    unit["dodge_roll_direction"] = Vector2.ZERO
    unit["dodge_roll_cooldown"] = 0.0

static func can_dodge(unit: Dictionary) -> Dictionary:
    if unit.get("is_dodge_rolling", false):
        return {"allowed": false, "reason": "already_dodging"}
    if unit.get("dodge_roll_cooldown", 0.0) > 0:
        return {"allowed": false, "reason": "on_cooldown"}
    var energy = unit.get("energy", 0)
    if energy < CombatTiming.DODGE_ROLL_ENERGY_COST:
        return {"allowed": false, "reason": "insufficient_energy"}
    return {"allowed": true}

static func start_dodge(unit: Dictionary, direction: Vector2) -> void:
    unit["is_dodge_rolling"] = true
    unit["dodge_roll_timer"] = CombatTiming.DODGE_ROLL_DURATION
    unit["dodge_roll_direction"] = direction.normalized()
    unit["dodge_roll_cooldown"] = CombatTiming.DODGE_ROLL_COOLDOWN
    unit["invincibility_timer"] = CombatTiming.DODGE_ROLL_IFRAMES
    unit["energy"] -= CombatTiming.DODGE_ROLL_ENERGY_COST

static func process_dodge_roll(unit: Dictionary, delta: float) -> Vector2:
    if not unit.get("is_dodge_rolling", false):
        return Vector2.ZERO

    unit["dodge_roll_timer"] -= delta
    if unit["dodge_roll_timer"] <= 0:
        unit["is_dodge_rolling"] = false
        return Vector2.ZERO

    var direction = unit.get("dodge_roll_direction", Vector2.ZERO)
    var speed = CombatTiming.DODGE_ROLL_DISTANCE / CombatTiming.DODGE_ROLL_DURATION
    return direction * speed

## ... (~100 more lines)
```

**Git Commit:**
```bash
git add source/server/managers/combat/combat_dodge_system.gd
git commit -m "Phase 1.3: Extract dodge roll system

EXTRACTION:
- Dodge state management from combat_rules.gd
- I-frame logic
- Cooldown tracking
- Energy cost handling

New file: combat_dodge_system.gd (200 lines)
Refs: SPEC_combat_flow_improvements.md Phase 1.3"
```

### 1.4 Refactor combat_rules.gd (SHRINK IT)

**Changes:**
1. Remove extracted code (timing, combo, dodge)
2. Import new systems
3. Delegate to extracted components
4. **Result: 486 lines → 350 lines (-136 lines)**

```gdscript
## combat_rules.gd - Combat Rules Coordinator
## REFACTORED: Extracted timing, combo, dodge to separate systems
## PURPOSE: High-level rule enforcement and coordination
## SIZE: 350 lines (down from 486)

const CombatTiming = preload("res://source/server/managers/combat/combat_timing.gd")
const CombatComboSystem = preload("res://source/server/managers/combat/combat_combo_system.gd")
const CombatDodgeSystem = preload("res://source/server/managers/combat/combat_dodge_system.gd")

class_name CombatRules

## ========== CORE RULES (RETAINED) ==========
const HITS_TO_KILL_PLAYER: int = 6
const MUST_STOP_BEFORE_ATTACK: bool = false
## ... (balance constants remain)

## ========== REFACTORED FUNCTIONS ==========
static func can_move(unit: Dictionary) -> bool:
    # Use CombatTiming for state checks
    var attack_state = unit.get("attack_state", "")
    if attack_state == "attacking":
        return false
    # NEW: Allow movement during recovery!
    if attack_state == "recovering" and CombatTiming.MOVEMENT_ALLOWED_DURING_RECOVERY:
        return true
    # Delegate to dodge system
    if unit.get("is_dodge_rolling", false):
        return false
    return true

static func process_dodge_roll(unit: Dictionary, delta: float) -> Vector2:
    # Delegate to CombatDodgeSystem
    return CombatDodgeSystem.process_dodge_roll(unit, delta)

static func init_combat_fields(unit: Dictionary) -> void:
    # Initialize all combat subsystems
    CombatComboSystem.init_combo_fields(unit)
    CombatDodgeSystem.init_dodge_fields(unit)
    # ... existing fields

## ... (remaining ~250 lines of core combat logic)
```

**Git Commit:**
```bash
git add source/server/managers/combat_rules.gd
git commit -m "Phase 1.4: Refactor combat_rules.gd via extraction

REFACTOR:
- Import CombatTiming, CombatComboSystem, CombatDodgeSystem
- Delegate to extracted systems
- Remove duplicated code
- Enable movement during recovery

File size: 486 → 350 lines (-136 lines) ✅
Refs: SPEC_combat_flow_improvements.md Phase 1.4"
```

### 1.5 Verification

**Automated Tests:**
```gdscript
# tests/combat/test_phase1_refactor.gd
func test_timing_extraction():
    assert_eq(CombatTiming.WIND_UP_TIME, 0.12)
    assert_eq(CombatTiming.RECOVERY_TIME, 0.08)

func test_combo_system():
    var unit = {}
    CombatComboSystem.init_combo_fields(unit)
    assert_eq(unit.attack_combo_count, 0)
    CombatComboSystem.advance_combo(unit)
    assert_eq(unit.attack_combo_count, 1)

func test_dodge_extraction():
    var unit = {"energy": 50}
    CombatDodgeSystem.init_dodge_fields(unit)
    var result = CombatDodgeSystem.can_dodge(unit)
    assert_true(result.allowed)

func test_movement_during_recovery():
    var unit = {"attack_state": "recovering"}
    assert_true(CombatRules.can_move(unit), "Should allow movement during recovery")
```

**Run Tests:**
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=tests/combat/ -gprefix=test_phase1
```

**Acceptance Criteria:**
- [ ] All Phase 1 tests pass
- [ ] combat_rules.gd is <400 lines
- [ ] No new files exceed 400 lines
- [ ] Manual test: Can move during attack recovery
- [ ] Manual test: 3-hit combo speeds up

---

## Phase 2: Input Buffering
**Effort:** 5 hours
**Risk:** Medium
**Dependencies:** Phase 1 complete

### 2.1 Create Input Buffer System

**Create:** `combat_input_buffer.gd` (~300 lines)

```gdscript
## combat_input_buffer.gd - Combat Input Buffering
## PURPOSE: Queue actions during cooldowns for responsive feel
## DEPENDENCIES: None (standalone system)

class_name CombatInputBuffer
extends RefCounted

const BUFFER_WINDOW: float = 0.15  # 150ms
const MAX_BUFFER_SIZE: int = 3

var queue: Array = []  # [{action, timestamp, data}]

func buffer_action(action: String, data: Variant = null) -> bool:
    # Check for duplicates
    for entry in queue:
        if entry.action == action:
            return false  # Already buffered

    if queue.size() >= MAX_BUFFER_SIZE:
        return false  # Queue full

    queue.append({
        "action": action,
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "data": data
    })
    return true

func process_queue(ready_states: Dictionary, executor: Object) -> void:
    var current_time = Time.get_ticks_msec() / 1000.0
    var i = 0

    while i < queue.size():
        var entry = queue[i]
        var age = current_time - entry.timestamp

        # Expire old entries
        if age > BUFFER_WINDOW:
            queue.remove_at(i)
            continue

        # Try to execute
        var is_ready = ready_states.get(entry.action + "_ready", false)
        if is_ready and executor.has_method("execute_" + entry.action):
            executor.call("execute_" + entry.action, entry.data)
            queue.remove_at(i)
            continue

        i += 1

func clear() -> void:
    queue.clear()

func is_buffered(action: String) -> bool:
    for entry in queue:
        if entry.action == action:
            return true
    return false
```

**Git Commit:**
```bash
git add source/server/managers/combat/combat_input_buffer.gd
git commit -m "Phase 2.1: Create input buffering system

NEW FEATURE:
- 150ms buffer window for responsive input
- Queue management with expiration
- Duplicate prevention
- Generic action executor pattern

File size: 300 lines
Refs: SPEC_combat_flow_improvements.md Phase 2.1"
```

### 2.2 Extract Input Handler from Controller

**Create:** `battle_input_handler.gd` (~350 lines)

```gdscript
## battle_input_handler.gd - Battle Input Processing
## EXTRACTED FROM: realtime_battle_controller.gd (lines 207-453)
## PURPOSE: Handle all combat input (movement, attack, dodge, target)
## DEPENDENCIES: CombatInputBuffer

class_name BattleInputHandler
extends RefCounted

var controller_ref: WeakRef
var input_buffer: CombatInputBuffer = CombatInputBuffer.new()

func initialize(controller: Object) -> void:
    controller_ref = weakref(controller)

func process_input(delta: float, battle_scene, in_battle: bool) -> Dictionary:
    if not in_battle:
        return {}

    # Movement input
    var velocity = _read_movement_input()

    # Action input
    _process_action_input()

    # Process buffered inputs
    _process_buffer()

    return {"velocity": velocity}

func _read_movement_input() -> Vector2:
    var velocity = Vector2.ZERO
    if Input.is_action_pressed("up"): velocity.y -= 1
    if Input.is_action_pressed("down"): velocity.y += 1
    if Input.is_action_pressed("left"): velocity.x -= 1
    if Input.is_action_pressed("right"): velocity.x += 1
    return velocity.normalized()

func _process_action_input() -> void:
    if Input.is_action_pressed("action") or Input.is_key_pressed(KEY_SPACE):
        try_attack()
    if Input.is_action_just_pressed("defend"):
        try_dodge()

func try_attack() -> void:
    var controller = controller_ref.get_ref()
    if not controller:
        return

    if controller.attack_cooldown_timer <= 0:
        controller.execute_attack(controller.current_target_id)
    elif controller.attack_cooldown_timer <= input_buffer.BUFFER_WINDOW:
        input_buffer.buffer_action("attack", controller.current_target_id)

func try_dodge() -> void:
    var controller = controller_ref.get_ref()
    if not controller:
        return

    if controller.dodge_roll_cooldown_timer <= 0:
        controller.execute_dodge_roll(controller.last_velocity.normalized())
    elif controller.dodge_roll_cooldown_timer <= input_buffer.BUFFER_WINDOW:
        input_buffer.buffer_action("dodge_roll", controller.last_velocity.normalized())

func _process_buffer() -> void:
    var controller = controller_ref.get_ref()
    if not controller:
        return

    input_buffer.process_queue({
        "attack_ready": controller.attack_cooldown_timer <= 0,
        "dodge_roll_ready": controller.dodge_roll_cooldown_timer <= 0
    }, controller)

## ... (~200 more lines for targeting, zoom, etc.)
```

**Git Commit:**
```bash
git add scripts/realtime_battle/battle_input_handler.gd
git commit -m "Phase 2.2: Extract input handling from controller

EXTRACTION:
- Movement input → battle_input_handler.gd
- Action input → battle_input_handler.gd
- Targeting logic → battle_input_handler.gd
- Input buffering integration

New file: battle_input_handler.gd (350 lines)
Refs: SPEC_combat_flow_improvements.md Phase 2.2"
```

### 2.3 Refactor Controller (SHRINK IT)

**Modify:** `realtime_battle_controller.gd`
**Result:** 614 lines → 450 lines (-164 lines)

```gdscript
## realtime_battle_controller.gd - Battle Controller (Refactored)
## REFACTORED: Extracted input handling to battle_input_handler.gd
## PURPOSE: Coordinate battle lifecycle and network communication
## SIZE: 450 lines (down from 614)

const BattleInputHandler = preload("res://scripts/realtime_battle/battle_input_handler.gd")

var input_handler: BattleInputHandler

func _ready():
    set_process(false)
    input_handler = BattleInputHandler.new()

func initialize(scene: RealtimeBattleScene, net_service: Node) -> void:
    battle_scene = scene
    network_service = net_service
    input_handler.initialize(self)

func _process(delta: float):
    if not in_battle:
        return

    # Update cooldowns
    if attack_cooldown_timer > 0: attack_cooldown_timer -= delta
    if dodge_roll_cooldown_timer > 0: dodge_roll_cooldown_timer -= delta

    # Delegate input processing
    var input_result = input_handler.process_input(delta, battle_scene, in_battle)
    last_velocity = input_result.get("velocity", Vector2.ZERO)

    # Send to server
    input_timer += delta
    if input_timer >= INPUT_SEND_RATE:
        input_timer = 0.0
        _send_movement_to_server()

## Executor methods (called by input buffer)
func execute_attack(target_id: String) -> void:
    # Actual attack execution logic
    attack_cooldown_timer = ATTACK_COOLDOWN
    _send_attack_to_server(target_id)

func execute_dodge_roll(direction: Vector2) -> void:
    # Actual dodge execution logic
    dodge_roll_cooldown_timer = DODGE_ROLL_COOLDOWN
    _send_dodge_roll_to_server(direction)

## ... (remaining ~350 lines of network/lifecycle logic)
```

**Git Commit:**
```bash
git add scripts/realtime_battle/realtime_battle_controller.gd
git commit -m "Phase 2.3: Refactor controller via input extraction

REFACTOR:
- Delegate input to BattleInputHandler
- Add executor methods for input buffer
- Remove 250 lines of input code
- Simplified _process() loop

File size: 614 → 450 lines (-164 lines) ✅
Refs: SPEC_combat_flow_improvements.md Phase 2.3"
```

**Acceptance Criteria:**
- [ ] realtime_battle_controller.gd <450 lines
- [ ] All new files <400 lines
- [ ] Input buffering works (press attack during cooldown → executes when ready)
- [ ] No duplicate buffered actions

---

## Phase 3: Hit Feedback & Juice
**Effort:** 6 hours
**Risk:** Low (client-side only)
**Dependencies:** Phase 1-2 complete

**Strategy:** Split large visual effects file into 4 focused components

### 3.1 Create Hit Freeze System

**Create:** `combat_hit_freeze.gd` (~180 lines)

```gdscript
## combat_hit_freeze.gd - Hit Freeze (Time Stop) Effect
## PURPOSE: Brief time freeze on hits for impact feel
## DEPENDENCIES: None (Engine.time_scale manipulation)

class_name CombatHitFreeze
extends Node

const FREEZE_NORMAL: int = 1      # 1 frame @ 60fps
const FREEZE_CRIT: int = 3        # 3 frames
const FREEZE_FLANK_BACK: int = 3  # Back attacks

func apply_freeze(freeze_frames: int) -> void:
    if freeze_frames <= 0:
        return

    var freeze_duration = freeze_frames / 60.0  # Convert frames to seconds
    Engine.time_scale = 0.0

    # Use unscaled timer to wait during freeze
    await get_tree().create_timer(freeze_duration, true, false, true).timeout
    Engine.time_scale = 1.0

func apply_freeze_for_damage_type(flank_type: String, is_crit: bool) -> void:
    var frames = FREEZE_NORMAL
    if is_crit or flank_type == "back":
        frames = FREEZE_CRIT
    apply_freeze(frames)

## ... (~100 more lines for configuration, safety)
```

### 3.2 Create Screen Shake System

**Create:** `combat_screen_shake.gd` (~150 lines)

```gdscript
## combat_screen_shake.gd - Camera Shake Effect
## PURPOSE: Screen shake on hits for impact
## DEPENDENCIES: Camera2D reference

class_name CombatScreenShake
extends Node

const SHAKE_INTENSITY_NORMAL: float = 0.15
const SHAKE_INTENSITY_CRIT: float = 0.3
const SHAKE_DURATION: float = 0.15

var camera: Camera2D
var original_offset: Vector2

func initialize(cam: Camera2D) -> void:
    camera = cam
    if camera:
        original_offset = camera.offset

func shake(intensity: float, duration: float) -> void:
    if not camera:
        return

    var elapsed = 0.0
    while elapsed < duration:
        elapsed += get_process_delta_time()
        var progress = 1.0 - (elapsed / duration)
        var shake_amount = intensity * progress

        camera.offset = original_offset + Vector2(
            randf_range(-shake_amount, shake_amount) * 10,
            randf_range(-shake_amount, shake_amount) * 10
        )
        await get_tree().process_frame

    camera.offset = original_offset

func shake_for_damage(flank_type: String, is_crit: bool) -> void:
    var intensity = SHAKE_INTENSITY_NORMAL
    if is_crit or flank_type == "back":
        intensity = SHAKE_INTENSITY_CRIT
    shake(intensity, SHAKE_DURATION)
```

### 3.3 Create Damage Numbers System

**Create:** `combat_damage_numbers.gd` (~220 lines)

```gdscript
## combat_damage_numbers.gd - Floating Damage Numbers
## PURPOSE: Spawn damage popups above targets
## DEPENDENCIES: Label scene for popup

class_name CombatDamageNumbers
extends Node

var damage_label_scene: PackedScene
var numbers_container: Node

func initialize(container: Node) -> void:
    numbers_container = container
    _create_label_scene()

func _create_label_scene() -> void:
    # Create damage label scene programmatically
    damage_label_scene = PackedScene.new()
    # ... scene setup

func spawn_damage_number(position: Vector2, damage: int, flank_type: String) -> void:
    if not damage_label_scene or not numbers_container:
        return

    var label = damage_label_scene.instantiate()
    label.text = str(damage)
    label.position = position

    # Color based on flank
    match flank_type:
        "back": label.modulate = Color.ORANGE  # Critical
        "side": label.modulate = Color.YELLOW
        _: label.modulate = Color.WHITE

    numbers_container.add_child(label)

    # Animate
    _animate_damage_number(label)

func _animate_damage_number(label: Label) -> void:
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(label, "position:y", label.position.y - 100, 1.0)
    tween.tween_property(label, "modulate:a", 0.0, 1.0)
    tween.finished.connect(func(): label.queue_free())

## ... (~120 more lines for styling, batching)
```

### 3.4 Create Particles System

**Create:** `combat_particles.gd` (~180 lines)

```gdscript
## combat_particles.gd - Hit Particle Effects
## PURPOSE: Spawn particles on combat events
## DEPENDENCIES: GPUParticles2D

class_name CombatParticles
extends Node

var particles_container: Node
var hit_particle_material: ParticleProcessMaterial

func initialize(container: Node) -> void:
    particles_container = container
    _setup_particle_material()

func spawn_hit_particles(position: Vector2, flank_type: String) -> void:
    var particles = GPUParticles2D.new()
    particles.position = position
    particles.process_material = hit_particle_material
    particles.amount = _get_particle_count(flank_type)
    particles.one_shot = true
    particles.emitting = true

    particles_container.add_child(particles)

    # Auto-cleanup
    await get_tree().create_timer(2.0).timeout
    particles.queue_free()

func _get_particle_count(flank_type: String) -> int:
    match flank_type:
        "back": return 30  # Big hit
        "side": return 20
        _: return 15

## ... (~120 more lines)
```

### 3.5 Create Feedback Event System (Server)

**Create:** `combat_feedback_events.gd` (~350 lines)

```gdscript
## combat_feedback_events.gd - Server Feedback Events
## PURPOSE: Generate feedback data for client effects
## DEPENDENCIES: CombatRules, ElementalSystem

class_name CombatFeedbackEvents
extends RefCounted

static func create_damage_event(attacker: Dictionary, target: Dictionary, damage: int, flank_type: String) -> Dictionary:
    return {
        "type": "damage",
        "attacker_id": attacker.id,
        "target_id": target.id,
        "damage": damage,
        "flank_type": flank_type,
        "freeze_frames": _calculate_freeze_frames(damage, flank_type),
        "shake_intensity": _calculate_shake_intensity(damage, flank_type),
        "is_crit": _is_critical_hit(damage, flank_type)
    }

static func _calculate_freeze_frames(damage: int, flank_type: String) -> int:
    if flank_type == "back":
        return 3  # 50ms freeze
    return 1  # 16ms freeze

static func _calculate_shake_intensity(damage: int, flank_type: String) -> float:
    if flank_type == "back":
        return 0.3
    return 0.15

static func _is_critical_hit(damage: int, flank_type: String) -> bool:
    return flank_type == "back"

## ... (~280 more lines for other event types)
```

### 3.6 Git Commits

```bash
# Commit sequence
git add source/client/combat/combat_hit_freeze.gd
git commit -m "Phase 3.1: Create hit freeze system (180 lines)"

git add source/client/combat/combat_screen_shake.gd
git commit -m "Phase 3.2: Create screen shake system (150 lines)"

git add source/client/combat/combat_damage_numbers.gd
git commit -m "Phase 3.3: Create damage numbers system (220 lines)"

git add source/client/combat/combat_particles.gd
git commit -m "Phase 3.4: Create hit particles system (180 lines)"

git add source/server/managers/combat/combat_feedback_events.gd
git commit -m "Phase 3.5: Create server feedback events (350 lines)"

git add scripts/realtime_battle/realtime_battle_scene.gd
git commit -m "Phase 3.6: Integrate visual effects into battle scene

- Initialize hit freeze, shake, damage numbers, particles
- Wire damage events to effects
- Add effects container nodes

Added: ~100 lines (stays under 700 total)
Refs: SPEC_combat_flow_improvements.md Phase 3.6"
```

**Acceptance Criteria:**
- [ ] All Phase 3 files <400 lines
- [ ] Hit freeze works (brief time stop)
- [ ] Screen shake feels impactful
- [ ] Damage numbers spawn and float
- [ ] Particles spawn on hits

---

## Phase 4: Combo Integration
**Effort:** 4 hours
**Risk:** Low (combo system already extracted in Phase 1)
**Dependencies:** Phase 1-3 complete

### 4.1 Integrate Combo into Attack Flow

**Modify:** `combat_rules.gd` (~+50 lines, stays at 400)

```gdscript
static func start_attack(unit: Dictionary, target_id: String, battle_units: Dictionary = {}) -> void:
    # Get combo count for timing
    var combo_count = unit.get("attack_combo_count", 0)

    # Calculate scaled timing
    var wind_up = CombatComboSystem.get_scaled_timing(combo_count, CombatTiming.WIND_UP_TIME, false)
    var recovery = CombatComboSystem.get_scaled_timing(combo_count, CombatTiming.RECOVERY_TIME, true)

    unit["attack_state"] = "winding_up"
    unit["attack_state_timer"] = wind_up
    unit["attack_target_id"] = target_id
    unit["current_recovery_time"] = recovery  # Store for later
    unit["velocity"] = Vector2.ZERO

    # Advance combo
    CombatComboSystem.advance_combo(unit)

    # Lunge towards target
    # ... existing lunge logic
```

**Modify:** `realtime_combat_manager.gd` (~+20 lines for combo processing)

```gdscript
func _process_battle(battle: Dictionary, delta: float) -> void:
    for unit_id in units.keys():
        var unit = units[unit_id]
        if unit.state == "dead":
            continue

        # Process combo window
        CombatComboSystem.process_combo_window(unit, delta)

        # ... existing processing
```

**Git Commit:**
```bash
git add source/server/managers/combat_rules.gd
git add source/server/managers/realtime_combat_manager.gd
git commit -m "Phase 4.1: Integrate combo system into attack flow

- Apply combo scaling to wind-up/recovery
- Process combo window timers
- Advance combo on attacks

combat_rules.gd: +50 lines (~400 total) ✅
realtime_combat_manager.gd: +20 lines (520 total) ✅
Refs: SPEC_combat_flow_improvements.md Phase 4.1"
```

### 4.2 Client Combo Counter

**Modify:** `combat_damage_numbers.gd` (~+50 lines, stays at 270)

```gdscript
func show_combo_counter(position: Vector2, combo_count: int) -> void:
    if combo_count <= 0:
        return

    var label = _create_combo_label()
    label.text = "%d HIT" % combo_count if combo_count == 1 else "%d HITS" % combo_count
    label.position = position + Vector2(0, -50)
    label.modulate = Color.ORANGE

    numbers_container.add_child(label)
    _animate_combo_label(label)
```

**Git Commit:**
```bash
git add source/client/combat/combat_damage_numbers.gd
git commit -m "Phase 4.2: Add combo counter display

- Show combo count above player
- Fade animation
- Orange color for visibility

combat_damage_numbers.gd: +50 lines (~270 total) ✅
Refs: SPEC_combat_flow_improvements.md Phase 4.2"
```

**Acceptance Criteria:**
- [ ] 3 consecutive attacks speed up progressively
- [ ] Combo counter displays (1 HIT → 2 HITS → 3 HITS)
- [ ] Combo resets after 0.5s window expires

---

## Phase 5: Entity Interpolation
**Effort:** 6 hours
**Risk:** Medium (network timing sensitive)
**Dependencies:** Phase 1-4 complete

### 5.1 Create Interpolator

**Create:** `entity_interpolator.gd` (~350 lines)

```gdscript
## entity_interpolator.gd - Network Entity Interpolation
## PURPOSE: Smooth remote entity movement (no snapping)
## DEPENDENCIES: None (standalone system)

class_name EntityInterpolator
extends RefCounted

const INTERPOLATION_DELAY: float = 0.1  # 100ms
const MAX_BUFFER_SIZE: int = 10
const EXTRAPOLATION_LIMIT: float = 0.05  # 50ms max

var state_buffer: Array = []
var render_timestamp: float = 0.0

func add_state(state: Dictionary) -> void:
    state_buffer.append({
        "timestamp": state.get("server_timestamp", Time.get_ticks_msec()),
        "position": state.position,
        "velocity": state.get("velocity", Vector2.ZERO),
        "hp": state.hp,
        "state": state.state,
        "facing": state.facing
    })

    if state_buffer.size() > MAX_BUFFER_SIZE:
        state_buffer.pop_front()

func get_interpolated_state(current_time: float) -> Dictionary:
    if state_buffer.size() < 2:
        return state_buffer.back() if state_buffer.size() == 1 else {}

    var target_time = current_time - (INTERPOLATION_DELAY * 1000.0)

    # Find interpolation range
    var from_state = null
    var to_state = null

    for i in range(state_buffer.size() - 1):
        if state_buffer[i].timestamp <= target_time and state_buffer[i+1].timestamp >= target_time:
            from_state = state_buffer[i]
            to_state = state_buffer[i+1]
            break

    if not from_state or not to_state:
        return state_buffer.back()

    # Interpolate
    var time_range = to_state.timestamp - from_state.timestamp
    if time_range == 0:
        return to_state

    var alpha = float(target_time - from_state.timestamp) / time_range
    alpha = clamp(alpha, 0.0, 1.0)

    return {
        "position": from_state.position.lerp(to_state.position, alpha),
        "hp": to_state.hp,
        "state": to_state.state,
        "facing": to_state.facing
    }

func cleanup_old_states(current_time: float) -> void:
    while state_buffer.size() > 2:
        if state_buffer[0].timestamp < current_time - 1000:
            state_buffer.pop_front()
        else:
            break

## ... (~200 more lines for extrapolation, etc.)
```

**Git Commit:**
```bash
git add source/client/combat/entity_interpolator.gd
git commit -m "Phase 5.1: Create entity interpolation system

- 100ms interpolation delay (Source Engine model)
- Buffered state interpolation
- Extrapolation for packet loss
- Old state cleanup

File size: 350 lines
Refs: SPEC_combat_flow_improvements.md Phase 5.1"
```

### 5.2 Integrate into Battle Units

**Modify:** `realtime_battle_unit.gd` (~+80 lines, reaches 380)

```gdscript
## realtime_battle_unit.gd
const EntityInterpolator = preload("res://source/client/combat/entity_interpolator.gd")

var interpolator: EntityInterpolator = null
var is_local_player: bool = false

func _ready():
    if not is_local_player:
        interpolator = EntityInterpolator.new()

func _process(delta: float):
    if is_local_player or not interpolator:
        return  # Local player uses prediction

    # Get interpolated state
    var state = interpolator.get_interpolated_state(Time.get_ticks_msec())
    if state.has("position"):
        position = state.position

    interpolator.cleanup_old_states(Time.get_ticks_msec())

func on_server_state_update(state: Dictionary) -> void:
    if is_local_player:
        return  # Don't interpolate local player

    if interpolator:
        interpolator.add_state(state)
```

**Git Commit:**
```bash
git add scripts/realtime_battle/realtime_battle_unit.gd
git commit -m "Phase 5.2: Integrate interpolation into battle units

- Add EntityInterpolator for remote units
- Skip interpolation for local player
- Apply interpolated position in _process
- Add state to buffer on server updates

File size: 300 → 380 lines (+80) ✅
Refs: SPEC_combat_flow_improvements.md Phase 5.2"
```

### 5.3 Add Timestamps to Network

**Modify:** `realtime_combat_network.gd` (~+30 lines)

```gdscript
static func broadcast_all_battle_states(active_battles: Dictionary, network_handler) -> void:
    for battle_id in active_battles:
        var battle = active_battles[battle_id]
        if battle.state != "active":
            continue

        var server_timestamp = Time.get_ticks_msec()
        var units_state = []

        for unit_id in battle.units:
            var unit = battle.units[unit_id]
            units_state.append({
                "id": unit.id,
                "position": unit.position,
                "velocity": unit.velocity,  # For extrapolation
                "hp": unit.hp,
                "state": unit.state,
                "facing": unit.facing,
                "server_timestamp": server_timestamp  # NEW!
            })

        for peer_id in battle.participants:
            network_handler.rpc_id(peer_id, "rt_battle_state_update", units_state)
```

**Git Commit:**
```bash
git add source/server/managers/combat/realtime_combat_network.gd
git commit -m "Phase 5.3: Add server timestamps to state updates

- Include server_timestamp in all broadcasts
- Include velocity for extrapolation
- Enable interpolation timing

Refs: SPEC_combat_flow_improvements.md Phase 5.3"
```

**Acceptance Criteria:**
- [ ] Remote players move smoothly (no snapping)
- [ ] NPCs glide smoothly
- [ ] Local player still uses prediction (responsive)

---

## Phase 6: Testing & Integration
**Effort:** 4 hours
**Risk:** Low
**Dependencies:** Phase 1-5 complete

### 6.1 File Size Audit

```bash
# Run final audit
echo "=== FINAL FILE SIZE AUDIT ===" > docs/final_audit.txt
echo "" >> docs/final_audit.txt
wc -l source/server/managers/combat/*.gd >> docs/final_audit.txt
wc -l source/client/combat/*.gd >> docs/final_audit.txt
wc -l scripts/realtime_battle/*.gd >> docs/final_audit.txt

# Check for violations
violations=$(wc -l source/**/*.gd scripts/**/*.gd | awk '$1 > 450 {print}' | wc -l)
if [ "$violations" -gt 0 ]; then
    echo "ERROR: Files exceed 450 line limit!"
    exit 1
fi
```

**Expected Results:**
```
source/server/managers/combat/combat_rules.gd:           350
source/server/managers/combat/combat_timing.gd:          300
source/server/managers/combat/combat_combo_system.gd:    250
source/server/managers/combat/combat_dodge_system.gd:    200
source/server/managers/combat/combat_input_buffer.gd:    300
source/server/managers/combat/combat_feedback_events.gd: 350
source/client/combat/combat_hit_freeze.gd:               180
source/client/combat/combat_screen_shake.gd:             150
source/client/combat/combat_damage_numbers.gd:           270
source/client/combat/combat_particles.gd:                180
source/client/combat/entity_interpolator.gd:             350
scripts/realtime_battle/realtime_battle_controller.gd:   450
scripts/realtime_battle/battle_input_handler.gd:         350
scripts/realtime_battle/realtime_battle_unit.gd:         380
```

**All files under 450 lines ✅**

### 6.2 Integration Tests

```gdscript
# tests/integration/test_combat_flow_full.gd
extends GutTest

func test_full_combat_sequence():
    var battle = _create_test_battle()

    # Phase 1: Attack with movement during recovery
    battle.player.attack("enemy_1")
    await get_tree().create_timer(0.13).timeout  # After wind-up
    assert_true(CombatRules.can_move(battle.player), "Can move during recovery")

    # Phase 2: Buffer attack during cooldown
    battle.controller.input_handler.try_attack()
    assert_true(battle.controller.input_handler.input_buffer.is_buffered("attack"))

    # Phase 3: Hit feedback triggers
    battle.apply_damage("enemy_1", 50, "back")
    assert_eq(battle.scene.freeze_frames_applied, 3, "Back hit should freeze 3 frames")

    # Phase 4: Combo advances
    battle.player.attack("enemy_1")
    await get_tree().create_timer(0.6).timeout
    battle.player.attack("enemy_1")
    assert_eq(battle.player.attack_combo_count, 2, "Combo should advance")

    # Phase 5: Remote entity interpolates
    var remote_player = battle.get_remote_player()
    assert_not_null(remote_player.interpolator, "Remote should have interpolator")
```

### 6.3 Performance Benchmark

```gdscript
# tests/performance/test_combat_performance.gd
func test_60fps_with_50_units():
    var battle = _spawn_battle(50)
    var frame_times = []

    for i in range(600):  # 10 seconds
        var start = Time.get_ticks_usec()
        battle._process_battle(0.016)
        var end = Time.get_ticks_usec()
        frame_times.append(end - start)

    var avg = frame_times.reduce(func(a,b): return a+b) / frame_times.size()
    var fps = 1000000.0 / avg
    assert_gt(fps, 60.0, "Should maintain 60fps")
```

### 6.4 Final Merge

```bash
git checkout master
git merge --no-ff feature/combat-flow-improvements -m "Feature: Combat Flow Improvements (Complete)

ANTI-GOD-FILE REFACTOR:
- combat_rules.gd: 486 → 350 lines (-136)
- realtime_battle_controller.gd: 614 → 450 lines (-164)
- All new files: <400 lines each

NEW COMPONENTS (11 files, 3,080 total lines):
- combat_timing.gd (300)
- combat_combo_system.gd (250)
- combat_dodge_system.gd (200)
- combat_input_buffer.gd (300)
- combat_feedback_events.gd (350)
- combat_hit_freeze.gd (180)
- combat_screen_shake.gd (150)
- combat_damage_numbers.gd (270)
- combat_particles.gd (180)
- entity_interpolator.gd (350)
- battle_input_handler.gd (350)

FEATURES:
✅ Phase 1: Faster combat (0.4s → 0.25s attacks)
✅ Phase 2: Input buffering (150ms grace)
✅ Phase 3: Hit feedback (freeze/shake/particles)
✅ Phase 4: 3-hit combo system
✅ Phase 5: Entity interpolation (smooth movement)
✅ Phase 6: Testing & integration

TESTS:
- 52 automated tests passing
- Performance: 60fps with 50+ units
- No files exceed 450 lines

Refs: SPEC_combat_flow_improvements.md"

git tag -a v0.2.0-combat-flow -m "Combat Flow Improvements Release"
git push origin master --tags
```

---

## Success Metrics

### Code Quality (Enforced)
- ✅ No files exceed 450 lines
- ✅ 2 bloated files shrunk (combat_rules, controller)
- ✅ 11 focused components created (<400 lines avg)
- ✅ Zero god files

### Combat Feel (Playtest)
- ✅ Attack commitment: 0.4s → 0.25s (37% faster)
- ✅ Input buffering: 0% input loss during cooldowns
- ✅ Hit feedback: Freeze + shake + particles
- ✅ Combo system: Progressive 3-hit chains
- ✅ Movement: Smooth interpolation (no snapping)

### Performance
- ✅ 60fps maintained with 50+ units
- ✅ Input latency <50ms
- ✅ Network overhead <10KB/s per player

---

**END OF SPECIFICATION**
