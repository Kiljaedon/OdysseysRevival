class_name MapManager
extends Node

## ============================================================================
## MAP MANAGER (CLIENT-SIDE)
## ============================================================================
## Handles map loading, TMX parsing, tile management, and map boundaries.
##
## IMPORTANT: This is the CLIENT-SIDE MapManager (different from ServerMapManager)
## - Client MapManager: Handles visual map rendering, TMX parsing, boundaries
## - ServerMapManager: Handles server map state, collision detection, pathfinding
##
## Dependencies: TileMapLayer nodes (bottom_layer, middle_layer, top_layer)
## ============================================================================

# Node references (injected via initialize)
var bottom_layer: TileMapLayer
var middle_layer: TileMapLayer
var top_layer: TileMapLayer
var game_world: Node2D
var test_character: CharacterBody2D
var collision_system_manager: CollisionSystemManager

# Map state
var current_map_width: int = 0
var current_map_height: int = 0
var current_map_name: String = ""
var maps_directory: String = "res://maps/"

# Transition zones (parsed from TMX Transitions objectgroup)
# Each zone: { rect: Rect2, target_map: String, spawn_x: int, spawn_y: int, direction: String }
var transition_zones: Array[Dictionary] = []

# Signals for map transitions
signal transition_triggered(target_map: String, spawn_x: int, spawn_y: int)

# Map boundaries
var map_boundaries: Array[StaticBody2D] = []

# Middle layer collision bodies (auto-generated)
var middle_layer_collisions: Array[StaticBody2D] = []

# Battle system
var battle_enabled: bool = true  # Enable/disable combat triggers on this map

# Map info UI reference (optional)
var map_info: Label

# Tile size constants (32px base * 4x scale = 128px)
const TILE_SIZE_BASE: int = 32
const TILE_SCALE: int = 4
const TILE_SIZE_SCALED: int = TILE_SIZE_BASE * TILE_SCALE  # 128px

## ============================================================================
## INITIALIZATION
## ============================================================================

## Initialize with required node references
## SIGNATURE: initialize(bottom, middle, top, world, character, collision_sys)
## This signature differentiates from ServerMapManager.initialize()
func initialize(bottom: TileMapLayer, middle: TileMapLayer, top: TileMapLayer,
				world: Node2D, character: CharacterBody2D, collision_sys: CollisionSystemManager = null):
	bottom_layer = bottom
	middle_layer = middle
	top_layer = top
	game_world = world
	test_character = character
	
	# Optional dependency (might be null in some contexts)
	if collision_sys:
		collision_system_manager = collision_sys
		print("[MapManager] CollisionSystemManager dependency set")
	
	print("[MapManager] ✓ Client-side MapManager initialized")

## Load selected map by name
func load_selected_map(map_name: String):
	print("[MapManager] Loading map: ", map_name)
	load_tmx_map(map_name)

## Load TMX map file from disk
## Opens and reads the TMX XML file, passes to parse_and_load_tmx()
## map_name can be "map_name" or "Subdir/map_name" for maps in subdirectories
func load_tmx_map(map_name: String):
	# map_name can include subdirectory (e.g., "World Maps/sample_map")
	var tmx_path = "res://maps/" + map_name + ".tmx"
	print("=== LOADING TMX MAP ===")
	print("Map name: ", map_name)
	print("TMX path: ", tmx_path)
	print("File exists: ", FileAccess.file_exists(tmx_path))

	if not FileAccess.file_exists(tmx_path):
		print("ERROR: TMX file not found: ", tmx_path)
		return

	var file = FileAccess.open(tmx_path, FileAccess.READ)
	if not file:
		print("ERROR: Failed to open TMX file: ", tmx_path)
		return

	var tmx_content = file.get_as_text()
	file.close()

	print("TMX content length: ", tmx_content.length())
	print("Parsing TMX...")
	parse_and_load_tmx(tmx_content, map_name)

