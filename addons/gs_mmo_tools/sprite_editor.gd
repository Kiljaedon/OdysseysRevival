@tool
## Golden Sun MMO Sprite Animation Editor
## Based on Odyssey sprite system with proper quality standards
class_name GSMMOSpriteEditor extends Control

## The sprite sheet resource to load and edit
@export var sprite_sheet_path: String = "res://assets-odyssey/sprites_part1.png"

## Individual sprite size in the sheet
@export var sprite_grid_size: Vector2i = Vector2i(32, 32)

## Maximum number of sprites to display (performance limit)
@export var max_sprites_displayed: int = 500

# Private members - following GDQuest patterns
var _sprite_sheet_texture: Texture2D
var _current_animation: String = ""
var _current_frame: int = 0
var _animations: Dictionary = {}

# Node references - using proper @onready pattern from existing code
@onready var _sprite_preview: TextureRect = $VBox/HBox/Preview/SpritePreview
@onready var _animation_list: ItemList = $VBox/HBox/Controls/AnimationList
@onready var _frame_list: ItemList = $VBox/HBox/Controls/FrameList
@onready var _grid_container: GridContainer = $VBox/HBox/SpriteSheet/ScrollContainer/GridContainer

# Signals following the documentation pattern
@warning_ignore("unused_signal")
signal animation_selected(animation_name: String)
@warning_ignore("unused_signal")
signal frame_selected(frame_index: int)

func _ready() -> void:
	_validate_setup()
	_initialize_animations()
	if _load_sprite_sheet():
		_create_sprite_grid()
		_populate_animation_list()

func _validate_setup() -> void:
	"""Validate that all required nodes exist"""
	var required_nodes = [
		"VBox/HBox/Preview/SpritePreview",
		"VBox/HBox/Controls/AnimationList",
		"VBox/HBox/Controls/FrameList",
		"VBox/HBox/SpriteSheet/ScrollContainer/GridContainer"
	]

	for node_path in required_nodes:
		if not has_node(node_path):
			push_error("SpriteEditor: Required node not found: " + node_path)

func _initialize_animations() -> void:
	"""Setup predefined Golden Sun style animations"""
	_animations = {
		"idle_down": {"frames": [0, 1], "direction": "down"},
		"idle_up": {"frames": [2, 3], "direction": "up"},
		"idle_left": {"frames": [4, 5], "direction": "left"},
		"idle_right": {"frames": [6, 7], "direction": "right"},
		"walk_down": {"frames": [8, 9, 10, 11], "direction": "down"},
		"walk_up": {"frames": [12, 13, 14, 15], "direction": "up"},
		"walk_left": {"frames": [16, 17, 18, 19], "direction": "left"},
		"walk_right": {"frames": [20, 21, 22, 23], "direction": "right"},
		"attack_down": {"frames": [24, 25, 26], "direction": "down"},
		"attack_up": {"frames": [27, 28, 29], "direction": "up"},
		"cast_spell": {"frames": [30, 31, 32, 33], "direction": "down"},
		"djinn_summon": {"frames": [34, 35, 36, 37, 38], "direction": "down"}
	}

func _load_sprite_sheet() -> bool:
	"""Load the sprite sheet with proper error handling"""
	if sprite_sheet_path.is_empty():
		push_warning("SpriteEditor: No sprite sheet path specified")
		return false

	if not ResourceLoader.exists(sprite_sheet_path):
		push_error("SpriteEditor: Sprite sheet not found: " + sprite_sheet_path)
		return false

	var resource = load(sprite_sheet_path)
	if not resource is Texture2D:
		push_error("SpriteEditor: Resource is not a Texture2D: " + sprite_sheet_path)
		return false

	_sprite_sheet_texture = resource as Texture2D
	print("SpriteEditor: Loaded sprite sheet: ", _sprite_sheet_texture.get_size())
	return true

func _create_sprite_grid() -> void:
	"""Create clickable grid from sprite sheet with performance limits"""
	if not _sprite_sheet_texture or not _grid_container:
		return

	var sheet_size = _sprite_sheet_texture.get_size()
	var cols = int(sheet_size.x / sprite_grid_size.x)
	var rows = int(sheet_size.y / sprite_grid_size.y)
	var total_sprites = cols * rows

	_grid_container.columns = cols

	# Performance limit - don't create too many UI elements
	var sprites_to_create = mini(total_sprites, max_sprites_displayed)

	for i in range(sprites_to_create):
		var row = i / cols
		var col = i % cols

		var sprite_button = Button.new()
		sprite_button.custom_minimum_size = sprite_grid_size
		sprite_button.pressed.connect(_on_sprite_selected.bind(col, row))

		var atlas_texture = _create_atlas_texture(col, row)
		if atlas_texture:
			sprite_button.icon = atlas_texture

		_grid_container.add_child(sprite_button)

