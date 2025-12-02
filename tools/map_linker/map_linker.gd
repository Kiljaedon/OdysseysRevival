extends Control
## Map Linker - Visual editor for placing warps, NPC spawns, and player spawns on TMX maps
## Phase 2: Core viewer with map list, preview, and pan/zoom

const TMXLoader = preload("res://source/common/maps/tmx_loader.gd")

# UI References
@onready var world_map_dropdown: OptionButton = $UI/HSplitContainer/MapListPanel/Content/WorldMapDropdown
@onready var battle_map_dropdown: OptionButton = $UI/HSplitContainer/MapListPanel/Content/BattleMapDropdown
@onready var map_preview: SubViewport = $UI/HSplitContainer/MapPreviewPanel/Content/SubViewportContainer/SubViewport
@onready var map_camera: Camera2D = $UI/HSplitContainer/MapPreviewPanel/Content/SubViewportContainer/SubViewport/Camera2D
@onready var object_list: ItemList = $UI/HSplitContainer/ObjectPanel/Content/ObjectList
@onready var properties_container: VBoxContainer = $UI/HSplitContainer/ObjectPanel/Content/PropertiesContainer
@onready var status_label: Label = $UI/StatusBar/StatusLabel
@onready var zoom_label: Label = $UI/HSplitContainer/MapPreviewPanel/Content/Controls/ZoomLabel
@onready var viewport_container: SubViewportContainer = $UI/HSplitContainer/MapPreviewPanel/Content/SubViewportContainer

# State
var world_maps_dir: String = "res://maps/World Maps/"
var current_map_type: String = "world"
var current_map_path: String = ""
var current_tmx_data: Dictionary = {}
var zoom_level: float = 1.0
var is_panning: bool = false
var pan_start: Vector2 = Vector2.ZERO
var camera_start: Vector2 = Vector2.ZERO

# Object markers
var warp_markers: Array[Node2D] = []
var npc_markers: Array[Node2D] = []
var player_spawn_marker: Node2D = null

# Placement mode
enum PlacementMode { NONE, WARP, NPC_SPAWN, PLAYER_SPAWN }
var current_mode: PlacementMode = PlacementMode.NONE
var selected_object_index: int = -1

# Tileset references (will be loaded from TMX)
var loaded_tilesets: Dictionary = {}


func _ready():
	print("=== MAP LINKER STARTED ===")

	# Connect viewport input (not in scene file)
	if viewport_container:
		viewport_container.gui_input.connect(_on_viewport_input)
	else:
		push_error("[MapLinker] viewport_container is null!")

	# Connect dropdown selection signals
	if world_map_dropdown:
		world_map_dropdown.item_selected.connect(_on_world_map_selected)
		print("[MapLinker] World map dropdown connected")
	else:
		push_error("[MapLinker] world_map_dropdown is null!")

	if battle_map_dropdown:
		battle_map_dropdown.item_selected.connect(_on_battle_map_selected)
		print("[MapLinker] Battle map dropdown connected")
	else:
		push_error("[MapLinker] battle_map_dropdown is null!")

	# Load map list after a frame to ensure UI is ready
	call_deferred("_scan_maps_directory")

	# Set initial status
	status_label.text = "Select a map from the list to begin"

	print("[MapLinker] Ready complete")


var world_map_list: Array[String] = []

func _scan_maps_directory():
	"""Scan World Maps folder (world maps are also used as battle arenas)"""
	# Scan World Maps
	world_map_dropdown.clear()
	world_map_dropdown.add_item("-- Select World Map --")
	world_map_list.clear()

	var world_dir = DirAccess.open(world_maps_dir)
	if world_dir:
		_scan_folder(world_dir, world_map_list)
	world_map_list.sort()
	for map_file in world_map_list:
		world_map_dropdown.add_item(map_file)
	print("[MapLinker] Found %d maps" % world_map_list.size())

	# Battle maps dropdown shows same maps (world maps serve as arenas)
	if battle_map_dropdown:
		battle_map_dropdown.clear()
		battle_map_dropdown.add_item("-- Select Map (Arena View) --")
		for map_file in world_map_list:
			battle_map_dropdown.add_item(map_file)

	status_label.text = "Found %d maps (world maps also serve as battle arenas)" % world_map_list.size()


