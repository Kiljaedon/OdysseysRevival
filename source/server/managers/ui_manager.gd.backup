## UI Manager - Server UI creation and updates
## Handles all server monitoring interface elements and controls
extends Node
class_name ServerUIManager

# Preload ConfigManager to ensure availability
const ConfigManager = preload("res://source/common/config/config_manager.gd")

# Reference to server_world for data access
var server_world: Node2D = null

# ========== UI ELEMENT REFERENCES ==========
var server_log: RichTextLabel
var console_log: RichTextLabel  # New: Terminal/console output
var player_count_label: Label
var status_label: Label
var bandwidth_label: Label
var packets_label: Label

# Stats panel labels
var stats_uptime_label: Label
var stats_accounts_label: Label
var stats_online_players_label: Label
var stats_npcs_label: Label
var stats_activity_log: RichTextLabel

# Connection info
var local_ip_label: Label
var public_ip_label: Label

# Update timers
var stats_timer: float = 0.0
var server_stats_timer: float = 0.0

# Console output capture
var _log_file_path: String = ""
var _last_log_position: int = 0
var _console_update_timer: float = 0.0


func initialize(server_ref: Node2D):
	server_world = server_ref

	# Setup console output capture via custom logger
	_setup_console_capture()

	print("[UIManager] Initialized")


func _setup_console_capture():
	"""Setup to capture Godot's print output by reading log file"""
	# Get the Godot log file path
	_log_file_path = OS.get_user_data_dir() + "/logs/godot.log"

	# Check if log file exists
	if FileAccess.file_exists(_log_file_path):
		# Start from current end of file
		var file = FileAccess.open(_log_file_path, FileAccess.READ)
		if file:
			file.seek_end(0)
			_last_log_position = file.get_position()
			file.close()


func _process(delta: float):
	if not server_world:
		return

	# Skip UI updates in headless mode
	if DisplayServer.get_name() == "headless":
		return

	_update_network_stats(delta)
	_update_server_stats(delta)
	_update_console_from_log(delta)


func _update_console_from_log(delta: float):
	"""Poll Godot's log file for new output and display in console"""
	_console_update_timer += delta

	# Update every 0.1 seconds
	if _console_update_timer < 0.1:
		return

	_console_update_timer = 0.0

	if _log_file_path.is_empty() or not FileAccess.file_exists(_log_file_path):
		return

	var file = FileAccess.open(_log_file_path, FileAccess.READ)
	if not file:
		return

	# Seek to last read position
	file.seek(_last_log_position)

	# Read new content
	var new_content = file.get_as_text()
	var new_position = file.get_position()
	file.close()

	# Only update if there's new content
	if new_position > _last_log_position and not new_content.is_empty():
		_last_log_position = new_position

		# Split into lines and add each to console
		var lines = new_content.split("\n")
		for line in lines:
			if not line.strip_edges().is_empty():
				log_to_console(line)


# ========== UI CREATION ==========

