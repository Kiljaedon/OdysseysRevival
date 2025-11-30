class_name SpatialManager
extends Node
## Interest management system using spatial grid
## Only sends entities to clients that can see them
## Critical for scaling to 1000+ players

# Grid configuration
var grid_cell_size: int = 512  # Pixels per cell (4 tiles at 128px)
var visibility_radius: int = 2  # Grid cells to check around player

# Spatial grid: grid_key -> [entity_ids]
var spatial_grid: Dictionary = {}

# Entity tracking: entity_id -> {position, type, grid_key}
var tracked_entities: Dictionary = {}

## ========== ENTITY MANAGEMENT ==========

func register_entity(entity_id: int, position: Vector2, entity_type: String):
	"""Register an entity in the spatial grid"""
	var grid_key = position_to_grid_key(position)

	tracked_entities[entity_id] = {
		"position": position,
		"type": entity_type,
		"grid_key": grid_key
	}

	# Add to spatial grid
	if not spatial_grid.has(grid_key):
		spatial_grid[grid_key] = []

	if not spatial_grid[grid_key].has(entity_id):
		spatial_grid[grid_key].append(entity_id)

	#print("[SPATIAL] Registered %s #%d at grid %s" % [entity_type, entity_id, grid_key])


func unregister_entity(entity_id: int):
	"""Remove entity from spatial grid"""
	if not tracked_entities.has(entity_id):
		return

	var entity_data = tracked_entities[entity_id]
	var grid_key = entity_data.grid_key

	# Remove from grid cell
	if spatial_grid.has(grid_key):
		spatial_grid[grid_key].erase(entity_id)
		if spatial_grid[grid_key].is_empty():
			spatial_grid.erase(grid_key)

	tracked_entities.erase(entity_id)
	#print("[SPATIAL] Unregistered entity #%d" % entity_id)


func update_entity_position(entity_id: int, new_position: Vector2):
	"""Update entity position and move to new grid cell if needed"""
	if not tracked_entities.has(entity_id):
		push_error("[SPATIAL] Tried to update unregistered entity #%d" % entity_id)
		return

	var entity_data = tracked_entities[entity_id]
	var old_grid_key = entity_data.grid_key
	var new_grid_key = position_to_grid_key(new_position)

	# Update position
	entity_data.position = new_position

	# Check if moved to new grid cell
	if old_grid_key != new_grid_key:
		# Remove from old cell
		if spatial_grid.has(old_grid_key):
			spatial_grid[old_grid_key].erase(entity_id)
			if spatial_grid[old_grid_key].is_empty():
				spatial_grid.erase(old_grid_key)

		# Add to new cell
		if not spatial_grid.has(new_grid_key):
			spatial_grid[new_grid_key] = []

		if not spatial_grid[new_grid_key].has(entity_id):
			spatial_grid[new_grid_key].append(entity_id)

		entity_data.grid_key = new_grid_key
		#print("[SPATIAL] Entity #%d moved from grid %s to %s" % [entity_id, old_grid_key, new_grid_key])


## ========== INTEREST QUERIES ==========

func get_entities_near(position: Vector2, radius_cells: int = -1) -> Array:
	"""Get all entities within radius grid cells of position"""
	if radius_cells < 0:
		radius_cells = visibility_radius

	var center_grid = position_to_grid_coords(position)
	var nearby_entities = []

	# Check all grid cells within radius
	for x in range(center_grid.x - radius_cells, center_grid.x + radius_cells + 1):
		for y in range(center_grid.y - radius_cells, center_grid.y + radius_cells + 1):
			var grid_key = Vector2i(x, y)

			if spatial_grid.has(grid_key):
				nearby_entities.append_array(spatial_grid[grid_key])

	return nearby_entities


func get_entities_for_player(peer_id: int) -> Dictionary:
	"""Get all entities that should be visible to a player
	Returns: {entity_id: position}"""

	if not tracked_entities.has(peer_id):
		return {}

	var player_pos = tracked_entities[peer_id].position
	var nearby_ids = get_entities_near(player_pos)
	var result = {}

	for entity_id in nearby_ids:
		if entity_id == peer_id:
			continue  # Don't send player their own position

		if tracked_entities.has(entity_id):
			result[entity_id] = tracked_entities[entity_id].position

	return result


func get_players_who_can_see(entity_id: int) -> Array:
	"""Get list of player peer_ids who can see this entity"""
	if not tracked_entities.has(entity_id):
		return []

	var entity_pos = tracked_entities[entity_id].position
	var nearby_ids = get_entities_near(entity_pos)
	var players = []

	for id in nearby_ids:
		if not tracked_entities.has(id):
			continue

		# Only return player entities
		if tracked_entities[id].type == "player":
			players.append(id)

	return players


## ========== GRID UTILITIES ==========

func position_to_grid_coords(position: Vector2) -> Vector2i:
	"""Convert world position to grid coordinates"""
	return Vector2i(
		int(floor(position.x / grid_cell_size)),
		int(floor(position.y / grid_cell_size))
	)


func position_to_grid_key(position: Vector2) -> Vector2i:
	"""Convert world position to grid key (same as coords)"""
	return position_to_grid_coords(position)


func grid_key_to_position(grid_key: Vector2i) -> Vector2:
	"""Convert grid key to world position (center of cell)"""
	return Vector2(
		grid_key.x * grid_cell_size + grid_cell_size / 2,
		grid_key.y * grid_cell_size + grid_cell_size / 2
	)


## ========== DEBUG ==========

func get_stats() -> Dictionary:
	"""Get spatial manager statistics"""
	return {
		"total_entities": tracked_entities.size(),
		"active_cells": spatial_grid.size(),
		"cell_size": grid_cell_size,
		"visibility_radius": visibility_radius
	}


func print_stats():
	"""Print spatial manager statistics"""
	var stats = get_stats()
	print("[SPATIAL] Stats: %d entities in %d cells (cell_size=%d, radius=%d)" % [
		stats.total_entities,
		stats.active_cells,
		stats.cell_size,
		stats.visibility_radius
	])


func get_entities_in_cell(grid_key: Vector2i) -> Array:
	"""Get all entities in a specific grid cell"""
	if spatial_grid.has(grid_key):
		return spatial_grid[grid_key]
	return []
