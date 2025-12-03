class_name ElementalSystem
extends RefCounted

## Elemental System
## Defines the core elemental relationships (weaknesses and resistances).
## Extracted from the legacy SharedBattleCalculator.

## ========== ELEMENTAL CHART ==========
# 0: Neutral, 1: Venus (Earth), 2: Mercury (Water), 3: Mars (Fire), 4: Jupiter (Wind)
# Values > 1.0 mean the attacker deals MORE damage (Weakness)
# Values < 1.0 mean the attacker deals LESS damage (Resistance)
const ELEMENT_MODIFIERS = {
	"Venus":   {"Venus": 1.0, "Mercury": 1.2, "Mars": 0.8, "Jupiter": 1.0},
	"Mercury": {"Venus": 0.8, "Mercury": 1.0, "Mars": 1.2, "Jupiter": 1.0},
	"Mars":    {"Venus": 1.0, "Mercury": 0.8, "Mars": 1.0, "Jupiter": 1.2},
	"Jupiter": {"Venus": 1.2, "Mercury": 1.0, "Mars": 0.8, "Jupiter": 1.0}
}

static func get_elemental_modifier(attacker_element: String, defender_element: String) -> float:
	if not ELEMENT_MODIFIERS.has(attacker_element):
		return 1.0
	if not ELEMENT_MODIFIERS[attacker_element].has(defender_element):
		return 1.0
	return ELEMENT_MODIFIERS[attacker_element][defender_element]

static func calculate_elemental_damage_modifier(
	power: float,
	attacker_element_power: float,
	defender_element_resist: float
) -> float:
	# Legacy formula: Base + (Power * (1 + (ElemPwr - ElemRes)/200))
	# Returns the MULTIPLIER to be applied to base damage
	return 1.0 + ((attacker_element_power - defender_element_resist) / 200.0)
