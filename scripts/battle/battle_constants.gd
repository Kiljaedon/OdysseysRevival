class_name BattleConstants
## Battle System Constants - Complete Reference
## All magic numbers from battle system documented for easy balancing
## NOTE: These are for REFERENCE ONLY - changing these does NOT change the game
## To actually change values, you must edit the source files where they're used

# ========== TIMING (await get_tree().create_timer) ==========
# What they do: Control pacing of battle - how long between actions
# Higher = slower/more dramatic, Lower = faster/more arcade-like
# Found in: battle_window_v2.gd execute_player_attack(), execute_ally_turn(), execute_enemy_turn()

const SHOW_TURN_DELAY = 0.5          # Pause before character acts (shows "X's Turn!" message)
                                      # Effect: 0.5s = quick acknowledgment, 1.0s = slower paced

const DEFEND_ACTION_DELAY = 1.0      # How long to display "X defends!" message
                                      # Effect: Gives player time to see who defended

const ENEMY_THINK_TIME = 1.5         # Pause after enemy acts before advancing turn
                                      # Effect: Prevents instant enemy chain attacks, feels more natural
                                      # Lower = enemies feel more aggressive

const ALLY_THINK_TIME = 1.5          # Pause after ally NPC acts before advancing turn
                                      # Effect: Same as enemy timing, keeps consistent pacing

const SELECTION_PHASE_TIME = 8.0     # How long player has to choose their action each round
                                      # Effect: 8s = strategic decisions, 5s = pressure, 15s = too slow
                                      # Found in: battle_combat_controller.gd

# ========== DAMAGE FORMULAS ==========
# What they do: Determine base damage before position/role modifiers
# Higher multipliers = bigger numbers, more damage variance
# Found in: battle_window_v2.gd calculate_damage()

# CASTER (Magic) damage formula: (INT × 2.2) - (defender's INT/2 + WIS/3)
const CASTER_MAGIC_MULT = 2.2        # INT × 2.2 for magic damage
                                      # Effect: Was 2.5 (too strong), nerfed to 2.2 for balance
                                      # Example: 18 INT = 39.6 base damage (before defense)

const INT_MAGIC_DEF_DIVISOR = 2.0    # Defender's INT / 2 = magic defense
                                      # Effect: 20 INT = 10 magic defense (reduces magic damage by 10)

const WIS_MAGIC_DEF_DIVISOR = 3.0    # Defender's WIS / 3 = additional magic defense
                                      # Effect: 15 WIS = 5 more magic defense (total with INT)

# PHYSICAL damage formula: (STR × 2) + weapon_power - (defender's VIT/2)
const PHYSICAL_STR_MULT = 2.0        # STR × 2 for physical damage
                                      # Effect: 18 STR = 36 base damage (before defense)
                                      # Why 2.0 vs caster 2.2? Physical has weapon bonuses later

const VIT_DEFENSE_DIVISOR = 2.0      # Defender's VIT / 2 = physical defense
                                      # Effect: 20 VIT = 10 physical defense (reduces damage by 10)

# Weapon power (future system)
const DEFAULT_WEAPON_POWER = 0       # Currently no weapons implemented
                                      # Effect: Will add bonus damage (swords = +10, axes = +15, etc)

# ========== POSITION PENALTIES (OFFENSIVE) ==========
# What they do: Punish/reward positioning choices (front row vs back row)
# Lower values = bigger penalties for bad positioning
# Found in: battle_window_v2.gd calculate_range_penalty()

# MELEE role - wants to be in front row attacking front row targets
const MELEE_BACK_ROW_PENALTY = 0.6           # Melee fighter standing in back row deals 60% damage (40% penalty)
                                              # Effect: Punishes cowardly melee hiding in back
                                              # Was 0.5 (too harsh), buffed to 0.6 for balance
                                              # Example: 36 damage becomes 21.6 damage

const MELEE_VS_BACK_ROW_PENALTY = 0.6        # Melee attacking back row target deals 60% damage (40% penalty)
                                              # Effect: Hard to reach enemies hiding behind tanks
                                              # Example: 36 damage becomes 21.6 damage

const MELEE_WORST_CASE_FLOOR = 0.36          # When BOTH penalties apply (back row melee vs back row target)
                                              # Effect: 0.6 × 0.6 = 0.36, so 36 damage becomes 13 damage
                                              # This is the minimum - melee can't fall below 36% damage

