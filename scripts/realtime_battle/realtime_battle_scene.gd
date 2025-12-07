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
const ARENA_PADDING: int = 128  # Keep units away from edges (matches server MAP_EDGE_PADDING)

## ========== MAP DATA ==========
var arena_width: int = 2560   # Default: 20 tiles * 128px scaled (overwritten by battle_data)
var arena_height: int = 1920  # Default: 15 tiles * 128px scaled (overwritten by battle_data)
var battle_map_name: String = "sample_map"

## ========== STATE ==========
var battle_id: int = -1
var battle_active: bool = false
var player_unit_id: String = ""
var units: Dictionary = {}  # unit_id -> RealtimeBattleUnit
var projectiles: Dictionary = {}  # projectile_id -> projectile node (server-authoritative)
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

## ========== CHILD NODES ==========
@onready var arena_renderer: Node2D = $ArenaRenderer
@onready var units_container: Node2D = $UnitsContainer
@onready var camera: Camera2D = $BattleCamera
@onready var ui_layer: CanvasLayer = $BattleUI
@onready var player_name_label: Label = $BattleUI/PlayerHUD/PlayerNameLabel
@onready var player_hp_bar: ProgressBar = $BattleUI/PlayerHUD/HPBar
@onready var player_mp_bar: ProgressBar = $BattleUI/PlayerHUD/MPBar
@onready var player_ep_bar: ProgressBar = $BattleUI/PlayerHUD/EPBar

func _ready():
	print("[RT_BATTLE_SCENE] Ready")
func _process(_delta: float):
	if not battle_active:
		return
	# Camera follows the player unit
	var player = get_player_unit()
	if player:
		if player.position.is_finite():
			camera.global_position = player.position
		else:
			print("[RT_BATTLE_SCENE] WARNING: Player position invalid (NaN/Inf): ", player.position)

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

	# Clear projectiles
	for proj in projectiles.values():
		if is_instance_valid(proj):
			proj.queue_free()
	projectiles.clear()

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
	"""Handle damage event from server (damage already confirmed by server)"""
	if not attacker_id in units or not target_id in units:
		return

	var attacker = units[attacker_id]
	var target = units[target_id]

	# Play attack animation on attacker (melee only - ranged already triggered on projectile spawn)
	var combat_role = attacker.combat_role if attacker.combat_role else "melee"
	var combat_role_lower = combat_role.to_lower()

	if combat_role_lower not in ["ranged", "caster"]:
		# Melee/Hybrid - play attack animation
		attacker.play_attack_animation()

	# Show damage on target (server confirmed the hit)
	target.show_damage(damage, flank_type)

	unit_damaged.emit(target_id, damage, flank_type)

func on_unit_death(unit_id: String) -> void:
	"""Handle unit death from server"""
	if unit_id in units:
		units[unit_id].play_death()
	unit_died.emit(unit_id)

func on_dodge_roll_event(unit_id: String, direction: Vector2) -> void:
	"""Handle dodge roll from server"""
	if unit_id in units:
		units[unit_id].play_dodge_roll(direction)

## ========== SERVER-AUTHORITATIVE PROJECTILES ==========

func on_projectile_spawn(proj_data: Dictionary) -> void:
	"""Handle server-spawned projectile"""
	var proj_id = proj_data.get("id", "")
	var attacker_id = proj_data.get("attacker_id", "")
	var start_pos = proj_data.get("position", Vector2.ZERO)
	var velocity = proj_data.get("velocity", Vector2.ZERO)
	var texture_path = proj_data.get("texture", "")

	# Convert world position to arena position
	start_pos = world_to_arena_pos(start_pos)
	
	# FIX: Offset projectile up to chest height (feet are at 0, top is ~ -96)
	start_pos.y -= 48.0

	print("[BATTLE_SCENE] Projectile spawn: %s from %s at %s, velocity=%s, texture=%s" % [proj_id, attacker_id, start_pos, velocity, texture_path])

	# Play attack animation on attacker
	if attacker_id in units:
		units[attacker_id].play_attack_animation()

	# Create projectile visual
	var projectile_scene = preload("res://scenes/projectile.tscn")
	var projectile = projectile_scene.instantiate()
	projectile.name = proj_id

	# Set texture BEFORE adding to tree (so it's ready when _ready() runs)
	var frame_count = 8
	var texture_loaded = false
	if texture_path and projectile.has_node("Sprite2D"):
		var sprite = projectile.get_node("Sprite2D")
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			if texture:
				sprite.texture = texture
				sprite.hframes = frame_count
				sprite.frame = 0
				projectile.total_frames = frame_count
				texture_loaded = true
				print("[BATTLE_SCENE] Projectile texture loaded: %s (hframes=%d)" % [texture_path, frame_count])
			else:
				print("[BATTLE_SCENE] ERROR: Failed to load texture: %s" % texture_path)
		else:
			print("[BATTLE_SCENE] ERROR: Texture not found: %s" % texture_path)

	if not texture_loaded:
		print("[BATTLE_SCENE] WARNING: Projectile %s has no texture!" % proj_id)

	# Add to units_container for proper z-ordering (above units)
	if units_container:
		units_container.add_child(projectile)
	else:
		add_child(projectile)

	# Set high z-index so projectile renders above units
	projectile.z_index = 100

	# Calculate direction from velocity
	var direction = velocity.normalized() if velocity.length() > 0 else Vector2.RIGHT

	# Initialize projectile (will move based on velocity)
	projectile.position = start_pos
	projectile.initialize(start_pos, direction, 0, attacker_id, "")

	# Override with server velocity (authoritative)
	projectile.set_server_velocity(velocity)

	projectiles[proj_id] = projectile
	print("[BATTLE_SCENE] Projectile %s added at position %s, z_index=%d" % [proj_id, projectile.position, projectile.z_index])

func on_projectile_hit(projectile_id: String, target_id: String, hit_position: Vector2) -> void:
	"""Handle projectile hit from server"""
	print("[BATTLE_SCENE] Projectile %s HIT %s at %s" % [projectile_id, target_id, hit_position])

	# Remove projectile visual
	if projectile_id in projectiles:
		var projectile = projectiles[projectile_id]
		if is_instance_valid(projectile):
			# Optional: Play hit effect at target position
			projectile.queue_free()
		projectiles.erase(projectile_id)

	# Damage event will come separately from server

func on_projectile_miss(projectile_id: String, final_position: Vector2) -> void:
	"""Handle projectile miss from server (despawn)"""
	print("[BATTLE_SCENE] Projectile %s MISSED at %s" % [projectile_id, final_position])

	# Remove projectile visual
	if projectile_id in projectiles:
		var projectile = projectiles[projectile_id]
		if is_instance_valid(projectile):
			# Optional: Play miss/fizzle effect
			projectile.queue_free()
		projectiles.erase(projectile_id)



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
