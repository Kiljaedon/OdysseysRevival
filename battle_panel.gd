extends Panel

signal panel_locked(panel)
signal panel_unlocked(panel)
signal panel_selected(panel)
signal layout_changed

@export var is_locked: bool = false
@export var can_resize: bool = true
@export var panel_title: String = "Panel"

var is_dragging: bool = false
var is_resizing: bool = false
var drag_offset: Vector2
var resize_margin: int = 10
var min_size: Vector2 = Vector2(200, 150)

@onready var title_bar: Control = null
@onready var lock_button: Button = null
@onready var hide_button: Button = null
@onready var title_label: Label = null

var is_panel_hidden: bool = true  # Hidden by default

# Sprite positioning and scaling
var sprite_node: TextureRect = null
var current_direction: String = "down"
var animation_frame: int = 0
var is_selected: bool = false
var character_data: Dictionary = {}
var battle_window: Node = null

# Animation cycling
var direction_animations: Dictionary = {
	"down": ["walk_down_1", "walk_down_2"],
	"up": ["walk_up_1", "walk_up_2"],
	"left": ["walk_left_1", "walk_left_2"],
	"right": ["walk_right_1", "walk_right_2"]
}

var attack_animations: Dictionary = {
	"down": "attack_down",
	"up": "attack_up",
	"left": "attack_left",
	"right": "attack_right"
}

# Zoom/scale controls
var sprite_scale: float = 1.0
var min_scale: float = 0.1
var max_scale: float = 5.0
var zoom_step: float = 0.1

# Double-click detection
var last_click_time: float = 0.0
var double_click_threshold: float = 0.3  # seconds
var is_movable: bool = false  # Can drag entire panel (not just title bar)


func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Find and setup sprite
	sprite_node = find_sprite_node(self)
	if sprite_node:
		# Make sprite highly clickable - prioritize it for input
		sprite_node.mouse_filter = Control.MOUSE_FILTER_STOP
		sprite_node.z_index = 50  # Above panel content but below title bar
		sprite_node.gui_input.connect(_on_sprite_clicked)
		print("✓ Setup sprite input for ", name, ": ", sprite_node.name)
	else:
		print("⚠ WARNING: No sprite found for ", name)

	# Make sure we can receive input
	set_process_input(true)

	# Connect panel's own gui_input for movable dragging
	gui_input.connect(_on_panel_input)

	# Create title bar after scene is loaded so it's last child (receives input first)
	call_deferred("create_title_bar")

	# Call this after a frame to ensure everything is set up
	call_deferred("_setup_dragging")

