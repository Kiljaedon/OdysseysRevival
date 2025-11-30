extends Control
## Chat UI for Odysseys Revival
## Press Enter to open, type message, press Enter to send
## Draggable, resizable, and lockable window

signal message_sent(message: String)

var is_chat_open: bool = false
var is_locked: bool = false
var is_dragging: bool = false
var is_resizing: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var resize_start_pos: Vector2 = Vector2.ZERO
var resize_start_size: Vector2 = Vector2.ZERO

var window_panel: PanelContainer
var title_bar: HBoxContainer
var lock_button: Button
var chat_container: VBoxContainer
var message_history: RichTextLabel
var input_container: HBoxContainer
var input_field: LineEdit
var resize_handle: Control


func _ready():
	create_ui()
	hide_input()
	load_layout()


func create_ui():
	# Window panel (draggable container)
	window_panel = PanelContainer.new()
	window_panel.position = Vector2(850, 60)  # Right side, next to game screen
	window_panel.custom_minimum_size = Vector2(300, 600)
	window_panel.size = Vector2(300, 600)

	# Kenny RPG panel texture
	var panel_texture = load("res://assets/ui/kenney/rpg-expansion/panel_brown.png")
	if panel_texture:
		var stylebox = StyleBoxTexture.new()
		stylebox.texture = panel_texture
		stylebox.texture_margin_left = 16
		stylebox.texture_margin_top = 16
		stylebox.texture_margin_right = 16
		stylebox.texture_margin_bottom = 16
		window_panel.add_theme_stylebox_override("panel", stylebox)
	else:
		print("[CHAT_UI] ERROR: Panel texture failed to load")

	add_child(window_panel)

	# Main vertical layout
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	window_panel.add_child(main_vbox)

	# Title bar
	title_bar = HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 30)
	main_vbox.add_child(title_bar)

	# Title label
	var title_label = Label.new()
	title_label.text = "  💬 Chat"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.0))  # Gold color
	title_bar.add_child(title_label)

	# Lock button
	lock_button = create_styled_button("🔓", Vector2(40, 30))
	lock_button.tooltip_text = "Lock/Unlock window"
	lock_button.pressed.connect(_on_lock_toggled)
	title_bar.add_child(lock_button)

	# Chat container
	chat_container = VBoxContainer.new()
	chat_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_container.add_theme_constant_override("separation", 5)
	main_vbox.add_child(chat_container)

	# Message history background
	var history_bg = PanelContainer.new()
	history_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_bg.custom_minimum_size = Vector2(180, 180)

	# Try to load Kenny background texture
	var bg_texture = load("res://assets/ui/kenney/rpg-expansion/panel_beige.png")
	if bg_texture:
		var bg_stylebox = StyleBoxTexture.new()
		bg_stylebox.texture = bg_texture
		bg_stylebox.texture_margin_left = 12
		bg_stylebox.texture_margin_top = 12
		bg_stylebox.texture_margin_right = 12
		bg_stylebox.texture_margin_bottom = 12
		history_bg.add_theme_stylebox_override("panel", bg_stylebox)
	else:
		# Fallback to flat style if texture not found
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
		history_bg.add_theme_stylebox_override("panel", bg_style)

	chat_container.add_child(history_bg)

	# Message history
	message_history = RichTextLabel.new()
	message_history.bbcode_enabled = true
	message_history.scroll_following = true
	message_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Bright white default text
	message_history.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0))
	message_history.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	message_history.add_theme_constant_override("shadow_offset_x", 1)
	message_history.add_theme_constant_override("shadow_offset_y", 1)
	history_bg.add_child(message_history)

	# Input container
	input_container = HBoxContainer.new()
	input_container.visible = false
	chat_container.add_child(input_container)

	# Input field
	input_field = LineEdit.new()
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field.custom_minimum_size = Vector2(0, 40)
	input_field.placeholder_text = "Type message and press Enter..."
	input_field.text_submitted.connect(_on_message_submitted)
	# Lighter colors for better visibility
	input_field.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	input_field.add_theme_color_override("font_placeholder_color", Color(0.6, 0.6, 0.6))
	input_container.add_child(input_field)

	# Resize handle (bottom-right corner)
	resize_handle = Control.new()
	resize_handle.custom_minimum_size = Vector2(20, 20)
	resize_handle.position = window_panel.size - Vector2(20, 20)
	resize_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	window_panel.add_child(resize_handle)


