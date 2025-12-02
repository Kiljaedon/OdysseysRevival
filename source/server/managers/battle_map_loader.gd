extends Node
## Battle Spawn Generator - Generates spawn positions for battle instances
## Uses the WORLD MAP as the battle arena (no separate battle maps needed)
##
## Spawn rules:
##   - Aggressor (who attacked first) spawns at BOTTOM, facing up
##   - Defender spawns at TOP, facing down
##   - Allies spawn in a group near their leader
##   - Good vertical gap between teams (6+ tiles minimum)

class_name BattleMapLoader

## Constants
const TILE_SIZE_BASE: int = 32
const TILE_SCALE: int = 4
const TILE_SIZE_SCALED: int = TILE_SIZE_BASE * TILE_SCALE  # 128px

const WORLD_MAPS_PATH: String = "res://maps/World Maps/"

## Spawn zone configuration
const EDGE_MARGIN: float = 256.0  # 2 tiles from edge
const TEAM_GAP_TILES: int = 6  # Minimum 6 tiles between teams vertically
const TEAM_GAP: float = TEAM_GAP_TILES * TILE_SIZE_SCALED  # 768px gap

## Ally grouping - how close allies spawn to each other
const ALLY_SPREAD_X: float = 192.0  # ~1.5 tiles horizontal spread
const ALLY_SPREAD_Y: float = 128.0  # 1 tile vertical spread

## Cached map dimensions
var map_dimensions: Dictionary = {}  # map_name -> {width, height}


func _ready() -> void:
	print("[BattleMapLoader] Initialized - Dynamic spawn generation enabled")


## ========== PUBLIC API ==========

func generate_battle_spawns(world_map_name: String, ally_count: int, enemy_count: int, player_is_aggressor: bool) -> Dictionary:
	"""Generate spawn positions for a battle on the given world map.

	Args:
		world_map_name: The map where battle takes place
		ally_count: Number of player + mercenaries (1-4)
		enemy_count: Number of enemies (1-3)
		player_is_aggressor: True if player attacked first (gets bottom position)

	Returns: {
		ally_spawns: Array[Vector2],
		enemy_spawns: Array[Vector2],
		ally_facing: String,
		enemy_facing: String,
		map_bounds: {width, height}
	}
	"""
	var bounds = get_map_bounds(world_map_name)

	# Determine zones based on who attacked first
	var bottom_zone: Dictionary
	var top_zone: Dictionary
	_calculate_spawn_zones(bounds, bottom_zone, top_zone)

	var ally_zone: Dictionary
	var enemy_zone: Dictionary
	var ally_facing: String
	var enemy_facing: String

	if player_is_aggressor:
		# Player attacked first - allies at bottom, enemies at top
		ally_zone = bottom_zone
		enemy_zone = top_zone
		ally_facing = "up"
		enemy_facing = "down"
	else:
		# NPC attacked first - enemies at bottom, allies at top
		ally_zone = top_zone
		enemy_zone = bottom_zone
		ally_facing = "down"
		enemy_facing = "up"

	# Generate randomized positions within zones
	var ally_spawns = _generate_team_spawns(ally_zone, ally_count, bounds)
	var enemy_spawns = _generate_team_spawns(enemy_zone, enemy_count, bounds)

	print("[BattleMapLoader] Generated battle spawns for %s" % world_map_name)
	print("[BattleMapLoader]   Player aggressor: %s" % player_is_aggressor)
	print("[BattleMapLoader]   Allies (%d): %s facing %s" % [ally_count, ally_spawns, ally_facing])
	print("[BattleMapLoader]   Enemies (%d): %s facing %s" % [enemy_count, enemy_spawns, enemy_facing])

	return {
		"ally_spawns": ally_spawns,
		"enemy_spawns": enemy_spawns,
		"ally_facing": ally_facing,
		"enemy_facing": enemy_facing,
		"map_bounds": bounds
	}


func get_map_bounds(world_map_name: String) -> Dictionary:
	"""Get the dimensions of a world map"""
	if map_dimensions.has(world_map_name):
		return map_dimensions[world_map_name]

	# Try to load from TMX
	var bounds = _load_map_dimensions(world_map_name)
	map_dimensions[world_map_name] = bounds
	return bounds


## ========== LEGACY API (for compatibility) ==========

func get_spawn_points(world_map_name: String) -> Dictionary:
	"""Legacy API - generates default spawns (player as aggressor, 1v1)"""
	var spawns = generate_battle_spawns(world_map_name, 1, 1, true)
	return {
		"player_spawn": spawns.ally_spawns[0] if spawns.ally_spawns.size() > 0 else Vector2(1280, 1600),
		"enemy_spawns": spawns.enemy_spawns,
		"player_facing": spawns.ally_facing,
		"enemy_facings": _fill_array(spawns.enemy_facing, spawns.enemy_spawns.size()),
		"map_bounds": spawns.map_bounds
	}


