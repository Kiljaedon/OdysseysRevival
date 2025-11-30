# Real-Time Action Battle System - Implementation Plan

## Overview

Transform the turn-based FF6-style battle system into a Zelda-like real-time action combat system where:
- Player attacks overworld NPC → transitions to separate battle arena
- Player controls their character directly (WASD + attack)
- Squad mercenaries are AI-controlled
- Enemies use existing AI archetypes in real-time
- Combat uses existing damage formulas, stats, and reward systems

---

## Core Design Principles

1. **Reuse existing systems** - Damage calc, AI archetypes, stats, rewards
2. **Server-authoritative** - All damage/rewards validated server-side (MMO requirement)
3. **Strategic positioning** - Flanking bonuses, range requirements, line-of-sight projectiles
4. **Clear victory conditions** - Kill captain/leader = instant win
5. **Slot-based squad system** - 4 slots, larger units cost more slots
6. **Size matters** - Bigger units = bigger hitbox, more reach, but slower

---

## Squad & Size System

### Squad Slots
- **Max slots**: 4 (Player + 3 mercenary slots)
- **5th slot**: Reserved for Djinn/Elemental (future)
- Units cost 1-3 slots based on size

### Size Categories

| Category | Slots | Hitbox | Melee Range | Move Mod | Attack Mod |
|----------|-------|--------|-------------|----------|------------|
| **Small** | 1 | 50×85 | 50 px | +15% | +20% |
| **Standard** | 1 | 60×95 | 60 px | Base | Base |
| **Large** | 2 | 100×140 | 80 px | -20% | -15% |
| **Massive** | 3 | 160×200 | 120 px | -35% | -30% |

**Note**: For initial implementation, only **standard** size will be used. Large/massive support built into architecture for future content (dragons, giants, etc.)

### Size Config Data
```
const SIZE_CONFIGS = {
    "small": {
        "slot_cost": 1,
        "hitbox": Vector2(50, 85),
        "melee_range": 50,
        "collision_radius": 25,
        "move_speed_modifier": 1.15,
        "attack_speed_modifier": 1.20
    },
    "standard": {
        "slot_cost": 1,
        "hitbox": Vector2(60, 95),
        "melee_range": 60,
        "collision_radius": 30,
        "move_speed_modifier": 1.0,
        "attack_speed_modifier": 1.0
    },
    "large": {
        "slot_cost": 2,
        "hitbox": Vector2(100, 140),
        "melee_range": 80,
        "collision_radius": 50,
        "move_speed_modifier": 0.80,
        "attack_speed_modifier": 0.85
    },
    "massive": {
        "slot_cost": 3,
        "hitbox": Vector2(160, 200),
        "melee_range": 120,
        "collision_radius": 80,
        "move_speed_modifier": 0.65,
        "attack_speed_modifier": 0.70
    }
}
```

### Example Squad Configurations (Future)
```
Standard Party:     [Player][Merc1][Merc2][Merc3]  = 4 slots
Beastmaster+Dragon: [Player][======Dragon======]  = 4 slots
Mixed Party:        [Player][==Ogre==][Mage]      = 4 slots
```

---

## Control Scheme

### Player Movement (Cross-Platform)
```
PC:
- WASD keys for direct movement
- Click-to-move (click location, player walks there)
- Both work simultaneously

Mobile/Phone:
- Tap-to-move (tap location, player walks there)
- Virtual joystick (future consideration)
```

### Player Actions
```
Attack:
- PC: Spacebar or Left Click on enemy
- Mobile: Tap enemy while in range

Defend Mode:
- PC: Shift key or Defend button
- Mobile: Defend button on HUD
```

### Squad Control
```
Current Implementation:
- Squad mercenaries are FULLY AI-controlled
- Use AI archetypes (AGGRESSIVE/DEFENSIVE/TACTICAL/CHAOTIC)
- No direct player commands for now

Future (Commander System):
- Issue basic orders
- Set priority targets
- Formation controls
```

---

## Defend Mode (Player Ability)

### Stats
| Property | Value |
|----------|-------|
| Damage Reduction | 90% |
| Duration | 5 seconds |
| Cooldown | 20 seconds |

