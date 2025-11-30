class_name CollisionSystemManager
extends Node

## ============================================================================
## COLLISION SYSTEM MANAGER
## ============================================================================
## Handles collision detection, collision response, and hitbox management.
## Manages collision objects from TMX maps (object layers with rectangles).
##
## Responsibilities:
## - Collision object loading from TMX
## - Collision detection and response
## - Hitbox management
## - Collision layer/mask management
## ============================================================================

# Node references (injected via initialize)
var game_world: Node2D

# Collision objects from TMX object layers
var collision_objects: Array[StaticBody2D] = []

## ============================================================================
## INITIALIZATION
## ============================================================================

func initialize(world: Node2D) -> void:
	"""Initialize with dependency injection."""
	game_world = world
	print("[CollisionSystemManager]  Initialized")

## ============================================================================
## COLLISION OBJECT LOADING (TMX)
## ============================================================================

func load_collision_objects(objectgroup_content: String, tile_width: int, tile_height: int) -> int:
	"""Parse TMX objectgroup content and create StaticBody2D collision objects.

	TMX Object Format:
	  <object id="1" x="224" y="192" width="64" height="32"/>

	Returns: Number of collision objects created
	"""
	print("=== LOADING COLLISION OBJECTS ===")

	# Parse object elements: <object id="1" x="224" y="192" width="64" height="32"/>
	var object_regex = RegEx.new()
	object_regex.compile('<object[^>]*x="([^"]*)"[^>]*y="([^"]*)"[^>]*width="([^"]*)"[^>]*height="([^"]*)"')
	var object_results = object_regex.search_all(objectgroup_content)

	var objects_created = 0
	for object_result in object_results:
		var obj_x = object_result.get_string(1).to_float()
		var obj_y = object_result.get_string(2).to_float()
		var obj_width = object_result.get_string(3).to_float()
		var obj_height = object_result.get_string(4).to_float()

		# Account for 4x tile scale
		obj_x *= 4
		obj_y *= 4
		obj_width *= 4
		obj_height *= 4

		# Create StaticBody2D for collision
		var collision_body = StaticBody2D.new()
		collision_body.name = "CollisionObject_" + str(objects_created)
		collision_body.collision_layer = 1  # Same as tiles
		collision_body.collision_mask = 0

		# Position at center of rectangle
		collision_body.position = Vector2(obj_x + obj_width / 2, obj_y + obj_height / 2)

		# Create collision shape
		var collision_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(obj_width, obj_height)
		collision_shape.shape = rect_shape

		collision_body.add_child(collision_shape)
		game_world.add_child(collision_body)
		collision_objects.append(collision_body)

		print("  Created collision object at (", obj_x, ", ", obj_y, ") size (", obj_width, "x", obj_height, ")")
		objects_created += 1

	print("=== COLLISION OBJECTS LOADED: ", objects_created, " ===")
	return objects_created

## ============================================================================
## COLLISION OBJECT MANAGEMENT
## ============================================================================

func clear_collision_objects() -> void:
	"""Clear all collision objects (called when loading new map)."""
	print("[CollisionSystemManager] Clearing ", collision_objects.size(), " collision objects")

	for obj in collision_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	collision_objects.clear()

func get_collision_object_count() -> int:
	"""Get number of active collision objects."""
	return collision_objects.size()

func get_collision_objects() -> Array[StaticBody2D]:
	"""Get all collision objects."""
	return collision_objects

## ============================================================================
## UTILITY FUNCTIONS
## ============================================================================

func set_collision_layer(layer: int) -> void:
	"""Set collision layer for all collision objects."""
	for obj in collision_objects:
		if is_instance_valid(obj):
			obj.collision_layer = layer

func set_collision_mask(mask: int) -> void:
	"""Set collision mask for all collision objects."""
	for obj in collision_objects:
		if is_instance_valid(obj):
			obj.collision_mask = mask

func debug_print_collision_info() -> void:
	"""Print debug information about collision objects."""
	print("=== COLLISION SYSTEM DEBUG ===")
	print("Total collision objects: ", collision_objects.size())
	for i in range(collision_objects.size()):
		var obj = collision_objects[i]
		if is_instance_valid(obj):
			print("  [%d] %s at %s (layer=%d, mask=%d)" % [
				i, obj.name, obj.position, obj.collision_layer, obj.collision_mask
			])
