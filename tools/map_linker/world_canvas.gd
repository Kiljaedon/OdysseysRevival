extends Control
class_name WorldCanvas

## Infinite canvas for managing MapNodes.
## Handles camera navigation, drag-and-drop of maps, and drawing connection lines.

# Config
var zoom_min: float = 0.1
var zoom_max: float = 4.0
var zoom_speed: float = 0.1

# State
var zoom_level: float = 1.0
var is_panning: bool = false
var pan_start: Vector2 = Vector2.ZERO
var camera_pos: Vector2 = Vector2.ZERO

# Connection State
var selected_warp: Dictionary = {} # { "node": MapNode, "warp_id": int, "warp_pos": Vector2 }
var is_drawing_link: bool = false
var current_mouse_pos: Vector2 = Vector2.ZERO

@onready var content: Node2D = $Content
@onready var maps_container: Node2D = $Content/Maps
@onready var connections_container: Node2D = $Content/Connections

const MapNodeScene = preload("res://tools/map_linker/map_node.tscn")

func _ready():
	# Enable input processing
	set_process_input(true)
	
	# Initial center
	camera_pos = size / 2

func _draw():
	# Draw active connection line being dragged
	if is_drawing_link and not selected_warp.is_empty():
		var start = selected_warp.node.position + selected_warp.warp_pos
		var end = (get_local_mouse_position() - content.position) / zoom_level
		draw_bezier_link(start, end, Color.YELLOW)
		
	# Draw existing connections (TODO: Store and iterate real connections)
	pass

func draw_bezier_link(start: Vector2, end: Vector2, color: Color):
	var control_scale = start.distance_to(end) * 0.5
	var cp1 = start + Vector2(control_scale, 0)
	var cp2 = end - Vector2(control_scale, 0)
	
	# Manual Bezier curve generation (Function draw_bezier not found in this version)
	var points = PackedVector2Array()
	var segments = 20
	for i in range(segments + 1):
		var t = float(i) / segments
		var q0 = start.lerp(cp1, t)
		var q1 = cp1.lerp(cp2, t)
		var q2 = cp2.lerp(end, t)
		var r0 = q0.lerp(q1, t)
		var r1 = q1.lerp(q2, t)
		var point = r0.lerp(r1, t)
		points.append(point)
	
	draw_polyline(points, color, 3.0 * zoom_level)
	
	# Draw Arrowhead
	var dir = (end - cp2).normalized()
	draw_circle(end, 5.0 * zoom_level, color)

func add_map(path: String, position: Vector2 = Vector2.ZERO):
	var map_node = MapNodeScene.instantiate()
	maps_container.add_child(map_node)
	map_node.position = position
	map_node.setup(path)
	
	# Connect signals
	map_node.warp_selected.connect(_on_warp_selected.bind(map_node))
	map_node.map_dragged.connect(_on_map_dragged)

func _on_warp_selected(warp_id: int, btn: Button, map_node: Node2D):
	print("Selected Warp: ", warp_id)
	selected_warp = {
		"node": map_node,
		"warp_id": warp_id,
		"warp_pos": btn.position + btn.size/2 # Center of warp rect
	}
	is_drawing_link = true

func _on_map_dragged(relative: Vector2):
	queue_redraw() # Redraw lines if maps move

