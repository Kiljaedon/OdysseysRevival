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

# World maps (overworld exploration) - also used as battle arenas
var world_maps: Array[String] = []
var world_map_paths: Dictionary = {}  # map_name -> "World Maps/map_name.tmx"

# Combined available maps (for backwards compatibility)
var available_maps: Array[String] = []
var map_paths: Dictionary = {}

# Active battle instances
# instance_id -> { map_name, players: [], npcs: [], created_at }
var battle_instances: Dictionary = {}
var next_instance_id: int = 1

# Player to battle instance mapping
var player_battle_instance: Dictionary = {}  # player_id -> instance_id

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
	"""Scan World Maps directory (world maps are also used as battle arenas)"""
	world_maps.clear()
	world_map_paths.clear()
	available_maps.clear()
	map_paths.clear()

	# Scan World Maps - these serve as both exploration maps AND battle arenas
	_scan_map_folder("res://maps/World Maps/", world_maps, world_map_paths)

	# Build combined lists for backwards compatibility
	for map_name in world_maps:
		available_maps.append(map_name)
		map_paths[map_name] = world_map_paths[map_name]

	print("[ServerMapManager] Available maps: ", world_maps)


func _scan_map_folder(path: String, map_list: Array[String], path_dict: Dictionary):
	"""Scan a specific map folder for TMX files"""
	var dir = DirAccess.open(path)
	if not dir:
		print("[ServerMapManager] Could not open: %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tmx"):
			var map_name = file_name.get_basename()
			var relative_path = path.replace("res://maps/", "") + file_name
			map_list.append(map_name)
			path_dict[map_name] = relative_path
		file_name = dir.get_next()
	dir.list_dir_end()


func get_map_path(map_name: String) -> String:
	"""Get the full path for a world map by name"""
	if world_map_paths.has(map_name):
		return "res://maps/" + world_map_paths[map_name]
	# Fallback
	return "res://maps/World Maps/" + map_name + ".tmx"


func get_battle_map_path(map_name: String) -> String:
	"""Get the full path for a battle map (same as world map - we use world maps as arenas)"""
	return get_map_path(map_name)


# ========== MAP COLLISION LOADING (Server-Side Validation) ========== 

