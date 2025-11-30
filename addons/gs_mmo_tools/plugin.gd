@tool
extends EditorPlugin

## Golden Sun MMO Development Tools Plugin
## Provides sprite animation editor and map editor based on Odyssey system

var sprite_editor_dock: Control
# map_editor_dock removed - using standalone system

func _enter_tree() -> void:
	print("Golden Sun MMO Tools - Plugin Loading...")

	# Ensure essential resources exist before loading tools
	_create_tileset_if_missing()

	# Load editors with error handling
	if _load_sprite_editor():
		print("Golden Sun MMO Tools - Sprite Editor loaded")
	else:
		push_warning("Golden Sun MMO Tools - Failed to load Sprite Editor")

	# Map editor now handled by standalone system (gateway.gd -> standalone_map_editor.tscn)
	# Old plugin-based map editor disabled to prevent conflicts
	print("Golden Sun MMO Tools - Map Editor (using standalone system)")

	print("Golden Sun MMO Tools - Plugin Loaded")

func _create_tileset_if_missing():
	const TILESET_IMAGE_PATH = "res://assets-odyssey/tiles_part1.png"
	const TILESET_RESOURCE_PATH = "res://addons/gs_mmo_tools/resources/main_tileset.tres"
	
	if not ResourceLoader.exists(TILESET_RESOURCE_PATH):
		print("Golden Sun MMO Tools - main_tileset.tres not found. Creating it automatically...")
		if not ResourceLoader.exists(TILESET_IMAGE_PATH):
			push_error("Golden Sun MMO Tools - Cannot create tileset: tiles_part1.png not found at " + TILESET_IMAGE_PATH)
			return

		var source_image = load(TILESET_IMAGE_PATH)
		var new_tileset = TileSet.new()
		var new_source = TileSetAtlasSource.new()
		
		new_source.texture = source_image
		new_source.texture_region_size = Vector2i(32, 32)
		new_tileset.add_source(new_source)
		
		var error = ResourceSaver.save(new_tileset, TILESET_RESOURCE_PATH)
		if error == OK:
			print("Golden Sun MMO Tools - Successfully created main_tileset.tres")
		else:
			push_error("Golden Sun MMO Tools - Failed to save main_tileset.tres. Error: " + str(error))

func _load_sprite_editor() -> bool:
	"""Load sprite editor with error handling"""
	var sprite_editor_scene = load("res://addons/gs_mmo_tools/sprite_editor.tscn")
	if not sprite_editor_scene:
		push_error("Golden Sun MMO Tools - Cannot load sprite_editor.tscn")
		return false

	sprite_editor_dock = sprite_editor_scene.instantiate()
	if not sprite_editor_dock:
		push_error("Golden Sun MMO Tools - Cannot instantiate sprite editor")
		return false

	add_control_to_dock(DOCK_SLOT_LEFT_UL, sprite_editor_dock)
	return true

# _load_map_editor() removed - now using standalone system (gateway.gd -> standalone_map_editor.tscn)

func _exit_tree() -> void:
	# Clean up safely
	if sprite_editor_dock:
		remove_control_from_docks(sprite_editor_dock)
		sprite_editor_dock = null

	# Map editor dock no longer used (using standalone system)

	print("Golden Sun MMO Tools - Plugin Unloaded")