func _on_sprite_clicked(event: InputEvent):
	"""Handle clicking on the sprite to select panel"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("🖱️ Sprite clicked on ", name)

		# ALWAYS bring panel to front by moving to end of parent's children
		if get_parent():
			get_parent().move_child(self, get_parent().get_child_count() - 1)
			print("  ↑ Brought ", name, " to front")

		# Check for double-click
		var current_time = Time.get_ticks_msec() / 1000.0
		var time_since_last = current_time - last_click_time

		if time_since_last < double_click_threshold:
			# Double-click detected - toggle movable mode
			is_movable = !is_movable
			if is_movable:
				print("  🔓 ", name, " is now MOVABLE - drag anywhere to move")
			else:
				print("  🔒 ", name, " is now LOCKED - drag title bar only")
			update_selection_visual()
		else:
			# Single click - just select
			print("  ✓ Selected ", name)
			select()

		last_click_time = current_time
		get_viewport().set_input_as_handled()

func find_sprite_node(node: Node) -> TextureRect:
	"""Find first TextureRect with Sprite in name"""
	if node is TextureRect and "Sprite" in node.name:
		return node
	for child in node.get_children():
		var result = find_sprite_node(child)
		if result:
			return result
	return null

func scale_sprite_to_panel():
	"""Resize panel window to fit the current sprite size, growing from center"""
	if not sprite_node:
		return

	# Store old size and center position
	var old_size = size
	var old_center = position + (old_size / 2.0)

	# Get sprite's actual display size from custom_minimum_size
	var sprite_display_size = sprite_node.custom_minimum_size

	# Add padding for HP/MP bars and name label (approximately 100px)
	var padding = 100.0

	# Resize panel to fit sprite + padding
	var new_panel_width = sprite_display_size.x + 40  # 20px padding on each side
	var new_panel_height = sprite_display_size.y + padding + 50  # 50 for title bar

	size = Vector2(new_panel_width, new_panel_height)

	# Keep center position the same - adjust position so panel grows from center
	var new_center = position + (size / 2.0)
	position = position - (new_center - old_center)

	print(name, " panel resized to fit sprite: ", size)

func create_title_bar():
	# Create title bar
	title_bar = Panel.new()  # Use Panel instead of Control for better input handling
	title_bar.name = "TitleBar"
	title_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_bar.custom_minimum_size.y = 50
	title_bar.offset_bottom = 50  # Use offset instead of size when using anchors
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP  # Capture all mouse events
	title_bar.z_index = 100  # Ensure title bar is on top
	add_child(title_bar)
	move_child(title_bar, get_child_count() - 1)  # Move to end (renders on top)

	# Set background color
	title_bar.modulate = Color(0.3, 0.3, 0.3, 0.8)

	# Connect title bar input to handle dragging
	title_bar.gui_input.connect(_on_title_bar_input)

	# Create title label
	title_label = Label.new()
	title_label.text = panel_title
	title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	title_label.offset_left = 10
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through to title bar
	title_bar.add_child(title_label)

	# Create hide button (left of lock button)
	hide_button = Button.new()
	hide_button.text = "👁"
	hide_button.custom_minimum_size = Vector2(40, 40)
	hide_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	hide_button.offset_right = -50
	hide_button.offset_left = -90
	hide_button.focus_mode = Control.FOCUS_NONE
	hide_button.pressed.connect(_on_hide_button_pressed)
	title_bar.add_child(hide_button)

	# Create lock button
	lock_button = Button.new()
	lock_button.text = "🔓"
	lock_button.custom_minimum_size = Vector2(40, 40)
	lock_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	lock_button.offset_right = -5
	lock_button.offset_left = -45
	lock_button.focus_mode = Control.FOCUS_NONE  # Don't steal focus
	lock_button.pressed.connect(_on_lock_button_pressed)
	title_bar.add_child(lock_button)

	update_lock_visual()

func _on_lock_button_pressed():
	is_locked = !is_locked
	update_visual_state()

	if is_locked:
		panel_locked.emit(self)
	else:
		panel_unlocked.emit(self)

func _on_hide_button_pressed():
	is_panel_hidden = !is_panel_hidden
	update_visual_state()

func update_visual_state():
	# Update lock button icon
	if lock_button:
		lock_button.text = "🔒" if is_locked else "🔓"

	# Update hide button icon
	if hide_button:
		hide_button.text = "👁‍🗨" if is_panel_hidden else "👁"

	# Handle panel background and UI visibility
	if is_panel_hidden:
		hide_ui_elements(true)
	else:
		hide_ui_elements(false)

	# Update selection visual (handles modulate based on selection/movable/locked state)
	update_selection_visual()

func hide_ui_elements(hidden: bool):
	"""Hide/show HP/MP bars, name labels - keep only sprite visible when hidden"""
	# Find the unit container (PlayerUnit, EnemyUnit1, etc.)
	for child in get_children():
		if child is VBoxContainer and "Unit" in child.name:
			# Hide everything in the VBoxContainer except the sprite
			for ui_element in child.get_children():
				if ui_element is TextureRect and "Sprite" in ui_element.name:
					# Keep sprite visible
					ui_element.visible = true
				else:
					# Hide name labels, HP/MP bars
					ui_element.visible = !hidden

# Keep old function name for compatibility
func update_lock_visual():
	update_visual_state()

func cycle_animation_frame():
	"""Cycle to next walk animation frame in current direction"""
	var animations = direction_animations.get(current_direction, ["walk_down_1"])
	animation_frame = (animation_frame + 1) % animations.size()
	var anim_name = animations[animation_frame]
	print(name, " -> ", current_direction, " walk #", animation_frame + 1, ": ", anim_name)

	# Apply animation to sprite
	apply_character_animation(anim_name)
	layout_changed.emit()

func trigger_attack_animation():
	"""Play attack animation in current direction"""
	var anim_name = attack_animations.get(current_direction, "attack_down")
	print(name, " -> ATTACK ", current_direction, ": ", anim_name)

	# Apply attack animation to sprite
	apply_character_animation(anim_name)
	layout_changed.emit()

func apply_character_animation(anim_name: String):
	"""Load and display the character animation sprite"""
	if not sprite_node or not character_data.has("animations"):
		return

	if not character_data.animations.has(anim_name):
		print("WARN: Character missing animation: ", anim_name)
		return

	var anim_frames = character_data.animations[anim_name]
	if anim_frames.size() == 0:
		print("WARN: Animation ", anim_name, " is empty")
		return

	# Get first frame of animation
	var frame_data = anim_frames[0]
	var atlas_index = frame_data.get("atlas_index", 0)
	var row = frame_data.get("row", 0)
	var col = frame_data.get("col", 0)

	# Get texture from battle window
	if battle_window and battle_window.has_method("get_sprite_texture_from_coords"):
		var texture = battle_window.get_sprite_texture_from_coords(atlas_index, row, col)
		if texture:
			sprite_node.texture = texture
			print("✓ Applied animation: ", anim_name)
		else:
			print("ERROR: Failed to load sprite texture")

func _setup_dragging():
	# Ensure the panel can receive input events
	print("Setting up dragging for panel: ", panel_title)

	# Make sure we can receive focus and input
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS

func _on_panel_input(event: InputEvent):
	"""Handle input events on panel itself for movable dragging"""
	if not is_movable or is_locked:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging from anywhere on the panel
				is_dragging = true
				drag_offset = event.position
				accept_event()
			else:
				is_dragging = false

	elif event is InputEventMouseMotion:
		if is_dragging:
			var new_position = get_global_mouse_position() - drag_offset
			position = new_position
			layout_changed.emit()
			accept_event()

func _on_title_bar_input(event):
	"""Handle input events from title bar for dragging"""
	if is_locked:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if clicking on lock button - don't start dragging
				if lock_button and is_clicking_on_button(event.global_position, lock_button):
					return

				# Bring panel to front by moving to end of parent's children
				if get_parent():
					get_parent().move_child(self, get_parent().get_child_count() - 1)

				# Start dragging
				is_dragging = true
				drag_offset = event.position
				title_bar.accept_event()
			else:
				is_dragging = false

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
			# Calculate new position
			var parent_global_pos = Vector2.ZERO
			if get_parent():
				parent_global_pos = get_parent().global_position

			var new_pos = event.global_position - drag_offset - parent_global_pos

			# No bounds - panels can move anywhere freely
			position = new_pos

			# NO automatic scaling when dragging - sprite size stays fixed

			title_bar.accept_event()

func _gui_input(event):
	if is_locked:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Select panel on any click
				select()
				
				# Get mouse position relative to this panel
				var local_pos = event.position

				# Check if clicking on lock button - don't start dragging
				if lock_button and is_clicking_on_button(event.global_position, lock_button):
					print("Clicking on lock button")
					return

				print("Mouse pressed at: ", local_pos, " in panel: ", panel_title)

				# Check if clicking in resize area (bottom-right corner)
				if can_resize and is_in_resize_area(local_pos):
					print("Starting resize")
					is_resizing = true
					drag_offset = local_pos
					accept_event()
				# Check if clicking in title bar
				elif is_in_title_bar(local_pos):
					print("Starting drag")
					is_dragging = true
					drag_offset = local_pos
					accept_event()
			else:
				if is_dragging:
					print("Stopping drag")
				if is_resizing:
					print("Stopping resize")
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
			# Calculate new position
			# Get parent's global position to convert properly
			var parent_global_pos = Vector2.ZERO
			if get_parent():
				parent_global_pos = get_parent().global_position

			var new_pos = event.global_position - drag_offset - parent_global_pos

			# No bounds - panels can move anywhere freely
			position = new_pos

			# NO automatic scaling when dragging - sprite size stays fixed

			accept_event()
		elif is_resizing:
			# Resizing disabled - panel auto-fits sprite size
			# Use mouse wheel or -/= to change sprite size instead
			accept_event()

func is_in_title_bar(pos: Vector2) -> bool:
	return pos.y <= 50

func is_in_resize_area(pos: Vector2) -> bool:
	if not can_resize:
		return false

	var size_area = Vector2(resize_margin, resize_margin)
	return pos.x >= size.x - size_area.x and pos.y >= size.y - size_area.y

func is_clicking_on_button(global_pos: Vector2, button: Button) -> bool:
	"""Check if global mouse position is within button's bounds"""
	if not button:
		return false

	var button_rect = button.get_global_rect()
	return button_rect.has_point(global_pos)