## Parse TMX XML content and load tiles and collision objects
## LARGE FUNCTION (~200 lines) - Handles all TMX parsing and tile layer setup
##
## Process:
## 1. Extract map dimensions from <map> element
## 2. Parse all <layer> elements and load tiles via load_tiles_from_csv()
## 3. Parse all <objectgroup> elements for collision objects
## 4. Create map boundaries based on dimensions
## 5. Update map state variables
func parse_and_load_tmx(tmx_content: String, map_name: String):
	print("=== PARSING TMX CONTENT ===")
	print("Content length: ", tmx_content.length())

	# Clear all layers
	print("Clearing all map layers...")
	bottom_layer.clear()
	middle_layer.clear()
	top_layer.clear()
	print("Layers cleared")

	# Parse basic map info
	var map_width = 0
	var map_height = 0
	var tile_width = 32
	var tile_height = 32

	# Extract map dimensions using RegEx
	# Matches: width="1024" height="768" tilewidth="32" tileheight="32"
	var map_regex = RegEx.new()
	map_regex.compile('width="(\\d+)"\\s+height="(\\d+)"\\s+tilewidth="(\\d+)"\\s+tileheight="(\\d+)"')
	var map_result = map_regex.search(tmx_content)

	if map_result:
		map_width = map_result.get_string(1).to_int()
		map_height = map_result.get_string(2).to_int()
		tile_width = map_result.get_string(3).to_int()
		tile_height = map_result.get_string(4).to_int()

		print("Map dimensions: ", map_width, "x", map_height)
		print("Tile size: ", tile_width, "x", tile_height)

	# Extract layer data from CSV encoding
	# Matches: <layer name="Bottom"><data encoding="csv">CSV_DATA</data></layer>
	var layer_regex = RegEx.new()
	layer_regex.compile('<layer[^>]*name="([^"]*)"[^>]*>[\\s\\S]*?<data encoding="csv">([\\s\\S]*?)</data>[\\s\\S]*?</layer>')
	var layer_results = layer_regex.search_all(tmx_content)

	var layers_loaded = 0
	for layer_result in layer_results:
		var layer_name = layer_result.get_string(1)
		var csv_data = layer_result.get_string(2).strip_edges()

		print("Loading layer: ", layer_name)

		# Determine which TileMapLayer to use based on layer name
		var target_layer: TileMapLayer = bottom_layer
		if "middle" in layer_name.to_lower() or "object" in layer_name.to_lower():
			target_layer = middle_layer
		elif "top" in layer_name.to_lower() or "foreground" in layer_name.to_lower():
			target_layer = top_layer

		load_tiles_from_csv(csv_data, map_width, map_height, target_layer)
		layers_loaded += 1

	# Extract object layers for collision
	# Matches: <objectgroup name="Collision"><object x="224" y="192" width="64" height="32"/></objectgroup>
	var objectgroup_regex = RegEx.new()
	objectgroup_regex.compile('<objectgroup[^>]*name="([^"]*)"[^>]*>([\\s\\S]*?)</objectgroup>')
	var objectgroup_results = objectgroup_regex.search_all(tmx_content)

	var collision_objects_loaded = 0
	for objectgroup_result in objectgroup_results:
		var group_name = objectgroup_result.get_string(1)
		var group_content = objectgroup_result.get_string(2)

		print("Loading object group: ", group_name)

		# Only process collision object layers
		if "collision" in group_name.to_lower():
			if collision_system_manager:
				print("  [MapManager] Delegating collision loading to CollisionSystemManager")
				collision_system_manager.load_collision_objects(group_content, tile_width, tile_height)
			else:
				print("  [MapManager] WARNING: No CollisionSystemManager! Collision objects ignored.")

	# Parse transition zones from Transitions objectgroup
	parse_transitions_from_tmx(tmx_content)

	if layers_loaded > 0:
		# Store map dimensions in tiles
		current_map_width = map_width
		current_map_height = map_height
		current_map_name = map_name

		# Update map info
		if map_info:
			map_info.text = "%s\nSize: %dx%d tiles\nLayers: %d\nTile Size: %dx%d" % [
				map_name, map_width, map_height, layers_loaded, tile_width, tile_height
			]

		# Position character at center of map (or restore from pre-battle position)
		var game_state = get_node_or_null("/root/GameState")
		var spawn_pos = Vector2.ZERO

		if game_state and "pre_battle_position" in game_state and game_state.pre_battle_position != Vector2.ZERO:
			# Returning from battle - restore previous position
			spawn_pos = game_state.pre_battle_position
			game_state.pre_battle_position = Vector2.ZERO  # Clear it
			print("  ✓ Restored player position from battle: ", spawn_pos)
		else:
			# First spawn - use map center
			var center_x = (map_width * tile_width) / 2
			var center_y = (map_height * tile_height) / 2
			spawn_pos = Vector2(center_x, center_y)
			print("  ✓ Spawning player at map center: ", spawn_pos)

		if test_character:
			test_character.position = spawn_pos

		# Create map boundaries
		create_map_boundaries(map_width, map_height, tile_width, tile_height)

		# NOTE: Middle layer collision ENABLED per user request
		# Auto-collision makes ALL middle layer tiles solid
		generate_middle_layer_collision(map_width, map_height)

		print("TMX map loaded successfully: ", map_name)
		print("  Map size: ", map_width, "x", map_height, " tiles")
		print("  Tile layers: ", layers_loaded)
	else:
		print("Could not find layer data in TMX file")
		if map_info:
			map_info.text = "Error: No valid layers found"

