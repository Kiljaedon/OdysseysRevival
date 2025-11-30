class_name NPC_AI_Controller
extends RefCounted

## NPC AI Controller - Decisions logic for enemies
## Stateless logic: Input (Combat State) -> Output (Action)

## ========== PUBLIC API ==========

static func process_turn(combat: Dictionary, npc_unit: Dictionary, server_battle_manager) -> Dictionary:
	"""
	Decide the best action for this NPC.
	Returns a dictionary describing the action:
	{
		"action": "attack" | "defend" | "skill",
		"target_index": int,
		"skill_name": String (optional)
	}
	"""
	var archetype = npc_unit.get("ai_archetype", "AGGRESSIVE")
	var alive_enemies = _get_alive_enemies(combat) # From NPC perspective, "enemies" are the players/allies
	
	if alive_enemies.is_empty():
		return {"action": "defend", "target_index": -1} # No targets

	match archetype:
		"AGGRESSIVE":
			return _ai_aggressive(npc_unit, alive_enemies)
		"DEFENSIVE":
			return _ai_defensive(npc_unit, alive_enemies)
		"TACTICAL":
			return _ai_tactical(npc_unit, alive_enemies)
		"CHAOTIC":
			return _ai_chaotic(npc_unit, alive_enemies)
		_:
			return _ai_aggressive(npc_unit, alive_enemies) # Default

## ========== ARCHETYPE LOGIC ==========

static func _ai_aggressive(npc: Dictionary, targets: Array) -> Dictionary:
	"""AGGRESSIVE: Attacks the target with the lowest HP to secure a kill."""
	var best_target = targets[0]
	var lowest_hp = 99999

	for target in targets:
		var hp = target.get("hp", 100)
		if hp < lowest_hp:
			lowest_hp = hp
			best_target = target
	
	# TODO: Check if we have a high damage skill and MP to use it
	
	return {
		"action": "attack",
		"target_index": _get_squad_index(best_target)
	}

static func _ai_defensive(npc: Dictionary, targets: Array) -> Dictionary:
	"""DEFENSIVE: Defends if HP is low (< 40%), otherwise attacks random."""
	var hp = npc.get("hp", 100)
	var max_hp = npc.get("max_hp", 100)
	
	if float(hp) / float(max_hp) < 0.4:
		return {"action": "defend", "target_index": -1}
	
	var random_target = targets.pick_random()
	return {
		"action": "attack",
		"target_index": _get_squad_index(random_target)
	}

static func _ai_tactical(npc: Dictionary, targets: Array) -> Dictionary:
	"""TACTICAL: Prioritizes Casters/Healers (Back Row) -> Weakest."""
	
	# Filter for casters/healers (Back Row / Low Defense)
	var high_priority = []
	for target in targets:
		# TODO: Check combat_role if available in combat data
		# For now, assume back row (index 2,3,4,5 for 6-man squad) are priority
		var idx = _get_squad_index(target)
		if idx >= 2: # Back row logic
			high_priority.append(target)
	
	if not high_priority.is_empty():
		return _ai_aggressive(npc, high_priority) # Focus weakest high-priority target
	
	return _ai_aggressive(npc, targets)

static func _ai_chaotic(npc: Dictionary, targets: Array) -> Dictionary:
	"""CHAOTIC: Completely random target. 50% chance to use skill (if implemented)."""
	var random_target = targets.pick_random()
	
	# TODO: 50% chance to use random skill
	
	return {
		"action": "attack",
		"target_index": _get_squad_index(random_target)
	}

## ========== HELPERS ==========

static func _get_alive_enemies(combat: Dictionary) -> Array:
	"""Get list of living units on the OPPOSING team (The Player's team)"""
	var allies = combat.get("ally_squad", []) # The player's team
	var alive = []
	for unit in allies:
		if unit.get("hp", 0) > 0:
			alive.append(unit)
	return alive

static func _get_squad_index(unit: Dictionary) -> int:
	"""Helper to find the original index of a unit in its squad array"""
	# This relies on the unit dictionary having a reference or ID, 
	# but since we're dealing with copies in some places, we might need to search by identity.
	# For now, we assume 'unit' is the object from the array.
	# In a real implementation, we'd pass the full array and find index.
	
	# Hack: We need the index relative to the ally_squad array.
	# Ideally, the unit dict should know its index.
	# Let's assume unit has 'squad_index' if we built it correctly, or we infer it.
	if unit.has("squad_index"):
		return unit.squad_index
		
	# Fallback: We can't easily determine index without the full array context.
	# For Phase 2, we'll default to 0 (Player) if not found.
	return 0 
