class_name RealtimeBattleScene
extends Node2D
## Realtime Battle Scene - Client-side battle arena
## Displays the battle using the current map as the arena background
## Player at bottom, enemies at top, 10-15 tiles apart

## ========== SIGNALS ==========
signal battle_started(battle_data: Dictionary)
signal battle_ended(result: String, rewards: Dictionary)
signal unit_damaged(unit_id: String, damage: int, flank_type: String)
signal unit_died(unit_id: String)

## ========== CONSTANTS ==========
const ARENA_PADDING: int = 60  # Keep units away from edges

## ========== MAP DATA ==========
var arena_width: int = 2560   # Default: 20 tiles * 128px scaled (overwritten by battle_data)
var arena_height: int = 1920  # Default: 15 tiles * 128px scaled (overwritten by battle_data)
var battle_map_name: String = "sample_map"

## ========== CHILD NODES ==========
var arena_renderer: Node2D
var units_container: Node2D
var ui_layer: CanvasLayer
var camera: Camera2D

## Player corner HUD elements
var player_hp_bar: ProgressBar
var player_mp_bar: ProgressBar
var player_ep_bar: ProgressBar
var player_name_label: Label

## ========== STATE ==========
var battle_id: int = -1
var battle_active: bool = false
var player_unit_id: String = ""
var units: Dictionary = {}  # unit_id -> RealtimeBattleUnit
var map_snapshot: TextureRect = null  # Captured map background

## World-to-arena coordinate mapping
var world_to_arena_scale: float = 1.0  # Scale factor from world coords to arena
var world_offset: Vector2 = Vector2.ZERO  # Offset to center battle area in arena

func get_arena_pixel_size() -> Vector2:
	"""Get arena size in pixels"""
	return Vector2(arena_width, arena_height)

func world_to_arena_pos(world_pos: Vector2) -> Vector2:
	"""Convert world position to arena position"""
	return (world_pos - world_offset) * world_to_arena_scale

## ========== PRELOADS ==========
var RealtimeBattleUnit = preload("res://scripts/realtime_battle/realtime_battle_unit.gd")

## ========== LIFECYCLE ==========

func _ready():
	_create_scene_structure()
	print("[RT_BATTLE_SCENE] Ready")