# RANGED role - wants to be in back row (any target)
const RANGED_FRONT_ROW_PENALTY = 0.5         # Ranged fighter in front row deals 50% damage (forced to melee)
                                              # Effect: Archers suck at close combat
                                              # Example: 36 damage becomes 18 damage
                                              # No penalty for attacking back row (they're ranged!)

# HYBRID role - flexible positioning but slightly weaker overall
const HYBRID_VERSATILITY_PENALTY = 0.95      # Hybrid deals 95% damage from any position (small 5% penalty)
                                              # Effect: Jack-of-all-trades penalty (not specialized)
                                              # Was 0.9 (too weak), buffed to 0.95 for balance
                                              # Example: 36 damage becomes 34.2 damage

# CASTER role - no position penalties (magic hits from anywhere)
const CASTER_POSITION_PENALTY = 1.0          # Casters deal 100% damage from any position (no penalty)
                                              # Effect: Can sit safely in back row with no downside
                                              # Balanced by taking extra damage (see defensive modifiers)

# ========== DEFENSIVE MODIFIERS (ROLE-BASED) ==========
# What they do: Make some roles squishier (take more damage) for balance
# Higher values = take MORE damage (fragile)
# Found in: battle_window_v2.gd get_defensive_modifier()

const CASTER_FRAGILITY = 1.2         # Casters take 120% damage (multiply incoming damage by 1.2)
                                      # Effect: 20% extra damage taken (glass cannon - high damage but fragile)
                                      # Example: 50 damage hit becomes 60 damage
                                      # Why? Balances their high damage and no position penalties

const HYBRID_FRAGILITY = 1.15        # Hybrids take 115% damage (15% extra)
                                      # Effect: Slightly fragile but not as bad as casters
                                      # Was 1.2 (same as caster), reduced to 1.15 to make hybrids viable
                                      # Example: 50 damage hit becomes 57.5 damage

const RANGED_FRAGILITY = 1.1         # Ranged take 110% damage (10% extra)
                                      # Effect: Slightly vulnerable (light armor) but not too bad
                                      # Example: 50 damage hit becomes 55 damage
                                      # Why? They can stay in back row relatively safe

const MELEE_DEFENSE = 1.0            # Melee take 100% damage (normal, no modifier)
                                      # Effect: Tanks take damage as-is (heavy armor, tough)
                                      # Example: 50 damage hit stays 50 damage
                                      # Why? Their job is to absorb damage for the team

# ========== FORMATION POSITIONS ==========
# What they do: Define which positions are front/back for penalty calculations
# Found in: battle_window_v2.gd is_front_row()

const FRONT_ROW_SIZE = 3             # How many positions in front row
                                      # Effect: Positions [0, 1, 2] = front row (closer to enemies)

const BACK_ROW_SIZE = 3              # How many positions in back row
                                      # Effect: Positions [3, 4, 5] = back row (safer from melee)

const TOTAL_SQUAD_SIZE = 6           # Total units per side (3 front + 3 back)
                                      # Effect: Each team has 6 character slots max

const FRONT_ROW_MAX_INDEX = 2        # Used in position checks (index <= 2 = front row)
                                      # Effect: if panel_index <= 2 then front row, else back row

# ========== DEFEND ACTION ==========
# What it does: Reduce damage when player chooses "Defend" action
# Found in: battle_window_v2.gd execute_enemy_turn()

const DEFEND_DAMAGE_REDUCTION = 0.5  # Multiply incoming damage by 0.5 when defending
                                      # Effect: Defending cuts damage in HALF (50% reduction)
                                      # Example: 60 damage hit becomes 30 damage
                                      # Why? Gives defensive option instead of always attacking

# ========== UI COLORS ==========
# What they do: Control visual feedback for player actions and battle results
# Format: RGB channels from 0.0 (none) to 1.5 (overbright glow effect)
# Found in: battle_ui_manager.gd button highlighting, battle_window_v2.gd result screen

# Button highlight colors (when action is selected)
const SELECTED_BUTTON_COLOR_R = 1.5  # Red channel = 1.5 (overbright)
const SELECTED_BUTTON_COLOR_G = 1.5  # Green channel = 1.5 (overbright)
const SELECTED_BUTTON_COLOR_B = 0.5  # Blue channel = 0.5 (reduced)
                                      # Effect: R+G high, B low = YELLOW glow (1.5, 1.5, 0.5)
                                      # Why? Yellow = selected/active in most UIs