func create_styled_button(text: String, size: Vector2) -> Button:
	"""Create a styled button with Kenny RPG theme"""
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = size

	# Try to load Kenny button textures
	var button_texture = load("res://assets/ui/kenney/rpg-expansion/buttonSquare_brown.png")
	var button_pressed_texture = load("res://assets/ui/kenney/rpg-expansion/buttonSquare_brown_pressed.png")

	if button_texture:
		var button_style = StyleBoxTexture.new()
		button_style.texture = button_texture
		button_style.texture_margin_left = 8
		button_style.texture_margin_top = 8
		button_style.texture_margin_right = 8
		button_style.texture_margin_bottom = 8
		button.add_theme_stylebox_override("normal", button_style)

		if button_pressed_texture:
			var button_pressed_style = StyleBoxTexture.new()
			button_pressed_style.texture = button_pressed_texture
			button_pressed_style.texture_margin_left = 8
			button_pressed_style.texture_margin_top = 8
			button_pressed_style.texture_margin_right = 8
			button_pressed_style.texture_margin_bottom = 8
			button.add_theme_stylebox_override("pressed", button_pressed_style)

	# Button text color - gold
	button.add_theme_color_override("font_color", Color(0.95, 0.84, 0.0))
	button.add_theme_font_size_override("font_size", 12)

	return button


func _input(event):
	# Don't process input until UI is ready
	if not is_node_ready() or not window_panel:
		print("[CHAT_INPUT] Node not ready: is_node_ready=%s, window_panel=%s" % [is_node_ready(), window_panel != null])
		return

	# Log all key events for debugging
	if event is InputEventKey:
		print("[CHAT_INPUT] _input() Key event received - keycode=%d, KEY_ENTER=%d, is_chat_open=%s" % [event.keycode, KEY_ENTER, is_chat_open])
		# Let Tab key pass through to other systems (weapon toggling, etc.)
		if event.keycode == KEY_TAB:
			return
		# Let Space key pass through when chat is closed (for attacks)
		if event.keycode == KEY_SPACE and event.pressed and not is_chat_open:
			return

	# Handle Enter key - ONLY when chat is NOT open (to avoid conflicts with LineEdit)
	# When chat IS open, LineEdit._input() handles ENTER via text_submitted signal
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and not is_chat_open:
		print("[CHAT_INPUT] ENTER key pressed and chat is closed!")
		# Open chat
		print("[CHAT_INPUT] Opening chat...")
		open_chat()
		var viewport = get_viewport()
		if viewport:
			viewport.set_input_as_handled()
		print("[CHAT] Chat opened - input field focused")

	# Handle dragging
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if clicking title bar
				var mouse_pos = get_global_mouse_position()
				var title_rect = title_bar.get_global_rect()
				if title_rect.has_point(mouse_pos) and not is_locked:
					is_dragging = true
					drag_offset = mouse_pos - window_panel.position

				# Check if clicking resize handle
				var resize_rect = Rect2(resize_handle.global_position, resize_handle.size)
				if resize_rect.has_point(mouse_pos) and not is_locked:
					is_resizing = true
					resize_start_pos = mouse_pos
					resize_start_size = window_panel.size
			else:
				# Save layout when drag or resize ends
				if is_dragging or is_resizing:
					save_layout()
				is_dragging = false
				is_resizing = false

	elif event is InputEventMouseMotion:
		# Update drag position
		if is_dragging:
			var new_pos = get_global_mouse_position() - drag_offset
			var viewport_size = get_viewport_rect().size

			# Clamp position to keep window inside viewport
			new_pos.x = clamp(new_pos.x, 0, viewport_size.x - window_panel.size.x)
			new_pos.y = clamp(new_pos.y, 0, viewport_size.y - window_panel.size.y)

			window_panel.position = new_pos

		# Update resize
		elif is_resizing:
			var mouse_pos = get_global_mouse_position()
			var delta = mouse_pos - resize_start_pos
			var new_size = resize_start_size + delta

			# Enforce minimum size
			new_size.x = max(300, new_size.x)
			new_size.y = max(200, new_size.y)

			window_panel.size = new_size
			window_panel.custom_minimum_size = new_size

			# Update resize handle position
			resize_handle.position = new_size - Vector2(20, 20)

		# Change cursor on hover over resize handle
		elif not is_locked:
			var mouse_pos = get_global_mouse_position()
			var resize_rect = Rect2(resize_handle.global_position, resize_handle.size)
			if resize_rect.has_point(mouse_pos):
				Input.set_default_cursor_shape(Input.CURSOR_FDIAGSIZE)
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func open_chat():
	"""Open chat input"""
	print("[CHAT_OPEN] Called - input_field=%s, input_container=%s" % [input_field != null, input_container != null])
	if not input_field or not input_container:
		print("[CHAT_OPEN] ERROR: input_field or input_container is null!")
		return
	print("[CHAT_OPEN] Setting is_chat_open = true")
	is_chat_open = true
	input_container.visible = true
	print("[CHAT_OPEN] Calling grab_focus() on input_field")
	input_field.grab_focus()
	input_field.text = ""
	print("[CHAT_OPEN] Chat input field is now ready for input")