func _scan_folder(dir: DirAccess, results: Array[String]):
	"""Scan a single folder for TMX files"""
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tmx"):
			results.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _scan_recursive(dir: DirAccess, prefix: String, results: Array[String]):
	"""Recursively scan for TMX files"""
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				var subdir = DirAccess.open(dir.get_current_dir() + "/" + file_name)
				if subdir:
					_scan_recursive(subdir, prefix + file_name + "/", results)
		elif file_name.ends_with(".tmx"):
			results.append(prefix + file_name)
		file_name = dir.get_next()

	dir.list_dir_end()


func _on_world_map_selected(index: int):
	"""Handle world map dropdown selection"""
	if index == 0:
		return
	var map_name = world_map_list[index - 1]
	print("[MapLinker] WORLD MAP SELECTED: %s" % map_name)
	current_map_path = world_maps_dir + map_name
	current_map_type = "world"
	_load_selected_map(map_name)


func _on_battle_map_selected(index: int):
	"""Handle battle map dropdown selection (uses world maps as arenas)"""
	if index == 0:
		return
	var map_name = world_map_list[index - 1]
	print("[MapLinker] ARENA MAP SELECTED: %s" % map_name)
	current_map_path = world_maps_dir + map_name
	current_map_type = "battle"
	_load_selected_map(map_name)


func _load_selected_map(map_name: String):

	status_label.text = "Loading: " + map_name

	# Parse TMX file
	current_tmx_data = TMXLoader.parse_tmx_file(current_map_path)
	if current_tmx_data.is_empty():
		status_label.text = "ERROR: Failed to parse " + map_name
		return

	# Clear existing map content
	_clear_map_preview()

	# Render the map
	_render_map_preview()

	# Load objects (warps, spawns)
	_load_objects_from_tmx()

	# Update object list
	_update_object_list()

	# Reset camera
	_reset_camera()

	var type_label = "World" if current_map_type == "world" else "Battle"
	status_label.text = "Loaded %s Map: %s (%dx%d tiles)" % [type_label, map_name, current_tmx_data.width, current_tmx_data.height]


func _clear_map_preview():
	"""Remove all children from viewport except camera"""
	for child in map_preview.get_children():
		if child != map_camera:
			child.queue_free()

	warp_markers.clear()
	npc_markers.clear()
	player_spawn_marker = null


func _render_map_preview():
	"""Render TMX map layers to the preview viewport"""
	if current_tmx_data.is_empty():
		return

	# Create container for map tiles
	var map_container = Node2D.new()
	map_container.name = "MapContainer"
	map_preview.add_child(map_container)

	# Load tileset images
	_load_tilesets_for_map()

	# Render each layer
	var tile_width = current_tmx_data.tilewidth
	var tile_height = current_tmx_data.tileheight

	for layer_data in current_tmx_data.layers:
		var layer_node = Node2D.new()
		layer_node.name = layer_data.name
		map_container.add_child(layer_node)

		# Render tiles for this layer
		var data_index = 0
		for y in range(current_tmx_data.height):
			for x in range(current_tmx_data.width):
				if data_index < layer_data.data.size():
					var tile_id = layer_data.data[data_index]
					if tile_id > 0:
						var sprite = _create_tile_sprite(tile_id, x, y, tile_width, tile_height)
						if sprite:
							layer_node.add_child(sprite)
				data_index += 1

	# Create markers container
	var markers_container = Node2D.new()
	markers_container.name = "Markers"
	markers_container.z_index = 100
	map_preview.add_child(markers_container)


func _load_tilesets_for_map():
	"""Load tileset images referenced in the TMX"""
	loaded_tilesets.clear()

	# Load the Odyssey tileset parts (tiles_part1.png, tiles_part2.png)
	var tileset1 = load("res://assets-odyssey/tiles_part1.png")
	var tileset2 = load("res://assets-odyssey/tiles_part2.png")

	if tileset1:
		loaded_tilesets[1] = tileset1
		print("[MapLinker] Loaded tiles_part1.png")
	else:
		push_error("[MapLinker] Failed to load tiles_part1.png")

	if tileset2:
		loaded_tilesets[2] = tileset2
		print("[MapLinker] Loaded tiles_part2.png")
	else:
		push_error("[MapLinker] Failed to load tiles_part2.png")

	print("[MapLinker] Loaded %d tileset images" % loaded_tilesets.size())


