class_name BattleAnimations
extends Node
## Battle Animations System - Handles visual effects and attack animations
## Extracted from battle_window.gd for modularity

# Signals
signal animation_started()
signal animation_completed()

# Animation state
var is_animating_attack: bool = false

# References to UI elements (set by battle_window_v2)
var enemy_panels: Array = []
var ally_panels: Array = []
var enemy_sprites: Array = []
var ally_sprites: Array = []
var enemy_hp_bars: Array = []
var ally_hp_bars: Array = []
var parent_node: Node = null  # For adding child nodes (labels, particles, etc.)

## ========== INITIALIZATION ==========

func initialize_references(refs: Dictionary):
	"""Set all necessary references from parent scene"""
	enemy_panels = refs.get("enemy_panels", [])
	ally_panels = refs.get("ally_panels", [])
	enemy_sprites = refs.get("enemy_sprites", [])
	ally_sprites = refs.get("ally_sprites", [])
	enemy_hp_bars = refs.get("enemy_hp_bars", [])
	ally_hp_bars = refs.get("ally_hp_bars", [])
	parent_node = refs.get("parent_node", null)

## ========== ATTACK ANIMATION ==========

func play_attack_animation(sprite_node: TextureRect, character: Dictionary, attack_direction: String = "attack_right", target_sprite: TextureRect = null):
	"""Play attack animation - melee rushes to target, ranged/caster stays in position"""
	is_animating_attack = true
	animation_started.emit()

	var char_name = character.get("character_name", "Unknown")
	print("🎬 play_attack_animation called for: %s (has animations: %s)" % [char_name, character.has("animations")])

	if not character.has("animations"):
		print("❌ %s has NO animations - skipping animation" % char_name)
		is_animating_attack = false
		animation_completed.emit()
		return

	# Get parent panels to move entire units
	var attacker_panel = sprite_node.get_parent().get_parent()  # Sprite -> VBox -> Panel
	var target_panel = target_sprite.get_parent().get_parent() if target_sprite else null
	if not target_panel:
		is_animating_attack = false
		animation_completed.emit()
		return

	# Get target character data from panel
	var target_character_data = {}
	if "character_data" in target_panel:
		target_character_data = target_panel.character_data

	# Determine combat role and if character should move
	var attack_type = get_character_attack_type(character)

	# Find which panel index this is to check front/back row
	var attacker_index = -1
	if attacker_panel.get_parent().name == "PlayerArea":
		# Find in ally panels
		for i in range(ally_panels.size()):
			if ally_panels[i] == attacker_panel:
				attacker_index = i
				break
	else:
		# Find in enemy panels
		for i in range(enemy_panels.size()):
			if enemy_panels[i] == attacker_panel:
				attacker_index = i
				break

	var is_front_row_attacker = is_front_row(attacker_index, attacker_panel.get_parent().name == "EnemyArea")

	# Melee always moves, Hybrid moves only if in front row
	var should_move_to_target = (attack_type == "melee") or (attack_type == "hybrid" and is_front_row_attacker)

	# Store original positions
	var attacker_original_pos = attacker_panel.position

	# Calculate attack position - small step forward from current position (not all the way to target)
	var attacker_on_right = attacker_panel.get_parent().name == "PlayerArea"
	var step_distance = 40.0  # Small step forward to show who's attacking

	# Start from current position and step forward
	var attack_pos = attacker_original_pos

	# Step toward opponent
	if attacker_on_right:
		attack_pos.x -= step_distance  # Step left toward enemies
	else:
		attack_pos.x += step_distance  # Step right toward allies

	# Determine walk directions
	var attacker_approach_dir = "left" if attacker_on_right else "right"
	var attacker_return_dir = "right" if attacker_on_right else "left"

	# ========================================
	# PHASE 1: APPROACH (MELEE OR HYBRID IN FRONT ROW)
	# ========================================
	if should_move_to_target:
		# Start movement tween - quick step forward
		var tween_forward = create_tween()
		tween_forward.set_parallel(false)
		tween_forward.tween_property(attacker_panel, "position", attack_pos, 0.25).set_trans(Tween.TRANS_LINEAR)

		# Animate walk cycle in parallel - 2 frames at 0.125s each = 0.25s
		for i in range(2):
			var frame_suffix = "_1" if i % 2 == 0 else "_2"
			var attacker_walk_anim = "walk_" + attacker_approach_dir + frame_suffix
			if character.animations.has(attacker_walk_anim):
				var walk_frames = character.animations[attacker_walk_anim]
				if walk_frames.size() > 0:
					var frame_data = walk_frames[0]
					var atlas_index = frame_data.get("atlas_index", 0)
					var row = frame_data.get("row", 0)
					var col = frame_data.get("col", 0)
					var walk_texture = BattleDataLoader.get_sprite_texture_from_coords(atlas_index, row, col)
					if walk_texture:
						sprite_node.texture = walk_texture
			await get_tree().create_timer(0.125).timeout

		# Wait for tween to complete (in case of timing mismatch)
		if tween_forward and tween_forward.is_running():
			await tween_forward.finished

	# ========================================
	# PHASE 2: ATTACK SEQUENCE
	# ========================================
	# Show attack animation
	if character.animations.has(attack_direction):
		var attack_frames = character.animations[attack_direction]
		if attack_frames.size() > 0:
			var frame_data = attack_frames[0]
			var atlas_index = frame_data.get("atlas_index", 0)
			var row = frame_data.get("row", 0)
			var col = frame_data.get("col", 0)
			var attack_texture = BattleDataLoader.get_sprite_texture_from_coords(atlas_index, row, col)
			if attack_texture:
				sprite_node.texture = attack_texture

	await get_tree().create_timer(0.15).timeout

	# Show slash effect on target center
	if target_sprite and target_sprite is Control:
		# Calculate center of target sprite
		var target_sprite_center = target_sprite.global_position + (target_sprite.size / 2.0)
		show_slash_effect(target_sprite_center)
	elif target_sprite:
		print("⚠ WARNING: target_sprite is not a Control node")

	# HIT REACTION: Target spins from impact (down -> right -> up -> left)
	if target_character_data.has("animations"):
		# Frame 1: Face down
		if target_character_data.animations.has("walk_down_1"):
			var down_frames = target_character_data.animations["walk_down_1"]
			if down_frames.size() > 0:
				var frame_data = down_frames[0]
				var atlas_index = frame_data.get("atlas_index", 0)
				var row = frame_data.get("row", 0)
				var col = frame_data.get("col", 0)
				var down_texture = BattleDataLoader.get_sprite_texture_from_coords(atlas_index, row, col)
				if down_texture:
					target_sprite.texture = down_texture
		await get_tree().create_timer(0.08).timeout

		# Frame 2: Face right
		if target_character_data.animations.has("walk_right_1"):
			var right_frames = target_character_data.animations["walk_right_1"]
			if right_frames.size() > 0:
				var frame_data = right_frames[0]
				var atlas_index = frame_data.get("atlas_index", 0)
				var row = frame_data.get("row", 0)
				var col = frame_data.get("col", 0)
				var right_texture = BattleDataLoader.get_sprite_texture_from_coords(atlas_index, row, col)
				if right_texture:
					target_sprite.texture = right_texture
		await get_tree().create_timer(0.08).timeout

		# Frame 3: Face up
		if target_character_data.animations.has("walk_up_1"):
			var up_frames = target_character_data.animations["walk_up_1"]
			if up_frames.size() > 0:
				var frame_data = up_frames[0]
				var atlas_index = frame_data.get("atlas_index", 0)
				var row = frame_data.get("row", 0)
				var col = frame_data.get("col", 0)
				var up_texture = BattleDataLoader.get_sprite_texture_from_coords(atlas_index, row, col)
				if up_texture:
					target_sprite.texture = up_texture
		await get_tree().create_timer(0.08).timeout

		# Frame 4: Face left
		if target_character_data.animations.has("walk_left_1"):
			var left_frames = target_character_data.animations["walk_left_1"]
			if left_frames.size() > 0:
				var frame_data = left_frames[0]
				var atlas_index = frame_data.get("atlas_index", 0)
				var row = frame_data.get("row", 0)
				var col = frame_data.get("col", 0)
				var left_texture = BattleDataLoader.get_sprite_texture_from_coords(atlas_index, row, col)
				if left_texture:
					target_sprite.texture = left_texture
		await get_tree().create_timer(0.08).timeout

	# ========================================
	# PHASE 3: RETURN (MELEE OR HYBRID IN FRONT ROW)
	# ========================================
	if should_move_to_target:
		# Start return tween - quick step back
		var tween_back = create_tween()
		tween_back.set_parallel(false)
		tween_back.tween_property(attacker_panel, "position", attacker_original_pos, 0.25).set_trans(Tween.TRANS_LINEAR)

		# Animate walk cycle in parallel - 2 frames at 0.125s each = 0.25s
		for i in range(2):
			var frame_suffix = "_1" if i % 2 == 0 else "_2"
			var attacker_return_anim = "walk_" + attacker_return_dir + frame_suffix
			if character.animations.has(attacker_return_anim):
				var walk_frames = character.animations[attacker_return_anim]
				if walk_frames.size() > 0:
					var frame_data = walk_frames[0]
					var atlas_index = frame_data.get("atlas_index", 0)
					var row = frame_data.get("row", 0)
					var col = frame_data.get("col", 0)
					var walk_texture = BattleDataLoader.get_sprite_texture_from_coords(atlas_index, row, col)
					if walk_texture:
						sprite_node.texture = walk_texture
			await get_tree().create_timer(0.125).timeout

		# Wait for tween to complete (in case of timing mismatch)
		if tween_back and tween_back.is_running():
			await tween_back.finished

	# Return both to idle (facing down)
	BattleDataLoader.load_character_sprite(character, sprite_node)
	if target_character_data.has("animations"):
		BattleDataLoader.load_character_sprite(target_character_data, target_sprite)

	is_animating_attack = false
	animation_completed.emit()
	print("✅ Animation complete for: %s" % char_name)

