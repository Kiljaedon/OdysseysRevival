## Server Map Manager - Map Collision Loading and Management
## Handles server-side collision world for movement validation
## Also tracks player locations across maps for transitions
extends Node
class_name ServerMapManager

var server_world: Node  # Reference to ServerWorld
var collision_world: Node2D  # Server-side collision shapes

# Player tracking across maps
var player_maps: Dictionary = {}  # player_id -> map_name
var map_players: Dictionary = {}  # map_name -> Array[player_id]
var player_positions: Dictionary = {}  # player_id -> Vector2

# Transition zones per map (loaded from TMX)
var map_transitions: Dictionary = {}  # map_name -> Array[{rect, target_map, spawn_x, spawn_y, direction}]

# Available maps
var available_maps: Array[String] = []

# Collision tiles per map (middle layer tiles that block movement)
# map_name -> Dictionary of blocked tile positions: { Vector2i: true }
var map_collision_tiles: Dictionary = {}

# Map dimensions per map
# map_name -> { width: int, height: int, tile_width: int, tile_height: int }
var map_dimensions: Dictionary = {}

# Tile scale (32px base * 4x scale = 128px)
const TILE_SCALE: int = 4
const TILE_SIZE_BASE: int = 32
const TILE_SIZE_SCALED: int = TILE_SIZE_BASE * TILE_SCALE  # 128px


func initialize(server_ref: Node, collision_world_ref: Node2D):
	"""Initialize map manager with server and collision world references"""
	server_world = server_ref
	collision_world = collision_world_ref

	# Scan for available maps
	_scan_available_maps()

	print("[ServerMapManager] Initialized with %d available maps" % available_maps.size())


