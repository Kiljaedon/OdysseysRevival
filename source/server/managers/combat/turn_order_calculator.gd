extends Node
class_name TurnOrderCalculator

## Turn Order Calculator - Phase 1 Step 1.2 Refactoring
## Extracts turn order calculation logic from CombatManager
## Pure utility class for calculating initiative order based on DEX stat


static func calculate_turn_order(player: Dictionary, ally_squad: Array, enemy_squad: Array) -> Array:
	## Calculate turn order for all combatants sorted by DEX (highest first)
	## Returns array of turn order entries: {type, squad_index, name, dex}
	var turn_order = []

	# Add player as index 0
	turn_order.append({
		"type": "player",
		"squad_index": 0,
		"name": player.get("name", "Player"),
		"dex": player.get("stats", {}).get("DEX", 10)
	})

	# Add allies
	for i in range(ally_squad.size()):
		var ally = ally_squad[i]
		turn_order.append({
			"type": "ally",
			"squad_index": i,
			"name": ally.get("name", "Ally"),
			"dex": ally.get("stats", {}).get("DEX", 10)
		})

	# Add enemies
	for i in range(enemy_squad.size()):
		var enemy = enemy_squad[i]
		turn_order.append({
			"type": "enemy",
			"squad_index": i,
			"name": enemy.get("name", "Enemy"),
			"dex": enemy.get("stats", {}).get("DEX", 10)
		})

	# Sort by DEX (highest first)
	turn_order.sort_custom(func(a, b): return a.dex > b.dex)

	return turn_order