## Load tiles from CSV data into specified TileMapLayer
## Parses comma-separated tile IDs and converts to Godot tileset format
##
## Format:
## - CSV: "1,2,0,3,0,2,1,..." (comma-separated tile IDs)
## - Tile ID 0 = empty (no tile placed)
## - Tile ID > 0 = converted to tileset source and position
##
## Tileset references:
## - tiles_part1: firstgid=1, tiles 1-3584 (source_id=0)
## - tiles_part2: firstgid=3585, tiles 3585+ (source_id=1)
##
## Grid calculation:
## - Tileset is 7 columns wide
## - source_x = (tile_id - 1) % 7
## - source_y = (tile_id - 1) / 7
func load_tiles_from_csv(csv_data: String, map_width: int, map_height: int, target_layer: TileMapLayer):
	print("=== LOADING TILES FROM CSV ===")
	print("Target layer: ", target_layer.name)
	print("Map dimensions: ", map_width, " x ", map_height)
	print("CSV data length: ", csv_data.length())

	# Remove newlines and split by commas
	csv_data = csv_data.replace("\n", "").replace("\r", "")
	var tile_ids = csv_data.split(",")
	print("Total tile IDs in CSV: ", tile_ids.size())

	var tile_index = 0
	var tiles_placed = 0

	for y in range(map_height):
		for x in range(map_width):
			if tile_index < tile_ids.size():
				var tile_id = tile_ids[tile_index].strip_edges().to_int()

				# Convert Tiled tile ID to Godot format
				if tile_id > 0:
					# Determine which tileset source to use
					# tiles_part1: firstgid=1, tiles 1-3584 (source_id=0)
					# tiles_part2: firstgid=3585, tiles 3585-6979 (source_id=1)
					# collision: firstgid=6980, tiles 6980+ (source_id=2)
					var source_id = 0
					var adjusted_tile_id = tile_id - 1  # Convert to 0-based
					var source_x = 0
					var source_y = 0

					if tile_id >= 6980:
						# collision tileset
						source_id = 2
						adjusted_tile_id = tile_id - 6980
						source_x = adjusted_tile_id % 7
						source_y = adjusted_tile_id / 7
					elif tile_id >= 3585:
						# tiles_part2
						source_id = 1
						adjusted_tile_id = tile_id - 3585  # Adjust for second tileset
						source_x = adjusted_tile_id % 7
						source_y = adjusted_tile_id / 7
					else:
						# tiles_part1
						source_x = adjusted_tile_id % 7
						source_y = adjusted_tile_id / 7

					target_layer.set_cell(Vector2i(x, y), source_id, Vector2i(source_x, source_y))
					tiles_placed += 1

			tile_index += 1

	print("Processed ", tile_index, " tile positions")
	print("Placed ", tiles_placed, " actual tiles")
	print("=== TILE LOADING COMPLETE ===")