## ========== DAMAGE NUMBERS ==========

func show_damage_number(position: Vector2, damage: int):
	"""Show floating damage number that rises and fades"""
	if not parent_node:
		return

	var damage_label = Label.new()
	damage_label.text = str(damage)
	damage_label.add_theme_font_size_override("font_size", 32)
	damage_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Red color
	damage_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	damage_label.add_theme_constant_override("outline_size", 4)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	damage_label.position = position + Vector2(-30, -150)  # Above sprite
	damage_label.z_index = 100

	parent_node.add_child(damage_label)

	# Create tween for floating and fading
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 100, 1.5)
	tween.tween_property(damage_label, "modulate:a", 0.0, 1.5)

	# Remove label after animation
	await get_tree().create_timer(1.5).timeout
	damage_label.queue_free()

## ========== HP BAR ANIMATION ==========

func animate_hp_bar(hp_bar: ProgressBar, new_hp: float, max_hp: float):
	"""Smoothly animate HP bar to new value"""
	if not hp_bar:
		return

	var tween = create_tween()
	tween.tween_property(hp_bar, "value", new_hp, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func update_hp_bar_color(hp_bar: ProgressBar, current_hp: float, max_hp: float):
	"""Update HP bar color based on HP percentage (green → yellow → red)"""
	var hp_percent = current_hp / max_hp if max_hp > 0 else 0.0

	var bar_color: Color
	if hp_percent > 0.6:
		# Green (healthy)
		bar_color = Color(0.2, 0.8, 0.2)
	elif hp_percent > 0.3:
		# Yellow (warning) - interpolate between green and yellow
		var t = (hp_percent - 0.3) / 0.3  # 0.0 to 1.0
		bar_color = Color(0.2, 0.8, 0.2).lerp(Color(0.9, 0.9, 0.2), 1.0 - t)
	else:
		# Red (danger) - interpolate between yellow and red
		var t = hp_percent / 0.3  # 0.0 to 1.0
		bar_color = Color(0.9, 0.9, 0.2).lerp(Color(0.9, 0.2, 0.2), 1.0 - t)

	# Apply color to HP bar
	if hp_bar:
		hp_bar.modulate = bar_color

## ========== PARTICLE EFFECTS ==========

func spawn_impact_particles(hit_position: Vector2):
	"""Spawn particle effect at attack impact location"""
	if not parent_node:
		return

	# Check if impact effect exists before loading
	if not ResourceLoader.exists("res://effects/attack_impact.tscn"):
		return

	var impact_scene = load("res://effects/attack_impact.tscn")
	if not impact_scene:
		return

	var particles_node = impact_scene.instantiate()
	if particles_node:
		particles_node.position = hit_position
		parent_node.add_child(particles_node)
		# Find the CPUParticles2D child and start emission
		var particles = particles_node.get_node("Particles")
		if particles:
			particles.emitting = true
		print("Impact particles spawned at: ", hit_position)
	else:
		print("ERROR: Failed to instantiate particle scene")

func spawn_blood_particles(hit_position: Vector2):
	"""Create red particle burst on hit"""
	if not parent_node:
		return

	var particles = CPUParticles2D.new()
	particles.position = hit_position
	particles.z_index = 100
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 15
	particles.lifetime = 0.6
	particles.color = Color(0.8, 0.1, 0.1, 1)
	particles.color_ramp = create_blood_gradient()
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 400)
	particles.initial_velocity_min = 100
	particles.initial_velocity_max = 200
	particles.scale_amount_min = 2
	particles.scale_amount_max = 4
	parent_node.add_child(particles)

	await get_tree().create_timer(0.8).timeout
	particles.queue_free()

