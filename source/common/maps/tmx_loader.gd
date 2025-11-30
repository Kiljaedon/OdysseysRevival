class_name TMXLoader extends RefCounted

## TMX to Godot TileMap loader with automatic collision for Middle layer
## Loads Tiled TMX files and creates TileMap with collision on Middle layer
## Also parses object layers for warps, NPC spawns, and player spawns

static func load_tmx_to_tilemap(tmx_path: String, tileset_resource: TileSet) -> TileMap:
	var tilemap = TileMap.new()
	tilemap.tile_set = tileset_resource

	# Parse TMX file
	var tmx_data = parse_tmx_file(tmx_path)
	if not tmx_data:
		push_error("Failed to parse TMX file: " + tmx_path)
		return tilemap

	# Create layers
	create_layers_from_tmx(tilemap, tmx_data)

	# Add automatic collision for Middle layer
	setup_middle_layer_collision(tilemap)

	return tilemap

static func parse_tmx_file(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var xml_content = file.get_as_text()
	file.close()

	# Simple XML parsing for TMX structure
	var parser = XMLParser.new()
	parser.open_buffer(xml_content.to_utf8_buffer())

	var tmx_data = {
		"width": 0,
		"height": 0,
		"tilewidth": 32,
		"tileheight": 32,
		"layers": [],
		"object_groups": []
	}

	# Parse TMX structure
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			match parser.get_node_name():
				"map":
					tmx_data.width = parser.get_named_attribute_value_safe("width").to_int()
					tmx_data.height = parser.get_named_attribute_value_safe("height").to_int()
					tmx_data.tilewidth = parser.get_named_attribute_value_safe("tilewidth").to_int()
					tmx_data.tileheight = parser.get_named_attribute_value_safe("tileheight").to_int()
				"layer":
					var layer = parse_layer(parser, tmx_data)
					if layer:
						tmx_data.layers.append(layer)
				"objectgroup":
					var obj_group = parse_object_group(parser)
					if obj_group:
						tmx_data.object_groups.append(obj_group)

	return tmx_data

static func parse_layer(parser: XMLParser, tmx_data: Dictionary) -> Dictionary:
	var layer = {
		"name": parser.get_named_attribute_value_safe("name"),
		"width": parser.get_named_attribute_value_safe("width").to_int(),
		"height": parser.get_named_attribute_value_safe("height").to_int(),
		"data": [],
		"layer_type": ""
	}

	# Continue parsing to find layer properties and data
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			match parser.get_node_name():
				"property":
					if parser.get_named_attribute_value_safe("name") == "layer_type":
						layer.layer_type = parser.get_named_attribute_value_safe("value")
				"data":
					# Parse CSV tile data
					parser.read() # Move to content
					if parser.get_node_type() == XMLParser.NODE_TEXT:
						var csv_data = parser.get_node_data().strip_edges()
						layer.data = parse_csv_data(csv_data)
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "layer":
				break

	return layer

static func parse_object_group(parser: XMLParser) -> Dictionary:
	var group = {
		"name": parser.get_named_attribute_value_safe("name"),
		"objects": []
	}

	# Parse objects within the group
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if parser.get_node_name() == "object":
				var obj = parse_object(parser)
				if obj:
					group.objects.append(obj)
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "objectgroup":
				break

	return group

static func parse_object(parser: XMLParser) -> Dictionary:
	var obj = {
		"id": parser.get_named_attribute_value_safe("id").to_int(),
		"name": parser.get_named_attribute_value_safe("name"),
		"x": parser.get_named_attribute_value_safe("x").to_float(),
		"y": parser.get_named_attribute_value_safe("y").to_float(),
		"width": parser.get_named_attribute_value_safe("width").to_float(),
		"height": parser.get_named_attribute_value_safe("height").to_float(),
		"properties": {}
	}

	# Check if this is a self-closing tag
	if parser.is_empty():
		return obj

	# Parse object properties
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if parser.get_node_name() == "property":
				var prop_name = parser.get_named_attribute_value_safe("name")
				var prop_value = parser.get_named_attribute_value_safe("value")
				var prop_type = parser.get_named_attribute_value_safe("type")

				# Convert to appropriate type
				if prop_type == "int":
					obj.properties[prop_name] = prop_value.to_int()
				elif prop_type == "float":
					obj.properties[prop_name] = prop_value.to_float()
				elif prop_type == "bool":
					obj.properties[prop_name] = prop_value.to_lower() == "true"
				else:
					obj.properties[prop_name] = prop_value
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "object":
				break

	return obj

static func parse_csv_data(csv_string: String) -> Array:
	var data = []
	var lines = csv_string.split("\n")

	for line in lines:
		if line.strip_edges().is_empty():
			continue
		var row = line.strip_edges().rstrip(",").split(",")
		for tile_id_str in row:
			data.append(tile_id_str.strip_edges().to_int())

	return data

static func create_layers_from_tmx(tilemap: TileMap, tmx_data: Dictionary):
	var source_id = 0  # Assuming first tileset source

	# Create layers based on layer_type property
	for i in range(tmx_data.layers.size()):
		var layer_data = tmx_data.layers[i]
		var layer_index = i

		# Ensure layer exists
		while tilemap.get_layers_count() <= layer_index:
			tilemap.add_layer(-1)

		# Set layer properties
		tilemap.set_layer_name(layer_index, layer_data.name)

		# Place tiles
		var data_index = 0
		for y in range(tmx_data.height):
			for x in range(tmx_data.width):
				if data_index < layer_data.data.size():
					var tile_id = layer_data.data[data_index]
					if tile_id > 0:
						# Convert from Tiled 1-based to Godot 0-based
						var atlas_coords = Vector2i((tile_id - 1) % 7, (tile_id - 1) / 7)
						tilemap.set_cell(layer_index, Vector2i(x, y), source_id, atlas_coords)
					data_index += 1

static func setup_middle_layer_collision(tilemap: TileMap):
	# Find Middle layer (layer with "middle" layer_type or index 1)
	var middle_layer_index = find_middle_layer_index(tilemap)
	if middle_layer_index == -1:
		print("No Middle layer found for collision setup")
		return

	# Get all used cells in Middle layer
	var used_cells = tilemap.get_used_cells(middle_layer_index)

	# Create collision bodies for each used cell
	for cell_pos in used_cells:
		create_collision_for_cell(tilemap, cell_pos, middle_layer_index)

static func find_middle_layer_index(tilemap: TileMap) -> int:
	# Check layer names first
	for i in range(tilemap.get_layers_count()):
		var layer_name = tilemap.get_layer_name(i).to_lower()
		if "middle" in layer_name or "objects" in layer_name or "structures" in layer_name:
			return i

	# Fallback: assume layer 1 is Middle (Bottom=0, Middle=1, Foreground=2)
	if tilemap.get_layers_count() > 1:
		return 1

	return -1

static func create_collision_for_cell(tilemap: TileMap, cell_pos: Vector2i, layer_index: int):
	# Create StaticBody2D for collision
	var static_body = StaticBody2D.new()
	static_body.name = "Collision_" + str(cell_pos.x) + "_" + str(cell_pos.y)

	# Create CollisionShape2D
	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(32, 32)  # Tile size
	collision_shape.shape = rect_shape

	# Position the collision
	var tile_size = Vector2(32, 32)
	var world_pos = Vector2(cell_pos.x * tile_size.x + tile_size.x/2,
							cell_pos.y * tile_size.y + tile_size.y/2)
	static_body.position = world_pos

	# Add to scene
	static_body.add_child(collision_shape)
	tilemap.add_child(static_body)

## Create warp areas from parsed TMX object data
static func create_warps_from_tmx(parent: Node2D, tmx_data: Dictionary, tile_width: int = 32, tile_height: int = 32) -> Array[Area2D]:
	var warps: Array[Area2D] = []

	for group in tmx_data.object_groups:
		if group.name.to_lower() == "warps":
			for obj in group.objects:
				var obj_type = obj.properties.get("type", "")
				if obj_type == "warp":
					var warp = create_warp_area(obj, tile_width, tile_height)
					if warp:
						parent.add_child(warp)
						warps.append(warp)

	return warps

static func create_warp_area(obj: Dictionary, tile_width: int, tile_height: int) -> Area2D:
	var area = Area2D.new()
	area.name = "Warp_" + str(obj.properties.get("warp_id", obj.id))

	# Position (Tiled uses top-left, Godot uses center for collision)
	var width = obj.width if obj.width > 0 else tile_width
	var height = obj.height if obj.height > 0 else tile_height
	area.position = Vector2(obj.x + width / 2, obj.y + height / 2)

	# Create collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision.shape = shape
	area.add_child(collision)

	# Store warp data as metadata
	area.set_meta("target_map", obj.properties.get("target_map", ""))
	area.set_meta("target_x", obj.properties.get("target_x", 0))
	area.set_meta("target_y", obj.properties.get("target_y", 0))
	area.set_meta("warp_id", obj.properties.get("warp_id", 0))
	area.set_meta("trigger", obj.properties.get("trigger", "touch"))

	# Set collision layer for warps (layer 4)
	area.collision_layer = 8  # Layer 4
	area.collision_mask = 1   # Detect player on layer 1

	return area

## Create NPC spawn points from parsed TMX object data
static func create_npc_spawns_from_tmx(parent: Node2D, tmx_data: Dictionary, tile_width: int = 32, tile_height: int = 32) -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []

	for group in tmx_data.object_groups:
		if group.name.to_lower() == "npcspawns":
			for obj in group.objects:
				var obj_type = obj.properties.get("type", "")
				if obj_type == "npc_spawn":
					var spawn_data = {
						"position": Vector2(obj.x + tile_width / 2, obj.y + tile_height / 2),
						"spawn_id": obj.properties.get("spawn_id", 0),
						"npc_type": obj.properties.get("npc_type", ""),
						"npc_name": obj.properties.get("npc_name", ""),
						"dialog": obj.properties.get("dialog", ""),
						"facing": obj.properties.get("facing", "down")
					}
					spawns.append(spawn_data)

	return spawns

## Get player spawn point from parsed TMX object data
static func get_player_spawn_from_tmx(tmx_data: Dictionary, tile_width: int = 32, tile_height: int = 32) -> Vector2:
	for group in tmx_data.object_groups:
		if group.name.to_lower() == "playerspawn":
			for obj in group.objects:
				var obj_type = obj.properties.get("type", "")
				if obj_type == "player_spawn":
					return Vector2(obj.x + tile_width / 2, obj.y + tile_height / 2)

	# Default spawn at center of map
	return Vector2(tmx_data.width * tile_width / 2, tmx_data.height * tile_height / 2)

## Convenience function to load TMX directly into a scene with all objects
static func create_map_scene_from_tmx(tmx_path: String, tileset_path: String) -> Node2D:
	var tileset = load(tileset_path) as TileSet
	if not tileset:
		push_error("Failed to load tileset: " + tileset_path)
		return null

	var scene_root = Node2D.new()
	scene_root.name = "TMXMap"

	# Parse TMX data
	var tmx_data = parse_tmx_file(tmx_path)
	if not tmx_data:
		push_error("Failed to parse TMX file: " + tmx_path)
		return scene_root

	# Create tilemap
	var tilemap = TileMap.new()
	tilemap.tile_set = tileset
	tilemap.name = "TileMap"
	create_layers_from_tmx(tilemap, tmx_data)
	setup_middle_layer_collision(tilemap)
	scene_root.add_child(tilemap)

	# Create warps container
	var warps_container = Node2D.new()
	warps_container.name = "Warps"
	scene_root.add_child(warps_container)
	create_warps_from_tmx(warps_container, tmx_data, tmx_data.tilewidth, tmx_data.tileheight)

	# Store spawn data and TMX path as metadata
	scene_root.set_meta("tmx_path", tmx_path)
	scene_root.set_meta("player_spawn", get_player_spawn_from_tmx(tmx_data, tmx_data.tilewidth, tmx_data.tileheight))
	scene_root.set_meta("npc_spawns", create_npc_spawns_from_tmx(scene_root, tmx_data, tmx_data.tilewidth, tmx_data.tileheight))

	print("TMX Map loaded: " + tmx_path)
	print("  - Player spawn: ", scene_root.get_meta("player_spawn"))
	print("  - Warps: ", warps_container.get_child_count())
	print("  - NPC spawns: ", scene_root.get_meta("npc_spawns").size())

	return scene_root
