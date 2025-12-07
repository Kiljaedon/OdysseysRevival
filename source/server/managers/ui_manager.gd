extends Node
class_name ServerUIManager

const ConfigManager = preload("res://source/common/config/config_manager.gd")

var server_world: Node = null

# ========== UI ELEMENT REFERENCES ==========
var console_log: RichTextLabel
var server_log: RichTextLabel  # Alias for compatibility
var player_count_label: Label
var status_label: Label
var uptime_label: Label
var bandwidth_label: Label
var packets_label: Label
var line_count_label: Label
var log_path_label: Label # New debug label

# Stats panel labels
var stats_uptime_label: Label
var stats_accounts_label: Label
var stats_online_players_label: Label
var stats_npcs_label: Label
var stats_activity_log: RichTextLabel

# Connection info
var local_ip_label: Label
var public_ip_label: Label

# Admin panel reference
var admin_panel: PanelContainer
var admin_tabs: TabContainer

# Update timers
var stats_timer: float = 0.0
var server_stats_timer: float = 0.0

# Console output capture
var _log_file_path: String = ""
var _last_log_position: int = 0
var _console_update_timer: float = 0.0
var _console_line_count: int = 0
var _ui_ready: bool = false

# Buffer for log scanning
var _log_buffer: String = ""
var _session_marker_found: bool = false
const SESSION_MARKER = "=== ODYSSEYS REVIVAL - DEVELOPMENT SERVER ==="


func initialize(server_ref: Node, custom_log_path: String = ""):
	server_world = server_ref
	
	if not custom_log_path.is_empty():
		_log_file_path = custom_log_path
	else:
		# Use project folder instead of AppData
		_log_file_path = ProjectSettings.globalize_path("res://logs/godot.log")
		
	_setup_console_capture()
	print("[UIManager] Initialized - Log Capture Mode")
	
	if log_path_label:
		log_path_label.text = "Log: " + _log_file_path


func _setup_console_capture():
	"""Capture Godot's print output from session start using buffer scan"""
	if _log_file_path.is_empty() or not FileAccess.file_exists(_log_file_path):
		return

	var file = FileAccess.open(_log_file_path, FileAccess.READ)
	if not file:
		return
	
	# Determine where to start reading. 
	# If the file is huge, we only want the tail to find the recent start.
	var file_len = file.get_length()
	var start_pos = 0
	if file_len > 100000: # If > 100KB, just read last 50KB
		start_pos = file_len - 50000
	
	file.seek(start_pos)
	_log_buffer = file.get_as_text()
	_last_log_position = file.get_position()
	file.close()
	
	# Initial scan attempt
	_scan_buffer_for_marker()


func _process(delta: float):
	if not server_world:
		return
	# REMOVED: DisplayServer.get_name() == "headless" check to allow logic updates (and testing)
	
	_update_header_stats(delta)
	_update_console_from_log(delta)


func _update_console_from_log(delta: float):
	_console_update_timer += delta
	if _console_update_timer < 0.1: # 10fps update for logs is plenty
		return
	_console_update_timer = 0.0

	if _log_file_path.is_empty() or not FileAccess.file_exists(_log_file_path):
		if log_path_label:
			log_path_label.text = "ERR: Log file not found! " + _log_file_path
			log_path_label.add_theme_color_override("font_color", Color.RED)
		return

	var file = FileAccess.open(_log_file_path, FileAccess.READ)
	if not file:
		return

	file.seek(_last_log_position)
	var new_content = file.get_as_text()
	_last_log_position = file.get_position()
	
	if not new_content.is_empty():
		_log_buffer += new_content
			
	file.close()
	
	# Process buffer
	if _session_marker_found:
		# We are in the session, just flush the buffer to console
		if not _log_buffer.is_empty():
			_flush_buffer_to_console()
	else:
		# Still looking for start of session
		_scan_buffer_for_marker()