func create_server_ui():
	# Skip UI creation in headless mode
	if DisplayServer.get_name() == "headless":
		print("[UIManager] Running in headless mode - skipping UI creation")
		return

	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	server_world.add_child(bg)

	# Main container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	server_world.add_child(margin)

	# Main horizontal split - Left: Admin Panel, Right: Console
	var main_hsplit = HSplitContainer.new()
	main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	main_hsplit.split_offset = -450  # Console takes ~450px on right
	margin.add_child(main_hsplit)

	# === LEFT SIDE: Admin Panel ===
	var left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 8)
	main_hsplit.add_child(left_panel)

	# Title
	var title = Label.new()
	title.text = "ODYSSEYS REVIVAL - DEVELOPMENT SERVER"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(title)

	# Status row
	var status_row = HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 30)
	left_panel.add_child(status_row)

	status_label = Label.new()
	status_label.text = "Status: STARTING..."
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.modulate = Color.YELLOW
	status_row.add_child(status_label)

	player_count_label = Label.new()
	player_count_label.text = "Players: 0"
	player_count_label.add_theme_font_size_override("font_size", 16)
	status_row.add_child(player_count_label)

	# Scrollable admin content
	var admin_scroll = ScrollContainer.new()
	admin_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	admin_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	admin_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	admin_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(admin_scroll)

	var admin_content = VBoxContainer.new()
	admin_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	admin_content.add_theme_constant_override("separation", 8)
	admin_scroll.add_child(admin_content)

	# Connection Info Panel
	create_connection_info_panel(admin_content)

	# Server Controls Section
	var controls_panel = PanelContainer.new()
	admin_content.add_child(controls_panel)

	var controls_vbox = VBoxContainer.new()
	controls_vbox.add_theme_constant_override("separation", 6)
	controls_panel.add_child(controls_vbox)

	var controls_title = Label.new()
	controls_title.text = "Server Controls"
	controls_title.add_theme_font_size_override("font_size", 14)
	controls_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_vbox.add_child(controls_title)

	# Delta compression toggle
	var delta_hbox = HBoxContainer.new()
	delta_hbox.add_theme_constant_override("separation", 10)
	controls_vbox.add_child(delta_hbox)

	var delta_check = CheckBox.new()
	delta_check.button_pressed = true
	delta_check.toggled.connect(_on_delta_compression_toggled)
	delta_hbox.add_child(delta_check)

	var delta_label = Label.new()
	delta_label.text = "Delta Compression"
	delta_label.add_theme_font_size_override("font_size", 12)
	delta_hbox.add_child(delta_label)

	# Network stats
	var stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 20)
	controls_vbox.add_child(stats_hbox)

	bandwidth_label = Label.new()
	bandwidth_label.text = "Bandwidth: 0 KB/s"
	bandwidth_label.add_theme_font_size_override("font_size", 11)
	stats_hbox.add_child(bandwidth_label)

	packets_label = Label.new()
	packets_label.text = "Packets/sec: 0"
	packets_label.add_theme_font_size_override("font_size", 11)
	stats_hbox.add_child(packets_label)

	# Server Stats Panel
	create_server_stats_panel(admin_content)

	# Admin Utilities Section
	create_admin_utilities_panel(admin_content)

	# Back button at bottom of left panel
	var back_button = Button.new()
	back_button.text = "Back to Menu"
	back_button.custom_minimum_size = Vector2(150, 35)
	back_button.pressed.connect(_on_back_to_menu)
	left_panel.add_child(back_button)

	# === RIGHT SIDE: Console Panel ===
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.custom_minimum_size = Vector2(400, 0)
	var console_style = StyleBoxFlat.new()
	console_style.bg_color = Color(0.02, 0.02, 0.04, 1.0)  # Very dark terminal background
	console_style.border_color = Color(0.15, 0.35, 0.15)
	console_style.set_border_width_all(2)
	console_style.set_corner_radius_all(4)
	right_panel.add_theme_stylebox_override("panel", console_style)
	main_hsplit.add_child(right_panel)

	var console_vbox = VBoxContainer.new()
	console_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(console_vbox)

	# Console title bar
	var console_title_bar = HBoxContainer.new()
	console_title_bar.add_theme_constant_override("separation", 10)
	console_vbox.add_child(console_title_bar)

	var console_title = Label.new()
	console_title.text = "  CONSOLE OUTPUT"
	console_title.add_theme_font_size_override("font_size", 14)
	console_title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	console_title_bar.add_child(console_title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console_title_bar.add_child(spacer)

	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(60, 25)
	clear_btn.pressed.connect(_on_clear_console)
	console_title_bar.add_child(clear_btn)

	# Console log (scrollable, terminal-style)
	var console_scroll = ScrollContainer.new()
	console_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console_vbox.add_child(console_scroll)

	console_log = RichTextLabel.new()
	console_log.bbcode_enabled = true
	console_log.scroll_following = true
	console_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console_log.add_theme_color_override("default_color", Color(0.4, 0.9, 0.4))
	console_log.add_theme_font_size_override("normal_font_size", 11)
	# Use monospace font for terminal look
	var mono_font = SystemFont.new()
	mono_font.font_names = ["Consolas", "Courier New", "monospace"]
	console_log.add_theme_font_override("normal_font", mono_font)
	console_scroll.add_child(console_log)

	# Also keep server_log reference pointing to console_log for compatibility
	server_log = console_log

	# Add welcome message to console
	log_to_console("[SERVER] Console initialized - capturing output...")


func create_connection_info_panel(parent: VBoxContainer):
	var conn_panel = PanelContainer.new()
	parent.add_child(conn_panel)

	var conn_vbox = VBoxContainer.new()
	conn_vbox.add_theme_constant_override("separation", 10)
	conn_panel.add_child(conn_vbox)

	var conn_title = Label.new()
	conn_title.text = "🌐 CONNECTION INFORMATION"
	conn_title.add_theme_font_size_override("font_size", 16)
	conn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	conn_vbox.add_child(conn_title)

	var ip_grid = GridContainer.new()
	ip_grid.columns = 2
	ip_grid.add_theme_constant_override("h_separation", 20)
	ip_grid.add_theme_constant_override("v_separation", 8)
	conn_vbox.add_child(ip_grid)

	var local_label = Label.new()
	local_label.text = "Local IP (LAN):"
	local_label.add_theme_font_size_override("font_size", 14)
	ip_grid.add_child(local_label)

	local_ip_label = Label.new()
	local_ip_label.text = server_world.detected_local_ip
	local_ip_label.add_theme_font_size_override("font_size", 14)
	local_ip_label.modulate = Color.CYAN
	ip_grid.add_child(local_ip_label)

	var public_label = Label.new()
	public_label.text = "Public IP (Internet):"
	public_label.add_theme_font_size_override("font_size", 14)
	ip_grid.add_child(public_label)

	public_ip_label = Label.new()
	public_ip_label.text = server_world.detected_public_ip
	public_ip_label.add_theme_font_size_override("font_size", 14)
	public_ip_label.modulate = Color.YELLOW
	ip_grid.add_child(public_ip_label)

	var port_label = Label.new()
	port_label.text = "Port:"
	port_label.add_theme_font_size_override("font_size", 14)
	ip_grid.add_child(port_label)

	var port_value = Label.new()
	port_value.text = str(server_world.server_port)
	port_value.add_theme_font_size_override("font_size", 14)
	port_value.modulate = Color.CYAN
	ip_grid.add_child(port_value)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	conn_vbox.add_child(spacer)

	var copy_config_btn = Button.new()
	copy_config_btn.text = "📋 COPY CONFIG FOR CLIENT"
	copy_config_btn.custom_minimum_size = Vector2(400, 60)
	copy_config_btn.add_theme_font_size_override("font_size", 18)
	copy_config_btn.pressed.connect(_on_copy_config)
	conn_vbox.add_child(copy_config_btn)

	var instructions = Label.new()
	instructions.text = "Copy this, paste in client Settings, save - done!"
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.modulate = Color(0.8, 0.8, 0.8)
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	conn_vbox.add_child(instructions)


func create_server_stats_panel(parent: VBoxContainer):
	var stats_panel = PanelContainer.new()
	parent.add_child(stats_panel)

	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 10)
	stats_panel.add_child(stats_vbox)

	var stats_title = Label.new()
	stats_title.text = "📊 REAL-TIME SERVER STATISTICS"
	stats_title.add_theme_font_size_override("font_size", 18)
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_vbox.add_child(stats_title)

	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 30)
	stats_grid.add_theme_constant_override("v_separation", 10)
	stats_vbox.add_child(stats_grid)

	var uptime_key = Label.new()
	uptime_key.text = "⏱️ Server Uptime:"
	uptime_key.add_theme_font_size_override("font_size", 14)
	stats_grid.add_child(uptime_key)

	stats_uptime_label = Label.new()
	stats_uptime_label.text = "0s"
	stats_uptime_label.add_theme_font_size_override("font_size", 14)
	stats_uptime_label.modulate = Color.CYAN
	stats_grid.add_child(stats_uptime_label)

	var accounts_key = Label.new()
	accounts_key.text = "👥 Total Accounts:"
	accounts_key.add_theme_font_size_override("font_size", 14)
	stats_grid.add_child(accounts_key)

	stats_accounts_label = Label.new()
	stats_accounts_label.text = "0"
	stats_accounts_label.add_theme_font_size_override("font_size", 14)
	stats_accounts_label.modulate = Color.CYAN
	stats_grid.add_child(stats_accounts_label)

	var online_key = Label.new()
	online_key.text = "🟢 Online Players:"
	online_key.add_theme_font_size_override("font_size", 14)
	stats_grid.add_child(online_key)

	stats_online_players_label = Label.new()
	stats_online_players_label.text = "0"
	stats_online_players_label.add_theme_font_size_override("font_size", 14)
	stats_online_players_label.modulate = Color.GREEN
	stats_grid.add_child(stats_online_players_label)

	var npcs_key = Label.new()
	npcs_key.text = "🤖 Active NPCs:"
	npcs_key.add_theme_font_size_override("font_size", 14)
	stats_grid.add_child(npcs_key)

	stats_npcs_label = Label.new()
	stats_npcs_label.text = "0"
	stats_npcs_label.add_theme_font_size_override("font_size", 14)
	stats_npcs_label.modulate = Color.YELLOW
	stats_grid.add_child(stats_npcs_label)

	var activity_title = Label.new()
	activity_title.text = "📋 Recent Activity:"
	activity_title.add_theme_font_size_override("font_size", 14)
	stats_vbox.add_child(activity_title)

	var activity_scroll = ScrollContainer.new()
	activity_scroll.custom_minimum_size = Vector2(0, 150)
	stats_vbox.add_child(activity_scroll)

	stats_activity_log = RichTextLabel.new()
	stats_activity_log.bbcode_enabled = true
	stats_activity_log.scroll_following = true
	stats_activity_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_activity_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	activity_scroll.add_child(stats_activity_log)

	stats_activity_log.append_text("[color=gray]Server started - waiting for player activity...[/color]\n")