## ============================================================================
## MIDDLE LAYER AUTO-COLLISION
## ============================================================================

## Generate collision bodies for all non-empty tiles on the Middle layer
## This makes all Middle layer tiles solid automatically
func generate_middle_layer_collision(map_width: int, map_height: int):
	print("[MapManager] Generating collision for Middle layer tiles...")

	# Clear existing middle layer collisions
	for collision in middle_layer_collisions:
		if is_instance_valid(collision):
			collision.queue_free()
	middle_layer_collisions.clear()

	# Tile dimensions (accounting for 4x scale)
	var tile_size = 32 * 4  # 128 pixels per scaled tile
	var collision_count = 0

	# Scan middle layer and create collision for each non-empty tile
	for y in range(map_height):
		for x in range(map_width):
			var cell_pos = Vector2i(x, y)
			var source_id = middle_layer.get_cell_source_id(cell_pos)

			# If tile exists (source_id != -1), create collision
			if source_id != -1:
				var collision_body = StaticBody2D.new()
				collision_body.name = "MiddleCollision_%d_%d" % [x, y]
				collision_body.collision_layer = 1
				collision_body.collision_mask = 0

				# Position at center of tile
				collision_body.position = Vector2(
					x * tile_size + tile_size / 2,
					y * tile_size + tile_size / 2
				)

				var collision_shape = CollisionShape2D.new()
				var rect_shape = RectangleShape2D.new()
				rect_shape.size = Vector2(tile_size, tile_size)
				collision_shape.shape = rect_shape

				collision_body.add_child(collision_shape)
				game_world.add_child(collision_body)
				middle_layer_collisions.append(collision_body)
				collision_count += 1

	print("[MapManager] Created ", collision_count, " collision bodies for Middle layer tiles")

## ============================================================================
## MAP BOUNDARY CREATION
## ============================================================================

func create_map_boundaries(map_width: int, map_height: int, tile_width: int, tile_height: int):
	"""Create collision boundaries around the map edges."""
	print("[MapManager] Creating map boundaries...")

	# Clear existing boundaries
	for boundary in map_boundaries:
		boundary.queue_free()
	map_boundaries.clear()

	# Calculate map dimensions in pixels (accounting for 4x tile scale)
	var scaled_tile_width = tile_width * 4
	var scaled_tile_height = tile_height * 4
	var map_pixel_width = map_width * scaled_tile_width
	var map_pixel_height = map_height * scaled_tile_height

	var wall_thickness = 512.0  # Extra thick walls

	# Character sprite: (32px - 2px crop) × 3 scale = 90px displayed, extends 45px below center
	# Collision box: 30px, extends 15px below center
	# Total clearance needed: 45px (sprite half) + 15px (collision radius) = 60px
	var sprite_clearance = 60.0  # Keep sprite fully on tiles - works for ANY map size

	# Create 4 boundary walls - positioned to prevent ANY black areas from being walkable
	# Walls positioned so character sprite stays fully on tiles regardless of map size
	var boundaries_data = [
		{"name": "TopWall", "pos": Vector2(map_pixel_width / 2, sprite_clearance - wall_thickness / 2), "size": Vector2(map_pixel_width + wall_thickness * 2, wall_thickness)},
		{"name": "BottomWall", "pos": Vector2(map_pixel_width / 2, map_pixel_height - sprite_clearance + wall_thickness / 2), "size": Vector2(map_pixel_width + wall_thickness * 2, wall_thickness)},
		{"name": "LeftWall", "pos": Vector2(sprite_clearance - wall_thickness / 2, map_pixel_height / 2), "size": Vector2(wall_thickness, map_pixel_height + wall_thickness * 2)},
		{"name": "RightWall", "pos": Vector2(map_pixel_width - sprite_clearance + wall_thickness / 2, map_pixel_height / 2), "size": Vector2(wall_thickness, map_pixel_height + wall_thickness * 2)}
	]

	for boundary_data in boundaries_data:
		var boundary = StaticBody2D.new()
		boundary.name = boundary_data.name
		boundary.collision_layer = 1  # Same layer as middle layer tiles
		boundary.collision_mask = 0
		boundary.position = boundary_data.pos

		var collision_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = boundary_data.size
		collision_shape.shape = rect_shape

		boundary.add_child(collision_shape)
		game_world.add_child(boundary)
		map_boundaries.append(boundary)

		# Debug output
		print("  ", boundary_data.name, ": pos=", boundary_data.pos, " size=", boundary_data.size)

	print("[MapManager] Created ", map_boundaries.size(), " boundary walls")
	print("  Map dimensions: ", map_pixel_width, "x", map_pixel_height, "px (", map_width, "x", map_height, " tiles)")
	print("  Wall thickness: ", wall_thickness, "px")
	if test_character:
		print("  Character position: ", test_character.position)