func _scan_buffer_for_marker():
	var marker_pos = _log_buffer.rfind(SESSION_MARKER)
	
	if marker_pos != -1:
		# Found it! Discard everything before it.
		_session_marker_found = true
		_log_buffer = _log_buffer.substr(marker_pos)
		_flush_buffer_to_console()
		
		if log_path_label:
			log_path_label.text = "Log: Connected (" + _log_file_path.get_file() + ")"
			log_path_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		# Not found yet. 
		if log_path_label:
			log_path_label.text = "Log: Scanning... (" + str(_log_buffer.length()) + "b)"
			log_path_label.add_theme_color_override("font_color", Color.YELLOW)
			
		# Optimization: If buffer gets too big (>50KB) and no marker, 
		# we might be looking at old logs. Trim head.
		if _log_buffer.length() > 100000:
			_log_buffer = _log_buffer.right(50000)


func _flush_buffer_to_console():
	if not _ui_ready:
		return # Wait for UI
		
	var lines = _log_buffer.split("\n")
	
	for line in lines:
		var trimmed = line.strip_edges() # strip \r
		if not trimmed.is_empty():
			_append_to_console(trimmed)
	
	_log_buffer = "" # Clear buffer after flushing


func _append_to_console(message: String):
	if not console_log:
		return
	_console_line_count += 1
	if line_count_label:
		line_count_label.text = "%d lines" % _console_line_count
	var colored = _colorize_message(message)
	console_log.append_text(colored + "\n")


func _colorize_message(message: String) -> String:
	var msg_upper = message.to_upper()
	if "ERROR" in msg_upper:
		return "[color=red]%s[/color]" % message
	elif "WARNING" in msg_upper:
		return "[color=yellow]%s[/color]" % message
	elif message.begins_with("[SERVER]"):
		return "[color=cyan]%s[/color]" % message
	elif message.begins_with("[BaseServer]"):
		return "[color=#00CED1]%s[/color]" % message
	elif message.begins_with("[NETWORK]"):
		return "[color=aqua]%s[/color]" % message
	elif message.begins_with("[NPC]"):
		return "[color=orange]%s[/color]" % message
	elif message.begins_with("[COMBAT]") or message.begins_with("[RT_COMBAT]"):
		return "[color=#FF6B6B]%s[/color]" % message
	elif message.begins_with("[BATTLE"):
		return "[color=#FF8C00]%s[/color]" % message
	elif message.begins_with("[AUTH]"):
		return "[color=#9370DB]%s[/color]" % message
	elif message.begins_with("[PLAYER]"):
		return "[color=#32CD32]%s[/color]" % message
	elif message.begins_with("[CONNECT]"):
		return "[color=#20B2AA]%s[/color]" % message
	elif message.begins_with("[ANTI_CHEAT]"):
		return "[color=#FFD700]%s[/color]" % message
	elif message.begins_with("[DEBUG]"):
		return "[color=#888888]%s[/color]" % message
	elif message.begins_with("[CONFIG]"):
		return "[color=#DDA0DD]%s[/color]" % message
	elif message.begins_with("[SPATIAL]") or message.begins_with("[MAP]"):
		return "[color=#87CEEB]%s[/color]" % message
	elif message.begins_with("[INPUT]") or message.begins_with("[CHAT]"):
		return "[color=#98FB98]%s[/color]" % message
	elif message.begins_with("[CONTENT]"):
		return "[color=#F0E68C]%s[/color]" % message
	elif message.begins_with("[STATS]"):
		return "[color=#DEB887]%s[/color]" % message
	elif message.begins_with("==="):
		return "[color=#FFFFFF][b]%s[/b][/color]" % message
	elif message.begins_with("Window size") or message.begins_with("UI Scaler"):
		return "[color=#666666]%s[/color]" % message
	else:
		return "[color=#66FF66]%s[/color]" % message