func create_admin_utilities_panel(parent: VBoxContainer):
	var util_panel = PanelContainer.new()
	parent.add_child(util_panel)

	var util_vbox = VBoxContainer.new()
	util_vbox.add_theme_constant_override("separation", 10)
	util_panel.add_child(util_vbox)

	var util_title = Label.new()
	util_title.text = "🛠️ SERVER ADMIN UTILITIES"
	util_title.add_theme_font_size_override("font_size", 18)
	util_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	util_vbox.add_child(util_title)

	var tab_container = TabContainer.new()
	tab_container.custom_minimum_size = Vector2(0, 300)
	util_vbox.add_child(tab_container)

	server_world.admin_ui.create_account_management_tab(tab_container)
	server_world.admin_ui.create_communication_tab(tab_container)
	server_world.admin_ui.create_server_info_tab(tab_container)


# ========== CONNECTION INFO HANDLERS ========== 

func update_connection_info_display():
	if local_ip_label:
		local_ip_label.text = server_world.detected_local_ip
	if public_ip_label:
		public_ip_label.text = server_world.detected_public_ip


func _on_copy_config():
	var config_text = "{\n"
	config_text += '\t"server_address": "%s",\n' % server_world.detected_local_ip
	config_text += '\t"server_port": %d\n' % server_world.server_port
	config_text += "}"

	var full_text = config_text
	if server_world.detected_public_ip != "Detecting..." and server_world.detected_public_ip != "Unknown":
		full_text += "\n\n// For Internet/Remote: Change server_address to: " + server_world.detected_public_ip
		full_text += "\n// (Requires port forwarding on router!)"

	DisplayServer.clipboard_set(config_text)
	server_world.log_message("[CONFIG] ✅ Config copied to clipboard!")
	server_world.log_activity("[color=cyan]📋 Config copied to clipboard[/color]")
	server_world.log_message("[CONFIG] LAN Address: %s | Internet Address: %s" % [server_world.detected_local_ip, server_world.detected_public_ip])

	var config = {
		"server_address": server_world.detected_local_ip,
		"server_port": server_world.server_port
	}
	ConfigManager.save_client_config(config)
	server_world.log_message("[CONFIG] Saved to data/client_config.json")