## ========== SPAWN ZONE CALCULATION ==========

func _calculate_spawn_zones(bounds: Dictionary, bottom_zone: Dictionary, top_zone: Dictionary) -> void:
	"""Calculate the top and bottom spawn zones with proper gap"""
	var map_width = bounds.width
	var map_height = bounds.height

	# Usable area (excluding margins)
	var usable_left = EDGE_MARGIN
	var usable_right = map_width - EDGE_MARGIN
	var usable_top = EDGE_MARGIN
	var usable_bottom = map_height - EDGE_MARGIN

	# Calculate zone heights - divide remaining space after gap
	var usable_height = usable_bottom - usable_top - TEAM_GAP
	var zone_height = usable_height / 2.0

	# Bottom zone (lower 40% of usable area)
	bottom_zone["x_min"] = usable_left
	bottom_zone["x_max"] = usable_right
	bottom_zone["y_min"] = usable_bottom - zone_height
	bottom_zone["y_max"] = usable_bottom

	# Top zone (upper 40% of usable area)
	top_zone["x_min"] = usable_left
	top_zone["x_max"] = usable_right
	top_zone["y_min"] = usable_top
	top_zone["y_max"] = usable_top + zone_height


func _generate_team_spawns(zone: Dictionary, count: int, bounds: Dictionary) -> Array:
	"""Generate grouped spawn positions for a team within a zone"""
	var spawns: Array = []

	if count <= 0:
		return spawns

	# Calculate center of zone for the leader
	var zone_center_x = (zone.x_min + zone.x_max) / 2.0
	var zone_center_y = (zone.y_min + zone.y_max) / 2.0

	# Add some randomization to center (within middle 50% of zone)
	var x_range = (zone.x_max - zone.x_min) * 0.25
	var y_range = (zone.y_max - zone.y_min) * 0.25

	var leader_x = zone_center_x + randf_range(-x_range, x_range)
	var leader_y = zone_center_y + randf_range(-y_range, y_range)

	# Leader spawn (player or captain)
	spawns.append(Vector2(leader_x, leader_y))

	# Generate ally/minion spawns near leader
	for i in range(1, count):
		var offset_x = randf_range(-ALLY_SPREAD_X, ALLY_SPREAD_X)
		var offset_y = randf_range(-ALLY_SPREAD_Y, ALLY_SPREAD_Y)

		# Spread allies in a loose formation
		match i:
			1:  # First ally - to the left
				offset_x = -ALLY_SPREAD_X + randf_range(-32, 32)
			2:  # Second ally - to the right
				offset_x = ALLY_SPREAD_X + randf_range(-32, 32)
			3:  # Third ally - behind center
				offset_x = randf_range(-64, 64)
				offset_y = ALLY_SPREAD_Y + randf_range(0, 64)

		var ally_x = clamp(leader_x + offset_x, zone.x_min, zone.x_max)
		var ally_y = clamp(leader_y + offset_y, zone.y_min, zone.y_max)

		spawns.append(Vector2(ally_x, ally_y))

	return spawns


## ========== MAP LOADING ==========

func _load_map_dimensions(world_map_name: String) -> Dictionary:
	"""Load map dimensions from world map TMX"""
	var tmx_path = WORLD_MAPS_PATH + world_map_name + ".tmx"
	var bounds = {"width": 2560, "height": 1920}  # Default 20x15 tiles

	var file = FileAccess.open(tmx_path, FileAccess.READ)
	if not file:
		print("[BattleMapLoader] Cannot read map %s, using defaults" % tmx_path)
		return bounds

	var xml_content = file.get_as_text()
	file.close()

	# Parse dimensions from TMX
	var map_regex = RegEx.new()
	map_regex.compile('<map[^>]*width="(\\d+)"[^>]*height="(\\d+)"')
	var match = map_regex.search(xml_content)

	if match:
		var tile_width = int(match.get_string(1))
		var tile_height = int(match.get_string(2))
		bounds.width = tile_width * TILE_SIZE_SCALED
		bounds.height = tile_height * TILE_SIZE_SCALED
		print("[BattleMapLoader] Loaded map bounds: %dx%d (%dx%d tiles)" % [bounds.width, bounds.height, tile_width, tile_height])

	return bounds


## ========== UTILITY ==========

func _fill_array(value: String, count: int) -> Array:
	"""Create an array filled with the same value"""
	var arr: Array = []
	for i in range(count):
		arr.append(value)
	return arr


func clear_cache() -> void:
	"""Clear cached map dimensions"""
	map_dimensions.clear()
	print("[BattleMapLoader] Cache cleared")