func create_server_ui():
	if DisplayServer.get_name() == "headless":
		print("[UIManager] Running in headless mode - skipping UI creation")
		return

	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	server_world.add_child(bg)

	var main_margin = MarginContainer.new()
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 6)
	main_margin.add_theme_constant_override("margin_right", 6)
	main_margin.add_theme_constant_override("margin_top", 6)
	main_margin.add_theme_constant_override("margin_bottom", 6)
	server_world.add_child(main_margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 4)
	main_margin.add_child(main_vbox)

	_create_header_bar(main_vbox)
	_create_console_panel(main_vbox)
	_create_admin_footer(main_vbox)

	_ui_ready = true
	# Trigger buffer flush immediately if we have data
	if not _log_buffer.is_empty() and _session_marker_found:
		_flush_buffer_to_console()


func _create_header_bar(parent: VBoxContainer):
	var header = PanelContainer.new()
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.10, 0.10, 0.14, 1.0)
	header_style.set_corner_radius_all(2)
	header.add_theme_stylebox_override("panel", header_style)
	parent.add_child(header)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 15)
	header.add_child(header_hbox)

	var title = Label.new()
	title.text = "ODYSSEYS REVIVAL SERVER"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	header_hbox.add_child(title)

	var spacer1 = Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer1)
	
	# Debug Log Path Label
	log_path_label = Label.new()
	log_path_label.text = "Log: Initializing..."
	log_path_label.add_theme_font_size_override("font_size", 11)
	log_path_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	header_hbox.add_child(log_path_label)

	status_label = Label.new()
	status_label.text = "STARTING..."
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color.YELLOW)
	header_hbox.add_child(status_label)

	player_count_label = Label.new()
	player_count_label.text = "Players: 0"
	player_count_label.add_theme_font_size_override("font_size", 14)
	player_count_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	header_hbox.add_child(player_count_label)

	uptime_label = Label.new()
	uptime_label.text = "00:00:00"
	uptime_label.add_theme_font_size_override("font_size", 14)
	uptime_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	header_hbox.add_child(uptime_label)
	
	# Network stats in header
	bandwidth_label = Label.new()
	bandwidth_label.text = "0 KB/s"
	bandwidth_label.add_theme_font_size_override("font_size", 12)
	bandwidth_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header_hbox.add_child(bandwidth_label)


func _create_console_panel(parent: VBoxContainer):
	var console_panel = PanelContainer.new()
	# DOMINANT CONSOLE: Expand vertically with high stretch ratio
	console_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console_panel.size_flags_stretch_ratio = 6.0 # 6:1 ratio against admin panel (Much bigger)

	var console_style = StyleBoxFlat.new()
	console_style.bg_color = Color(0.01, 0.01, 0.01, 1.0)
	console_style.border_color = Color(0.2, 0.4, 0.2)
	console_style.set_border_width_all(1)
	console_style.set_corner_radius_all(2)
	console_panel.add_theme_stylebox_override("panel", console_style)
	parent.add_child(console_panel)

	var console_vbox = VBoxContainer.new()
	console_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console_panel.add_child(console_vbox)

	var title_bar = HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 10)
	console_vbox.add_child(title_bar)

	var console_title = Label.new()
	console_title.text = " CONSOLE OUTPUT"
	console_title.add_theme_font_size_override("font_size", 13)
	console_title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	title_bar.add_child(console_title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(spacer)

	line_count_label = Label.new()
	line_count_label.text = "0 lines"
	line_count_label.add_theme_font_size_override("font_size", 11)
	line_count_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	title_bar.add_child(line_count_label)

	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(50, 20)
	clear_btn.add_theme_font_size_override("font_size", 12)
	clear_btn.pressed.connect(_on_clear_console)
	title_bar.add_child(clear_btn)

	# Create scroll container to hold the console
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED # Re-enable horizontal scrolling
	console_vbox.add_child(scroll)

	console_log = RichTextLabel.new()
	console_log.bbcode_enabled = true
	console_log.scroll_following = true
	console_log.selection_enabled = true
	console_log.fit_content = false # Allow content to exceed bounding box, enabling scroll
	console_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console_log.add_theme_color_override("default_color", Color(0.8, 0.8, 0.8))
	console_log.add_theme_font_size_override("normal_font_size", 16) # Increased font size (was 14)
	scroll.add_child(console_log)
	server_log = console_log


func _create_admin_footer(parent: VBoxContainer):
	admin_panel = PanelContainer.new()
	# Small footer
	admin_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	admin_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	admin_panel.size_flags_stretch_ratio = 1.0
	admin_panel.custom_minimum_size = Vector2(0, 120) # Minimum height

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.14, 1.0)
	panel_style.set_corner_radius_all(2)
	admin_panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(admin_panel)

	admin_tabs = TabContainer.new()
	admin_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	admin_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	admin_panel.add_child(admin_tabs)

	_create_connection_tab()
	_create_stats_tab()

	if server_world.admin_ui:
		server_world.admin_ui.create_account_management_tab(admin_tabs)
		server_world.admin_ui.create_communication_tab(admin_tabs)
		server_world.admin_ui.create_server_info_tab(admin_tabs)