func _create_tile_sprite(tile_id: int, x: int, y: int, tile_width: int, tile_height: int) -> Sprite2D:
	"""Create a sprite for a single tile"""
	# Determine which tileset this tile belongs to
	# Tiled uses 1-based tile IDs, with different ranges for different tilesets

	var tileset_key = 1
	var local_id = tile_id - 1  # Convert to 0-based

	# Check tileset ranges (from sample_map.tmx: firstgid=1, 3585, 6980)
	if tile_id >= 6980:
		tileset_key = 3  # collision_tileset
		local_id = tile_id - 6980
	elif tile_id >= 3585:
		tileset_key = 2  # sprites_part2
		local_id = tile_id - 3585
	else:
		tileset_key = 1  # sprites_part1
		local_id = tile_id - 1

	if not loaded_tilesets.has(tileset_key):
		# Skip collision tileset tiles (they're invisible markers)
		if tileset_key == 3:
			return null
		return null

	var sprite = Sprite2D.new()
	sprite.texture = loaded_tilesets[tileset_key]
	sprite.centered = false

	# Calculate atlas coordinates
	# Assuming tileset is 7 tiles wide (like the TMX loader assumes)
	var atlas_columns = 7
	if loaded_tilesets[tileset_key]:
		atlas_columns = int(loaded_tilesets[tileset_key].get_width() / tile_width)

	var atlas_x = local_id % atlas_columns
	var atlas_y = local_id / atlas_columns

	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		atlas_x * tile_width,
		atlas_y * tile_height,
		tile_width,
		tile_height
	)

	sprite.position = Vector2(x * tile_width, y * tile_height)

	return sprite


func _load_objects_from_tmx():
	"""Load warps, NPC spawns, player spawn from TMX object groups"""
	warp_markers.clear()
	npc_markers.clear()
	player_spawn_marker = null

	var markers_container = map_preview.get_node_or_null("Markers")
	if not markers_container:
		return

	for group in current_tmx_data.object_groups:
		var group_name = group.name.to_lower()

		for obj in group.objects:
			var obj_type = obj.properties.get("type", "")

			if group_name == "warps" or obj_type == "warp":
				var marker = _create_warp_marker(obj)
				markers_container.add_child(marker)
				warp_markers.append(marker)
			elif group_name == "npcspawns" or obj_type == "npc_spawn":
				var marker = _create_npc_marker(obj)
				markers_container.add_child(marker)
				npc_markers.append(marker)
			elif group_name == "playerspawn" or obj_type == "player_spawn":
				player_spawn_marker = _create_player_marker(obj)
				markers_container.add_child(player_spawn_marker)


func _create_warp_marker(obj: Dictionary) -> Node2D:
	"""Create visual marker for warp zone"""
	var marker = Node2D.new()
	marker.name = "Warp_" + str(obj.id)
	marker.position = Vector2(obj.x, obj.y)
	marker.set_meta("object_data", obj)

	# Create colored rectangle
	var rect = ColorRect.new()
	rect.color = Color(1.0, 0.0, 1.0, 0.5)  # Magenta
	rect.size = Vector2(obj.width if obj.width > 0 else 32, obj.height if obj.height > 0 else 32)
	marker.add_child(rect)

	# Add label
	var label = Label.new()
	label.text = "W"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(4, 4)
	marker.add_child(label)

	return marker


func _create_npc_marker(obj: Dictionary) -> Node2D:
	"""Create visual marker for NPC spawn"""
	var marker = Node2D.new()
	marker.name = "NPC_" + str(obj.id)
	marker.position = Vector2(obj.x, obj.y)
	marker.set_meta("object_data", obj)

	# Create colored rectangle
	var rect = ColorRect.new()
	rect.color = Color(0.0, 1.0, 0.0, 0.5)  # Green
	rect.size = Vector2(obj.width if obj.width > 0 else 32, obj.height if obj.height > 0 else 32)
	marker.add_child(rect)

	# Add label
	var label = Label.new()
	label.text = obj.properties.get("npc_id", "NPC")
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(2, 2)
	marker.add_child(label)

	return marker


func _create_player_marker(obj: Dictionary) -> Node2D:
	"""Create visual marker for player spawn"""
	var marker = Node2D.new()
	marker.name = "PlayerSpawn"
	marker.position = Vector2(obj.x, obj.y)
	marker.set_meta("object_data", obj)

	# Create colored diamond shape
	var rect = ColorRect.new()
	rect.color = Color(0.0, 0.5, 1.0, 0.7)  # Blue
	rect.size = Vector2(obj.width if obj.width > 0 else 32, obj.height if obj.height > 0 else 32)
	marker.add_child(rect)

	# Add label
	var label = Label.new()
	label.text = "P"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(8, 4)
	marker.add_child(label)

	return marker