func _create_scene_structure():
	# Arena background layer
	arena_renderer = Node2D.new()
	arena_renderer.name = "ArenaRenderer"
	add_child(arena_renderer)

	# Units layer
	units_container = Node2D.new()
	units_container.name = "UnitsContainer"
	add_child(units_container)

	# Camera following player (centered on arena for fullscreen)
	camera = Camera2D.new()
	camera.name = "BattleCamera"
	# Zoom to fit arena nicely on screen
	camera.zoom = Vector2(1.0, 1.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	# Center camera on arena (no scrolling needed for fullscreen)
	camera.position = Vector2(arena_width / 2.0, arena_height / 2.0)
	add_child(camera)

	# UI layer for battle effects (if needed later)
	ui_layer = CanvasLayer.new()
	ui_layer.name = "BattleUI"
	ui_layer.layer = 10
	add_child(ui_layer)

	# Bottom-left corner HUD removed - using overhead bars only

func _process(_delta: float):
	if not battle_active:
		return
	# Camera follows the player unit
	var player = get_player_unit()
	if player:
		camera.global_position = player.position

## ========== BATTLE LIFECYCLE ==========

func start_battle(battle_data: Dictionary) -> void:
	"""Initialize battle from server data"""
	battle_id = battle_data.get("id", -1)
	player_unit_id = battle_data.get("player_unit_id", "")
	battle_map_name = battle_data.get("battle_map_name", "sample_map")

	# Get arena size from server (full map size)
	var arena_pixels = battle_data.get("arena_pixels", Vector2(2560, 1920))
	arena_width = int(arena_pixels.x)
	arena_height = int(arena_pixels.y)

	# Direct coordinate mapping (1:1, server sends positions in battle map coords)
	world_to_arena_scale = 1.0
	world_offset = Vector2.ZERO

	print("[RT_BATTLE_SCENE] Battle map: %s (%dx%d)" % [battle_map_name, arena_width, arena_height])

	# Render arena using battle map
	_render_arena_from_map(battle_data)

	# Spawn units (positions are already in arena coords from server)
	_spawn_units(battle_data.get("units", {}))

	# Camera follows player (set to player position)
	var player_pos = battle_data.get("player_position", Vector2(arena_width / 2, arena_height - 256))
	camera.global_position = player_pos
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.make_current()

	battle_active = true
	battle_started.emit(battle_data)

	print("[RT_BATTLE_SCENE] Battle %d started on %s" % [battle_id, battle_map_name])

func end_battle(result: String, rewards: Dictionary) -> void:
	"""Clean up battle"""
	battle_active = false

	# Clear units
	for unit in units.values():
		if is_instance_valid(unit):
			unit.queue_free()
	units.clear()

	# Clear arena
	for child in arena_renderer.get_children():
		child.queue_free()
	map_snapshot = null

	battle_ended.emit(result, rewards)
	print("[RT_BATTLE_SCENE] Battle %d ended: %s" % [battle_id, result])

## ========== ARENA RENDERING ==========

func _render_arena_from_map(_battle_data: Dictionary) -> void:
	"""Render battle arena by cloning the current map's TileMapLayers"""
	# Primary method: Clone the actual map the player is standing on
	var captured = _capture_map_viewport()
	if captured:
		print("[RT_BATTLE_SCENE] Cloned current map for battle arena")
		return

	# Fallback: simple grass arena
	print("[RT_BATTLE_SCENE] WARNING: Using fallback grass arena (could not clone map)")
	_render_fallback_arena()

func _load_battle_map_tmx(map_path: String) -> bool:
	"""Load battle map from TMX file using TMXLoader"""
	var tileset = load("res://addons/gs_mmo_tools/resources/main_tileset.tres") as TileSet
	if not tileset:
		print("[RT_BATTLE_SCENE] Could not load tileset")
		return false

	# Parse TMX and create layers
	var tmx_data = TMXLoader.parse_tmx_file(map_path)
	if tmx_data.is_empty():
		print("[RT_BATTLE_SCENE] Failed to parse TMX: %s" % map_path)
		return false

	# Create TileMapLayers for each layer in the TMX
	var tile_scale = 4  # 32px tiles scaled 4x = 128px
	for i in range(tmx_data.layers.size()):
		var layer_data = tmx_data.layers[i]
		var tile_layer = TileMapLayer.new()
		tile_layer.name = "Battle_" + layer_data.name
		tile_layer.tile_set = tileset
		tile_layer.scale = Vector2(tile_scale, tile_scale)
		tile_layer.z_index = i - 5  # Bottom at -5, Middle at -4, Top at -3

		# Place tiles from CSV data
		# Uses dual tileset sources like map_manager:
		# - tiles_part1: firstgid=1, tiles 1-3584 (source_id=0)
		# - tiles_part2: firstgid=3585, tiles 3585+ (source_id=1)
		var data_index = 0
		for y in range(tmx_data.height):
			for x in range(tmx_data.width):
				if data_index < layer_data.data.size():
					var tile_id = layer_data.data[data_index]
					if tile_id > 0:
						var source_id = 0
						var adjusted_tile_id = tile_id - 1  # Convert to 0-based

						if tile_id >= 3585:
							# tiles_part2 (trees and other higher tiles)
							source_id = 1
							adjusted_tile_id = tile_id - 3585

						# Convert to atlas coords (7 columns per row in tileset)
						var atlas_x = adjusted_tile_id % 7
						var atlas_y = adjusted_tile_id / 7
						tile_layer.set_cell(Vector2i(x, y), source_id, Vector2i(atlas_x, atlas_y))
				data_index += 1

		arena_renderer.add_child(tile_layer)

	return true

func _capture_map_viewport() -> bool:
	"""Capture the current game viewport as the arena background"""
	var parent_node = get_meta("parent_node") if has_meta("parent_node") else null
	if not parent_node:
		print("[RT_BATTLE_SCENE] No parent_node found")
		return false

	# Try multiple approaches to find the tile map layers
	var bottom_layer: TileMapLayer = null
	var middle_layer: TileMapLayer = null
	var top_layer: TileMapLayer = null

	# Approach 1: Look for GameWorld child (old structure)
	var game_world = parent_node.get_node_or_null("GameWorld")
	if game_world:
		bottom_layer = game_world.get_node_or_null("BottomLayer")
		middle_layer = game_world.get_node_or_null("MiddleLayer")
		top_layer = game_world.get_node_or_null("TopLayer")
		print("[RT_BATTLE_SCENE] Found layers via GameWorld child")

	# Approach 2: Direct children of parent (current structure)
	if not bottom_layer:
		bottom_layer = parent_node.get_node_or_null("BottomLayer")
		middle_layer = parent_node.get_node_or_null("MiddleLayer")
		top_layer = parent_node.get_node_or_null("TopLayer")
		if bottom_layer:
			print("[RT_BATTLE_SCENE] Found layers as direct children of parent")

	# Approach 3: Search entire tree for TileMapLayers
	if not bottom_layer:
		print("[RT_BATTLE_SCENE] Searching tree for TileMapLayers...")
		for child in parent_node.get_children():
			if child is TileMapLayer:
				var child_name = child.name.to_lower()
				if "bottom" in child_name:
					bottom_layer = child
				elif "middle" in child_name:
					middle_layer = child
				elif "top" in child_name:
					top_layer = child
			# Also check grandchildren
			for grandchild in child.get_children():
				if grandchild is TileMapLayer:
					var gc_name = grandchild.name.to_lower()
					if "bottom" in gc_name:
						bottom_layer = grandchild
					elif "middle" in gc_name:
						middle_layer = grandchild
					elif "top" in gc_name:
						top_layer = grandchild

	if not bottom_layer:
		print("[RT_BATTLE_SCENE] No BottomLayer found in any location")
		return false

	# Clone the map layers into the arena
	print("[RT_BATTLE_SCENE] Cloning layers to arena...")
	_clone_map_layer(bottom_layer, -10)
	if middle_layer:
		_clone_map_layer(middle_layer, -5)
	if top_layer:
		_clone_map_layer(top_layer, 0)

	print("[RT_BATTLE_SCENE] Map layers cloned to arena successfully")
	return true

func _clone_map_layer(source_layer: TileMapLayer, z_index_value: int) -> void:
	"""Clone a TileMapLayer for use in the battle arena"""
	# Create a new TileMapLayer with the same data
	var cloned_layer = TileMapLayer.new()
	cloned_layer.name = "Arena_" + source_layer.name
	cloned_layer.tile_set = source_layer.tile_set
	cloned_layer.z_index = z_index_value
	cloned_layer.texture_filter = source_layer.texture_filter

	# Scale to fit arena (source is 4x scale, arena needs to fit 892x660)
	# Original map: 20x15 tiles * 32px * 4 scale = 2560x1920 pixels
	# Arena: 892x660 pixels
	# Scale factor: arena / original = ~0.35
	var scale_factor = min(arena_width / 2560.0, arena_height / 1920.0) * 1.2  # Slight upscale for better coverage
	cloned_layer.scale = Vector2(scale_factor * 4, scale_factor * 4)  # Include original 4x scale

	# Copy all cells from source
	var used_cells = source_layer.get_used_cells()
	for cell in used_cells:
		var source_id = source_layer.get_cell_source_id(cell)
		var atlas_coords = source_layer.get_cell_atlas_coords(cell)
		var alt_tile = source_layer.get_cell_alternative_tile(cell)
		cloned_layer.set_cell(cell, source_id, atlas_coords, alt_tile)

	# Center the map in the arena
	cloned_layer.position = Vector2(
		(arena_width - 2560 * scale_factor) / 2.0,
		(arena_height - 1920 * scale_factor) / 2.0
	)

	arena_renderer.add_child(cloned_layer)

func _render_fallback_arena() -> void:
	"""Render simple grass arena as fallback"""
	# Main grass background
	var bg = Polygon2D.new()
	bg.name = "ArenaBG"
	bg.color = Color(0.28, 0.48, 0.25)  # Grass green
	bg.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(arena_width, 0),
		Vector2(arena_width, arena_height),
		Vector2(0, arena_height)
	])
	bg.z_index = -10
	arena_renderer.add_child(bg)

	# Add some texture variation with lighter patches
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Consistent pattern
	for i in range(20):
		var patch = Polygon2D.new()
		patch.name = "GrassPatch%d" % i
		var px = rng.randf_range(50, arena_width - 50)
		var py = rng.randf_range(50, arena_height - 50)
		var size = rng.randf_range(40, 100)
		patch.color = Color(0.32, 0.52, 0.28, 0.4)  # Lighter grass
		patch.polygon = PackedVector2Array([
			Vector2(px - size/2, py - size/3),
			Vector2(px + size/2, py - size/3),
			Vector2(px + size/2, py + size/3),
			Vector2(px - size/2, py + size/3)
		])
		patch.z_index = -9
		arena_renderer.add_child(patch)

