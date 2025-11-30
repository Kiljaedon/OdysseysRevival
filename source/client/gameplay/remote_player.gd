extends Node2D
## Remote Player - Represents another player in the world

@onready var sprite: AnimatedSprite2D
@onready var name_label: Label

var peer_id: int = 0
var character_name: String = ""
var sprite_row: int = 0
var sprite_col: int = 0


func _ready():
	# Create sprite
	sprite = AnimatedSprite2D.new()
	sprite.offset = Vector2(0, -30)
	sprite.centered = true
	add_child(sprite)
	
	# Create name tag
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-50, -90)  # Above sprite
	name_label.size = Vector2(100, 20)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	add_child(name_label)


func setup(player_data: Dictionary):
	"""Initialize remote player with data from server"""
	peer_id = player_data.get("peer_id", 0)
	character_name = player_data.get("character_name", "Unknown")
	sprite_row = player_data.get("sprite_row", 0)
	sprite_col = player_data.get("sprite_col", 0)

	# Set name tag
	name_label.text = character_name

	# Load sprite from atlas
	load_sprite()


func load_sprite():
	"""Load character sprite from atlas"""
	var atlas = load("res://artwork/odyssey_sprites_part1.png")
	
	if not atlas:
		push_error("Failed to load odyssey_sprites_part1.png")
		return
	
	# Create sprite frames for walking animations
	var sprite_frames = SpriteFrames.new()
	
	# Define animations: walk_down, walk_left, walk_right, walk_up
	var directions = ["walk_down", "walk_left", "walk_right", "walk_up"]
	var frame_offsets = [0, 3, 6, 9]  # Column offsets for each direction
	
	for i in range(directions.size()):
		var anim_name = directions[i]
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_loop(anim_name, true)
		sprite_frames.set_animation_speed(anim_name, 8.0)
		
		# Add 3 frames for walking animation
		for frame in range(3):
			var col = sprite_col + frame_offsets[i] + frame
			var texture = get_sprite_from_atlas(atlas, sprite_row, col)
			sprite_frames.add_frame(anim_name, texture)
	
	sprite.sprite_frames = sprite_frames
	sprite.play("walk_down")


func get_sprite_from_atlas(atlas: Texture2D, row: int, col: int) -> AtlasTexture:
	"""Extract a sprite from the atlas"""
	var sprite_width = 32
	var sprite_height = 32
	var y_offset = 0

	# Special handling for Cleric (row 102)
	if row == 102:
		sprite_height = 38
		y_offset = -1

	var atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = atlas

	var x = col * sprite_width
	# Always use 32 for row calculation (standard row height in sprite sheet)
	var y = row * 32 + y_offset

	atlas_texture.region = Rect2(x, y, sprite_width, sprite_height)

	return atlas_texture


func update_position(new_position: Vector2):
	"""Update player position (smooth interpolation)"""
	# Simple lerp for now, can add more sophisticated interpolation later
	position = position.lerp(new_position, 0.3)


func update_animation(direction: String):
	"""Update animation based on movement direction"""
	if sprite and sprite.sprite_frames:
		var anim_name = "walk_" + direction
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)