func _update_object_list():
	"""Update the object list panel"""
	object_list.clear()

	# Add warps
	for i in range(warp_markers.size()):
		var marker = warp_markers[i]
		var obj_data = marker.get_meta("object_data", {})
		var target = obj_data.properties.get("target_map", "?")
		object_list.add_item("Warp %d -> %s" % [i + 1, target])
		object_list.set_item_metadata(object_list.item_count - 1, {"type": "warp", "index": i})

	# Add NPC spawns
	for i in range(npc_markers.size()):
		var marker = npc_markers[i]
		var obj_data = marker.get_meta("object_data", {})
		var npc_id = obj_data.properties.get("npc_id", "Unknown")
		object_list.add_item("NPC: %s" % npc_id)
		object_list.set_item_metadata(object_list.item_count - 1, {"type": "npc", "index": i})

	# Add player spawn
	if player_spawn_marker:
		object_list.add_item("Player Spawn")
		object_list.set_item_metadata(object_list.item_count - 1, {"type": "player", "index": 0})


func _on_object_selected(index: int):
	"""Handle object selection in list"""
	selected_object_index = index
	var metadata = object_list.get_item_metadata(index)

	if not metadata:
		return

	# Highlight selected object
	_highlight_object(metadata)

	# Show properties
	_show_object_properties(metadata)


func _highlight_object(metadata: Dictionary):
	"""Highlight the selected object on the map"""
	# Reset all highlights
	for marker in warp_markers:
		marker.modulate = Color.WHITE
	for marker in npc_markers:
		marker.modulate = Color.WHITE
	if player_spawn_marker:
		player_spawn_marker.modulate = Color.WHITE

	# Highlight selected
	var obj_type = metadata.get("type", "")
	var obj_index = metadata.get("index", 0)

	if obj_type == "warp" and obj_index < warp_markers.size():
		warp_markers[obj_index].modulate = Color(1.5, 1.5, 0.5)
		_center_camera_on(warp_markers[obj_index].position)
	elif obj_type == "npc" and obj_index < npc_markers.size():
		npc_markers[obj_index].modulate = Color(1.5, 1.5, 0.5)
		_center_camera_on(npc_markers[obj_index].position)
	elif obj_type == "player" and player_spawn_marker:
		player_spawn_marker.modulate = Color(1.5, 1.5, 0.5)
		_center_camera_on(player_spawn_marker.position)


func _show_object_properties(metadata: Dictionary):
	"""Show properties for selected object"""
	# Clear existing properties
	for child in properties_container.get_children():
		child.queue_free()

	var obj_type = metadata.get("type", "")
	var obj_index = metadata.get("index", 0)
	var obj_data: Dictionary = {}

	if obj_type == "warp" and obj_index < warp_markers.size():
		obj_data = warp_markers[obj_index].get_meta("object_data", {})
		_create_warp_properties(obj_data)
	elif obj_type == "npc" and obj_index < npc_markers.size():
		obj_data = npc_markers[obj_index].get_meta("object_data", {})
		_create_npc_properties(obj_data)
	elif obj_type == "player" and player_spawn_marker:
		obj_data = player_spawn_marker.get_meta("object_data", {})
		_create_player_properties(obj_data)


func _create_warp_properties(obj_data: Dictionary):
	"""Create property fields for warp"""
	var title = Label.new()
	title.text = "WARP PROPERTIES"
	title.add_theme_font_size_override("font_size", 14)
	properties_container.add_child(title)

	_add_property_label("Target Map:", obj_data.properties.get("target_map", ""))
	_add_property_label("Target X:", str(obj_data.properties.get("target_x", 0)))
	_add_property_label("Target Y:", str(obj_data.properties.get("target_y", 0)))
	_add_property_label("Trigger:", obj_data.properties.get("trigger", "touch"))
	_add_property_label("Position:", "%.0f, %.0f" % [obj_data.x, obj_data.y])


func _create_npc_properties(obj_data: Dictionary):
	"""Create property fields for NPC spawn"""
	var title = Label.new()
	title.text = "NPC SPAWN PROPERTIES"
	title.add_theme_font_size_override("font_size", 14)
	properties_container.add_child(title)

	_add_property_label("NPC ID:", obj_data.properties.get("npc_id", ""))
	_add_property_label("Facing:", obj_data.properties.get("facing", "down"))
	_add_property_label("Spawn Count:", str(obj_data.properties.get("spawn_count", 1)))
	_add_property_label("Position:", "%.0f, %.0f" % [obj_data.x, obj_data.y])