func _add_arena_border() -> void:
	"""Add arena border decoration"""
	# Arena border (thick)
	var border = Line2D.new()
	border.name = "ArenaBorder"
	border.default_color = Color(0.4, 0.3, 0.2)  # Brown border
	border.width = 12.0
	border.points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(arena_width, 0),
		Vector2(arena_width, arena_height),
		Vector2(0, arena_height),
		Vector2(0, 0)
	])
	border.z_index = 5
	arena_renderer.add_child(border)

	# Inner border accent
	var inner_border = Line2D.new()
	inner_border.name = "InnerBorder"
	inner_border.default_color = Color(0.5, 0.4, 0.3)
	inner_border.width = 4.0
	var margin = 16.0
	inner_border.points = PackedVector2Array([
		Vector2(margin, margin),
		Vector2(arena_width - margin, margin),
		Vector2(arena_width - margin, arena_height - margin),
		Vector2(margin, arena_height - margin),
		Vector2(margin, margin)
	])
	inner_border.z_index = 5
	arena_renderer.add_child(inner_border)

	# Add corner decorations
	_add_corner_decoration(Vector2(32, 32))
	_add_corner_decoration(Vector2(arena_width - 32, 32))
	_add_corner_decoration(Vector2(32, arena_height - 32))
	_add_corner_decoration(Vector2(arena_width - 32, arena_height - 32))