### Behavior
```
- Player activates defend mode
- Player takes 90% reduced damage for 5 seconds
- Player CANNOT MOVE while defending (rooted)
- Player cannot attack while defending
- 20 second cooldown before can use again
- Visual indicator (shield effect, blue glow)
- UI shows cooldown timer
```

### Server Implementation
```
Player unit state includes:
- is_defending: bool
- defend_timer: float (counts down from 5.0)
- defend_cooldown: float (counts down from 20.0)

Damage calculation modified:
if target.is_defending:
    damage = int(damage * 0.1)  # 90% reduction
```

---

## Phase 1: Foundation

### 1.1 BattleState Autoload
Global singleton for passing data between overworld and battle scenes.

```
Location: source/common/autoloads/battle_state.gd

Properties:
- current_battle: Dictionary (all battle data)
- player_data: Dictionary
- squad_data: Array[Dictionary]
- enemy_data: Array[Dictionary]
- terrain_type: String
- arena_size: Vector2i
- overworld_position: Vector2 (for return)
- first_strike: bool
- captain_index: int (which enemy is captain)
- player_is_captain: bool (true - killing player ends battle)
```

### 1.2 BattleSpeedCalculator
DEX-based speed formulas.

```
Location: source/common/combat/battle_speed_calculator.gd

Constants:
- DEX_MOVE_MODIFIER = 0.01 (+1% move speed per DEX)
- DEX_ATTACK_MODIFIER = 0.015 (+1.5% attack speed per DEX)
- MIN_ATTACK_COOLDOWN = 0.3 seconds

Functions:
- calculate_move_speed(base_move_speed, dex) -> float
- calculate_attack_speed(base_attack_speed, dex) -> float
- calculate_attack_cooldown(base_attack_speed, dex) -> float
```

### 1.3 BattleMapGenerator
Terrain detection and arena generation.

```
Location: source/common/combat/battle_map_generator.gd

Constants:
- ARENA_SIZES = {small: 12x10, medium: 16x12, large: 20x16}
- TERRAIN_TYPES = {grass: [...], dirt: [...], stone: [...], etc}

Arena Size Usage:
- SMALL (12x10): Normal overworld mobs, random encounters
- MEDIUM (16x12): Dungeon bosses, mini-bosses
- LARGE (20x16): Raid bosses, world bosses

Functions:
- detect_terrain_at_position(map_manager, world_pos) -> String
- determine_arena_size(enemy_type) -> String
- generate_battle_map(terrain, size) -> Dictionary
- calculate_spawn_points(size) -> Dictionary
- generate_obstacles(terrain, size) -> Array

### Default Spawn Formations

Player team spawns at BOTTOM, enemies spawn at TOP.
All units face toward center of arena at start.

```
SMALL ARENA (12x10 tiles = 1536x1280 px)

     [E1]   [E2]   [E3]        ← Enemies (row 2, facing DOWN)



           (battle zone)



     [M1] [PLAYER] [M2]        ← Player + Squad (row 8, facing UP)
           [M3]

Spawn Points (in pixels, 128px per tile):
ENEMIES (top, row 2):
  - E1: (384, 256)   - 3 tiles from left
  - E2: (768, 256)   - center
  - E3: (1152, 256)  - 3 tiles from right
  - E4: (576, 128)   - between E1-E2, row 1 (if needed)
  - E5: (960, 128)   - between E2-E3, row 1 (if needed)

PLAYER TEAM (bottom, row 8):
  - Player: (768, 1024)  - center
  - M1: (512, 1024)      - left of player
  - M2: (1024, 1024)     - right of player
  - M3: (768, 1152)      - behind player (row 9)

Initial Facing:
  - Enemies face DOWN (toward player)
  - Player/Squad face UP (toward enemies)
```

```
MEDIUM ARENA (16x12 tiles = 2048x1536 px)

ENEMIES (top, row 2):
  - E1: (512, 256)
  - E2: (1024, 256)   - center
  - E3: (1536, 256)
  - E4: (768, 128)    - row 1
  - E5: (1280, 128)   - row 1

PLAYER TEAM (bottom, row 10):
  - Player: (1024, 1280)
  - M1: (768, 1280)
  - M2: (1280, 1280)
  - M3: (1024, 1408)