## ============================================================================
## UTILITY FUNCTIONS
## ============================================================================

func set_map_info_label(label: Label) -> void:
	"""Set the map info label reference for UI updates."""
	map_info = label

## Get current map width in pixels (accounting for tile scale)
## Returns width = tiles × tile_width × 4 (for 4x scale)
func get_map_width_pixels(tile_width: int = 32) -> float:
	return current_map_width * tile_width * 4

## Get current map height in pixels (accounting for tile scale)
## Returns height = tiles × tile_height × 4 (for 4x scale)
func get_map_height_pixels(tile_height: int = 32) -> float:
	return current_map_height * tile_height * 4

func is_battle_enabled() -> bool:
	"""Check if battles are enabled on the current map."""
	return battle_enabled

func set_battle_enabled(enabled: bool) -> void:
	"""Enable or disable battles on the current map."""
	battle_enabled = enabled
	print("[MapManager] Battle enabled: ", enabled)

## Return collision data from TMX for CollisionSystemManager
## This is called by parse_and_load_tmx internally
func get_collision_data_from_tmx(objectgroup_results: Array) -> Dictionary:
	"""Extract collision object data from parsed TMX objectgroup results."""
	var collision_data = {
		"objectgroups": []
	}

	for objectgroup_result in objectgroup_results:
		var group_name = objectgroup_result.get_string(1)
		var group_content = objectgroup_result.get_string(2)

		# Only process collision object layers
		if "collision" in group_name.to_lower():
			collision_data.objectgroups.append({
				"name": group_name,
				"content": group_content
			})

	return collision_data

## ============================================================================
## MAP TRANSITION SYSTEM
## ============================================================================