func _add_corner_decoration(pos: Vector2) -> void:
	"""Add a corner decoration element"""
	var corner = Polygon2D.new()
	corner.color = Color(0.35, 0.25, 0.15)  # Dark brown
	var size = 24.0
	corner.polygon = PackedVector2Array([
		Vector2(pos.x - size/2, pos.y - size/2),
		Vector2(pos.x + size/2, pos.y - size/2),
		Vector2(pos.x + size/2, pos.y + size/2),
		Vector2(pos.x - size/2, pos.y + size/2)
	])
	corner.z_index = 6
	arena_renderer.add_child(corner)

## ========== UNIT MANAGEMENT ==========

func _spawn_units(units_data: Dictionary) -> void:
	"""Spawn all battle units"""
	for unit_id in units_data:
		var unit_data = units_data[unit_id]
		_spawn_unit(unit_id, unit_data)

func _spawn_unit(unit_id: String, unit_data: Dictionary) -> void:
	"""Spawn a single unit"""
	var unit_node = Node2D.new()
	unit_node.set_script(RealtimeBattleUnit)
	unit_node.name = unit_id
	units_container.add_child(unit_node)

	# Convert world position to arena position
	var world_pos = unit_data.get("position", Vector2.ZERO)
	var arena_pos = world_to_arena_pos(world_pos)
	unit_data["position"] = arena_pos

	unit_node.initialize(unit_data)
	units[unit_id] = unit_node

	print("[RT_BATTLE_SCENE] Spawned unit: %s at world %s -> arena %s" % [unit_id, world_pos, arena_pos])