func close_chat():
	"""Close chat input"""
	if not input_field or not input_container:
		return
	is_chat_open = false
	input_container.visible = false
	input_field.release_focus()
	input_field.text = ""


func hide_input():
	"""Hide chat input"""
	if not input_container:
		return
	input_container.visible = false
	is_chat_open = false


func _on_message_submitted(text: String):
	"""Handle Enter key in input field"""
	print("[CHAT] ========== _on_message_submitted CALLED ==========")
	print("[CHAT] Raw text received: '%s'" % text)
	print("[CHAT] text is null: %s" % (text == null))

	if text == null:
		print("[CHAT] Text is null, closing chat")
		close_chat()
		return

	var message = text.strip_edges()
	print("[CHAT] After strip_edges: '%s'" % message)
	print("[CHAT] message.is_empty(): %s" % message.is_empty())

	if message == null or message.is_empty():
		print("[CHAT] Message is empty, closing chat")
		close_chat()
		return

	# Send message
	print("[CHAT] MESSAGE VALID - Emitting message_sent signal with: '%s'" % message)
	print("[CHAT] Signal connections: %s" % get_signal_connection_list("message_sent"))
	message_sent.emit(message)
	print("[CHAT] Signal emitted successfully")
	print("[CHAT] ========== END _on_message_submitted ==========")

	# Close chat
	close_chat()


func add_message(player_name: String, message: String, channel: String = "all"):
	"""Add message to chat history with channel color coding"""
	print("[CHAT_DISPLAY] add_message() called with: player=%s, message=%s, channel=%s" % [player_name, message, channel])
	print("[CHAT_DISPLAY] message_history = %s" % (message_history if message_history else "NULL"))
	print("[CHAT_DISPLAY] window_panel visible = %s" % (window_panel.visible if window_panel else "NO WINDOW"))
	print("[CHAT_DISPLAY] message_history visible = %s" % (message_history.visible if message_history else "NULL"))

	if not message_history:
		print("[CHAT_DISPLAY] ERROR: message_history is NULL!")
		return

	var timestamp = Time.get_time_string_from_system().substr(0, 5)  # HH:MM only

	# Channel-specific colors
	var channel_color = Color.WHITE
	var channel_prefix = ""
	match channel:
		"all":
			channel_color = Color.CYAN
			channel_prefix = ""
		"party":
			channel_color = Color.LIGHT_GREEN
			channel_prefix = "[P] "
		"guild":
			channel_color = Color.ORANGE
			channel_prefix = "[G] "
		"whisper":
			channel_color = Color.MAGENTA
			channel_prefix = "[W] "
		"trade":
			channel_color = Color.GOLD
			channel_prefix = "[T] "

	var formatted = "[color=lightgray][%s][/color] %s[color=%s]%s:[/color] [color=white]%s[/color]\n" % [
		timestamp,
		channel_prefix,
		channel_color.to_html(),
		player_name,
		message
	]
	print("[CHAT_DISPLAY] Appending formatted text: %s" % formatted)
	message_history.append_text(formatted)
	print("[CHAT_DISPLAY] Message appended successfully. Current text length: %d" % message_history.text.length())


func add_system_message(message: String):
	"""Add system message to chat"""
	if not message_history:
		return
	var formatted = "[color=#FFD700]*** %s ***[/color]\n" % message  # Bright gold
	message_history.append_text(formatted)


func add_server_message(message: String):
	"""Add server announcement to chat"""
	if not message_history:
		return
	var formatted = "[center][color=#FFA500]━━━━━━━━━━━━━━━━━━━━━━\n[b]SERVER:[/b] %s\n━━━━━━━━━━━━━━━━━━━━━━[/color][/center]\n" % message  # Bright orange
	message_history.append_text(formatted)


func add_error_message(message: String):
	"""Add error message to chat"""
	if not message_history:
		return
	var formatted = "[color=red]ERROR: %s[/color]\n" % message
	message_history.append_text(formatted)


func _on_lock_toggled():
	"""Toggle window lock"""
	if not lock_button or not title_bar or not window_panel:
		return
	is_locked = !is_locked
	lock_button.text = "🔒" if is_locked else "🔓"

	# Visual feedback
	if is_locked:
		title_bar.modulate = Color(0.8, 0.8, 0.8)
		window_panel.modulate = Color(0.95, 0.95, 0.95)
	else:
		title_bar.modulate = Color(1.0, 1.0, 1.0)
		window_panel.modulate = Color(1.0, 1.0, 1.0)

	# Save layout when lock state changes
	save_layout()