func load_map_collision(map_path: String):
	"""Load collision objects from TMX file for server-side validation"""
	var debug_file = FileAccess.open("user://server_map_debug.txt", FileAccess.WRITE)
	if debug_file: debug_file.store_line("Loading map collision: %s" % map_path)
	
	server_world.log_message("[COLLISION] Loading map collision from: %s" % map_path)

	# Clear existing collision objects
	if collision_world:
		for child in collision_world.get_children():
			child.queue_free()

	# Read TMX file
	var file = FileAccess.open(map_path, FileAccess.READ)
	if not file:
		server_world.log_message("[COLLISION] ERROR: Failed to load map file: %s" % map_path)
		if debug_file: debug_file.store_line("ERROR: File not found")
		return

	var tmx_content = file.get_as_text()
	file.close()
	
	if debug_file: debug_file.store_line("TMX content read: %d bytes" % tmx_content.length())

	# Parse tile dimensions
	var map_regex = RegEx.new()
	map_regex.compile('<map[^>]*tilewidth="([^"]*)"[^>]*tileheight="([^"]*)"')
	var map_match = map_regex.search(tmx_content)

	if not map_match:
		server_world.log_message("[COLLISION] ERROR: Could not parse map dimensions")
		if debug_file: debug_file.store_line("ERROR: Map dimensions parse failed")
		return

	var tile_width = map_match.get_string(1).to_int()
	var tile_height = map_match.get_string(2).to_int()
	
	if debug_file: debug_file.store_line("Map dims: %dx%d tiles" % [tile_width, tile_height])

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
	if debug_file: debug_file.store_line("Collision objects loaded: %d" % total_objects)

	# Also parse Middle layer tiles for collision
	if debug_file: debug_file.store_line("Starting middle layer parsing...")
	_parse_middle_layer_collision(tmx_content, map_path.get_file().get_basename())
	if debug_file: 
		debug_file.store_line("Middle layer parsing complete")
		debug_file.close()


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
	"""Parse collision tiles from TMX - robust version checking for 'Collision' or 'Middle' layers"""
	
	# Initialize collision dictionary immediately
	map_collision_tiles[map_name] = {}
	
	# 1. Parse map dimensions
	var map_width = 20
	var map_height = 15
	
	var dim_regex = RegEx.new()
	dim_regex.compile('width="(\\d+)"\\s+height="(\\d+)"')
	var dim_match = dim_regex.search(tmx_content)
	if dim_match:
		map_width = dim_match.get_string(1).to_int()
		map_height = dim_match.get_string(2).to_int()
		
	# Store map dimensions
	map_dimensions[map_name] = {
		"width": map_width,
		"height": map_height,
		"tile_width": 32,
		"tile_height": 32
	}

	# 2. Find collision tileset GID
	var collision_gid: int = 0
	var tileset_regex = RegEx.new()
	tileset_regex.compile('<tileset[^>]*firstgid="(\\d+)"[^>]*source="[^"]*[Cc]ollision[^"]*"')
	var tileset_result = tileset_regex.search(tmx_content)
	if tileset_result:
		collision_gid = tileset_result.get_string(1).to_int()
	
	# 3. Parse ALL layers using string splitting (safer than complex regex)
	var layer_blocks = tmx_content.split("<layer ")
	
	var collision_tiles = {}
	var blocked_count = 0
	
	for i in range(1, layer_blocks.size()):
		var block = layer_blocks[i]
		
		# Extract layer name
		var is_explicit_collision_layer = false
		if 'name="' in block:
			var name_start = block.find('name="') + 6
			var name_end = block.find('"', name_start)
			if name_start > 5 and name_end > name_start:
				var layer_name = block.substr(name_start, name_end - name_start)
				# Treat 'Middle' layer as collision too, as per requirement
				if "Collision" in layer_name or "collision" in layer_name or "Middle" in layer_name:
					is_explicit_collision_layer = true
		
		# Find CSV data
		var data_start = block.find('<data encoding="csv">')
		if data_start == -1: continue
		
		data_start += 21 # Length of tag
		var data_end = block.find('</data>', data_start)
		if data_end == -1: continue
		
		var csv_data = block.substr(data_start, data_end - data_start).strip_edges()
		csv_data = csv_data.replace("\n", "").replace("\r", "")
		var tile_ids = csv_data.split(",")
		
		var tile_index = 0
		for y in range(map_height):
			for x in range(map_width):
				if tile_index < tile_ids.size():
					var tile_id = tile_ids[tile_index].strip_edges().to_int()
					
					var is_blocked = false
					# If it's an explicit collision/middle layer, ANY tile is blocked
					if is_explicit_collision_layer and tile_id > 0:
						is_blocked = true
					# Or if it matches the specific collision tileset GID
					elif collision_gid > 0 and tile_id >= collision_gid:
						is_blocked = true
						
					if is_blocked:
						if not collision_tiles.has(Vector2i(x, y)):
							collision_tiles[Vector2i(x, y)] = true
							blocked_count += 1
				
				tile_index += 1

	map_collision_tiles[map_name] = collision_tiles
	server_world.log_message("[COLLISION] Parsed %d blocked tiles for %s (Middle layer enabled)" % [blocked_count, map_name])

	# Debug: Show a sample of blocked tiles
	var sample_tiles = []
	var count = 0
	for tile_pos in collision_tiles:
		if count < 5:
			sample_tiles.append("(%d,%d)" % [tile_pos.x, tile_pos.y])
			count += 1
		else:
			break
	if sample_tiles.size() > 0:
		server_world.log_message("[COLLISION] Sample blocked tiles: %s..." % ", ".join(sample_tiles))
	
	# Generate physics bodies for these tiles so MovementValidator works
	_generate_tile_colliders(map_name, collision_tiles)


