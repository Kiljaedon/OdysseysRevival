class_name RealtimeBattleUnit
extends Node2D
## Realtime Battle Unit - Visual representation of a combat unit
## Handles sprite, animations, health bar, damage numbers

## ========== IMPORTS ==========
const EntityInterpolator = preload("res://source/client/combat/entity_interpolator.gd")

## ========== CONSTANTS ==========
const INTERPOLATION_SPEED: float = 8.0  # Fallback lerp speed
const SNAP_DISTANCE: float = 200.0  # Distance at which to snap to server position
const WALK_FRAME_DURATION: float = 0.15  # Seconds per walk frame
const SPRITE_SCALE: float = 4.0  # Match overworld sprite scale
const BASE_SPRITE_SIZE: int = 32  # Base sprite size before scaling

## ========== STATE ==========
var unit_id: String = ""
var unit_name: String = ""
var class_name_id: String = ""  # For loading sprites
var team: String = ""
var hp: int = 100
var max_hp: int = 100
var facing: String = "down"
var unit_state: String = "idle"
var is_dodge_rolling: bool = false
var is_player_controlled: bool = false

## Server position for interpolation (fallback for player)
var server_position: Vector2 = Vector2.ZERO
var server_velocity: Vector2 = Vector2.ZERO

## Entity interpolator for smooth remote unit movement
var interpolator: EntityInterpolator = null

## Animation state
var walk_frame: int = 1  # 1 or 2
var walk_timer: float = 0.0
var attack_timer: float = 0.0
var is_playing_attack: bool = false
const ATTACK_ANIM_DURATION: float = 0.3  # How long to show attack frame
var sprite_frames_data: Dictionary = {}  # Animation frames from character data
var character_sprite_manager = null  # Reference to load sprites

## ========== CHILD NODES ==========
var sprite: TextureRect
var stats_container: Control
var health_bar: ProgressBar
var mana_bar: ProgressBar
var energy_bar: ProgressBar
var name_label: Label
var damage_label: Label
var target_indicator: Node2D

## Stats
var mp: int = 50
var max_mp: int = 50
var energy: int = 100
var max_energy: int = 100

## ========== LIFECYCLE ==========

func _ready():
	_create_visuals()

	# Initialize interpolator for remote units (not for local player)
	if not is_player_controlled:
		interpolator = EntityInterpolator.new()

func _create_visuals():
	var scaled_size = BASE_SPRITE_SIZE * SPRITE_SCALE  # 128px

	# Sprite for character
	sprite = TextureRect.new()
	sprite.name = "Sprite"
	sprite.size = Vector2(scaled_size, scaled_size)
	sprite.position = Vector2(-scaled_size / 2, -scaled_size)
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(sprite)

	# --- NEW CLEAN STATS CONTAINER (VBox) ---
	var bar_width = 50.0
	
	# Use VBoxContainer for automatic, perfect stacking
	var vbox = VBoxContainer.new()
	vbox.name = "StatsContainer"
	vbox.custom_minimum_size = Vector2(bar_width, 0) # Height auto-calculated
	vbox.size = Vector2(bar_width, 0)
	# Position: Centered X, Lower Y (-36px above sprite) - Closer but not touching
	vbox.position = Vector2(-bar_width / 2, -scaled_size - 36)
	vbox.add_theme_constant_override("separation", 1) # 1px gap between bars
	vbox.z_index = 100
	vbox.z_as_relative = false
	stats_container = vbox # Keep reference
	add_child(stats_container)

	# 1. Name Label (Top)
	name_label = Label.new()
	name_label.text = unit_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.add_theme_constant_override("line_spacing", 0)
	stats_container.add_child(name_label)

	# 2. Health Bar (Red)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(bar_width, 4) # 4px tall
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_bar.show_percentage = false
	_style_bar(health_bar, Color(0.9, 0.2, 0.2, 1.0))
	stats_container.add_child(health_bar)

	# 3. Mana Bar (Blue)
	mana_bar = ProgressBar.new()
	mana_bar.custom_minimum_size = Vector2(bar_width, 3) # 3px tall
	mana_bar.max_value = max_mp
	mana_bar.value = mp
	mana_bar.show_percentage = false
	_style_bar(mana_bar, Color(0.2, 0.4, 1.0, 1.0))
	stats_container.add_child(mana_bar)

	# 4. Energy Bar (Yellow)
	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(bar_width, 3) # 3px tall
	energy_bar.max_value = max_energy
	energy_bar.value = energy
	energy_bar.show_percentage = false
	_style_bar(energy_bar, Color(1.0, 0.8, 0.1, 1.0))
	stats_container.add_child(energy_bar)

	# Damage label (floating text)
	damage_label = Label.new()
	damage_label.visible = false
	damage_label.position = Vector2(-15, -scaled_size / 2)
	damage_label.add_theme_font_size_override("font_size", 14)
	damage_label.add_theme_color_override("font_color", Color.RED)
	damage_label.add_theme_color_override("font_outline_color", Color.BLACK)
	damage_label.add_theme_constant_override("outline_size", 2)
	add_child(damage_label)

	# Target indicator
	target_indicator = Node2D.new()
	target_indicator.name = "TargetIndicator"
	target_indicator.visible = false
	add_child(target_indicator)
	_create_target_indicator()