```

```
LARGE ARENA (20x16 tiles = 2560x2048 px)

ENEMIES (top, row 2-3):
  - E1: (640, 256)
  - E2: (1280, 256)   - center
  - E3: (1920, 256)
  - E4: (960, 384)    - row 3
  - E5: (1600, 384)   - row 3

PLAYER TEAM (bottom, row 13-14):
  - Player: (1280, 1664)
  - M1: (896, 1664)
  - M2: (1664, 1664)
  - M3: (1280, 1792)
```
```

---

## Phase 2: Battle Arena Scene

### 2.1 BattleArena Scene Structure
```
BattleArena (Node2D)
├── TileMapLayer (battle terrain)
├── Obstacles (Node2D container)
├── Units (Node2D container)
│   ├── Player (BattleUnit)
│   ├── Squad (BattleUnit x3)
│   └── Enemies (BattleUnit x1-5)
├── Projectiles (Node2D container)
├── Camera2D (follows player, zoomable)
└── BattleUI (CanvasLayer)
    ├── HPBars (follow units)
    └── BattleStatus
```

### 2.2 BattleArena Script
```
Location: scenes/battle/battle_arena.gd

Responsibilities:
- Build tilemap from generated data
- Spawn player, squad, enemies at spawn points
- Create arena boundaries
- Track captain units
- Detect victory/defeat conditions
- Handle battle end and rewards

Key Functions:
- _ready() → build arena, spawn units
- _spawn_player(data, position)
- _spawn_squad(squad_data, positions)
- _spawn_enemies(enemy_data, positions)
- _setup_teams() → tell AI who enemies are
- _on_unit_died(unit) → check captain death, victory
- _on_victory() → calculate rewards, show UI
- _on_defeat() → show defeat UI
- _return_to_overworld()

Victory Conditions:
- All enemies dead = victory
- Enemy captain dead = instant victory
- Player dead = defeat
```

---

## Phase 3: Battle Unit System

### 3.1 BattleUnit (CharacterBody2D)
Unified class for player, squad mercenaries, and enemies.

```
Location: scenes/battle/battle_unit.gd

Properties:
- unit_name: String
- team: String ("player" or "enemy")
- is_player_controlled: bool
- is_captain: bool
- combat_role: String (melee/ranged/caster/hybrid)

Stats:
- hp, max_hp
- dex
- base_move_speed, base_attack_speed
- move_speed (calculated)
- attack_cooldown (calculated)
- attack_range: float (melee ~60, ranged ~300)
- weaknesses: Dictionary

Components:
- anim: BattleUnitAnimation
- ai: BattleUnitAI (null for player)
- damage_handler: BattleDamageHandler
- attack_hitbox: Area2D
- hurtbox: Area2D

Signals:
- died(unit)
- damaged(amount, attacker)
```

### 3.2 BattleUnitAnimation
Handles facing and attack frame playback.

```
Location: scenes/battle/components/battle_unit_animation.gd

Properties:
- current_direction: String (up/down/left/right)
- animated_sprite: AnimatedSprite2D

Functions:
- face_target(target_position) → update direction
- face_direction_from_velocity(velocity)
- play_walk()
- play_idle()
- play_attack() → plays all frames, emits animation_finished
- get_facing_vector() -> Vector2
```

### 3.3 BattleUnitAI
Real-time AI state machine. Adapts existing NPC_AI_Controller archetypes.

**Design Philosophy**: AI should be competent but NOT hyper-optimized.
Players should be able to outmaneuver enemies with good tactics.
AI does NOT actively seek flanking positions or exploit weaknesses perfectly.