func get_unit(unit_id: String) -> Node2D:
	"""Get unit node by ID"""
	return units.get(unit_id)

func get_player_unit() -> Node2D:
	"""Get the player's unit"""
	return units.get(player_unit_id)

## ========== SERVER STATE UPDATES ==========

func on_state_update(units_state: Array) -> void:
	"""Apply server state update to all units"""
	for state in units_state:
		var unit_id = state.get("id", "")
		if unit_id in units:
			# Convert world position to arena position
			if state.has("position"):
				var world_pos = state["position"]
				state["position"] = world_to_arena_pos(world_pos)
			units[unit_id].apply_server_state(state)

			# Update player corner HUD if this is the player unit
			if unit_id == player_unit_id:
				var unit = units[unit_id]
				update_player_hud(
					unit.hp, unit.max_hp,
					unit.mp, unit.max_mp,
					unit.energy, unit.max_energy,
					unit.unit_name
				)

func on_damage_event(attacker_id: String, target_id: String, damage: int, flank_type: String) -> void:
	"""Handle damage event from server"""
	if not attacker_id in units or not target_id in units:
		return

	var attacker = units[attacker_id]
	var target = units[target_id]

	# Play attack animation on attacker
	attacker.play_attack_animation()

	# Check if attacker uses projectiles (ranged/caster)
	var combat_role = attacker.get("combat_role")
	var combat_role_lower = combat_role.to_lower() if combat_role else "melee"

	if combat_role_lower in ["ranged", "caster"]:
		# Store damage for later (when projectile hits)
		target.set_meta("pending_damage", damage)
		target.set_meta("pending_flank", flank_type)
		# Spawn projectile
		_spawn_projectile(attacker, target, combat_role_lower)
	else:
		# Melee/Hybrid - show damage immediately
		target.show_damage(damage, flank_type)

	unit_damaged.emit(target_id, damage, flank_type)

func _spawn_projectile(attacker: Node2D, target: Node2D, role: String):
	"""Spawn a visual projectile from attacker to target"""
	var projectile_scene = preload("res://scenes/projectile.tscn")
	var projectile = projectile_scene.instantiate()
	add_child(projectile)

	# Set projectile texture based on role (case-insensitive)
	var texture_path = ""
	var role_lower = role.to_lower() if role else ""
	match role_lower:
		"ranged":
			texture_path = "res://assets/projectiles/Light Bolt.png"
		"caster":
			texture_path = "res://assets/projectiles/Arcane Bolt.png"

	if texture_path and projectile.has_node("Sprite2D"):
		var sprite = projectile.get_node("Sprite2D")
		sprite.texture = load(texture_path)

	# Calculate direction
	var direction = (target.position - attacker.position).normalized()

	# Initialize projectile
	projectile.initialize(attacker.position, direction, 0, "", "")

	# Make projectile hit target after travel time
	var distance = attacker.position.distance_to(target.position)
	var travel_time = distance / projectile.speed
	await get_tree().create_timer(travel_time).timeout

	# Show damage when projectile reaches target
	if is_instance_valid(target):
		var dmg = target.get_meta("pending_damage", 0)
		var flank = target.get_meta("pending_flank", "front")
		target.show_damage(dmg, flank)
		target.remove_meta("pending_damage")
		target.remove_meta("pending_flank")