func _input(event):
	if event is InputEventMouseButton:
		# Panning (Middle Mouse or Space+Left)
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_panning = true
				pan_start = event.position
			else:
				is_panning = false
		
		# Zooming
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_point(1.1, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_point(0.9, event.position)
			
		# End Link Dragging
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_drawing_link:
				_finish_link(event.position)

	elif event is InputEventMouseMotion:
		if is_panning:
			var delta = event.position - pan_start
			camera_pos += delta
			pan_start = event.position
			_update_transform()
			
		if is_drawing_link:
			queue_redraw()

func _zoom_at_point(factor: float, center: Vector2):
	var old_zoom = zoom_level
	zoom_level = clamp(zoom_level * factor, zoom_min, zoom_max)
	
	# Adjust camera pos to zoom towards mouse
	var mouse_world_before = (center - content.position) / old_zoom
	var mouse_world_after = (center - content.position) / zoom_level
	# This math is complex for a simple transform, simplifying:
	# Just scale around center?
	# Let's stick to simple center zoom for now, offset logic is brittle
	_update_transform()

func _update_transform():
	content.scale = Vector2(zoom_level, zoom_level)
	content.position = camera_pos 

const TMXWriter = preload("res://source/common/maps/tmx_writer.gd")

# Pending changes: Array of { "source_map": path, "warp_id": id, "target_map": name, "target_x": x, "target_y": y }
var pending_changes: Array[Dictionary] = []

func save_all():
	var success_count = 0
	var fail_count = 0
	
	for change in pending_changes:
		var result = TMXWriter.update_warp_target(
			change.source_map,
			change.warp_id,
			change.target_map,
			change.target_x,
			change.target_y
		)
		
		if result:
			# Also carve collision at the warp location
			# We need the rect of the warp object. We can get it from the map node if it's still loaded
			# Or we store it in pending_changes
			if change.has("warp_rect"):
				TMXWriter.carve_collision(change.source_map, change.warp_rect)
			
			success_count += 1
		else:
			fail_count += 1
			push_error("Failed to save link for " + change.source_map)
			
	if fail_count == 0:
		pending_changes.clear()
		print("Saved %d changes successfully." % success_count)
	else:
		print("Saved %d changes with %d failures." % [success_count, fail_count])

func _finish_link(mouse_pos: Vector2):
	is_drawing_link = false
	queue_redraw()
	
	# Find map under mouse (Target Map)
	var world_pos = (mouse_pos - content.position) / zoom_level
	var target_map_node = _get_map_at_pos(world_pos)
	
	if target_map_node and not selected_warp.is_empty():
		var source_node = selected_warp.node
		var target_name = target_map_node.tmx_path.get_file()
		
		# Calculate local coordinates in target map
		# Mouse pos is global to canvas. Map node is at map_node.position
		var local_pos = world_pos - target_map_node.position
		
		# Snap to tile
		var tile_x = int(local_pos.x / 32) * 32
		var tile_y = int(local_pos.y / 32) * 32
		
		print("Linking Warp %d -> %s at %d, %d" % [selected_warp.warp_id, target_name, tile_x, tile_y])
		
		# Store change
		var change = {
			"source_map": source_node.tmx_path,
			"warp_id": selected_warp.warp_id,
			"target_map": target_name,
			"target_x": tile_x,
			"target_y": tile_y,
			"warp_rect": _get_warp_rect(source_node, selected_warp.warp_id)
		}
		pending_changes.append(change)
		
		# Visual feedback (optional: permanent line)
		pass
	else:
		print("Link dropped on empty space")

func _get_map_at_pos(pos: Vector2) -> Node2D:
	for child in maps_container.get_children():
		if child is MapNode:
			var rect = Rect2(child.position, child.selection_border.size)
			if rect.has_point(pos):
				return child
	return null

func _get_warp_rect(map_node: MapNode, warp_id: int) -> Rect2:
	# Helper to find the rect of a warp object from the node metadata
	# This requires MapNode to expose its data or we lookup buttons
	for btn in map_node.object_container.get_children():
		if btn.has_meta("object_id") and btn.get_meta("object_id") == warp_id:
			var obj = btn.get_meta("data")
			return Rect2(obj.x, obj.y, obj.width, obj.height)
	return Rect2()

func _can_drop_data(at_position, data):
	return typeof(data) == TYPE_DICTIONARY and data.has("files")

func _drop_data(at_position, data):
	var world_pos = (at_position - content.position) / zoom_level
	for file_path in data.files:
		if file_path.ends_with(".tmx"):
			add_map(file_path, world_pos)
			world_pos += Vector2(50, 50) # Cascade
