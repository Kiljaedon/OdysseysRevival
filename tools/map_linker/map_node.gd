extends Node2D
class_name MapNode

## Visual representation of a TMX map on the infinite canvas.
## Handles rendering and interaction with map objects (warps).

signal warp_selected(warp_id: int, warp_node: Node2D)
signal map_dragged(relative_pos: Vector2)

var tmx_path: String = ""
var map_data: Dictionary = {}
var is_selected: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _is_dragging: bool = false

@onready var tile_container: Node2D = $TileContainer
@onready var object_container: Node2D = $ObjectContainer
@onready var selection_border: ReferenceRect = $SelectionBorder
@onready var label: Label = $Header/Label

const TMXLoader = preload("res://source/common/maps/tmx_loader.gd")

func setup(path: String):
	tmx_path = path
	name = path.get_file().get_basename()
	label.text = name
	
	_load_map()

func _load_map():
	# 1. Parse Data
	map_data = TMXLoader.parse_tmx_file(tmx_path)
	if map_data.is_empty():
		push_error("MapNode: Failed to parse " + tmx_path)
		return
		
	# 2. Render Tiles (Simplified)
	# We use TMXLoader to create a visual representation
	# For the tool, we might not need full collision, so we could just visualize
	# But reusing TMXLoader.create_map_scene_from_tmx is easiest, then strip collision
	
	var scene = TMXLoader.create_map_scene_from_tmx(tmx_path, "res://assets-odyssey/tiles_part1.png") # TODO: Handle multiple tilesets dynamically
	if not scene:
		push_error("MapNode: Failed to create scene for " + tmx_path)
		return

	if scene:
		# Reparent the visual parts to our container
		var tilemap = scene.get_node_or_null("TileMap")
		if tilemap:
			scene.remove_child(tilemap)
			tile_container.add_child(tilemap)
			
			# Disable collision for tool view to save performance/physics issues
			# Iterating to free StaticBodies
			for child in tilemap.get_children():
				if child is StaticBody2D:
					child.queue_free()
		
		# Load Objects specifically for the Tool (Custom logic instead of Scene's warps)
		_create_tool_objects()
		
		scene.queue_free()
		
	# Update Border Size
	var width = map_data.width * map_data.tilewidth
	var height = map_data.height * map_data.tileheight
	selection_border.size = Vector2(width, height)
	$Header.position.y = -30
	$Header.size.x = width

func _create_tool_objects():
	# Create clickable buttons for Warps
	for group in map_data.object_groups:
		if group.name.to_lower() == "warps":
			for obj in group.objects:
				# Case insensitive check for type
				var obj_type = str(obj.properties.get("type", "")).to_lower()
				if obj_type == "warp":
					var btn = _create_warp_button(obj)
					object_container.add_child(btn)

func _create_warp_button(obj: Dictionary) -> Button:
	var btn = Button.new()
	btn.flat = true
	btn.position = Vector2(obj.x, obj.y)
	btn.size = Vector2(obj.width, obj.height)
	btn.toggle_mode = true
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 0, 1, 0.3) # Magenta transparent
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 0, 1, 0.8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	
	# Metadata
	btn.set_meta("object_id", obj.id)
	btn.set_meta("data", obj)
	
	btn.pressed.connect(func(): _on_warp_clicked(obj.id, btn))
	
	return btn

func _on_warp_clicked(id: int, btn: Button):
	warp_selected.emit(id, btn)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start = get_global_mouse_position()
				_is_dragging = true
			else:
				_is_dragging = false
				
	elif event is InputEventMouseMotion:
		if _is_dragging:
			var current_pos = get_global_mouse_position()
			var delta = current_pos - _drag_start
			position += delta
			_drag_start = current_pos
			map_dragged.emit(delta)