# ========== SERVER CONTROLS ========== 

func _on_back_to_menu():
	server_world.log_message("[SERVER] Shutting down...")

	if server_world.server and server_world.server.server:
		server_world.server.server.close()

	server_world.get_tree().change_scene_to_file("res://source/common/main.tscn")


func _on_delta_compression_toggled(enabled: bool):
	if server_world.network_manager:
		server_world.network_manager.set_delta_compression(enabled)
	else:
		server_world.log_message("[ERROR] Network manager not initialized")


func _update_network_stats(delta: float):
	stats_timer += delta

	if stats_timer >= 1.0:
		stats_timer = 0.0
		
		var packets_per_sec = 0
		var bytes_per_sec = 0

		if server_world.network_sync:
			var stats = server_world.network_sync.get_stats_summary()
			packets_per_sec = stats.get("packets_sent_this_second", 0)
			bytes_per_sec = stats.get("bytes_sent_this_second", 0)

		# Update UI labels (use direct references)
		if bandwidth_label:
			bandwidth_label.text = "Bandwidth: %.1f KB/s" % (bytes_per_sec / 1024.0)

		if packets_label:
			packets_label.text = "Packets/sec: %d" % packets_per_sec


func _update_server_stats(delta: float):
	server_stats_timer += delta

	if server_stats_timer >= 1.0:
		server_stats_timer = 0.0

		if stats_uptime_label:
			var uptime_seconds = (Time.get_ticks_msec() / 1000.0) - server_world.server_start_time
			var hours = int(uptime_seconds / 3600)
			var minutes = int((uptime_seconds - hours * 3600) / 60)
			var seconds = int(uptime_seconds) % 60
			stats_uptime_label.text = "%02d:%02d:%02d" % [hours, minutes, seconds]

		if stats_accounts_label:
			var accounts_dir = ProjectSettings.globalize_path("res://data/accounts/")
			var account_count = 0
			if DirAccess.dir_exists_absolute(accounts_dir):
				var dir = DirAccess.open(accounts_dir)
				if dir:
					dir.list_dir_begin()
					var file_name = dir.get_next()
					while file_name != "":
						if not dir.current_is_dir() and file_name.ends_with(".json"):
							account_count += 1
						file_name = dir.get_next()
					dir.list_dir_end()
			stats_accounts_label.text = str(account_count)

		if stats_online_players_label:
			var player_list = []
			if server_world.player_manager:
				for peer_id in server_world.player_manager.connected_players:
					var player = server_world.player_manager.connected_players[peer_id]
					var char_name = player.get("character_data", {}).get("name", "Unknown")
					player_list.append(char_name)

			var player_count = server_world.player_manager.connected_players.size() if server_world.player_manager else 0
			stats_online_players_label.text = "%d" % player_count
			if player_count > 0:
				stats_online_players_label.text += " (%s)" % ", ".join(player_list)

		if stats_npcs_label:
			var npc_count = server_world.npc_manager.server_npcs.size() if server_world.npc_manager else 0
			stats_npcs_label.text = str(npc_count)