func _create_player_properties(obj_data: Dictionary):
	"""Create property fields for player spawn"""
	var title = Label.new()
	title.text = "PLAYER SPAWN PROPERTIES"
	title.add_theme_font_size_override("font_size", 14)
	properties_container.add_child(title)

	_add_property_label("Facing:", obj_data.properties.get("facing", "down"))
	_add_property_label("Position:", "%.0f, %.0f" % [obj_data.x, obj_data.y])


func _add_property_label(name: String, value: String):
	"""Add a property label to the properties panel"""
	var hbox = HBoxContainer.new()
	properties_container.add_child(hbox)

	var name_label = Label.new()
	name_label.text = name
	name_label.custom_minimum_size.x = 80
	hbox.add_child(name_label)

	var value_label = Label.new()
	value_label.text = value
	hbox.add_child(value_label)


func _reset_camera():
	"""Reset camera to show map from top-left"""
	if current_tmx_data.is_empty():
		return

	var map_width = current_tmx_data.width * current_tmx_data.tilewidth
	var map_height = current_tmx_data.height * current_tmx_data.tileheight

	# Set zoom to fit map or use 1:1 if map is small
	var viewport_size = viewport_container.size
	var zoom_x = viewport_size.x / map_width
	var zoom_y = viewport_size.y / map_height
	zoom_level = min(zoom_x, zoom_y)
	zoom_level = clamp(zoom_level, 0.25, 2.0)

	map_camera.zoom = Vector2(zoom_level, zoom_level)

	# Position camera so top-left of map is visible
	# Camera position is the center of view, so offset by half viewport
	var view_width = viewport_size.x / zoom_level
	var view_height = viewport_size.y / zoom_level
	map_camera.position = Vector2(view_width / 2, view_height / 2)

	_update_zoom_label()
	print("[MapLinker] Camera reset: pos=%s, zoom=%s, map=%dx%d" % [map_camera.position, zoom_level, map_width, map_height])


func _center_camera_on(pos: Vector2):
	"""Center camera on a position"""
	map_camera.position = pos


func _on_viewport_input(event: InputEvent):
	"""Handle input on the map preview"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			# Left or middle mouse for panning
			is_panning = event.pressed
			if is_panning:
				pan_start = event.position
				camera_start = map_camera.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom in
			_zoom(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out
			_zoom(0.9)
	elif event is InputEventMouseMotion:
		if is_panning:
			var delta = event.position - pan_start
			map_camera.position = camera_start - delta / zoom_level


func _zoom(factor: float):
	"""Apply zoom factor"""
	zoom_level *= factor
	zoom_level = clamp(zoom_level, 0.1, 4.0)
	map_camera.zoom = Vector2(zoom_level, zoom_level)
	_update_zoom_label()


func _update_zoom_label():
	"""Update zoom level display"""
	zoom_label.text = "Zoom: %.0f%%" % (zoom_level * 100)


# === Button Handlers ===

func _on_back_button_pressed():
	"""Return to main menu"""
	get_tree().change_scene_to_file("res://source/common/main.tscn")


func _on_refresh_button_pressed():
	"""Rescan maps directory"""
	_scan_maps_directory()


func _on_zoom_in_pressed():
	"""Zoom in button"""
	_zoom(1.25)


func _on_zoom_out_pressed():
	"""Zoom out button"""
	_zoom(0.8)


func _on_zoom_reset_pressed():
	"""Reset zoom button"""
	_reset_camera()


func _on_place_warp_pressed():
	"""Enter warp placement mode"""
	current_mode = PlacementMode.WARP
	status_label.text = "Click on map to place warp (ESC to cancel)"


func _on_place_spawn_pressed():
	"""Enter NPC spawn placement mode"""
	current_mode = PlacementMode.NPC_SPAWN
	status_label.text = "Click on map to place NPC spawn (ESC to cancel)"


func _on_place_player_pressed():
	"""Enter player spawn placement mode"""
	current_mode = PlacementMode.PLAYER_SPAWN
	status_label.text = "Click on map to place player spawn (ESC to cancel)"


func _on_save_pressed():
	"""Save changes to TMX file"""
	# TODO: Implement TMX saving in Phase 3
	status_label.text = "Save not yet implemented (Phase 3)"


func _input(event: InputEvent):
	"""Handle global input"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			current_mode = PlacementMode.NONE
			status_label.text = "Placement cancelled"