func _create_connection_tab():
	var tab = VBoxContainer.new()
	tab.name = "Connection"
	tab.add_theme_constant_override("separation", 4)
	admin_tabs.add_child(tab)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 4)
	tab.add_child(grid)

	var local_lbl = Label.new()
	local_lbl.text = "Local IP:"
	grid.add_child(local_lbl)

	local_ip_label = Label.new()
	local_ip_label.text = server_world.detected_local_ip if server_world else "..."
	local_ip_label.add_theme_color_override("font_color", Color.CYAN)
	grid.add_child(local_ip_label)

	var port_lbl = Label.new()
	port_lbl.text = "Port:"
	grid.add_child(port_lbl)

	var port_val = Label.new()
	port_val.text = str(server_world.server_port) if server_world else "9123"
	port_val.add_theme_color_override("font_color", Color.CYAN)
	grid.add_child(port_val)

	var public_lbl = Label.new()
	public_lbl.text = "Public IP:"
	grid.add_child(public_lbl)

	public_ip_label = Label.new()
	public_ip_label.text = server_world.detected_public_ip if server_world else "..."
	public_ip_label.add_theme_color_override("font_color", Color.YELLOW)
	grid.add_child(public_lbl)
	grid.add_child(public_ip_label)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	tab.add_child(btn_row)

	var copy_btn = Button.new()
	copy_btn.text = "Copy Client Config"
	copy_btn.custom_minimum_size = Vector2(140, 24)
	copy_btn.pressed.connect(_on_copy_config)
	btn_row.add_child(copy_btn)

	var back_btn = Button.new()
	back_btn.text = "Shutdown"
	back_btn.custom_minimum_size = Vector2(100, 24)
	back_btn.pressed.connect(_on_back_to_menu)
	back_btn.modulate = Color(1.0, 0.5, 0.5)
	btn_row.add_child(back_btn)


func _create_stats_tab():
	var tab = VBoxContainer.new()
	tab.name = "Stats"
	tab.add_theme_constant_override("separation", 4)
	admin_tabs.add_child(tab)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 4)
	tab.add_child(grid)

	var acc_lbl = Label.new()
	acc_lbl.text = "Accounts:"
	grid.add_child(acc_lbl)

	stats_accounts_label = Label.new()
	stats_accounts_label.text = "0"
	stats_accounts_label.add_theme_color_override("font_color", Color.CYAN)
	grid.add_child(stats_accounts_label)

	var online_lbl = Label.new()
	online_lbl.text = "Online:"
	grid.add_child(online_lbl)

	stats_online_players_label = Label.new()
	stats_online_players_label.text = "0"
	stats_online_players_label.add_theme_color_override("font_color", Color.GREEN)
	grid.add_child(stats_online_players_label)

	var npc_lbl = Label.new()
	npc_lbl.text = "NPCs:"
	grid.add_child(npc_lbl)

	stats_npcs_label = Label.new()
	stats_npcs_label.text = "0"
	stats_npcs_label.add_theme_color_override("font_color", Color.YELLOW)
	grid.add_child(stats_npcs_label)