func create_blood_gradient() -> Gradient:
	"""Create red to transparent gradient for blood particles"""
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.8, 0.1, 0.1, 1))
	gradient.set_color(1, Color(0.6, 0.0, 0.0, 0))
	return gradient

## ========== VISUAL EFFECTS ==========

func play_hit_flash(sprite_node: TextureRect):
	"""Flash sprite white when taking damage"""
	var original_modulate = sprite_node.modulate

	# Flash white
	sprite_node.modulate = Color(2.0, 2.0, 2.0, 1.0)
	await get_tree().create_timer(0.1).timeout

	# Return to normal
	sprite_node.modulate = original_modulate

func screen_shake(strength: float = 10.0, duration: float = 0.3):
	"""Shake the entire battle window"""
	if not parent_node:
		return

	var original_position = parent_node.position
	var shake_timer = 0.0
	var shake_interval = 0.05

	while shake_timer < duration:
		# Random offset
		var offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		parent_node.position = original_position + offset

		await get_tree().create_timer(shake_interval).timeout
		shake_timer += shake_interval

		# Reduce strength over time
		strength *= 0.8

	# Return to original position
	parent_node.position = original_position

func show_slash_effect(hit_position: Vector2):
	"""Display diagonal slash lines at impact point"""
	if not parent_node:
		return

	# Main slashes - 2 thin diagonal lines
	for i in range(2):
		var slash_line = Line2D.new()
		# Make slashes cover entire sprite area (150x150)
		var offset = Vector2(-75, -75) + Vector2(i * 30, i * 30)
		slash_line.add_point(hit_position + offset)
		slash_line.add_point(hit_position + offset + Vector2(150, 150))
		slash_line.width = 3
		slash_line.default_color = Color(1, 1 - (i * 0.4), 1 - (i * 0.4), 1)  # White to red gradient
		slash_line.z_index = 100
		parent_node.add_child(slash_line)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(slash_line, "width", 6, 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(slash_line, "modulate:a", 0.0, 0.3)

		await get_tree().create_timer(0.3).timeout
		slash_line.queue_free()

	# Center emphasis slash - smaller, brighter
	var center_slash = Line2D.new()
	var center_offset = Vector2(-30, -30)
	center_slash.add_point(hit_position + center_offset)
	center_slash.add_point(hit_position + center_offset + Vector2(60, 60))
	center_slash.width = 4
	center_slash.default_color = Color(1, 1, 1, 1)  # Bright white
	center_slash.z_index = 101  # On top of other slashes
	parent_node.add_child(center_slash)

	var center_tween = create_tween()
	center_tween.set_parallel(true)
	center_tween.tween_property(center_slash, "width", 8, 0.15).set_ease(Tween.EASE_OUT)
	center_tween.tween_property(center_slash, "modulate:a", 0.0, 0.25)

	await get_tree().create_timer(0.25).timeout
	center_slash.queue_free()

	spawn_blood_particles(hit_position)

## ========== UTILITY FUNCTIONS ==========

func is_front_row(panel_index: int, is_enemy: bool) -> bool:
	"""Determine if a panel is in the front row based on formation"""
	# Front row = panels 1, 2, 3 (indices 0, 1, 2)
	# Back row = panels 4, 5, 6 (indices 3, 4, 5)
	return panel_index < 3

func get_character_attack_type(character_data: Dictionary) -> String:
	"""Determine combat role based on character's combat_role tag"""
	# Use new combat_role field if available
	if character_data.has("combat_role"):
		var role = character_data.combat_role.to_lower()

		if "melee" in role:
			return "melee"
		elif "ranged" in role:
			return "ranged"
		elif "caster" in role:
			return "caster"
		elif "hybrid" in role:
			return "hybrid"

	# Fallback to old class_template system for backward compatibility
	if character_data.has("class_template"):
		var char_class = character_data.class_template.to_lower()

		# Pure melee classes
		var melee_classes = ["warrior", "knight", "paladin", "berserker", "monk", "fighter"]
		# Ranged classes
		var ranged_classes = ["archer", "ranger", "gunner", "sniper", "hunter"]
		# Magic classes
		var magic_classes = ["mage", "wizard", "sorcerer", "cleric", "priest", "shaman", "warlock"]

		for melee in melee_classes:
			if melee in char_class:
				return "melee"
		for ranged in ranged_classes:
			if ranged in char_class:
				return "ranged"
		for magic in magic_classes:
			if magic in char_class:
				return "caster"

	# Default to melee if nothing specified
	return "melee"