func _create_target_indicator() -> void:
	"""Create small target indicator ring under unit feet"""
	# Small ellipse at feet using Line2D
	var ring = Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(1.0, 0.3, 0.3, 0.8)  # Red target ring
	# Draw small ellipse
	var points = PackedVector2Array()
	for i in range(17):
		var angle = i * PI * 2 / 16
		points.append(Vector2(cos(angle) * 20, sin(angle) * 8))
	ring.points = points
	target_indicator.add_child(ring)

func _create_slim_bar(x: float, y: float, width: float, height: float, fill_color: Color) -> ProgressBar:
	"""Create a slim progress bar for overhead stats - no labels, no background panel"""
	var bar = ProgressBar.new()
	bar.position = Vector2(x, y)
	bar.custom_minimum_size = Vector2(width, height)
	bar.size = Vector2(width, height)
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	bar.clip_contents = true
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# Dark background, colored fill
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	bg_style.set_corner_radius_all(1)
	bg_style.set_content_margin_all(0)
	bg_style.set_expand_margin_all(0)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(1)
	fill_style.set_content_margin_all(0)
	fill_style.set_expand_margin_all(0)

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	stats_container.add_child(bar)

	return bar

func _style_bar(bar: ProgressBar, fill_color: Color) -> void:
	"""Apply minimalist style to progress bar"""
	var corner_radius = 1
	
	# Background Style (Dark semi-transparent)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.4)
	bg_style.set_corner_radius_all(corner_radius)
	bg_style.set_content_margin_all(0)
	bg_style.set_expand_margin_all(0)
	bg_style.anti_aliasing = false

	# Fill Style (Value)
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(corner_radius)
	fill_style.set_content_margin_all(0)
	fill_style.set_expand_margin_all(0)
	fill_style.anti_aliasing = false

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
func _style_thin_bar(bar: ProgressBar, fill_color: Color, bg_color: Color) -> void:
	"""Style for thin bars - TRANSPARENT background, colored fill only"""
	# Background - nearly invisible dark tint
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.3)  # Dark transparent
	bg_style.set_corner_radius_all(0)
	bg_style.set_content_margin_all(0)
	bg_style.set_border_width_all(0)

	# Fill (the actual colored bar)
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(0)
	fill_style.set_content_margin_all(0)
	fill_style.set_border_width_all(0)

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)

func _process(delta: float):
	# Remote units: Use interpolator for smooth movement
	if not is_player_controlled and interpolator:
		var interp_state = interpolator.get_interpolated_state(Time.get_ticks_msec())

		if interp_state.has("position"):
			# Check for teleport (too far off)
			var diff = position.distance_to(interp_state.position)
			if diff > SNAP_DISTANCE:
				position = interp_state.position  # Snap
			else:
				position = interp_state.position  # Use interpolated position directly

		interpolator.cleanup_old_states(Time.get_ticks_msec())
	else:
		# Player unit: client-side prediction with gentle server reconciliation
		var diff = position.distance_to(server_position)
		if diff > SNAP_DISTANCE:
			position = server_position
		elif diff > 50:
			position = position.lerp(server_position, 3.0 * delta)

	# Handle attack animation timer
	if is_playing_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			is_playing_attack = false
			_update_sprite_frame()  # Return to walk/idle frame

	# Animate walk cycle when moving (check velocity, not just state)
	if not is_playing_attack:
		var is_moving = server_velocity.length() > 10 or (is_player_controlled and _local_velocity.length() > 10)
		if is_moving:
			walk_timer += delta
			if walk_timer >= WALK_FRAME_DURATION:
				walk_timer = 0.0
				walk_frame = 2 if walk_frame == 1 else 1
				_update_sprite_frame()
		else:
			# Reset to idle frame when stopped
			if walk_frame != 1:
				walk_frame = 1
				_update_sprite_frame()

