extends Node
## Global debug configuration
## Set these flags to control debug output throughout the game

# Master debug flag - set to false to disable ALL debug prints
const DEBUG_ENABLED: bool = true

# Specific debug categories
const DEBUG_NETWORK: bool = true      # Network packets, connections
const DEBUG_COMBAT: bool = true       # Combat triggers, damage calculation
const DEBUG_MOVEMENT: bool = false    # Player/NPC movement updates (VERY SPAMMY)
const DEBUG_SPAWN: bool = true        # Entity spawning/despawning
const DEBUG_INPUT: bool = false       # Input processing (VERY SPAMMY)
const DEBUG_UI: bool = false          # UI state changes
const DEBUG_AUTH: bool = true         # Login, account creation
const DEBUG_DATABASE: bool = true     # Database operations
const DEBUG_NPC: bool = false         # NPC AI behavior (SPAMMY)
const DEBUG_SPATIAL: bool = false     # Spatial/interest management (SPAMMY)

## Helper function to check if debug output is enabled for a category
static func is_enabled(category: String) -> bool:
	if not DEBUG_ENABLED:
		return false

	match category:
		"network": return DEBUG_NETWORK
		"combat": return DEBUG_COMBAT
		"movement": return DEBUG_MOVEMENT
		"spawn": return DEBUG_SPAWN
		"input": return DEBUG_INPUT
		"ui": return DEBUG_UI
		"auth": return DEBUG_AUTH
		"database": return DEBUG_DATABASE
		"npc": return DEBUG_NPC
		"spatial": return DEBUG_SPATIAL
		_: return true  # Unknown categories default to enabled

## Helper print functions (use these instead of direct print())
static func debug_print(category: String, message: String) -> void:
	if is_enabled(category):
		print("[%s] %s" % [category.to_upper(), message])

static func debug_print_verbose(category: String, message: String) -> void:
	# Only prints if both DEBUG_ENABLED and category are true
	if DEBUG_ENABLED and is_enabled(category):
		print("[%s] %s" % [category.to_upper(), message])
