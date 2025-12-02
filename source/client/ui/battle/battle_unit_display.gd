class_name BattleUnitDisplay
extends RefCounted

## BattleUnitDisplay - Handles sprite rendering, animations, and scaling for battle units
## Pure display component with no dragging/input logic

# Sprite and animation state
var sprite_node: TextureRect = null
var current_direction: String = "down"
var animation_frame: int = 0
var sprite_scale: float = 1.0
var character_data: Dictionary = {}
var battle_window: Node = null

# Scale limits
var min_scale: float = 0.1
var max_scale: float = 5.0
var zoom_step: float = 0.1

# Animation definitions
var direction_animations: Dictionary = {
	"down": ["walk_down_1", "walk_down_2"],
	"up": ["walk_up_1", "walk_up_2"],
	"left": ["walk_left_1", "walk_left_2"],
	"right": ["walk_right_1", "walk_right_2"]
}

var attack_animations: Dictionary = {
	"down": "attack_down",
	"up": "attack_up",
	"left": "attack_left",
	"right": "attack_right"
}


func initialize(sprite: TextureRect, battle_win: Node) -> void:
	"""Initialize with sprite node and battle window reference"""
	sprite_node = sprite
	battle_window = battle_win

	if sprite_node:
		sprite_node.mouse_filter = Control.MOUSE_FILTER_STOP
		sprite_node.z_index = 50


func set_character_data(data: Dictionary) -> void:
	"""Set character data for animation lookups"""
	character_data = data


func cycle_animation_frame() -> void:
	"""Cycle to next walk animation frame in current direction"""
	var animations = direction_animations.get(current_direction, ["walk_down_1"])
	animation_frame = (animation_frame + 1) % animations.size()
	var anim_name = animations[animation_frame]

	apply_character_animation(anim_name)


func trigger_attack_animation() -> void:
	"""Play attack animation in current direction"""
	var anim_name = attack_animations.get(current_direction, "attack_down")
	apply_character_animation(anim_name)


func apply_character_animation(anim_name: String) -> void:
	"""Load and display the character animation sprite"""
	if not sprite_node or not character_data.has("animations"):
		return

	if not character_data.animations.has(anim_name):
		print("WARN: Character missing animation: ", anim_name)
		return

	var anim_frames = character_data.animations[anim_name]
	if anim_frames.size() == 0:
		print("WARN: Animation ", anim_name, " is empty")
		return

	# Get first frame of animation
	var frame_data = anim_frames[0]
	var atlas_index = frame_data.get("atlas_index", 0)
	var row = frame_data.get("row", 0)
	var col = frame_data.get("col", 0)

	# Get texture from battle window
	if battle_window and battle_window.has_method("get_sprite_texture_from_coords"):
		var texture = battle_window.get_sprite_texture_from_coords(atlas_index, row, col)
		if texture:
			sprite_node.texture = texture


func set_direction(direction: String) -> void:
	"""Set current facing direction"""
	if direction in ["up", "down", "left", "right"]:
		current_direction = direction


func zoom_in() -> void:
	"""Increase sprite scale"""
	sprite_scale = clamp(sprite_scale + zoom_step, min_scale, max_scale)
	apply_sprite_scale()


func zoom_out() -> void:
	"""Decrease sprite scale"""
	sprite_scale = clamp(sprite_scale - zoom_step, min_scale, max_scale)
	apply_sprite_scale()


func apply_sprite_scale() -> void:
	"""Apply current scale to sprite"""
	if sprite_node:
		var base_sprite_size = 120.0
		var new_size = base_sprite_size * sprite_scale
		sprite_node.custom_minimum_size = Vector2(new_size, new_size)


func get_sprite_display_size() -> Vector2:
	"""Get current sprite display size for panel sizing"""
	if sprite_node:
		return sprite_node.custom_minimum_size
	return Vector2(120, 120)


func get_display_data() -> Dictionary:
	"""Get display state for layout persistence"""
	return {
		"sprite_scale": sprite_scale,
		"current_direction": current_direction,
		"animation_frame": animation_frame
	}


func apply_display_data(data: Dictionary) -> void:
	"""Restore display state from layout data"""
	if data.has("sprite_scale"):
		sprite_scale = data.sprite_scale
		apply_sprite_scale()

	if data.has("current_direction"):
		current_direction = data.current_direction

	if data.has("animation_frame"):
		animation_frame = data.animation_frame
