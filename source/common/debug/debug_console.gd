extends CanvasLayer
## Debug Console System for Odysseys Revival
## Shows real-time connection status, logs, and debug info
## Can be disabled for release builds

signal command_entered(command: String)

var is_visible: bool = true
var max_log_lines: int = 100
var log_lines: Array = []
var chat_lines: Array = []

@onready var console_panel: PanelContainer
@onready var log_text: RichTextLabel
@onready var chat_text: RichTextLabel
@onready var command_input: LineEdit
@onready var stats_label: Label
@onready var tab_container: TabContainer
@onready var motd_label: Label
var resize_handle: Panel

var debug_enabled: bool = false  # Set to false for release
var message_of_the_day: String = "Welcome to Golden Sun MMO Server!"

# Dragging variables
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# Resizing variables
var resizing: bool = false
var resize_start_pos: Vector2 = Vector2.ZERO
var resize_start_size: Vector2 = Vector2.ZERO
var resize_edge_size: float = 10.0  # Pixel width of resize edges


func _ready():
	if not debug_enabled:
		queue_free()
		return
	
	create_ui()
	add_log("=== Debug Console Initialized ===")
	add_log("Press F12 to toggle console")
	add_log("Type 'help' for commands")
	log_text.append_text("[DEBUG] If you see this, the debug console is rendering correctly.\n")


func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		toggle_visibility()