const NORMAL_BUTTON_COLOR_R = 1.0    # Red channel = 1.0 (normal)
const NORMAL_BUTTON_COLOR_G = 1.0    # Green channel = 1.0 (normal)
const NORMAL_BUTTON_COLOR_B = 1.0    # Blue channel = 1.0 (normal)
                                      # Effect: Equal RGB = white/neutral (1.0, 1.0, 1.0)
                                      # Why? Default button state, no emphasis

# Result screen colors (shown when battle ends)
const VICTORY_TEXT_COLOR_R = 0.2     # Red channel = 0.2 (low)
const VICTORY_TEXT_COLOR_G = 1.0     # Green channel = 1.0 (full)
const VICTORY_TEXT_COLOR_B = 0.2     # Blue channel = 0.2 (low)
                                      # Effect: High G, low R+B = BRIGHT GREEN (0.2, 1.0, 0.2)
                                      # Why? Green = success/victory universal color

const DEFEAT_TEXT_COLOR_R = 1.0      # Red channel = 1.0 (full)
const DEFEAT_TEXT_COLOR_G = 0.2      # Green channel = 0.2 (low)
const DEFEAT_TEXT_COLOR_B = 0.2      # Blue channel = 0.2 (low)
                                      # Effect: High R, low G+B = BRIGHT RED (1.0, 0.2, 0.2)
                                      # Why? Red = danger/defeat universal color

# ========== STAT DEFAULTS ==========
# What they do: Fallback values when character doesn't have stats defined
# Higher = characters without stats become stronger (not recommended)
# Found in: battle_window_v2.gd calculate_damage(), get_defensive_modifier()

const DEFAULT_STR = 10               # Default strength if character.base_stats.str missing
                                      # Effect: 10 STR = 20 physical damage base (STR × 2)
                                      # Why 10? Balanced starting point for level 1 characters

const DEFAULT_INT = 10               # Default intelligence if character.base_stats.int missing
                                      # Effect: 10 INT = 22 magic damage base (INT × 2.2)
                                      # Why 10? Matches STR default, keeps physical/magic balanced

const DEFAULT_VIT = 10               # Default vitality if character.base_stats.vit missing
                                      # Effect: 10 VIT = 5 physical defense (VIT / 2)
                                      # Why 10? Provides minimal defense without making invincible

const DEFAULT_WIS = 10               # Default wisdom if character.base_stats.wis missing
                                      # Effect: 10 WIS = 3.33 magic defense (WIS / 3)
                                      # Why 10? Matches other stats, provides small magic resistance

const DEFAULT_DEX = 10               # Default dexterity if character.base_stats.dex missing
                                      # Effect: 10 DEX = middle of turn order (not fast, not slow)
                                      # Why 10? Neutral turn priority, used for turn order sorting

# ========== REWARDS (end_battle calculations) ==========
# What they do: Calculate XP and gold rewards when battle ends successfully
# Higher values = faster progression and more gold income
# Found in: battle_window_v2.gd calculate_rewards() or end_battle()

const XP_BASE_PER_ENEMY = 50         # Starting XP reward per enemy defeated
const XP_LEVEL_MULTIPLIER = 10       # Extra XP per enemy level
                                      # Formula: (BASE + enemy_level × MULTIPLIER) × enemy_count
                                      # Example: Defeat 3 level-5 enemies = (50 + 5×10) × 3 = 300 XP
                                      # Effect: Level 1 enemy = 60 XP, Level 10 enemy = 150 XP
                                      # Why? Rewards scale with difficulty to prevent grinding weak enemies

const GOLD_BASE_PER_ENEMY = 20       # Starting gold reward per enemy defeated
const GOLD_LEVEL_MULTIPLIER = 5      # Extra gold per enemy level
                                      # Formula: (BASE + enemy_level × MULTIPLIER) × enemy_count
                                      # Example: Defeat 3 level-5 enemies = (20 + 5×5) × 3 = 135 gold
                                      # Effect: Level 1 enemy = 25 gold, Level 10 enemy = 70 gold
                                      # Why? Gold scales slower than XP (5 vs 10) to control economy