func _draw():
	if not is_locked and can_resize:
		# Draw resize handle
		var handle_size = 10
		var handle_pos = size - Vector2(handle_size, handle_size)
		draw_rect(Rect2(handle_pos, Vector2(handle_size, handle_size)), Color.GRAY)

func _input(event):
	"""Handle WASD animation cycling and zoom controls when selected"""
	if not is_selected:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# WASD walk animation cycling (single keypress, not hold)
		if event.keycode == KEY_W:
			current_direction = "up"
			cycle_animation_frame()
			get_viewport().set_input_as_handled()

		elif event.keycode == KEY_A:
			current_direction = "left"
			cycle_animation_frame()
			get_viewport().set_input_as_handled()

		elif event.keycode == KEY_S:
			current_direction = "down"
			cycle_animation_frame()
			get_viewport().set_input_as_handled()

		elif event.keycode == KEY_D:
			current_direction = "right"
			cycle_animation_frame()
			get_viewport().set_input_as_handled()

		# Space = attack in current direction
		elif event.keycode == KEY_SPACE:
			trigger_attack_animation()
			get_viewport().set_input_as_handled()

		# Zoom controls with - and =
		elif event.keycode == KEY_EQUAL:
			sprite_scale = clamp(sprite_scale + zoom_step, min_scale, max_scale)
			apply_sprite_scale()
			get_viewport().set_input_as_handled()

		elif event.keycode == KEY_MINUS:
			sprite_scale = clamp(sprite_scale - zoom_step, min_scale, max_scale)
			apply_sprite_scale()
			get_viewport().set_input_as_handled()