```
Location: scenes/battle/components/battle_unit_ai.gd

States:
- IDLE: No target, look for one
- CHASE: Moving toward target (direct path, not optimal)
- ATTACK: In range, executing attack
- RETREAT: Low HP, backing away (DEFENSIVE archetype only)
- REPOSITION: Ranged unit needs line of sight (basic repositioning)

Properties:
- archetype: String (AGGRESSIVE/DEFENSIVE/TACTICAL/CHAOTIC)
- attack_range: float
- chase_range: float
- attack_cooldown: float
- cooldown_timer: float
- current_target: BattleUnit
- enemies: Array[BattleUnit]
- allies: Array[BattleUnit]

Archetype Behaviors (adapted from existing NPC_AI_Controller):
- AGGRESSIVE: Target lowest HP enemy, relentless chase
- DEFENSIVE: Retreat when HP < 40%, otherwise random target
- TACTICAL: Prioritize back-line/casters, then lowest HP
- CHAOTIC: Random target, unpredictable

AI Limitations (intentional):
- Does NOT pathfind around obstacles optimally
- Does NOT coordinate attacks with allies
- Does NOT actively seek flanking positions
- Does NOT switch targets frequently (sticky targeting)
- Ranged units reposition minimally for LOS, not tactically

Functions:
- _physics_process(delta) → state machine loop
- _select_target() → uses archetype logic from NPC_AI_Controller
- _is_in_attack_range() -> bool
- _has_clear_shot(target) -> bool (for ranged - line of sight)
```

### 3.4 BattleDamageHandler
Processes hitbox collisions and applies damage.

```
Location: scenes/battle/components/battle_damage_handler.gd

Functions:
- _on_hitbox_entered(hitbox: Area2D)
  - Check not friendly fire
  - Call SharedBattleCalculator.calculate_damage()
  - Apply flanking bonus (SIDE +15%, BACK +30%)
  - Apply weakness multiplier
  - Apply defend reduction (90% if defending)
  - Subtract HP
  - Emit damaged signal
  - Spawn damage number
  - Check death

Note: Critical hits DISABLED for initial implementation.
Will be added later with dedicated crit stat system.

- _is_flanking(attacker) -> bool
  - Dot product of attacker direction vs defender facing
  - < -0.3 = behind

- _apply_weakness(damage, damage_type) -> int
  - Lookup in unit's weakness table
```

---

## Phase 4: Ranged Combat System

### 4.1 Ranged Attack Rules
```
Requirements:
- Must be within range (configurable per unit, ~300px default)
- Must have clear line of sight (no obstacles between)
- Must stand still to fire (brief windup ~0.3s)
- Projectile travels in straight line
- Projectile has max travel distance

Ranged AI Behavior:
- If target out of range → CHASE until in range
- If target in range but no clear shot → REPOSITION
- If target in range with clear shot → stop, windup, fire
```

### 4.2 Projectile System
```
Location: scenes/battle/projectile.gd

Properties:
- damage: int
- damage_type: String
- speed: float (~400 px/s)
- max_distance: float
- owner_unit: BattleUnit
- team: String

Behavior:
- Travels in straight line (set direction on spawn)
- On hit enemy hurtbox → apply damage, queue_free()
- On hit obstacle → queue_free()
- On max distance reached → queue_free()

Spawning:
- From BattleUnit.perform_ranged_attack()
- Spawned at unit position
- Direction = toward target at time of fire
```

### 4.3 Line of Sight Check
```
Function: has_clear_shot(from: Vector2, to: Vector2) -> bool

Implementation:
- Raycast from attacker to target
- Check for obstacle collisions
- Return false if blocked
```

---

## Phase 5: Combat Roles & Positioning

### 5.1 Combat Role Definitions
```
MELEE:
- attack_range: 60px
- Must be close to attack
- Full damage, best defense
- No line of sight needed

RANGED:
- attack_range: 300px
- Must stand still to attack
- Projectile-based
- Requires line of sight
- Fragile (+10% incoming damage)

CASTER:
- attack_range: 250px
- Spell-based (future: mana cost)
- Requires line of sight (spells blocked by obstacles)
- Very fragile (+20% incoming damage)

HYBRID:
- attack_range: 150px
- Can melee or short-range attack
- Moderate fragility (+15% incoming damage)
```

### 5.2 Flanking System (Tiered)
```
Position Bonuses:
- FRONT (facing attacker): No bonus (1.0x)
- SIDE (perpendicular): +15% damage (1.15x)
- BACK (behind): +30% damage (1.30x)

Detection (using dot product):
- Get direction from defender to attacker
- Get defender's facing direction
- dot > 0.5 = FRONT (defender facing attacker)
- dot between -0.5 and 0.5 = SIDE
- dot < -0.5 = BACK (attacker behind defender)

Visual feedback:
- SIDE hit: "FLANK!" yellow text
- BACK hit: "BACKSTAB!" red text
- Different color damage numbers
```