func _generate_tile_colliders(map_name: String, tiles: Dictionary):
	"""Convert parsed blocked tiles into StaticBody2D objects for the physics engine"""
	if not collision_world:
		return
		
	var bodies_created = 0
	var shape = RectangleShape2D.new()
	shape.size = Vector2(TILE_SIZE_SCALED, TILE_SIZE_SCALED)
	
	for tile_pos in tiles:
		# Calculate world position (center of tile)
		# Tile (0,0) is at 64,64 (half of 128)
		var world_x = tile_pos.x * TILE_SIZE_SCALED + (TILE_SIZE_SCALED / 2.0)
		var world_y = tile_pos.y * TILE_SIZE_SCALED + (TILE_SIZE_SCALED / 2.0)
		
		var body = StaticBody2D.new()
		body.name = "TileCol_%d_%d" % [tile_pos.x, tile_pos.y]
		body.position = Vector2(world_x, world_y)
		body.collision_layer = 1 # Layer 1 is for World Collision
		body.collision_mask = 0
		
		var collision = CollisionShape2D.new()
		collision.shape = shape
		body.add_child(collision)
		
		collision_world.add_child(body)
		bodies_created += 1
		
	server_world.log_message("[COLLISION] Generated %d physics bodies for middle layer tiles" % bodies_created)


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


func is_area_blocked(map_name: String, center_pos: Vector2, radius: int = 16) -> bool:
	"""
	Check if an area (defined by center + radius) overlaps any blocked tiles.
	Checks Center + 4 corners of the bounding box.
	Robust check for entity spawning.
	"""
	# Points to check: Center, TopLeft, TopRight, BottomLeft, BottomRight
	var points = [
		center_pos,
		center_pos + Vector2(-radius, -radius),
		center_pos + Vector2(radius, -radius),
		center_pos + Vector2(-radius, radius),
		center_pos + Vector2(radius, radius)
	]
	
	for point in points:
		var tile_x = int(point.x) >> 7
		var tile_y = int(point.y) >> 7
		if is_tile_blocked(map_name, tile_x, tile_y):
			return true
			
	return false


func is_position_blocked(map_name: String, position: Vector2) -> bool:
	"""Check if a world position is blocked (Legacy wrapper for single point)"""
	return is_area_blocked(map_name, position, 5) # Small radius for point check


func load_map_collision_tiles(map_name: String):
	"""Load collision tiles for a specific map"""
	var map_path = get_map_path(map_name)
	var file = FileAccess.open(map_path, FileAccess.READ)
	if not file:
		map_collision_tiles[map_name] = {}
		return

	var tmx_content = file.get_as_text()
	file.close()
	_parse_middle_layer_collision(tmx_content, map_name)