# ========== PUBLIC API FOR SERVER_WORLD ========== 

func log_to_activity(message: String):
	if stats_activity_log:
		stats_activity_log.append_text(message + "\n")


func update_player_count(count: int):
	if player_count_label:
		player_count_label.text = "Players: %d" % count


func update_status(status: String, color: Color = Color.WHITE):
	if status_label:
		status_label.text = "Status: %s" % status
		status_label.modulate = color

# ========== ADMIN TOOL BUTTON HANDLERS ========== 

func _on_print_stats_pressed():
	if server_world and server_world.stats_manager:
		server_world.stats_manager.print_stats()


func _on_list_players_pressed():
	if server_world and server_world.stats_manager:
		server_world.stats_manager.list_players()


func _on_toggle_console_pressed():
	if server_world and server_world.stats_manager:
		server_world.stats_manager.toggle_console()


func _on_clear_console():
	"""Clear the console output"""
	if console_log:
		console_log.clear()
		console_log.append_text("[color=gray]Console cleared.[/color]\n")


func log_to_console(message: String):
	"""Add a message to the console output with terminal-style formatting"""
	if not console_log:
		return

	# Color code based on message content
	var colored_message = message
	if message.begins_with("[ERROR]") or "ERROR" in message:
		colored_message = "[color=red]%s[/color]" % message
	elif message.begins_with("[WARNING]") or "WARNING" in message:
		colored_message = "[color=yellow]%s[/color]" % message
	elif message.begins_with("[OK]") or "SUCCESS" in message or "✓" in message or "✅" in message:
		colored_message = "[color=lime]%s[/color]" % message
	elif message.begins_with("[SERVER]") or message.begins_with("[COMBAT]"):
		colored_message = "[color=cyan]%s[/color]" % message
	elif message.begins_with("[NPC]"):
		colored_message = "[color=orange]%s[/color]" % message
	elif message.begins_with("[NETWORK]") or message.begins_with("[BaseServer]"):
		colored_message = "[color=aqua]%s[/color]" % message
	elif message.begins_with("[DEBUG]"):
		colored_message = "[color=gray]%s[/color]" % message
	else:
		colored_message = "[color=#66ff66]%s[/color]" % message  # Default green

	console_log.append_text(colored_message + "\n")