### 5.3 Monster Weaknesses
```
Location: source/common/combat/monster_weaknesses.gd

const WEAKNESSES = {
    "Goblin": {"fire": 1.5, "ice": 0.8, "physical": 1.0},
    "OrcWarrior": {"ice": 1.2, "lightning": 1.3, "physical": 0.7},
    "DarkMage": {"physical": 1.4, "holy": 2.0},
    "Rogue": {"fire": 1.1, "physical": 1.0},
    "EliteGuard": {"lightning": 1.2, "physical": 0.8},
    "RogueBandit": {"fire": 1.2, "ice": 1.0}
}

Usage:
- BattleDamageHandler looks up attacker's damage_type
- Multiplies final damage by weakness value
```

---

## Phase 6: UI Systems

### 6.1 HP Bars Above Units
```
Location: scenes/battle/ui/unit_hp_bar.gd

Behavior:
- Follows unit position (offset above head)
- Shows current HP / max HP
- Color changes: green → yellow → red
- Captain has special indicator (crown icon?)
- Hides when unit dies

Implementation:
- Node2D with ProgressBar child
- Updated in _process() to follow unit
- Connected to unit's damaged signal
```

### 6.2 Battle Status UI
```
Location: scenes/battle/ui/battle_status.gd

Shows:
- "BATTLE START" on enter
- "CAPTAIN DOWN!" on captain kill
- "VICTORY" / "DEFEAT" at end
- Reward summary on victory
```

### 6.3 Camera System
```
Behavior:
- Same as overworld (centered on player)
- Mouse wheel zoom in/out
- +/- keys for zoom
- Stays within arena bounds

Implementation:
- Reuse existing camera code from dev_client_controller
- Set limits to arena boundaries
```

---

## Phase 7: Battle Transition

### 7.1 Initiating Combat
```
Location: source/common/combat/battle_transition.gd

Trigger:
- Player hits NPC with attack hitbox (existing code)
- Modified to call BattleTransition.initiate_combat()

Process:
1. Detect terrain at player position
2. Get enemy NPC data
3. Build enemy squad (EnemySquadBuilder)
4. Determine arena size
5. Generate battle map
6. Store in BattleState
7. Change scene to battle_arena.tscn

Requirements for initiating:
- NPCs must be facing player (within 90 degrees of facing)
- NPCs cannot be in same tile (minimum spacing)
```

### 7.2 Combat Initiation Validation
```
Function: can_initiate_combat(player, npc) -> bool

Checks:
- NPC is facing player (dot product > 0)
- No other NPC in same tile (distance > tile_size)
- No other NPC within aggro range (cannot fight multiple NPCs at once)
- NPC battle_enabled = true
- Player weapon unsheathed

Multiple NPC Rule:
- Only ONE NPC can be engaged at a time
- If another NPC is too close, combat cannot start
- Minimum spacing required between NPCs for combat initiation
```

### 7.3 Returning to Overworld
```
On Victory:
1. Calculate rewards (existing CombatManager.calculate_rewards)
2. Apply XP/gold to player
3. Show victory UI
4. On dismiss → change scene to main
5. Restore player to pre_battle_position
6. Remove defeated NPC from world

On Defeat:
1. Show defeat UI
2. On dismiss → respawn at current map spawn point
   (For now: test map only, future: nearest town/checkpoint)
```

---

## Phase 8: Server-Authoritative Combat (CRITICAL - MMO)

### 8.1 Architecture Overview
```
This is an MMO - ALL combat logic MUST be server-authoritative.
Client is for display/input only. Server is the source of truth.

┌─────────────────┐                    ┌─────────────────┐
│     CLIENT      │                    │     SERVER      │
├─────────────────┤                    ├─────────────────┤
│ Input capture   │───── RPC ────────▶│ Validate action │
│ Animation       │                    │ Calculate damage│
│ Visual effects  │◀──── RPC ─────────│ Update state    │
│ Position interp │                    │ Broadcast result│
└─────────────────┘                    └─────────────────┘
```

