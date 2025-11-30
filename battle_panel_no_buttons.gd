extends Panel
# Battle panel with character movement simulation and zoom controls

signal panel_selected(panel)
signal layout_changed

var is_dragging: bool = false
var is_resizing: bool = false
var is_selected: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var min_size: Vector2 = Vector2(100, 100)

# Character sprite movement
var sprite_node: TextureRect = null
var sprite_offset: Vector2 = Vector2.ZERO
var current_direction: String = "down"
var is_moving: bool = false
var move_speed: float = 100.0

# Zoom/scale controls
var sprite_scale: float = 1.0
var min_scale: float = 0.1
var max_scale: float = 5.0
var zoom_step: float = 0.1

# Selection border
var selection_border: ColorRect = null

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	sprite_node = find_sprite_node(self)
	create_selection_border()
	
	if sprite_node:
		sprite_offset = (size / 2.0) - (sprite_node.size / 2.0)

func find_sprite_node(node: Node) -> TextureRect:
	if node is TextureRect and "Sprite" in node.name:
		return node
	for child in node.get_children():
		var result = find_sprite_node(child)
		if result:
			return result
	return null

func create_selection_border():
	selection_border = ColorRect.new()
	selection_border.color = Color(1, 1, 0, 0.4)
	selection_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_border.visible = false
	selection_border.z_index = 100
	add_child(selection_border)

func _process(delta):
	if selection_border:
		selection_border.size = size
	
	if sprite_node and is_moving:
		update_sprite_position(delta)

func update_sprite_position(delta):
	var movement = Vector2.ZERO
	
	match current_direction:
		"up":
			movement = Vector2(0, -move_speed * delta)
		"down":
			movement = Vector2(0, move_speed * delta)
		"left":
			movement = Vector2(-move_speed * delta, 0)
		"right":
			movement = Vector2(move_speed * delta, 0)
	
	sprite_offset += movement
	
	var max_x = size.x - (sprite_node.size.x * sprite_scale)
	var max_y = size.y - (sprite_node.size.y * sprite_scale)
	sprite_offset.x = clamp(sprite_offset.x, 0, max_x)
	sprite_offset.y = clamp(sprite_offset.y, 0, max_y)
	
	sprite_node.position = sprite_offset

func apply_sprite_scale():
	if sprite_node:
		sprite_node.scale = Vector2(sprite_scale, sprite_scale)
		print(name, " sprite scale: ", sprite_scale)
		layout_changed.emit()

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				select()
				var local_pos = event.position
				var resize_zone = Rect2(size - Vector2(10, 10), Vector2(10, 10))
				if resize_zone.has_point(local_pos):
					is_resizing = true
				else:
					is_dragging = true
				drag_offset = event.position
			else:
				if is_dragging or is_resizing:
					layout_changed.emit()
				is_dragging = false
				is_resizing = false
		
		# Mouse wheel zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and is_selected:
			sprite_scale = clamp(sprite_scale + zoom_step, min_scale, max_scale)
			apply_sprite_scale()
			accept_event()
		
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and is_selected:
			sprite_scale = clamp(sprite_scale - zoom_step, min_scale, max_scale)
			apply_sprite_scale()
			accept_event()
	
	elif event is InputEventMouseMotion:
		if is_dragging:
			position += event.relative
		elif is_resizing:
			var new_size = event.position + Vector2(10, 10)
			size = Vector2(max(new_size.x, min_size.x), max(new_size.y, min_size.y))
			queue_redraw()

func _input(event):
	if not is_selected:
		return
	
	if event is InputEventKey:
		# WASD movement
		if event.keycode == KEY_W:
			if event.pressed:
				current_direction = "up"
				is_moving = true
			else:
				is_moving = false
			get_viewport().set_input_as_handled()
		
		elif event.keycode == KEY_A:
			if event.pressed:
				current_direction = "left"
				is_moving = true
			else:
				is_moving = false
			get_viewport().set_input_as_handled()
		
		elif event.keycode == KEY_S:
			if event.pressed:
				current_direction = "down"
				is_moving = true
			else:
				is_moving = false
			get_viewport().set_input_as_handled()
		
		elif event.keycode == KEY_D:
			if event.pressed:
				current_direction = "right"
				is_moving = true
			else:
				is_moving = false
			get_viewport().set_input_as_handled()
		
		# Zoom controls with - and =
		elif event.keycode == KEY_EQUAL and event.pressed:
			sprite_scale = clamp(sprite_scale + zoom_step, min_scale, max_scale)
			apply_sprite_scale()
			get_viewport().set_input_as_handled()
		
		elif event.keycode == KEY_MINUS and event.pressed:
			sprite_scale = clamp(sprite_scale - zoom_step, min_scale, max_scale)
			apply_sprite_scale()
			get_viewport().set_input_as_handled()

func select():
	if not is_selected:
		is_selected = true
		if selection_border:
			selection_border.visible = true
		panel_selected.emit(self)
		print("=== Selected ", name, " ===")
		print("WASD = move sprite | Mouse wheel or -/+ = zoom | Panel pos: ", position)

func deselect():
	is_selected = false
	is_moving = false
	if selection_border:
		selection_border.visible = false

func _draw():
	draw_rect(Rect2(size - Vector2(10, 10), Vector2(10, 10)), Color.GRAY)
	
	if sprite_node:
		var sprite_center = sprite_offset + (sprite_node.size * sprite_scale / 2.0)
		draw_circle(sprite_center, 3, Color.RED)

func get_layout_data() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y},
		"size": {"x": size.x, "y": size.y},
		"sprite_offset": {"x": sprite_offset.x, "y": sprite_offset.y},
		"sprite_scale": sprite_scale,
		"current_direction": current_direction,
		"flip_h": sprite_node.flip_h if sprite_node else false,
		"flip_v": sprite_node.flip_v if sprite_node else false
	}

func apply_layout_data(data: Dictionary):
	if data.has("position"):
		var p = data.position
		position = Vector2(p.x, p.y) if p is Dictionary else p
	
	if data.has("size"):
		var s = data.size
		size = Vector2(s.x, s.y) if s is Dictionary else s
	
	if data.has("sprite_offset"):
		var so = data.sprite_offset
		sprite_offset = Vector2(so.x, so.y) if so is Dictionary else so
		if sprite_node:
			sprite_node.position = sprite_offset
	
	if data.has("sprite_scale"):
		sprite_scale = data.sprite_scale
		apply_sprite_scale()
	
	if data.has("current_direction"):
		current_direction = data.current_direction
	
	if sprite_node:
		if data.has("flip_h"):
			sprite_node.flip_h = data.flip_h
		if data.has("flip_v"):
			sprite_node.flip_v = data.flip_v