func _update_header_stats(delta: float):
	stats_timer += delta
	if stats_timer >= 1.0:
		stats_timer = 0.0

		if uptime_label and server_world:
			var uptime_sec = (Time.get_ticks_msec() / 1000.0) - server_world.server_start_time
			var h = int(uptime_sec / 3600)
			var m = int((uptime_sec - h * 3600) / 60)
			var s = int(uptime_sec) % 60
			uptime_label.text = "%02d:%02d:%02d" % [h, m, s]

		if server_world and server_world.network_sync:
			var stats = server_world.network_sync.get_stats_summary()
			if bandwidth_label:
				bandwidth_label.text = "%.1f KB/s" % (stats.get("bytes_sent_this_second", 0) / 1024.0)
			if packets_label:
				packets_label.text = "%d pkt/s" % stats.get("packets_sent_this_second", 0)

		if player_count_label and server_world and server_world.player_manager:
			var count = server_world.player_manager.connected_players.size()
			player_count_label.text = "Players: %d" % count

		_update_stats_tab()


func _update_stats_tab():
	if not server_world:
		return

	if stats_accounts_label:
		var accounts_dir = ProjectSettings.globalize_path("res://data/accounts/")
		var count = 0
		if DirAccess.dir_exists_absolute(accounts_dir):
			var dir = DirAccess.open(accounts_dir)
			if dir:
				dir.list_dir_begin()
				var f = dir.get_next()
				while f != "":
					if not dir.current_is_dir() and f.ends_with(".json"):
						count += 1
					f = dir.get_next()
				dir.list_dir_end()
		stats_accounts_label.text = str(count)

	if stats_online_players_label and server_world.player_manager:
		stats_online_players_label.text = str(server_world.player_manager.connected_players.size())

	if stats_npcs_label and server_world.npc_manager:
		stats_npcs_label.text = str(server_world.npc_manager.server_npcs.size())


func log_to_console(message: String):
	# NO-OP: We now rely solely on file capture to avoid duplicates 
	# and to ensure engine errors are captured in sequence.
	pass


func log_to_activity(message: String):
	# Redirect to console (which is handled by file capture now)
	pass


func update_player_count(count: int):
	if player_count_label:
		player_count_label.text = "Players: %d" % count


func update_status(new_status: String, color: Color = Color.WHITE):
	if status_label:
		status_label.text = new_status
		status_label.add_theme_color_override("font_color", color)


func update_connection_info_display():
	if local_ip_label and server_world:
		local_ip_label.text = server_world.detected_local_ip
	if public_ip_label and server_world:
		public_ip_label.text = server_world.detected_public_ip


func _on_clear_console():
	if console_log:
		console_log.clear()
		_console_line_count = 0
		if line_count_label:
			line_count_label.text = "0 lines"
		console_log.append_text("[color=gray]Console cleared.[/color]\n")


func _on_copy_config():
	if not server_world:
		return
	var config_text = '{\n\t"server_address": "%s",\n\t"server_port": %d\n}' % [
		server_world.detected_local_ip, server_world.server_port]
	DisplayServer.clipboard_set(config_text)
	# We can't log to console directly anymore, but we can print() which goes to file -> console
	print("[CONFIG] Client config copied to clipboard")
	var config = {"server_address": server_world.detected_local_ip, "server_port": server_world.server_port}
	ConfigManager.save_client_config(config)


func _on_back_to_menu():
	if server_world:
		print("[SERVER] Shutting down...")
		if server_world.server and server_world.server.server:
			server_world.server.server.close()
		server_world.get_tree().change_scene_to_file("res://source/common/main.tscn")


func _on_delta_compression_toggled(enabled: bool):
	if server_world and server_world.network_manager:
		server_world.network_manager.set_delta_compression(enabled)


func _on_print_stats_pressed():
	if server_world and server_world.stats_manager:
		server_world.stats_manager.print_stats()


func _on_list_players_pressed():
	if server_world and server_world.stats_manager:
		server_world.stats_manager.list_players()


func _on_toggle_console_pressed():
	if server_world and server_world.stats_manager:
		server_world.stats_manager.toggle_console()