### 8.2 Server Battle Manager
```
Location: source/server/managers/realtime_combat_manager.gd

Responsibilities:
- Create/track active battle instances
- Process player movement inputs
- Execute AI for all NPCs/squads
- Calculate all damage server-side
- Validate all actions
- Broadcast state to participants
- Detect victory/defeat
- Apply rewards

Data Structure:
var active_battles: Dictionary = {
    battle_id: {
        "participants": [peer_id_1, peer_id_2],
        "player_units": {peer_id: unit_data},
        "squad_units": {peer_id: [unit_data, ...]},
        "enemy_units": [unit_data, ...],
        "captain_id": String,
        "terrain": String,
        "arena_size": Vector2i,
        "state": "active" | "victory" | "defeat"
    }
}
```

### 8.3 Server-Side Unit State
```
Each unit on server tracks:
{
    "id": String (unique),
    "position": Vector2,
    "hp": int,
    "max_hp": int,
    "facing": String,
    "state": "idle" | "moving" | "attacking" | "dead",
    "target_id": String or null,
    "attack_cooldown": float,
    "team": "player" | "enemy",
    "is_captain": bool,
    "combat_role": String,
    "stats": Dictionary
}
```

### 8.4 Client → Server RPCs
```
Location: source/common/network/services/realtime_combat_service.gd

# Player requests to initiate battle
@rpc("any_peer", "call_remote", "reliable")
func request_battle_start(npc_id: int)

# Player movement input (sent frequently)
@rpc("any_peer", "call_remote", "unreliable_ordered")
func send_movement_input(battle_id: String, velocity: Vector2)

# Player attack action
@rpc("any_peer", "call_remote", "reliable")
func send_attack_action(battle_id: String, target_id: String)

# Player ranged attack
@rpc("any_peer", "call_remote", "reliable")
func send_ranged_attack(battle_id: String, target_id: String)
```

### 8.5 Server → Client RPCs
```
# Battle started - send initial state
@rpc("authority", "call_remote", "reliable")
func receive_battle_start(battle_data: Dictionary)

# Periodic state update (positions, HP, states)
@rpc("authority", "call_remote", "unreliable_ordered")
func receive_state_update(battle_id: String, units_state: Array)

# Damage event (for visual feedback)
@rpc("authority", "call_remote", "reliable")
func receive_damage_event(attacker_id: String, target_id: String, damage: int, is_crit: bool, is_flank: bool)

# Unit died
@rpc("authority", "call_remote", "reliable")
func receive_unit_death(battle_id: String, unit_id: String)

# Projectile spawned (for visual)
@rpc("authority", "call_remote", "reliable")
func receive_projectile_spawn(from_pos: Vector2, to_pos: Vector2, projectile_type: String)

# Battle ended
@rpc("authority", "call_remote", "reliable")
func receive_battle_end(battle_id: String, result: String, rewards: Dictionary)
```

### 8.6 Server Game Loop
```
func _physics_process(delta: float) -> void:
    for battle_id in active_battles:
        var battle = active_battles[battle_id]
        if battle.state != "active":
            continue

        # Process player inputs (from queued RPCs)
        _process_player_inputs(battle)

        # Run AI for all non-player units
        _process_ai_units(battle, delta)

        # Process attacks and damage
        _process_combat(battle)

        # Check victory/defeat
        _check_battle_end(battle)

        # Broadcast state to clients
        _broadcast_state(battle)
```

### 8.7 Damage Calculation (Server Only)
```
# All damage calculated on server using SharedBattleCalculator
func _process_attack(battle: Dictionary, attacker: Dictionary, target: Dictionary) -> void:
    # Validate target is alive and enemy
    if target.hp <= 0 or target.team == attacker.team:
        return

    # Calculate damage (server-side, no client trust)
    var damage = SharedBattleCalculator.calculate_damage(
        attacker.stats,
        target.stats,
        -1, -1,  # No row positions in real-time
        attacker.team == "enemy"
    )

    # Flanking bonus (calculated server-side)
    if _is_flanking(attacker, target):
        damage = int(damage * 1.3)

    # Weakness multiplier
    damage = _apply_weakness(damage, attacker.damage_type, target.weaknesses)

    # Apply damage
    target.hp -= damage

    # Notify clients
    for peer_id in battle.participants:
        receive_damage_event.rpc_id(peer_id, attacker.id, target.id, damage, false, _is_flanking(attacker, target))

    # Check death
    if target.hp <= 0:
        _handle_unit_death(battle, target)
```