func on_unit_death(unit_id: String) -> void:
	"""Handle unit death from server"""
	if unit_id in units:
		units[unit_id].play_death()
	unit_died.emit(unit_id)

func on_dodge_roll_event(unit_id: String, direction: Vector2) -> void:
	"""Handle dodge roll from server"""
	if unit_id in units:
		units[unit_id].play_dodge_roll(direction)


## ========== PLAYER CORNER HUD ==========

func _create_player_corner_hud() -> void:
	"""Create compact player stats HUD in bottom-left corner"""
	var hud_container = Control.new()
	hud_container.name = "PlayerHUD"
	hud_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hud_container.position = Vector2(8, -60)  # 8px from left, 60px from bottom
	hud_container.size = Vector2(120, 52)
	hud_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hud_container)

	# Semi-transparent background panel
	var bg = Panel.new()
	bg.name = "HUDBg"
	bg.size = Vector2(120, 52)
	bg.position = Vector2.ZERO
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.1, 0.7)
	bg_style.set_corner_radius_all(4)
	bg_style.set_border_width_all(1)
	bg_style.border_color = Color(0.3, 0.3, 0.4, 0.8)
	bg.add_theme_stylebox_override("panel", bg_style)
	hud_container.add_child(bg)

	# Player name label
	player_name_label = Label.new()
	player_name_label.text = "Player"
	player_name_label.position = Vector2(6, 2)
	player_name_label.size = Vector2(108, 12)
	player_name_label.add_theme_font_size_override("font_size", 10)
	player_name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	hud_container.add_child(player_name_label)

	# Stat bars - compact horizontal layout
	var bar_width = 100
	var bar_height = 10
	var bar_x = 6
	var bar_y = 16

	# HP bar (red)
	player_hp_bar = _create_hud_bar(hud_container, "HP", bar_x, bar_y, bar_width, bar_height,
		Color(0.85, 0.2, 0.2), Color(0.3, 0.1, 0.1, 0.8))
	bar_y += bar_height + 2

	# MP bar (blue)
	player_mp_bar = _create_hud_bar(hud_container, "MP", bar_x, bar_y, bar_width, bar_height,
		Color(0.2, 0.4, 0.9), Color(0.1, 0.1, 0.3, 0.8))
	bar_y += bar_height + 2

	# EP bar (green/yellow)
	player_ep_bar = _create_hud_bar(hud_container, "EP", bar_x, bar_y, bar_width, bar_height,
		Color(0.3, 0.8, 0.3), Color(0.1, 0.25, 0.1, 0.8))

func _create_hud_bar(parent: Control, label_text: String, x: float, y: float,
		width: float, height: float, fill_color: Color, bg_color: Color) -> ProgressBar:
	"""Create a labeled progress bar for the HUD"""
	var bar = ProgressBar.new()
	bar.position = Vector2(x, y)
	bar.size = Vector2(width, height)
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false

	# Style the bar
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = bg_color
	bg_style.set_corner_radius_all(2)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(2)

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	parent.add_child(bar)

	# Label inside bar
	var label = Label.new()
	label.text = label_text
	label.position = Vector2(4, 0)
	label.size = Vector2(width - 8, height)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(label)

	return bar

func update_player_hud(hp: int, max_hp: int, mp: int, max_mp: int, ep: int, max_ep: int, name: String = "") -> void:
	"""Update player corner HUD with current stats"""
	if player_hp_bar:
		player_hp_bar.max_value = max_hp
		player_hp_bar.value = hp
	if player_mp_bar:
		player_mp_bar.max_value = max_mp
		player_mp_bar.value = mp
	if player_ep_bar:
		player_ep_bar.max_value = max_ep
		player_ep_bar.value = ep
	if player_name_label and not name.is_empty():
		player_name_label.text = name
