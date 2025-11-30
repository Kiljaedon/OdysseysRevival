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
## Arena size - matches the SubViewport (900-8 = 892 width, 700-40 = 660 height)
const ARENA_WIDTH: int = 892  # Match viewport width
const ARENA_HEIGHT: int = 660  # Match viewport height
const ARENA_PADDING: int = 60  # Keep units away from edges

## ========== CHILD NODES ==========
var arena_renderer: Node2D
var units_container: Node2D
var ui_layer: CanvasLayer
var camera: Camera2D

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
	return Vector2(ARENA_WIDTH, ARENA_HEIGHT)

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
	camera.position = Vector2(ARENA_WIDTH / 2.0, ARENA_HEIGHT / 2.0)
	add_child(camera)

	# UI layer for health bars, damage numbers
	ui_layer = CanvasLayer.new()
	ui_layer.name = "BattleUI"
	ui_layer.layer = 10
	add_child(ui_layer)

func _process(_delta: float):
	if not battle_active:
		return
	# Camera stays centered on arena (fullscreen view)

## ========== BATTLE LIFECYCLE ==========

func start_battle(battle_data: Dictionary) -> void:
	"""Initialize battle from server data"""
	battle_id = battle_data.get("id", -1)
	player_unit_id = battle_data.get("player_unit_id", "")

	# Calculate coordinate mapping from world to arena
	# Battle center is where the player was when battle started
	var battle_center = battle_data.get("battle_center", Vector2(1280, 960))
	var spawn_distance = 12 * 128  # 12 tiles * 128px per tile = 1536px

	# The battle area in world coords spans from (center - spawn_distance) to (center + some margin)
	# We want to map this to fit in the arena (892x660)
	# Player at bottom of arena, enemies at top
	var world_battle_height = spawn_distance + 256  # Extra space above and below
	var world_battle_width = 800  # Width of battle area

	# Calculate scale to fit world battle area into arena
	world_to_arena_scale = min(
		(ARENA_WIDTH - ARENA_PADDING * 2) / world_battle_width,
		(ARENA_HEIGHT - ARENA_PADDING * 2) / world_battle_height
	)

	# Offset so battle center maps to arena center
	# Player is at battle_center, enemies are at battle_center.y - spawn_distance
	# We want player at bottom of arena (75% down), enemies at top (25% down)
	var arena_center_y = ARENA_HEIGHT * 0.5
	world_offset = Vector2(
		battle_center.x - (ARENA_WIDTH / 2.0) / world_to_arena_scale,
		battle_center.y - spawn_distance / 2.0 - (ARENA_HEIGHT / 2.0) / world_to_arena_scale
	)

	print("[RT_BATTLE_SCENE] Coordinate mapping: scale=%.3f, offset=%s" % [world_to_arena_scale, world_offset])

	# Render arena using current map as background
	_render_arena_from_map(battle_data)

	# Spawn units (positions will be converted from world to arena coords)
	_spawn_units(battle_data.get("units", {}))

	# Center camera on arena
	camera.global_position = Vector2(ARENA_WIDTH / 2.0, ARENA_HEIGHT / 2.0)
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()

	# Activate camera
	camera.make_current()

	battle_active = true
	battle_started.emit(battle_data)
	print("[RT_BATTLE_SCENE] Battle %d started (arena: %dx%d, using current map)" % [battle_id, ARENA_WIDTH, ARENA_HEIGHT])

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

func _render_arena_from_map(battle_data: Dictionary) -> void:
	"""Render battle arena using the current map as background"""
	print("[RT_BATTLE_SCENE] Rendering arena from current map")

	# Try to capture the current map viewport
	var captured = _capture_map_viewport()

	if not captured:
		# Fallback: render simple grass background
		print("[RT_BATTLE_SCENE] Could not capture map, using fallback grass arena")
		_render_fallback_arena()

	_add_arena_border()

func _capture_map_viewport() -> bool:
	"""Capture the current game viewport as the arena background"""
	var parent_node = get_meta("parent_node") if has_meta("parent_node") else null
	if not parent_node:
		print("[RT_BATTLE_SCENE] No parent_node found")
		return false

	# Find the GameWorld node which contains the map layers
	var game_world = parent_node.get_node_or_null("GameWorld")
	if not game_world:
		print("[RT_BATTLE_SCENE] No GameWorld found")
		return false

	# Get the tile map layers
	var bottom_layer = game_world.get_node_or_null("BottomLayer")
	var middle_layer = game_world.get_node_or_null("MiddleLayer")
	var top_layer = game_world.get_node_or_null("TopLayer")

	if not bottom_layer:
		print("[RT_BATTLE_SCENE] No BottomLayer found")
		return false

	# Clone the map layers into the arena
	_clone_map_layer(bottom_layer, -10)
	if middle_layer:
		_clone_map_layer(middle_layer, -5)
	if top_layer:
		_clone_map_layer(top_layer, 0)

	print("[RT_BATTLE_SCENE] Map layers cloned to arena")
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
	var scale_factor = min(ARENA_WIDTH / 2560.0, ARENA_HEIGHT / 1920.0) * 1.2  # Slight upscale for better coverage
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
		(ARENA_WIDTH - 2560 * scale_factor) / 2.0,
		(ARENA_HEIGHT - 1920 * scale_factor) / 2.0
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
		Vector2(ARENA_WIDTH, 0),
		Vector2(ARENA_WIDTH, ARENA_HEIGHT),
		Vector2(0, ARENA_HEIGHT)
	])
	bg.z_index = -10
	arena_renderer.add_child(bg)

	# Add some texture variation with lighter patches
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Consistent pattern
	for i in range(20):
		var patch = Polygon2D.new()
		patch.name = "GrassPatch%d" % i
		var px = rng.randf_range(50, ARENA_WIDTH - 50)
		var py = rng.randf_range(50, ARENA_HEIGHT - 50)
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
		Vector2(ARENA_WIDTH, 0),
		Vector2(ARENA_WIDTH, ARENA_HEIGHT),
		Vector2(0, ARENA_HEIGHT),
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
		Vector2(ARENA_WIDTH - margin, margin),
		Vector2(ARENA_WIDTH - margin, ARENA_HEIGHT - margin),
		Vector2(margin, ARENA_HEIGHT - margin),
		Vector2(margin, margin)
	])
	inner_border.z_index = 5
	arena_renderer.add_child(inner_border)

	# Add corner decorations
	_add_corner_decoration(Vector2(32, 32))
	_add_corner_decoration(Vector2(ARENA_WIDTH - 32, 32))
	_add_corner_decoration(Vector2(32, ARENA_HEIGHT - 32))
	_add_corner_decoration(Vector2(ARENA_WIDTH - 32, ARENA_HEIGHT - 32))

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

func on_damage_event(attacker_id: String, target_id: String, damage: int, flank_type: String) -> void:
	"""Handle damage event from server"""
	# Play attack animation on attacker
	if attacker_id in units:
		units[attacker_id].play_attack_animation()

	# Show damage on target
	if target_id in units:
		units[target_id].show_damage(damage, flank_type)
	unit_damaged.emit(target_id, damage, flank_type)

func on_unit_death(unit_id: String) -> void:
	"""Handle unit death from server"""
	if unit_id in units:
		units[unit_id].play_death()
	unit_died.emit(unit_id)

func on_defend_event(unit_id: String) -> void:
	"""Handle defend activation from server"""
	if unit_id in units:
		units[unit_id].show_defend()
