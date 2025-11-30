extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var tilemap: TileMapLayer = get_parent().get_node("TileMap")
@onready var map_button: Button = get_parent().get_node("UI/DevToolsPanel/VBox/MapSelection/MapButton")
@onready var char_button: Button = get_parent().get_node("UI/DevToolsPanel/VBox/CharSelection/CharButton")

var character_data: Dictionary = {}
var current_direction: String = "down"
var is_moving: bool = false
var is_attacking: bool = false
var move_speed: float = 128.0

var sprite_textures: Dictionary = {}

# Attack hitbox
var attack_hitbox: Area2D = null

var available_maps = [
	"res://maps/sample_map.tmx",
	"res://maps/odyssey_map_template.tmx",
	"res://maps/odyssey_enhanced_template.tmx"
]
var current_map_index = 0

func _ready():
	load_character_data("Knight")
	setup_animations()
	load_map(available_maps[current_map_index])

	# Connect buttons
	map_button.pressed.connect(_on_map_button_pressed)
	char_button.pressed.connect(_on_char_button_pressed)

	# Create attack hitbox
	create_attack_hitbox()

func load_character_data(character_name: String):
	var file_path = "res://characters/" + character_name + ".json"
	if not FileAccess.file_exists(file_path):
		print("Character file not found: " + file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Could not open character file")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("Invalid character JSON")
		return

	character_data = json.data
	print("Loaded character: " + character_data.get("character_name", "Unknown"))

func setup_animations():
	if character_data.is_empty():
		return

	# Load sprite textures
	for anim_name in character_data.animations:
		var frames = character_data.animations[anim_name]
		for frame_data in frames:
			var sprite_file = frame_data.sprite_file
			if not sprite_textures.has(sprite_file):
				var texture_path = "res://character_sprites/" + sprite_file
				if ResourceLoader.exists(texture_path):
					sprite_textures[sprite_file] = load(texture_path)

	# Setup initial sprite
	update_sprite()

func _physics_process(delta):
	if is_attacking:
		return

	handle_movement()
	handle_attack()
	move_and_slide()

func handle_movement():
	var input_vector = Vector2.ZERO

	# Get input
	if Input.is_action_pressed("up"):
		input_vector.y -= 1
		current_direction = "up"
	elif Input.is_action_pressed("down"):
		input_vector.y += 1
		current_direction = "down"
	elif Input.is_action_pressed("left"):
		input_vector.x -= 1
		current_direction = "left"
	elif Input.is_action_pressed("right"):
		input_vector.x += 1
		current_direction = "right"

	# Set velocity
	velocity = input_vector.normalized() * move_speed

	# Update movement state
	var was_moving = is_moving
	is_moving = input_vector != Vector2.ZERO

	# Update sprite if movement state changed
	if was_moving != is_moving:
		update_sprite()

func handle_attack():
	if Input.is_action_just_pressed("action") and not is_attacking:
		start_attack()

func start_attack():
	is_attacking = true
	velocity = Vector2.ZERO
	update_sprite()

	# Enable attack hitbox
	if attack_hitbox:
		attack_hitbox.monitoring = true
		print("Attack hitbox enabled")

	# Attack duration (0.3 seconds)
	await get_tree().create_timer(0.3).timeout

	# Disable attack hitbox
	if attack_hitbox:
		attack_hitbox.monitoring = false
		print("Attack hitbox disabled")

	is_attacking = false
	update_sprite()

func update_sprite():
	if character_data.is_empty():
		return

	var anim_name = get_animation_name()
	var frames = character_data.animations.get(anim_name, [])

	if frames.size() > 0:
		var frame_data = frames[0]  # Use first frame for now
		var sprite_file = frame_data.sprite_file
		if sprite_textures.has(sprite_file):
			# Create a simple SpriteFrames with one frame
			var sprite_frames = SpriteFrames.new()
			sprite_frames.add_animation("default")
			sprite_frames.add_frame("default", sprite_textures[sprite_file])
			sprite.sprite_frames = sprite_frames
			sprite.play("default")

func get_animation_name() -> String:
	if is_attacking:
		return "attack_" + current_direction
	elif is_moving:
		return "walk_" + current_direction + "_1"  # Use first walk frame
	else:
		return "walk_" + current_direction + "_1"  # Idle = first walk frame

func create_attack_hitbox():
	"""Create attack hitbox Area2D that detects NPC hurtboxes"""
	attack_hitbox = Area2D.new()
	attack_hitbox.collision_layer = 4  # Layer 4 for player attack hitbox
	attack_hitbox.collision_mask = 8  # Detect NPC hurtboxes on layer 8
	attack_hitbox.monitorable = true
	attack_hitbox.monitoring = false  # Disabled by default, enable during attack
	add_child(attack_hitbox)

	var hitbox_shape = CollisionShape2D.new()
	var hitbox_rect = RectangleShape2D.new()
	hitbox_rect.size = Vector2(70, 100)  # Slightly larger than player collision
	hitbox_shape.shape = hitbox_rect
	attack_hitbox.add_child(hitbox_shape)

	print("Attack hitbox created")

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://source/common/main.tscn")

func load_map(tmx_path: String):
	print("Loading map: " + tmx_path)

	if not FileAccess.file_exists(tmx_path):
		print("Map file not found: " + tmx_path)
		return

	var file = FileAccess.open(tmx_path, FileAccess.READ)
	if not file:
		print("Could not open map file")
		return

	var tmx_content = file.get_as_text()
	file.close()

	parse_tmx_and_load(tmx_content)

func parse_tmx_and_load(tmx_content: String):
	# Simple TMX parser for bottom layer only
	var xml_parser = XMLParser.new()
	xml_parser.open_buffer(tmx_content.to_utf8_buffer())

	var map_width = 0
	var map_height = 0
	var tile_data = ""
	var in_bottom_layer = false

	while xml_parser.read() != ERR_FILE_EOF:
		if xml_parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name = xml_parser.get_node_name()

			if node_name == "map":
				map_width = xml_parser.get_named_attribute_value_safe("width").to_int()
				map_height = xml_parser.get_named_attribute_value_safe("height").to_int()
				print("Map size: ", map_width, "x", map_height)

			elif node_name == "layer":
				var layer_name = xml_parser.get_named_attribute_value_safe("name")
				in_bottom_layer = (layer_name == "Bottom (Terrain Base)")

			elif node_name == "data" and in_bottom_layer:
				xml_parser.read()
				tile_data = xml_parser.get_node_data().strip_edges()

	if tile_data != "":
		load_tiles_to_map(tile_data, map_width, map_height)

func load_tiles_to_map(csv_data: String, width: int, height: int):
	var rows = csv_data.split("\n")

	for y in range(height):
		if y >= rows.size():
			break
		var row = rows[y].strip_edges()
		if row == "":
			continue
		var tiles = row.split(",")

		for x in range(width):
			if x >= tiles.size():
				break
			var tile_id = tiles[x].strip_edges().to_int()
			if tile_id > 0:
				# TMX uses 1-based IDs, Godot uses 0-based
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i((tile_id - 1) % 32, (tile_id - 1) / 32))

	print("Map loaded successfully!")

func _on_map_button_pressed():
	# Cycle through available maps
	current_map_index = (current_map_index + 1) % available_maps.size()
	var map_path = available_maps[current_map_index]
	var map_name = map_path.get_file().get_basename()

	print("Switching to map: " + map_name)
	map_button.text = map_name

	# Clear current map
	tilemap.clear()

	# Load new map
	load_map(map_path)

func _on_char_button_pressed():
	print("Character selection coming in Phase 3!")