func _on_motd_drag(event: InputEvent):
	"""Handle dragging from the MOTD bar"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = event.global_position - console_panel.global_position
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		console_panel.global_position = event.global_position - drag_offset


func can_start_drag(mouse_pos: Vector2) -> bool:
	"""Check if we can start dragging (only on header area, not tabs/buttons)"""
	if not console_panel:
		return false

	var panel_rect = console_panel.get_global_rect()
	if not panel_rect.has_point(mouse_pos):
		return false

	# Only allow dragging on the top 80 pixels (MOTD and status bar area)
	var relative_y = mouse_pos.y - panel_rect.position.y
	if relative_y > 80:
		return false

	return true


func get_resize_edge(mouse_pos: Vector2, rect: Rect2) -> String:
	"""Check if mouse is on a resize edge"""
	var on_right = abs(mouse_pos.x - rect.end.x) < resize_edge_size
	var on_bottom = abs(mouse_pos.y - rect.end.y) < resize_edge_size

	# Check if inside the panel area
	if not rect.has_point(mouse_pos):
		return ""

	# Bottom-right corner (diagonal resize)
	if on_right and on_bottom:
		return "bottom_right"

	return ""


func create_ui():
	# Main panel - positioned in bottom right corner
	console_panel = PanelContainer.new()
	console_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	console_panel.offset_left = -500  # 500 pixels from right edge
	console_panel.offset_top = -420  # Full height visible
	console_panel.offset_right = -10  # 10px margin from right
	console_panel.offset_bottom = -10  # 10px margin from bottom
	console_panel.custom_minimum_size = Vector2(480, 400)
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	stylebox.set_border_width_all(2)
	stylebox.set_border_color(Color(1, 0, 0, 1))
	console_panel.add_theme_stylebox_override("panel", stylebox)
	add_child(console_panel)
	
	var vbox = VBoxContainer.new()
	console_panel.add_child(vbox)

	# Message of the Day (draggable area)
	var motd_panel = PanelContainer.new()
	motd_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var motd_bg = StyleBoxFlat.new()
	motd_bg.bg_color = Color(0.15, 0.1, 0.05, 1.0)
	motd_panel.add_theme_stylebox_override("panel", motd_bg)
	motd_panel.gui_input.connect(_on_motd_drag)
	vbox.add_child(motd_panel)

	motd_label = Label.new()
	motd_label.text = "📢 MOTD: " + message_of_the_day
	motd_label.add_theme_color_override("font_color", Color.GOLD)
	motd_label.add_theme_font_size_override("font_size", 14)
	motd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	motd_label.custom_minimum_size = Vector2(0, 30)
	motd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	motd_panel.add_child(motd_label)

	# Separator
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# Stats bar
	stats_label = Label.new()
	stats_label.text = "Connecting..."
	stats_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(stats_label)

	# Separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Tab container for Console and Chat
	tab_container = TabContainer.new()
	tab_container.custom_minimum_size = Vector2(0, 400)
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tab_stylebox = StyleBoxFlat.new()
	tab_stylebox.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	tab_container.add_theme_stylebox_override("panel", tab_stylebox)
	vbox.add_child(tab_container)

	# Console tab (logs)
	var console_scroll = ScrollContainer.new()
	console_scroll.name = "Console"
	console_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console_scroll.follow_focus = true
	var console_scroll_bg = StyleBoxFlat.new()
	console_scroll_bg.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	console_scroll.add_theme_stylebox_override("panel", console_scroll_bg)
	tab_container.add_child(console_scroll)

	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = true
	log_text.scroll_following = true
	log_text.fit_content = false
	log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_text.custom_minimum_size = Vector2(0, 380)
	log_text.visible = true
	log_text.add_theme_color_override("default_color", Color.WHITE)
	log_text.add_theme_color_override("background_color", Color(0.2, 0.2, 0.2, 1.0))
	console_scroll.add_child(log_text)

	# Chat tab
	var chat_scroll = ScrollContainer.new()
	chat_scroll.name = "Chat"
	chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_scroll.follow_focus = true
	var chat_scroll_bg = StyleBoxFlat.new()
	chat_scroll_bg.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	chat_scroll.add_theme_stylebox_override("panel", chat_scroll_bg)
	tab_container.add_child(chat_scroll)

	chat_text = RichTextLabel.new()
	chat_text.bbcode_enabled = true
	chat_text.scroll_following = true
	chat_text.fit_content = false
	chat_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_text.custom_minimum_size = Vector2(0, 380)
	chat_text.visible = true
	chat_text.add_theme_color_override("default_color", Color.WHITE)
	chat_text.add_theme_color_override("background_color", Color(0.2, 0.2, 0.2, 1.0))
	chat_scroll.add_child(chat_text)
	chat_text.append_text("[color=gray]=== Chat Monitor ===\nAll player chat messages will appear here.[/color]\n\n")

	# Command input
	command_input = LineEdit.new()
	command_input.placeholder_text = "Enter command..."
	command_input.editable = true
	command_input.mouse_filter = Control.MOUSE_FILTER_STOP
	command_input.text_submitted.connect(_on_command_entered)
	vbox.add_child(command_input)

	# Command buttons
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 5)
	vbox.add_child(button_row)

	# Help button
	var help_btn = Button.new()
	help_btn.text = "Help"
	help_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_btn.pressed.connect(_on_help_pressed)
	button_row.add_child(help_btn)

	# Clear button
	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.pressed.connect(_on_clear_pressed)
	button_row.add_child(clear_btn)

	# FPS button
	var fps_btn = Button.new()
	fps_btn.text = "FPS"
	fps_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps_btn.pressed.connect(_on_fps_pressed)
	button_row.add_child(fps_btn)

	# Stats button
	var stats_btn = Button.new()
	stats_btn.text = "Stats"
	stats_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_btn.pressed.connect(_on_stats_pressed)
	button_row.add_child(stats_btn)

	# Quit button
	var quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_btn.modulate = Color(1.0, 0.5, 0.5)  # Red tint
	quit_btn.pressed.connect(_on_quit_pressed)
	button_row.add_child(quit_btn)



func toggle_visibility():
	is_visible = !is_visible
	console_panel.visible = is_visible


func add_log(message: String, color: String = "white"):
	var timestamp = Time.get_time_string_from_system()
	var formatted = "[color=%s][%s] %s[/color]" % [color, timestamp, message]
	log_lines.append(formatted)
	if log_lines.size() > max_log_lines:
		log_lines.pop_front()
	if log_text:
		log_text.clear()
		for line in log_lines:
			# Use BBCode directly (bbcode_enabled is true)
			log_text.append_text(line + "\n")
		log_text.scroll_to_line(log_text.get_line_count() - 1)
	# Always print to terminal for headless/server mode
	#	print("[DEBUG_CONSOLE] %s" % message)


func log_error(message: String):
	add_log("❌ ERROR: " + message, "red")


func log_warning(message: String):
	add_log("⚠️ WARNING: " + message, "yellow")


func log_success(message: String):
	add_log("✅ " + message, "green")


func log_info(message: String):
	add_log("ℹ️ " + message, "cyan")


func update_stats(status: String, peer_id: int = -1, players: int = 0):
	if stats_label:
		var text = "Status: %s" % status
		if peer_id > 0:
			text += " | Peer ID: %d" % peer_id
		if players > 0:
			text += " | Players: %d" % players
		
		stats_label.text = text
		
		# Color based on status
		if status.contains("Connected"):
			stats_label.add_theme_color_override("font_color", Color.GREEN)
		elif status.contains("Connecting"):
			stats_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			stats_label.add_theme_color_override("font_color", Color.RED)


func _on_command_entered(text: String):
	if text.is_empty():
		return
	
	add_log("> " + text, "lightblue")
	command_input.clear()
	
	# Handle built-in commands
	match text.to_lower():
		"help":
			add_log("Available commands:", "yellow")
			add_log("  help - Show this help")
			add_log("  clear - Clear console")
			add_log("  quit - Close game")
			add_log("  fps - Toggle FPS display")
			add_log("  stats - Show detailed stats")
		
		"clear":
			log_lines.clear()
			log_text.clear()
			add_log("Console cleared")
		
		"quit":
			get_tree().quit()
		
		"fps":
			var tree_root = get_tree().root
			var current = Performance.get_monitor(Performance.TIME_FPS)
			add_log("Current FPS: %.1f" % current)
		
		"stats":
			show_detailed_stats()
		
		_:
			# Emit for custom handling
			command_entered.emit(text)


func show_detailed_stats():
	add_log("=== Detailed Statistics ===", "yellow")
	add_log("FPS: %.1f" % Performance.get_monitor(Performance.TIME_FPS))
	add_log("Memory: %.2f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0))
	add_log("Objects: %d" % Performance.get_monitor(Performance.OBJECT_COUNT))
	add_log("Nodes: %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func add_chat(player_name: String, message: String, channel: String = "all"):
	"""Log chat messages to the Chat tab"""
	var timestamp = Time.get_time_string_from_system().substr(0, 5)  # HH:MM

	# Channel-specific colors
	var channel_color = "cyan"
	var channel_prefix = ""
	match channel:
		"all":
			channel_color = "cyan"
			channel_prefix = ""
		"party":
			channel_color = "lightgreen"
			channel_prefix = "[P] "
		"guild":
			channel_color = "orange"
			channel_prefix = "[G] "
		"whisper":
			channel_color = "magenta"
			channel_prefix = "[W] "
		"trade":
			channel_color = "gold"
			channel_prefix = "[T] "
		"server":
			channel_color = "yellow"
			channel_prefix = "[SERVER] "
		"admin":
			channel_color = "red"
			channel_prefix = "[ADMIN] "

	var formatted = "[color=lightgray][%s][/color] %s[color=%s]%s:[/color] [color=white]%s[/color]" % [
		timestamp,
		channel_prefix,
		channel_color,
		player_name,
		message
	]

	chat_lines.append(formatted)
	if chat_lines.size() > max_log_lines:
		chat_lines.pop_front()

	if chat_text:
		chat_text.clear()
		chat_text.append_text("[color=gray]=== Chat Monitor ===\nAll player chat messages will appear here.[/color]\n\n")
		for line in chat_lines:
			chat_text.append_text(line + "\n")
		chat_text.scroll_to_line(chat_text.get_line_count() - 1)


func set_motd(new_motd: String):
	"""Update the Message of the Day"""
	message_of_the_day = new_motd
	if motd_label:
		motd_label.text = "📢 MOTD: " + message_of_the_day


# ========== BUTTON HANDLERS ==========

func _on_help_pressed():
	"""Show help command"""
	add_log("Available commands:", "yellow")
	add_log("  help - Show this help")
	add_log("  clear - Clear console")
	add_log("  quit - Close game")
	add_log("  fps - Toggle FPS display")
	add_log("  stats - Show detailed stats")


func _on_clear_pressed():
	"""Clear console logs"""
	log_lines.clear()
	log_text.clear()
	add_log("Console cleared")


func _on_fps_pressed():
	"""Show current FPS"""
	var current = Performance.get_monitor(Performance.TIME_FPS)
	add_log("Current FPS: %.1f" % current)


func _on_stats_pressed():
	"""Show detailed stats"""
	show_detailed_stats()


func _on_quit_pressed():
	"""Quit the server"""
	add_log("Shutting down server...", "red")
	get_tree().quit()