func save_layout():
	"""Save chat window position, size, and lock state to persistent storage"""
	print("[CHAT_SAVE] ========== SAVE_LAYOUT CALLED ==========")
	if not window_panel:
		print("[CHAT_SAVE] ERROR: window_panel is null!")
		return

	var layout_data = {
		"chat_window": {
			"position": {"x": window_panel.position.x, "y": window_panel.position.y},
			"size": {"x": window_panel.size.x, "y": window_panel.size.y},
			"locked": is_locked
		}
	}

	print("[CHAT_SAVE] Saving position: ", window_panel.position)
	print("[CHAT_SAVE] Saving size: ", window_panel.size)
	print("[CHAT_SAVE] Saving locked: ", is_locked)

	var save_path = "user://gui_layout.json"
	var absolute_path = ProjectSettings.globalize_path(save_path)
	print("[CHAT_SAVE] Absolute save path: ", absolute_path)

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(layout_data, "\t")
		file.store_string(json_string)
		file.close()
		print("[CHAT_SAVE] ✓ GUI layout saved successfully!")
		print("[CHAT_SAVE] Saved JSON: ", json_string)
	else:
		var error = FileAccess.get_open_error()
		print("[CHAT_SAVE] ERROR: Could not save GUI layout - Error code: ", error)
	print("[CHAT_SAVE] ========== END SAVE_LAYOUT ==========")


func load_layout():
	"""Load chat window position, size, and lock state from persistent storage"""
	print("[CHAT_LOAD] ========== LOAD_LAYOUT CALLED ==========")
	var save_path = "user://gui_layout.json"
	var absolute_path = ProjectSettings.globalize_path(save_path)
	print("[CHAT_LOAD] Looking for file at: ", absolute_path)

	if not FileAccess.file_exists(save_path):
		print("[CHAT_LOAD] No saved GUI layout found - using defaults")
		print("[CHAT_LOAD] ========== END LOAD_LAYOUT (NO FILE) ==========")
		return

	print("[CHAT_LOAD] File exists! Opening...")
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		var error = FileAccess.get_open_error()
		print("[CHAT_LOAD] ERROR: Could not open GUI layout file - Error code: ", error)
		print("[CHAT_LOAD] ========== END LOAD_LAYOUT (OPEN ERROR) ==========")
		return

	var json_text = file.get_as_text()
	file.close()
	print("[CHAT_LOAD] Loaded JSON: ", json_text)

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		print("[CHAT_LOAD] ERROR: Could not parse GUI layout JSON - Error: ", json.get_error_message())
		print("[CHAT_LOAD] ========== END LOAD_LAYOUT (PARSE ERROR) ==========")
		return

	var layout_data = json.data
	if not layout_data or not layout_data.has("chat_window"):
		print("[CHAT_LOAD] ERROR: Invalid GUI layout data")
		print("[CHAT_LOAD] ========== END LOAD_LAYOUT (INVALID DATA) ==========")
		return

	print("[CHAT_LOAD] Parsed data successfully")

	# Wait one frame for window_panel to be created
	await get_tree().process_frame

	if not window_panel:
		print("[CHAT_LOAD] ERROR: window_panel not created yet")
		print("[CHAT_LOAD] ========== END LOAD_LAYOUT (NO PANEL) ==========")
		return

	var chat_data = layout_data.chat_window
	print("[CHAT_LOAD] Chat data: ", chat_data)

	# Restore position
	if chat_data.has("position"):
		var new_pos = Vector2(chat_data.position.x, chat_data.position.y)
		window_panel.position = new_pos
		print("[CHAT_LOAD] ✓ Restored position: ", new_pos)

	# Restore size
	if chat_data.has("size"):
		var new_size = Vector2(chat_data.size.x, chat_data.size.y)
		window_panel.size = new_size
		window_panel.custom_minimum_size = new_size
		if resize_handle:
			resize_handle.position = new_size - Vector2(20, 20)
		print("[CHAT_LOAD] ✓ Restored size: ", new_size)

	# Restore lock state
	if chat_data.has("locked"):
		is_locked = chat_data.locked
		if lock_button:
			lock_button.text = "🔒" if is_locked else "🔓"
		if title_bar and window_panel:
			if is_locked:
				title_bar.modulate = Color(0.8, 0.8, 0.8)
				window_panel.modulate = Color(0.95, 0.95, 0.95)
			else:
				title_bar.modulate = Color(1.0, 1.0, 1.0)
				window_panel.modulate = Color(1.0, 1.0, 1.0)
		print("[CHAT_LOAD] ✓ Restored locked state: ", is_locked)

	print("[CHAT_LOAD] ✓ GUI layout loaded successfully!")
	print("[CHAT_LOAD] ========== END LOAD_LAYOUT ==========")