var _local_velocity: Vector2 = Vector2.ZERO

func set_local_velocity(vel: Vector2) -> void:
	"""Called by controller for player movement prediction"""
	_local_velocity = vel
	if vel.length() > 10:
		_update_facing_from_velocity(vel)

## ========== INITIALIZATION ==========

func initialize(data: Dictionary) -> void:
	"""Initialize unit from server data"""
	unit_id = data.get("id", "")
	unit_name = data.get("name", "Unit")
	class_name_id = data.get("class_name", "")
	team = data.get("team", "enemy")
	
	# Robust stat initialization - check direct keys first, then source_data
	var source = data.get("source_data", {})
	var derived = source.get("derived_stats", {})
	var base = source.get("base_stats", {})
	
	# Max Stats (Hierarchy: direct > derived > base > default)
	max_hp = data.get("max_hp", derived.get("max_hp", base.get("hp", 100)))
	max_mp = data.get("max_mp", derived.get("max_mp", base.get("mp", 50)))
	max_energy = data.get("max_energy", derived.get("max_ep", base.get("energy", 100)))
	
	# Current Stats
	hp = data.get("hp", max_hp)
	mp = data.get("mp", max_mp)
	energy = data.get("energy", max_energy)

	facing = data.get("facing", "down")
	unit_state = data.get("state", "idle")
	is_dodge_rolling = data.get("is_dodge_rolling", false)
	is_player_controlled = data.get("is_player_controlled", false)

	server_position = data.get("position", Vector2.ZERO)
	position = server_position

	var npc_type = data.get("npc_type", "")
	print("[RT_UNIT] Init data: class=%s, npc_type=%s, team=%s, name=%s" % [class_name_id, npc_type, team, unit_name])
	print("[RT_UNIT] Stats: HP %d/%d, MP %d/%d, EP %d/%d" % [hp, max_hp, mp, max_mp, energy, max_energy])

	# Load sprite data from class_name or animations
	if data.has("animations") and not data.animations.is_empty():
		sprite_frames_data = data.animations
		print("[RT_UNIT] Using animations from server data")
	elif not class_name_id.is_empty():
		_load_sprites_from_class(class_name_id)
	elif team == "player" and unit_name != "Unit":
		# Player unit - try to get animations from character sprite manager
		_load_sprites_from_class("Warrior")  # Default to Warrior for now
	elif team == "enemy" and not npc_type.is_empty():
		# Try to load NPC sprites
		_load_sprites_from_npc(npc_type)
	elif team == "enemy":
		# Fallback to unit name
		_load_sprites_from_npc(unit_name)

	if sprite_frames_data.is_empty():
		print("[RT_UNIT] WARNING: No sprites loaded for %s!" % unit_id)

	# Update visuals - all units show HP, MP, and Energy
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = hp
	if mana_bar:
		mana_bar.max_value = max_mp
		mana_bar.value = mp
	if energy_bar:
		energy_bar.max_value = max_energy
		energy_bar.value = energy
	if name_label:
		name_label.text = unit_name

	# Player character renders on top of enemies
	if is_player_controlled:
		z_index = 10  # Player always on top
		# Keep overhead stats visible for player too (same as NPCs)
	else:
		z_index = 5   # Enemies below player

	# Set initial sprite
	_update_sprite_frame()
	print("[RT_UNIT] Initialized: %s (class=%s, team=%s)" % [unit_name, class_name_id, team])

