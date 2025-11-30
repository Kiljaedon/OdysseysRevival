class_name BattleMapGenerator
extends RefCounted
## Battle Map Generator - Creates battle arena data
## Used by: Server (authoritative), Client (rendering)
## Pure functions. Deterministic output.

## ========== CONSTANTS ==========
const TILE_SIZE: int = 128  # 32px * 4 scale

const ARENA_SIZES = {
	"small": Vector2i(12, 10),   # Normal mobs
	"medium": Vector2i(16, 12),  # Dungeon bosses
	"large": Vector2i(20, 16)    # Raid bosses
}

const DEFAULT_GRASS_TILE: int = 568  # From test map

## ========== MAP GENERATION ==========

static func generate_battle_map(arena_type: String = "small", terrain_tile: int = DEFAULT_GRASS_TILE) -> Dictionary:
	"""Generate a simple battle arena with grass tiles"""
	var size = ARENA_SIZES.get(arena_type, ARENA_SIZES["small"])

	return {
		"arena_type": arena_type,
		"size_tiles": size,
		"size_pixels": Vector2(size.x * TILE_SIZE, size.y * TILE_SIZE),
		"tile_size": TILE_SIZE,
		"terrain_tile": terrain_tile,
		"tiles": _generate_tile_grid(size, terrain_tile),
		"obstacles": []  # No obstacles for now
	}

static func _generate_tile_grid(size: Vector2i, tile_id: int) -> Array:
	"""Generate 2D array of tile IDs"""
	var grid = []
	for y in range(size.y):
		var row = []
		for x in range(size.x):
			row.append(tile_id)
		grid.append(row)
	return grid

## ========== SPAWN POSITIONS ==========

static func get_player_spawn_positions(map_data: Dictionary, squad_size: int = 4) -> Array:
	"""Get spawn positions for player squad (bottom of arena)"""
	var arena = map_data.size_pixels
	var center_x = arena.x / 2
	var bottom_y = arena.y - TILE_SIZE * 2

	var positions = []

	# Player at center bottom
	positions.append(Vector2(center_x, bottom_y))

	# Squad positions around player
	var squad_offsets = [
		Vector2(-TILE_SIZE * 2, 0),    # Left
		Vector2(TILE_SIZE * 2, 0),     # Right
		Vector2(0, TILE_SIZE)          # Behind
	]

	for i in range(min(squad_size - 1, squad_offsets.size())):
		positions.append(Vector2(center_x, bottom_y) + squad_offsets[i])

	return positions

static func get_enemy_spawn_positions(map_data: Dictionary, enemy_count: int = 5) -> Array:
	"""Get spawn positions for enemies (top of arena)"""
	var arena = map_data.size_pixels
	var center_x = arena.x / 2

	var positions = [
		Vector2(center_x - TILE_SIZE * 3, TILE_SIZE * 2),  # Left
		Vector2(center_x, TILE_SIZE * 2),                   # Center
		Vector2(center_x + TILE_SIZE * 3, TILE_SIZE * 2),  # Right
		Vector2(center_x - TILE_SIZE * 1.5, TILE_SIZE),    # Back left
		Vector2(center_x + TILE_SIZE * 1.5, TILE_SIZE)     # Back right
	]

	return positions.slice(0, enemy_count)

## ========== UTILITY ==========

static func get_arena_bounds(map_data: Dictionary) -> Rect2:
	"""Get arena bounds as Rect2"""
	return Rect2(Vector2.ZERO, map_data.size_pixels)

static func is_position_valid(map_data: Dictionary, position: Vector2, padding: float = 30.0) -> bool:
	"""Check if position is within arena bounds"""
	var bounds = get_arena_bounds(map_data)
	bounds = bounds.grow(-padding)
	return bounds.has_point(position)

static func clamp_to_arena(map_data: Dictionary, position: Vector2, padding: float = 30.0) -> Vector2:
	"""Clamp position to arena bounds"""
	var arena = map_data.size_pixels
	return Vector2(
		clamp(position.x, padding, arena.x - padding),
		clamp(position.y, padding, arena.y - padding)
	)