### 8.8 Client Display (Prediction + Interpolation)
```
Client responsibilities:
1. Send inputs immediately to server
2. Apply local prediction for movement (smooth feel)
3. Interpolate received positions (smooth other units)
4. Play animations based on server state
5. Show damage numbers when server confirms hit
6. NO local damage calculation - wait for server

Position interpolation:
- Store last 2-3 server positions per unit
- Interpolate between them for smooth display
- Snap if too far behind

Input prediction:
- Apply player movement locally immediately
- Server confirms/corrects position
- Small corrections = smooth blend
- Large corrections = snap (anti-cheat)
```

### 8.9 Anti-Cheat Considerations
```
Server validates:
- Player position within reasonable movement speed
- Attack cooldowns respected
- Target is valid (exists, in range, alive)
- Player is in active battle
- Actions correspond to player's unit (not hacking other units)

Rate limiting:
- Max movement updates: 20/second per player
- Max attack actions: 3/second per player

Sanity checks:
- Position delta < max_speed * time_delta * 1.5
- Attack range respected (server checks distance)
- Line of sight verified server-side for ranged
```

### 8.10 Multiplayer Battle Support
```
Future: Multiple players in same battle

Scenarios:
1. Party system - players fight together
2. PvP - players fight each other
3. Guild battles - large scale

For now: Single player vs NPCs, but architecture supports expansion
- Each player has their own unit + squad
- Server manages all units
- Broadcasts to all participants
```

---

## Implementation Order

**IMPORTANT: Server-first development. Build server logic, then client display.**

### Sprint 1: Server Foundation
1. [ ] Create RealtimeCombatManager on server
2. [ ] Create RealtimeCombatService (RPC definitions)
3. [ ] Implement battle instance creation/tracking
4. [ ] Create BattleSpeedCalculator (shared)
5. [ ] Create BattleMapGenerator (shared - server generates, sends to client)
6. [ ] Test: Server can create battle instances

### Sprint 2: Server Unit State
7. [ ] Define server-side unit data structure
8. [ ] Implement unit spawning on server
9. [ ] Implement server-side position tracking
10. [ ] Implement server-side HP tracking
11. [ ] Test: Server tracks all units in battle

### Sprint 3: Server Combat Logic
12. [ ] Port damage calculation to server (use SharedBattleCalculator)
13. [ ] Implement server-side flanking detection
14. [ ] Add monster weaknesses lookup
15. [ ] Implement attack cooldown validation
16. [ ] Implement hitbox collision detection (server-side)
17. [ ] Test: Server calculates damage correctly

### Sprint 4: Server AI
18. [ ] Create server-side BattleUnitAI
19. [ ] Implement IDLE, CHASE, ATTACK states
20. [ ] Port archetype target selection
21. [ ] Add RETREAT for DEFENSIVE archetype
22. [ ] Add REPOSITION for ranged units
23. [ ] Test: Server AI makes decisions

### Sprint 5: Server Ranged Combat
24. [ ] Implement server-side line of sight check
25. [ ] Implement ranged attack validation
26. [ ] Track projectiles server-side
27. [ ] Implement projectile hit detection
28. [ ] Test: Ranged attacks work server-side

### Sprint 6: Server Victory/Defeat
29. [ ] Track captain units
30. [ ] Detect captain death → instant victory
31. [ ] Detect all enemies dead → victory
32. [ ] Detect player dead → defeat
33. [ ] Calculate rewards server-side
34. [ ] Apply XP/gold to player data
35. [ ] Test: Battles end correctly on server

### Sprint 7: Client Foundation
36. [ ] Create BattleState autoload (client)
37. [ ] Create BattleArena scene structure
38. [ ] Implement receive_battle_start RPC handler
39. [ ] Build tilemap from server data
40. [ ] Test: Client receives and displays arena

### Sprint 8: Client Units
41. [ ] Create BattleUnit scene (client-side display only)
42. [ ] Create BattleUnitAnimation component
43. [ ] Load all animations (walk + attack)
44. [ ] Implement facing from server state
45. [ ] Implement position interpolation
46. [ ] Test: Units display and move smoothly