func _scan_available_maps():
	"""Scan the maps directory for available TMX files"""
	available_maps.clear()
	var maps_dir = "res://maps/"
	var dir = DirAccess.open(maps_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tmx"):
				available_maps.append(file_name.get_basename())
			file_name = dir.get_next()
		dir.list_dir_end()
	print("[ServerMapManager] Found maps: ", available_maps)


# ========== MAP COLLISION LOADING (Server-Side Validation) ==========

func load_map_collision(map_path: String):
	"""Load collision objects from TMX file for server-side validation"""
	server_world.log_message("[COLLISION] Loading map collision from: %s" % map_path)

	# Clear existing collision objects
	if collision_world:
		for child in collision_world.get_children():
			child.queue_free()

	# Read TMX file
	var file = FileAccess.open(map_path, FileAccess.READ)
	if not file:
		server_world.log_message("[COLLISION] ERROR: Failed to load map file: %s" % map_path)
		return

	var tmx_content = file.get_as_text()
	file.close()

	# Parse tile dimensions
	var map_regex = RegEx.new()
	map_regex.compile('<map[^>]*tilewidth="([^"]*)"[^>]*tileheight="([^"]*)"')
	var map_match = map_regex.search(tmx_content)

	if not map_match:
		server_world.log_message("[COLLISION] ERROR: Could not parse map dimensions")
		return

	var tile_width = map_match.get_string(1).to_int()
	var tile_height = map_match.get_string(2).to_int()

	# Find objectgroup with "collision" in the name (case-insensitive)
	var group_regex = RegEx.new()
	group_regex.compile('<objectgroup[^>]*name="[^"]*[Cc]ollision[^"]*"[^>]*>(.*?)</objectgroup>')
	var group_matches = group_regex.search_all(tmx_content)

	var total_objects = 0
	for group_match in group_matches:
		var group_content = group_match.get_string(1)
		var objects_created = load_collision_objects(group_content, tile_width, tile_height)
		total_objects += objects_created

	server_world.log_message("[COLLISION] Loaded %d collision objects from map" % total_objects)

	# Also parse Middle layer tiles for collision
	_parse_middle_layer_collision(tmx_content, map_path.get_file().get_basename())


func load_collision_objects(objectgroup_content: String, tile_width: int, tile_height: int) -> int:
	"""Parse collision rectangles from objectgroup and create StaticBody2D shapes"""
	# Parse object elements: <object x="224" y="192" width="64" height="32"/>
	var object_regex = RegEx.new()
	object_regex.compile('<object[^>]*x="([^"]*)"[^>]*y="([^"]*)"[^>]*width="([^"]*)"[^>]*height="([^"]*)"')
	var object_results = object_regex.search_all(objectgroup_content)

	var objects_created = 0
	for object_result in object_results:
		var obj_x = object_result.get_string(1).to_float()
		var obj_y = object_result.get_string(2).to_float()
		var obj_width = object_result.get_string(3).to_float()
		var obj_height = object_result.get_string(4).to_float()

		# Account for 4x tile scale (same as client)
		obj_x *= 4
		obj_y *= 4
		obj_width *= 4
		obj_height *= 4

		# Create StaticBody2D for collision validation
		var collision_body = StaticBody2D.new()
		collision_body.name = "ServerCollision_" + str(objects_created)
		collision_body.collision_layer = 1
		collision_body.collision_mask = 0

		# Position at center of rectangle
		collision_body.position = Vector2(obj_x + obj_width / 2, obj_y + obj_height / 2)

		# Create collision shape
		var collision_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(obj_width, obj_height)
		collision_shape.shape = rect_shape

		collision_body.add_child(collision_shape)
		collision_world.add_child(collision_body)

		objects_created += 1

	return objects_created


# ========== MIDDLE LAYER COLLISION PARSING ==========

func _parse_middle_layer_collision(tmx_content: String, map_name: String):
	"""Parse Middle layer tiles from TMX to identify collision tiles"""

	# Parse map dimensions
	var map_regex = RegEx.new()
	map_regex.compile('width="(\\d+)"\\s+height="(\\d+)"\\s+tilewidth="(\\d+)"\\s+tileheight="(\\d+)"')
	var map_result = map_regex.search(tmx_content)

	if not map_result:
		return

	var map_width = map_result.get_string(1).to_int()
	var map_height = map_result.get_string(2).to_int()
	var tile_width = map_result.get_string(3).to_int()
	var tile_height = map_result.get_string(4).to_int()

	# Store map dimensions
	map_dimensions[map_name] = {
		"width": map_width,
		"height": map_height,
		"tile_width": tile_width,
		"tile_height": tile_height
	}

	# Find Middle layer (contains collision tiles)
	var layer_regex = RegEx.new()
	layer_regex.compile('<layer[^>]*name="([^"]*[Mm]iddle[^"]*)"[^>]*>[\\s\\S]*?<data encoding="csv">([\\s\\S]*?)</data>[\\s\\S]*?</layer>')
	var layer_result = layer_regex.search(tmx_content)

	if not layer_result:
		map_collision_tiles[map_name] = {}
		return

	var csv_data = layer_result.get_string(2).strip_edges()

	# Parse CSV to find non-empty tiles
	csv_data = csv_data.replace("\n", "").replace("\r", "")
	var tile_ids = csv_data.split(",")

	var collision_tiles = {}
	var tile_index = 0
	var blocked_count = 0

	for y in range(map_height):
		for x in range(map_width):
			if tile_index < tile_ids.size():
				var tile_id = tile_ids[tile_index].strip_edges().to_int()
				# If tile is not empty (0), it's a collision tile
				if tile_id > 0:
					collision_tiles[Vector2i(x, y)] = true
					blocked_count += 1
			tile_index += 1

	map_collision_tiles[map_name] = collision_tiles


# Cached collision data for fast lookups (avoids dictionary lookup every frame)
var _cached_collision_map: String = ""
var _cached_collision_tiles: Dictionary = {}

func is_tile_blocked(map_name: String, tile_x: int, tile_y: int) -> bool:
	"""Check if a tile position is blocked by middle layer collision"""
	# Use cached reference if same map
	if map_name != _cached_collision_map:
		if not map_collision_tiles.has(map_name):
			load_map_collision_tiles(map_name)
		_cached_collision_map = map_name
		_cached_collision_tiles = map_collision_tiles.get(map_name, {})

	return _cached_collision_tiles.has(Vector2i(tile_x, tile_y))


func is_position_blocked(map_name: String, position: Vector2) -> bool:
	"""Check if a world position is blocked (converts to tile coords)"""
	# Inline the division for speed (avoid function call overhead)
	return is_tile_blocked(map_name, int(position.x) >> 7, int(position.y) >> 7)  # >> 7 = divide by 128


func load_map_collision_tiles(map_name: String):
	"""Load collision tiles for a specific map"""
	var map_path = "res://maps/" + map_name + ".tmx"
	var file = FileAccess.open(map_path, FileAccess.READ)
	if not file:
		map_collision_tiles[map_name] = {}
		return

	var tmx_content = file.get_as_text()
	file.close()
	_parse_middle_layer_collision(tmx_content, map_name)


func find_nearest_free_spawn(map_name: String, position: Vector2, max_search_radius: int = 10) -> Vector2:
	"""Find the nearest non-blocked tile position from a given position
	Returns the position if it's already free, or searches in a spiral pattern for the nearest free tile"""

	# First check if we have collision data
	if not map_collision_tiles.has(map_name):
		load_map_collision_tiles(map_name)

	# Convert world position to tile coordinates
	var center_tile_x = int(position.x / TILE_SIZE_SCALED)
	var center_tile_y = int(position.y / TILE_SIZE_SCALED)

	# Check if current position is already free
	if not is_tile_blocked(map_name, center_tile_x, center_tile_y):
		return position  # Already in a free spot

	# Get map dimensions
	var dims = map_dimensions.get(map_name, {"width": 20, "height": 15})
	var map_width = dims.width
	var map_height = dims.height

	# Search in expanding squares (spiral pattern)
	for radius in range(1, max_search_radius + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				# Only check tiles on the edge of this square
				if abs(dx) != radius and abs(dy) != radius:
					continue

				var check_x = center_tile_x + dx
				var check_y = center_tile_y + dy

				# Skip out of bounds
				if check_x < 1 or check_x >= map_width - 1:
					continue
				if check_y < 1 or check_y >= map_height - 1:
					continue

				# Check if this tile is free
				if not is_tile_blocked(map_name, check_x, check_y):
					# Convert tile back to world position (center of tile)
					return Vector2(
						check_x * TILE_SIZE_SCALED + TILE_SIZE_SCALED / 2,
						check_y * TILE_SIZE_SCALED + TILE_SIZE_SCALED / 2
					)

	# Fallback: return original position if no free spot found
	return position


# ========== PLAYER MAP TRACKING ==========

func add_player_to_map(player_id: int, map_name: String, position: Vector2 = Vector2.ZERO):
	"""Add a player to a specific map"""
	# Remove from old map if they were on one
	if player_maps.has(player_id):
		var old_map = player_maps[player_id]
		if map_players.has(old_map):
			map_players[old_map].erase(player_id)

	# Add to new map
	player_maps[player_id] = map_name
	player_positions[player_id] = position

	if not map_players.has(map_name):
		map_players[map_name] = []
	if player_id not in map_players[map_name]:
		map_players[map_name].append(player_id)

	print("[ServerMapManager] Player %d added to map '%s' at %s" % [player_id, map_name, position])


func remove_player(player_id: int):
	"""Remove a player from tracking (disconnect)"""
	if player_maps.has(player_id):
		var old_map = player_maps[player_id]
		if map_players.has(old_map):
			map_players[old_map].erase(player_id)
		player_maps.erase(player_id)

	player_positions.erase(player_id)
	print("[ServerMapManager] Player %d removed from tracking" % player_id)


func update_player_position(player_id: int, position: Vector2):
	"""Update a player's position"""
	player_positions[player_id] = position


func get_player_map(player_id: int) -> String:
	"""Get which map a player is on"""
	return player_maps.get(player_id, "")


func get_players_on_map(map_name: String) -> Array:
	"""Get all player IDs on a specific map"""
	return map_players.get(map_name, [])


func get_player_position(player_id: int) -> Vector2:
	"""Get a player's current position"""
	return player_positions.get(player_id, Vector2.ZERO)


# ========== MAP TRANSITION VALIDATION ==========

func load_map_transitions(map_name: String):
	"""Load transition zones from a map's TMX file"""
	var map_path = "res://maps/" + map_name + ".tmx"
	var file = FileAccess.open(map_path, FileAccess.READ)
	if not file:
		print("[ServerMapManager] Could not load transitions from: %s" % map_path)
		return

	var tmx_content = file.get_as_text()
	file.close()

	var transitions = []

	# Find Transitions objectgroup
	var objectgroup_regex = RegEx.new()
	objectgroup_regex.compile('<objectgroup[^>]*name="[Tt]ransitions?"[^>]*>([\\s\\S]*?)</objectgroup>')
	var objectgroup_result = objectgroup_regex.search(tmx_content)

	if not objectgroup_result:
		map_transitions[map_name] = []
		return

	var group_content = objectgroup_result.get_string(1)

	# Parse objects with properties
	var object_regex = RegEx.new()
	object_regex.compile('<object[^>]*x="([\\d.]+)"[^>]*y="([\\d.]+)"[^>]*width="([\\d.]+)"[^>]*height="([\\d.]+)"[^>]*>([\\s\\S]*?)</object>')
	var object_results = object_regex.search_all(group_content)

	for obj_result in object_results:
		var obj_x = obj_result.get_string(1).to_float() * 4  # Scale by 4x
		var obj_y = obj_result.get_string(2).to_float() * 4
		var obj_width = obj_result.get_string(3).to_float() * 4
		var obj_height = obj_result.get_string(4).to_float() * 4
		var obj_content = obj_result.get_string(5)

		# Parse properties
		var target_map = _parse_property(obj_content, "target_map")
		var spawn_x = _parse_property(obj_content, "spawn_x").to_int()
		var spawn_y = _parse_property(obj_content, "spawn_y").to_int()
		var direction = _parse_property(obj_content, "direction").to_lower()

		if target_map != "" and direction != "":
			transitions.append({
				"rect": Rect2(obj_x, obj_y, obj_width, obj_height),
				"target_map": target_map,
				"spawn_x": spawn_x,
				"spawn_y": spawn_y,
				"direction": direction
			})

	map_transitions[map_name] = transitions
	print("[ServerMapManager] Loaded %d transitions for map '%s'" % [transitions.size(), map_name])


func _parse_property(content: String, prop_name: String) -> String:
	"""Parse a property value from object content"""
	var prop_regex = RegEx.new()
	prop_regex.compile('<property\\s+name="' + prop_name + '"[^>]*value="([^"]*)"')
	var result = prop_regex.search(content)
	if result:
		return result.get_string(1)
	return ""


func validate_transition(player_id: int, target_map: String, spawn_x: int, spawn_y: int) -> Dictionary:
	"""Validate if a player can transition to a target map
	Returns: { valid: bool, reason: String }"""

	# Check if target map exists
	if target_map.get_basename() not in available_maps and target_map not in available_maps:
		return {"valid": false, "reason": "Map does not exist"}

	# Check if player is tracked
	if not player_maps.has(player_id):
		return {"valid": false, "reason": "Player not on any map"}

	var current_map = player_maps[player_id]
	var player_pos = player_positions.get(player_id, Vector2.ZERO)

	# Load transitions for current map if not already loaded
	if not map_transitions.has(current_map):
		load_map_transitions(current_map)

	# Check if player is in a valid transition zone
	var transitions = map_transitions.get(current_map, [])
	for transition in transitions:
		if transition.rect.has_point(player_pos):
			# Remove .tmx extension for comparison if present
			var transition_target = transition.target_map.get_basename()
			var request_target = target_map.get_basename()
			if transition_target == request_target:
				return {"valid": true, "reason": ""}

	return {"valid": false, "reason": "Not in a valid transition zone"}


func process_map_transition(player_id: int, target_map: String, spawn_x: int, spawn_y: int) -> Dictionary:
	"""Process a map transition request
	Returns: { success: bool, old_map: String, new_map: String, players_on_new_map: Array }"""

	var validation = validate_transition(player_id, target_map, spawn_x, spawn_y)
	if not validation.valid:
		return {"success": false, "reason": validation.reason}

	var old_map = player_maps[player_id]
	var new_map = target_map.get_basename()

	# Calculate spawn position in pixels (tile coords * 32 * 4 scale)
	var spawn_pos = Vector2(spawn_x * 32 * 4, spawn_y * 32 * 4)

	# Get other players on old map (to notify them)
	var old_map_players = get_players_on_map(old_map).duplicate()
	old_map_players.erase(player_id)

	# Move player to new map
	add_player_to_map(player_id, new_map, spawn_pos)

	# Load transitions for new map
	if not map_transitions.has(new_map):
		load_map_transitions(new_map)

	# Get players already on new map (excluding the transitioning player)
	var new_map_players = get_players_on_map(new_map).duplicate()
	new_map_players.erase(player_id)

	# Build player info for response
	var players_info = []
	for pid in new_map_players:
		var pos = player_positions.get(pid, Vector2.ZERO)
		players_info.append({
			"player_id": pid,
			"x": int(pos.x),
			"y": int(pos.y)
		})

	return {
		"success": true,
		"old_map": old_map,
		"new_map": new_map,
		"spawn_x": spawn_x,
		"spawn_y": spawn_y,
		"old_map_players": old_map_players,
		"new_map_players": new_map_players,
		"players_info": players_info
	}