## Parse transition zones from TMX Transitions objectgroup
## Looks for objects with properties: target_map, spawn_x, spawn_y, direction
func parse_transitions_from_tmx(tmx_content: String):
	print("[MapManager] Parsing transition zones...")
	transition_zones.clear()

	# Find Transitions objectgroup
	var objectgroup_regex = RegEx.new()
	objectgroup_regex.compile('<objectgroup[^>]*name="[Tt]ransitions?"[^>]*>([\\s\\S]*?)</objectgroup>')
	var objectgroup_result = objectgroup_regex.search(tmx_content)

	if not objectgroup_result:
		print("[MapManager] No Transitions layer found")
		return

	var group_content = objectgroup_result.get_string(1)

	# Parse each object in the Transitions group
	# Match objects with their properties
	var object_regex = RegEx.new()
	object_regex.compile('<object[^>]*x="([\\d.]+)"[^>]*y="([\\d.]+)"[^>]*width="([\\d.]+)"[^>]*height="([\\d.]+)"[^>]*>([\\s\\S]*?)</object>')
	var object_results = object_regex.search_all(group_content)

	# Also try matching objects without nested content (self-closing or different order)
	var object_regex_alt = RegEx.new()
	object_regex_alt.compile('<object[^/]*?x="([\\d.]+)"[^/]*?y="([\\d.]+)"[^/]*?width="([\\d.]+)"[^/]*?height="([\\d.]+)"[^>]*/?>')

	if object_results.size() == 0:
		object_results = object_regex_alt.search_all(group_content)

	for obj_result in object_results:
		var obj_x = obj_result.get_string(1).to_float()
		var obj_y = obj_result.get_string(2).to_float()
		var obj_width = obj_result.get_string(3).to_float()
		var obj_height = obj_result.get_string(4).to_float()
		var obj_content = obj_result.get_string(5) if obj_result.get_group_count() >= 5 else ""

		# Scale coordinates by 4x (Tiled uses 32px, Godot displays at 128px)
		var scaled_rect = Rect2(
			obj_x * 4,
			obj_y * 4,
			obj_width * 4,
			obj_height * 4
		)

		# Parse properties from object content
		var target_map = ""
		var spawn_x = 0
		var spawn_y = 0
		var direction = ""

		# Look for properties in the full group content around this object position
		# Find the object block that contains these coordinates
		var full_object_regex = RegEx.new()
		var escaped_x = str(obj_x).replace(".", "\\.")
		var escaped_y = str(obj_y).replace(".", "\\.")
		full_object_regex.compile('<object[^>]*x="' + escaped_x + '"[^>]*y="' + escaped_y + '"[^>]*>([\\s\\S]*?)</object>')
		var full_obj_result = full_object_regex.search(group_content)

		if full_obj_result:
			obj_content = full_obj_result.get_string(1)

		# Parse target_map property
		var prop_regex = RegEx.new()
		prop_regex.compile('<property\\s+name="target_map"[^>]*value="([^"]*)"')
		var prop_result = prop_regex.search(obj_content)
		if prop_result:
			target_map = prop_result.get_string(1)

		# Parse spawn_x property
		prop_regex.compile('<property\\s+name="spawn_x"[^>]*value="([^"]*)"')
		prop_result = prop_regex.search(obj_content)
		if prop_result:
			spawn_x = prop_result.get_string(1).to_int()

		# Parse spawn_y property
		prop_regex.compile('<property\\s+name="spawn_y"[^>]*value="([^"]*)"')
		prop_result = prop_regex.search(obj_content)
		if prop_result:
			spawn_y = prop_result.get_string(1).to_int()

		# Parse direction property
		prop_regex.compile('<property\\s+name="direction"[^>]*value="([^"]*)"')
		prop_result = prop_regex.search(obj_content)
		if prop_result:
			direction = prop_result.get_string(1).to_lower()

		# Only add if we have required properties
		if target_map != "" and direction != "":
			var zone = {
				"rect": scaled_rect,
				"target_map": target_map,
				"spawn_x": spawn_x,
				"spawn_y": spawn_y,
				"direction": direction
			}
			transition_zones.append(zone)
			print("[MapManager] Transition zone: ", scaled_rect, " -> ", target_map, " (", direction, ")")
		else:
			print("[MapManager] Skipping incomplete transition object at ", obj_x, ",", obj_y)

	print("[MapManager] Loaded ", transition_zones.size(), " transition zones")

## Check if a position + direction triggers a map transition
## Returns the transition zone dictionary if triggered, or empty dict if not
func check_transition(position: Vector2, move_direction: String) -> Dictionary:
	for zone in transition_zones:
		# Check if position is inside the zone rectangle
		if zone.rect.has_point(position):
			# Check if movement direction matches required direction
			if zone.direction == move_direction:
				return zone
	return {}

## Get all transition zones (for debugging/visualization)
func get_transition_zones() -> Array[Dictionary]:
	return transition_zones