func find_nearest_free_spawn(map_name: String, position: Vector2, max_search_radius: int = 10) -> Vector2:
	"""Find the nearest non-blocked AREA from a given position"""
	# First check if we have collision data
	if not map_collision_tiles.has(map_name):
		load_map_collision_tiles(map_name)

	# 1. Check if current position is already free (using robust area check)
	# Use a 24px radius (approx half of 64px width/height for safety)
	if not is_area_blocked(map_name, position, 24):
		return position  # Already in a free spot

	# Convert world position to tile coordinates for search grid
	var center_tile_x = int(position.x / TILE_SIZE_SCALED)
	var center_tile_y = int(position.y / TILE_SIZE_SCALED)

	# Get map dimensions
	var dims = map_dimensions.get(map_name, {"width": 20, "height": 15})
	var map_width = dims.width
	var map_height = dims.height

	# Search in expanding squares (spiral pattern)
	for radius in range(1, max_search_radius + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue

				var check_x = center_tile_x + dx
				var check_y = center_tile_y + dy

				if check_x < 1 or check_x >= map_width - 1: continue
				if check_y < 1 or check_y >= map_height - 1: continue

				# Candidate position: Center of the tile
				var candidate_pos = Vector2(
					check_x * TILE_SIZE_SCALED + TILE_SIZE_SCALED / 2,
					check_y * TILE_SIZE_SCALED + TILE_SIZE_SCALED / 2
				)
				
				# Check if this AREA is free (not just the center point)
				if not is_area_blocked(map_name, candidate_pos, 24):
					return candidate_pos

	return position


	# Fallback: return original position if no free spot found
	return position


func validate_spawn_position(map_name: String, target_position: Vector2) -> Vector2:
	"""
	SAFETY CHECK: Validate that a spawn position is safe (not in collision).
	Returns a safe position (either original or corrected).
	"""
	# Ensure collision data is loaded
	if not map_collision_tiles.has(map_name):
		server_world.log_message("[MAP_SAFETY] Loading collision tiles for %s..." % map_name)
		load_map_collision_tiles(map_name)

	var blocked_count = map_collision_tiles.get(map_name, {}).size()

	if is_position_blocked(map_name, target_position):
		# Try to find a safe spot
		var safe_pos = find_nearest_free_spawn(map_name, target_position, 20)
		if safe_pos != target_position:
			server_world.log_message("[MAP_SAFETY] Corrected spawn: %s -> %s (blocked tiles: %d)" % [target_position, safe_pos, blocked_count])
			return safe_pos
		else:
			server_world.log_message("[MAP_SAFETY] WARNING: Could not find free spawn near %s!" % target_position)

	return target_position


# ========== PLAYER MAP TRACKING ==========


# ========== PLAYER MAP TRACKING ==========


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
	var map_path = get_map_path(map_name)
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


# ========== BATTLE INSTANCE MANAGEMENT ========== 

func create_battle_instance(world_map_name: String, player_ids: Array, npc_ids: Array = []) -> int:
	"""Create a new instanced battle for players attacking NPCs on a world map.
	Returns the instance_id for this battle."""

	# Verify world map exists (we use it as the template for battle instances)
	if world_map_name not in world_maps:
		print("[ServerMapManager] ERROR: No world map for '%s'" % world_map_name)
		return -1

	var instance_id = next_instance_id
	next_instance_id += 1

	battle_instances[instance_id] = {
		"map_name": world_map_name,
		"players": player_ids.duplicate(),
		"npcs": npc_ids.duplicate(),
		"created_at": Time.get_unix_time_from_system(),
		"state": "active"  # active, ending, cleanup
	}

	# Track which players are in this instance
	for player_id in player_ids:
		player_battle_instance[player_id] = instance_id

	print("[ServerMapManager] Created battle instance %d on '%s' with %d players, %d NPCs" % [
		instance_id, world_map_name, player_ids.size(), npc_ids.size()
	])

	return instance_id


func get_battle_instance(instance_id: int) -> Dictionary:
	"""Get battle instance data"""
	return battle_instances.get(instance_id, {})


func get_player_battle_instance(player_id: int) -> int:
	"""Get the battle instance a player is in, or -1 if not in battle"""
	return player_battle_instance.get(player_id, -1)


func is_player_in_battle(player_id: int) -> bool:
	"""Check if a player is currently in a battle instance"""
	return player_battle_instance.has(player_id)


func add_player_to_battle(instance_id: int, player_id: int):
	"""Add a player to an existing battle instance (e.g., squad member joins)"""
	if not battle_instances.has(instance_id):
		return

	if player_id not in battle_instances[instance_id].players:
		battle_instances[instance_id].players.append(player_id)
		player_battle_instance[player_id] = instance_id


func remove_player_from_battle(player_id: int):
	"""Remove a player from their battle instance (flee, death, victory)"""
	if not player_battle_instance.has(player_id):
		return

	var instance_id = player_battle_instance[player_id]
	player_battle_instance.erase(player_id)

	if battle_instances.has(instance_id):
		battle_instances[instance_id].players.erase(player_id)

		# If no players left, mark for cleanup
		if battle_instances[instance_id].players.is_empty():
			battle_instances[instance_id].state = "cleanup"
			print("[ServerMapManager] Battle instance %d marked for cleanup (no players)" % instance_id)


func end_battle_instance(instance_id: int, result: String = "victory"):
	"""End a battle instance (victory, defeat, flee)"""
	if not battle_instances.has(instance_id):
		return

	battle_instances[instance_id].state = "ending"
	battle_instances[instance_id].result = result

	# Remove all players from battle tracking
	for player_id in battle_instances[instance_id].players:
		player_battle_instance.erase(player_id)

	print("[ServerMapManager] Battle instance %d ended with result: %s" % [instance_id, result])


func cleanup_battle_instance(instance_id: int):
	"""Fully remove a battle instance after it's ended"""
	if battle_instances.has(instance_id):
		battle_instances.erase(instance_id)
		print("[ServerMapManager] Battle instance %d cleaned up" % instance_id)


func get_players_in_battle_on_map(world_map_name: String) -> Array:
	"""Get all players currently in battle instances for a specific world map"""
	var players = []
	for instance_id in battle_instances:
		if battle_instances[instance_id].map_name == world_map_name:
			players.append_array(battle_instances[instance_id].players)
	return players


func get_active_battle_count() -> int:
	"""Get count of active battle instances"""
	var count = 0
	for instance_id in battle_instances:
		if battle_instances[instance_id].state == "active":
			count += 1
	return count