func set_sprite_data(animations: Dictionary) -> void:
	"""Set sprite animation data (called after initialization if needed)"""
	sprite_frames_data = animations
	_update_sprite_frame()

func _load_sprites_from_class(class_name_str: String) -> void:
	"""Load sprite data from character class JSON"""
	var file_path = "res://characters/classes/" + class_name_str + ".json"
	_load_character_json(file_path)

func _load_sprites_from_npc(npc_name: String) -> void:
	"""Load sprite data from NPC JSON"""
	var file_path = "res://characters/npcs/" + npc_name + ".json"
	if not FileAccess.file_exists(file_path):
		# Try with lowercase
		file_path = "res://characters/npcs/" + npc_name.to_lower() + ".json"
	_load_character_json(file_path)

func _load_character_json(file_path: String) -> void:
	"""Load animations from character JSON file"""
	if not FileAccess.file_exists(file_path):
		print("[RT_UNIT] Character file not found: ", file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) == OK:
		var data = json.data
		if data.has("animations"):
			sprite_frames_data = data.animations
			print("[RT_UNIT] Loaded sprites from: ", file_path)
		else:
			print("[RT_UNIT] No animations in: ", file_path)
	else:
		print("[RT_UNIT] JSON parse error: ", file_path)

func _update_sprite_frame() -> void:
	"""Update sprite texture based on facing and animation state"""
	if not sprite or sprite_frames_data.is_empty():
		return

	var anim_key: String

	if is_playing_attack:
		# Show attack frame
		anim_key = "attack_%s" % facing
	else:
		# Show walk frame
		anim_key = "walk_%s_%d" % [facing, walk_frame]

	if not sprite_frames_data.has(anim_key):
		# Fallback to frame 1 of walk
		anim_key = "walk_%s_1" % facing

	if sprite_frames_data.has(anim_key):
		var frame_data = sprite_frames_data[anim_key]
		if frame_data is Array and frame_data.size() > 0:
			var tex = _load_frame_texture(frame_data[0])
			if tex:
				sprite.texture = tex

func play_attack_animation() -> void:
	"""Start playing attack animation"""
	is_playing_attack = true
	attack_timer = ATTACK_ANIM_DURATION
	_update_sprite_frame()

func _load_frame_texture(frame_info) -> Texture2D:
	"""Load texture from frame info dictionary"""
	if frame_info is Dictionary:
		if frame_info.has("texture"):
			return frame_info.texture
		if frame_info.has("path"):
			return load(frame_info.path)
		# Atlas format: atlas_index, row, col
		if frame_info.has("atlas_index"):
			return _get_sprite_from_atlas(
				frame_info.get("atlas_index", 0),
				frame_info.get("row", 0),
				frame_info.get("col", 0)
			)
	return null

## Static atlas cache
static var _sprite_atlas_textures: Array = []
static var _atlas_loaded: bool = false

func _get_sprite_from_atlas(atlas_index: int, row: int, col: int) -> Texture2D:
	"""Create AtlasTexture from coordinates"""
	# Lazy load atlases
	if not _atlas_loaded:
		var atlas1 = load("res://assets-odyssey/sprites_part1.png")
		var atlas2 = load("res://assets-odyssey/sprites_part2.png")
		if atlas1:
			_sprite_atlas_textures.append(atlas1)
		if atlas2:
			_sprite_atlas_textures.append(atlas2)
		_atlas_loaded = true

	if atlas_index >= _sprite_atlas_textures.size():
		return null

	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = _sprite_atlas_textures[atlas_index]

	# Calculate position - account for row offset in part2
	var local_row = row if atlas_index == 0 else row - 512
	var x = col * 32
	var y = local_row * 32

	# Apply 1px edge crop to remove black border artifacts
	atlas_tex.region = Rect2(x + 1, y + 1, 30, 30)
	return atlas_tex

## ========== FACING ==========

func _update_facing_from_velocity(vel: Vector2) -> void:
	"""Update facing direction based on movement velocity"""
	if vel.length() < 10:
		return

	var old_facing = facing

	# Determine primary direction (no diagonals)
	if abs(vel.x) > abs(vel.y):
		facing = "right" if vel.x > 0 else "left"
	else:
		facing = "down" if vel.y > 0 else "up"

	if facing != old_facing:
		_update_sprite_frame()