func apply_sprite_scale():
	"""Apply manual zoom scale to sprite and resize panel to fit"""
	if sprite_node:
		# Change the actual size of the sprite TextureRect
		var base_sprite_size = 120.0  # Base size from scene
		var new_size = base_sprite_size * sprite_scale
		sprite_node.custom_minimum_size = Vector2(new_size, new_size)

		print(name, " sprite manual zoom: ", sprite_scale, " (size: ", new_size, ")")

		# Resize panel window to fit the new sprite size
		scale_sprite_to_panel()

		layout_changed.emit()

func select():
	"""Select this panel for WASD control"""
	if not is_selected:
		is_selected = true
		panel_selected.emit(self)
		print("=== Selected ", name, " ===")
		print("Double-click sprite to toggle movable | WASD = walk animations | SPACE = attack | Mouse wheel/-/+ = zoom")
		update_selection_visual()

func deselect():
	"""Deselect this panel"""
	is_selected = false
	is_movable = false
	update_selection_visual()

func update_selection_visual():
	"""Update visual feedback for selection and movable state"""
	# Determine alpha based on locked/hidden state
	var alpha = 0.0 if (is_locked or is_panel_hidden) else 1.0

	if is_movable:
		# Bright yellow highlight when movable
		self_modulate = Color(1.5, 1.5, 0.5, alpha)
	elif is_selected:
		# Subtle white highlight when selected
		self_modulate = Color(1.2, 1.2, 1.2, alpha)
	else:
		# Normal appearance when not selected
		self_modulate = Color(1, 1, 1, alpha)

func get_layout_data() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y},
		"size": {"x": size.x, "y": size.y},
		"sprite_scale": sprite_scale,
		"current_direction": current_direction,
		"animation_frame": animation_frame,
		"is_locked": is_locked,
		"is_panel_hidden": is_panel_hidden,
		"title": panel_title
	}

func apply_layout_data(data: Dictionary):
	if data.has("position"):
		var pos = data.position
		# Handle Vector2 stored as dictionary from JSON
		if pos is Dictionary:
			position = Vector2(pos.get("x", 0), pos.get("y", 0))
		# Handle Vector2 stored as string like "(100, 200)"
		elif pos is String:
			var coords = parse_vector2_string(pos)
			if coords:
				position = coords
		# Handle actual Vector2 object
		else:
			position = pos
	if data.has("size"):
		var sz = data.size
		# Handle Vector2 stored as dictionary from JSON
		if sz is Dictionary:
			size = Vector2(sz.get("x", 200), sz.get("y", 150))
		# Handle Vector2 stored as string like "(200, 150)"
		elif sz is String:
			var coords = parse_vector2_string(sz)
			if coords:
				size = coords
		# Handle actual Vector2 object
		else:
			size = sz
	if data.has("is_locked"):
		is_locked = data.is_locked
	if data.has("is_panel_hidden"):
		is_panel_hidden = data.is_panel_hidden
	if data.has("title"):
		panel_title = data.title
		if title_label:
			title_label.text = panel_title

	if data.has("sprite_scale"):
		sprite_scale = data.sprite_scale
		if sprite_node:
			sprite_node.scale = Vector2(sprite_scale, sprite_scale)

	if data.has("current_direction"):
		current_direction = data.current_direction

	if data.has("animation_frame"):
		animation_frame = data.animation_frame

	# Update visual state after loading all data
	update_visual_state()

func parse_vector2_string(s: String) -> Vector2:
	"""Parse Vector2 from string like '(100, 200)' or '100, 200'"""
	# Remove parentheses and whitespace
	s = s.replace("(", "").replace(")", "").strip_edges()
	var parts = s.split(",")
	if parts.size() == 2:
		return Vector2(parts[0].to_float(), parts[1].to_float())
	return Vector2.ZERO
