extends Panel

signal panel_locked(panel)
signal panel_unlocked(panel)

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

func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Make sure we can receive input
	set_process_input(true)

	# Create title bar after scene is loaded so it's last child (receives input first)
	call_deferred("create_title_bar")

	# Call this after a frame to ensure everything is set up
	call_deferred("_setup_dragging")

func create_title_bar():
	# Create title bar
	title_bar = Panel.new()  # Use Panel instead of Control for better input handling
	title_bar.name = "TitleBar"
	title_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_bar.custom_minimum_size.y = 30
	title_bar.size.y = 30
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
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through to title bar
	title_bar.add_child(title_label)

	# Create hide button (left of lock button)
	hide_button = Button.new()
	hide_button.text = "👁"
	hide_button.custom_minimum_size = Vector2(30, 25)
	hide_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	hide_button.offset_right = -40
	hide_button.offset_left = -70
	hide_button.focus_mode = Control.FOCUS_NONE
	hide_button.pressed.connect(_on_hide_button_pressed)
	title_bar.add_child(hide_button)

	# Create lock button
	lock_button = Button.new()
	lock_button.text = "🔓"
	lock_button.custom_minimum_size = Vector2(30, 25)
	lock_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	lock_button.offset_right = -5
	lock_button.offset_left = -35
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
		hide_button.text = "👁" if is_panel_hidden else "👁"

	# Handle panel background visibility
	if is_locked or is_panel_hidden:
		self_modulate = Color(1, 1, 1, 0.0)  # Hide panel background only (not children)
		# Keep title bar visible so user can still unlock/unhide it
	else:
		self_modulate = Color(1, 1, 1, 1.0)  # Show panel background

# Keep old function name for compatibility
func update_lock_visual():
	update_visual_state()

func _setup_dragging():
	# Ensure the panel can receive input events
	print("Setting up dragging for panel: ", panel_title)

	# Make sure we can receive focus and input
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS

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

				# Start dragging
				is_dragging = true
				drag_offset = event.position
				title_bar.accept_event()
			else:
				is_dragging = false

	elif event is InputEventMouseMotion:
		if is_dragging:
			# Calculate new position
			var parent_global_pos = Vector2.ZERO
			if get_parent():
				parent_global_pos = get_parent().global_position

			var new_pos = event.global_position - drag_offset - parent_global_pos

			# Permissive bounds - keep at least 50px visible on each edge
			var viewport_size = get_viewport_rect().size
			new_pos.x = clamp(new_pos.x, -size.x + 50, viewport_size.x - 50)
			new_pos.y = clamp(new_pos.y, 0, viewport_size.y - 30)

			position = new_pos
			title_bar.accept_event()

func _gui_input(event):
	if is_locked:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
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

	elif event is InputEventMouseMotion:
		if is_dragging:
			# Calculate new position
			# Get parent's global position to convert properly
			var parent_global_pos = Vector2.ZERO
			if get_parent():
				parent_global_pos = get_parent().global_position

			var new_pos = event.global_position - drag_offset - parent_global_pos

			# Permissive bounds - keep at least 50px visible on each edge
			var viewport_size = get_viewport_rect().size
			new_pos.x = clamp(new_pos.x, -size.x + 50, viewport_size.x - 50)
			new_pos.y = clamp(new_pos.y, 0, viewport_size.y - 30)

			position = new_pos
			accept_event()
		elif is_resizing:
			var local_pos = event.position
			var new_size = Vector2(local_pos.x, local_pos.y)
			new_size.x = max(new_size.x, min_size.x)
			new_size.y = max(new_size.y, min_size.y)
			size = new_size
			accept_event()

func is_in_title_bar(pos: Vector2) -> bool:
	return pos.y <= 30

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

func get_layout_data() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y},
		"size": {"x": size.x, "y": size.y},
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