func get_facing_direction() -> Vector2:
	"""Get the direction vector the unit is facing"""
	match facing:
		"up": return Vector2(0, -1)
		"down": return Vector2(0, 1)
		"left": return Vector2(-1, 0)
		"right": return Vector2(1, 0)
	return Vector2(0, 1)

## ========== SERVER STATE ==========

func apply_server_state(state: Dictionary) -> void:
	"""Apply authoritative server state"""
	server_position = state.get("position", server_position)
	server_velocity = state.get("velocity", Vector2.ZERO)

	# Add state to interpolator for remote units
	if not is_player_controlled and interpolator:
		interpolator.add_state(state)

	var old_facing = facing
	var old_state = unit_state

	facing = state.get("facing", facing)
	unit_state = state.get("state", unit_state)
	is_dodge_rolling = state.get("is_dodge_rolling", false)

	var new_hp = state.get("hp", hp)
	if new_hp != hp:
		hp = new_hp
		if health_bar:
			health_bar.value = hp

	var new_mp = state.get("mp", mp)
	if new_mp != mp:
		mp = new_mp
		if mana_bar:
			mana_bar.value = mp

	var new_energy = state.get("energy", energy)
	if new_energy != energy:
		energy = new_energy
		if energy_bar:
			energy_bar.value = energy

	# Update facing from server velocity if moving
	if server_velocity.length() > 10:
		_update_facing_from_velocity(server_velocity)
	elif facing != old_facing or (old_state == "moving" and unit_state != "moving"):
		walk_frame = 1
		_update_sprite_frame()

	# Update visual state (tint for defend/dead)
	_update_visual_state()

func _update_visual_state():
	"""Update visuals based on current state"""
	if unit_state == "dead":
		modulate.a = 0.5
	else:
		modulate.a = 1.0

## ========== TARGETING ==========

func set_targeted(is_targeted: bool) -> void:
	"""Show or hide target indicator"""
	if target_indicator:
		target_indicator.visible = is_targeted

func is_targeted() -> bool:
	"""Check if unit is currently targeted"""
	return target_indicator.visible if target_indicator else false

## ========== VISUAL EFFECTS ==========

func show_damage(damage: int, flank_type: String) -> void:
	"""Display floating damage number"""
	if damage_label:
		damage_label.text = str(damage)
		if flank_type == "back":
			damage_label.text += "!"
			damage_label.add_theme_color_override("font_color", Color.ORANGE)
		elif flank_type == "side":
			damage_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			damage_label.add_theme_color_override("font_color", Color.RED)

		damage_label.visible = true
		damage_label.position = Vector2(0, -100)

		# Animate floating up and fading
		var tween = create_tween()
		tween.tween_property(damage_label, "position:y", -140, 0.8)
		tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.8)
		tween.tween_callback(func(): damage_label.visible = false; damage_label.modulate.a = 1.0)

func play_dodge_roll(direction: Vector2) -> void:
	"""Play dodge roll visual effect - quick flash and semi-transparent during roll"""
	is_dodge_rolling = true

	# Flash white briefly at start, then semi-transparent during roll
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5, 0.7), 0.05)  # Bright and transparent
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0.5), 0.25)  # Stay semi-transparent during roll
	tween.tween_property(self, "modulate", Color.WHITE, 0.05)  # Return to normal
	tween.tween_callback(func(): is_dodge_rolling = false)

func play_death() -> void:
	"""Play death animation"""
	unit_state = "dead"
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.3, 0.5)
	tween.tween_property(self, "scale", Vector2(1.0, 0.5), 0.3)

## ========== STAMINA/ENERGY ==========

func drain_energy(amount: int) -> bool:
	"""Drain energy locally. Returns true if had enough energy."""
	if energy >= amount:
		energy -= amount
		if energy_bar:
			energy_bar.value = energy
		return true
	return false

func has_energy(amount: int) -> bool:
	"""Check if unit has enough energy"""
	return energy >= amount

func regen_energy(amount: int) -> void:
	"""Regenerate energy locally"""
	energy = mini(energy + amount, max_energy)
	if energy_bar:
		energy_bar.value = energy