func _create_atlas_texture(col: int, row: int) -> AtlasTexture:
	"""Create an atlas texture for a specific sprite with bounds checking"""
	if not _sprite_sheet_texture:
		return null

	var sheet_size = _sprite_sheet_texture.get_size()
	var x = col * sprite_grid_size.x
	var y = row * sprite_grid_size.y

	# Bounds checking
	if x >= sheet_size.x or y >= sheet_size.y:
		return null

	var atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = _sprite_sheet_texture
	atlas_texture.region = Rect2(x, y, sprite_grid_size.x, sprite_grid_size.y)

	return atlas_texture

func _populate_animation_list() -> void:
	"""Populate the animation list UI"""
	if not _animation_list:
		return

	_animation_list.clear()
	for anim_name in _animations.keys():
		_animation_list.add_item(anim_name)

func _on_sprite_selected(col: int, row: int) -> void:
	"""Handle sprite selection from grid with bounds checking"""
	if not _sprite_sheet_texture:
		return

	var cols = _sprite_sheet_texture.get_size().x / sprite_grid_size.x
	var sprite_index = row * cols + col

	print("SpriteEditor: Selected sprite index: ", sprite_index)
	_update_sprite_preview(col, row)

func _update_sprite_preview(col: int, row: int) -> void:
	"""Update the sprite preview display with error handling"""
	if not _sprite_preview:
		return

	var atlas_texture = _create_atlas_texture(col, row)
	if atlas_texture:
		_sprite_preview.texture = atlas_texture

func _on_animation_selected(index: int) -> void:
	"""Handle animation selection with bounds checking"""
	if not _animation_list or index < 0 or index >= _animation_list.get_item_count():
		return

	_current_animation = _animation_list.get_item_text(index)
	print("SpriteEditor: Selected animation: ", _current_animation)

	_update_frame_list()
	animation_selected.emit(_current_animation)

func _update_frame_list() -> void:
	"""Update frame list for current animation"""
	if not _frame_list or not _current_animation in _animations:
		return

	_frame_list.clear()
	var frames = _animations[_current_animation]["frames"]

	for i in range(frames.size()):
		_frame_list.add_item("Frame " + str(i))

func _on_frame_selected(index: int) -> void:
	"""Handle frame selection with bounds checking"""
	if not _current_animation in _animations:
		return

	var frames = _animations[_current_animation]["frames"]
	if index < 0 or index >= frames.size():
		return

	_current_frame = index
	frame_selected.emit(index)

	# Update preview to show this frame
	var sprite_index = frames[index]
	if _sprite_sheet_texture:
		var cols = _sprite_sheet_texture.get_size().x / sprite_grid_size.x
		var col = sprite_index % int(cols)
		var row = sprite_index / int(cols)
		_update_sprite_preview(col, row)

func save_animation_data(path: String) -> bool:
	"""Save animation configuration to JSON with error handling"""
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("SpriteEditor: Cannot open file for writing: " + path)
		return false

	var data = {
		"sprite_sheet": sprite_sheet_path,
		"grid_size": {"x": sprite_grid_size.x, "y": sprite_grid_size.y},
		"animations": _animations
	}

	file.store_string(JSON.stringify(data))
	file.close()
	print("SpriteEditor: Animation data saved to: ", path)
	return true

func load_animation_data(path: String) -> bool:
	"""Load animation configuration from JSON with error handling"""
	if not FileAccess.file_exists(path):
		push_error("SpriteEditor: File does not exist: " + path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("SpriteEditor: Cannot open file for reading: " + path)
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var result = json.parse(json_string)
	if result != OK:
		push_error("SpriteEditor: Invalid JSON in file: " + path)
		return false

	var data = json.data
	if not data is Dictionary:
		push_error("SpriteEditor: Invalid data format in file: " + path)
		return false

	_animations = data.get("animations", {})
	_populate_animation_list()
	print("SpriteEditor: Animation data loaded from: ", path)
	return true