### Sprint 9: Client Input & Prediction
47. [ ] Implement movement input capture
48. [ ] Send movement RPCs to server
49. [ ] Implement local prediction for player
50. [ ] Implement server correction blending
51. [ ] Implement attack input → RPC
52. [ ] Test: Player controls feel responsive

### Sprint 10: Client Combat Display
53. [ ] Handle receive_damage_event RPC
54. [ ] Show damage numbers
55. [ ] Play attack animations on server events
56. [ ] Handle receive_unit_death RPC
57. [ ] Play death animations
58. [ ] Test: Combat looks correct

### Sprint 11: Client Ranged Display
59. [ ] Handle receive_projectile_spawn RPC
60. [ ] Create Projectile scene (visual only)
61. [ ] Animate projectile travel
62. [ ] Test: Projectiles display correctly

### Sprint 12: Client UI
63. [ ] Create HP bar component
64. [ ] Attach HP bars to units (from server HP)
65. [ ] Create battle status UI
66. [ ] Handle receive_battle_end RPC
67. [ ] Show victory/defeat screens
68. [ ] Test: Full battle with UI

### Sprint 13: Integration
69. [ ] Modify NPC hit detection to send RPC
70. [ ] Server validates combat initiation
71. [ ] Implement full transition flow
72. [ ] Handle return to overworld
73. [ ] Server removes defeated NPC
74. [ ] Client syncs NPC removal
75. [ ] Test: Complete loop works

### Sprint 14: Polish & Anti-Cheat
76. [ ] Add rate limiting on server
77. [ ] Add position sanity checks
78. [ ] Add damage number popups
79. [ ] Add hit effects/particles
80. [ ] Camera shake on big hits
81. [ ] Balance pass on numbers
82. [ ] Stress test with simulated latency

---

## File Structure

```
source/
├── common/
│   ├── autoloads/
│   │   └── battle_state.gd
│   └── combat/
│       ├── battle_speed_calculator.gd
│       ├── battle_map_generator.gd
│       ├── battle_transition.gd
│       ├── monster_weaknesses.gd
│       └── shared_battle_calculator.gd (existing)
│
scenes/
└── battle/
    ├── battle_arena.tscn
    ├── battle_arena.gd
    ├── battle_unit.tscn
    ├── battle_unit.gd
    ├── projectile.tscn
    ├── projectile.gd
    ├── obstacle.tscn
    ├── obstacle.gd
    ├── components/
    │   ├── battle_unit_ai.gd
    │   ├── battle_unit_animation.gd
    │   └── battle_damage_handler.gd
    └── ui/
        ├── unit_hp_bar.tscn
        ├── unit_hp_bar.gd
        ├── battle_status.tscn
        ├── battle_status.gd
        └── damage_number.tscn
```

---

## Key Dependencies

| New System | Depends On |
|------------|------------|
| BattleUnit | CharacterResource (stats), Animation JSON |
| BattleDamageHandler | SharedBattleCalculator |
| BattleUnitAI | NPC_AI_Controller (archetype logic) |
| BattleMapGenerator | MapManager (terrain tiles) |
| Victory Rewards | CombatManager.calculate_rewards() |
| BattleSpeedCalculator | CharacterResource (base speeds) |

---

## Open Questions for Later

1. **Mercenary recruitment** - How does player get squad members?
2. **Mercenary base UI** - Where does player configure squad?
3. **Commander directives** - Phase 2 feature
4. **Escape from battle** - Can player flee? Penalty?
5. **Death penalties** - What happens on defeat? Respawn where?
6. **Multiplayer sync** - How do multiple players share a battle?
7. **Boss mechanics** - Special attacks, phases?

---

## Success Criteria

A successful implementation will:
1. Player can attack overworld NPC and transition to battle
2. Battle arena matches overworld terrain
3. Player controls character in real-time (WASD + attack)
4. Squad mercenaries fight automatically
5. Enemies use AI archetypes intelligently
6. Ranged units require positioning and line of sight
7. Flanking provides tactical advantage
8. Monster weaknesses matter
9. Captain death ends battle instantly
10. Victory awards XP/gold
11. Player returns to overworld at original position
12. Defeated NPC is removed from world
