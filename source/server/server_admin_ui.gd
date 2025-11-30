class_name ServerAdminUI
extends Node
## Server Admin Panel UI and Utilities
## Handles all admin panel creation and button callbacks

var server_world: Node  # Reference to main server

# UI Elements
var admin_tab_container: TabContainer
var accounts_list: VBoxContainer
var player_selector: OptionButton
var server_stats_label: Label  # Stores reference to auto-update stats


func _init(server_ref: Node):
	server_world = server_ref


# ========== ADMIN PANEL TAB CREATORS ==========

func create_account_management_tab(tab_container: TabContainer):
	"""Create Account Management admin panel tab"""
	var account_tab = VBoxContainer.new()
	account_tab.name = "Account Management"
	tab_container.add_child(account_tab)

	var title = Label.new()
	title.text = "📋 Account Management"
	title.add_theme_font_size_override("font_size", 16)
	account_tab.add_child(title)

	var sep1 = HSeparator.new()
	account_tab.add_child(sep1)

	# Create Account section
	var create_label = Label.new()
	create_label.text = "Create New Account:"
	account_tab.add_child(create_label)

	var create_container = HBoxContainer.new()
	account_tab.add_child(create_container)

	var username_input = LineEdit.new()
	username_input.placeholder_text = "Username"
	username_input.custom_minimum_size = Vector2(150, 0)
	create_container.add_child(username_input)

	var password_input = LineEdit.new()
	password_input.placeholder_text = "Password"
	password_input.secret = true
	password_input.custom_minimum_size = Vector2(150, 0)
	create_container.add_child(password_input)

	var create_btn = Button.new()
	create_btn.text = "Create Account"
	create_btn.pressed.connect(_on_admin_create_account.bind(username_input, password_input))
	create_container.add_child(create_btn)

	var sep2 = HSeparator.new()
	account_tab.add_child(sep2)

	# Accounts list section
	var list_header = HBoxContainer.new()
	account_tab.add_child(list_header)

	var list_label = Label.new()
	list_label.text = "Existing Accounts:"
	list_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_header.add_child(list_label)

	var refresh_btn = Button.new()
	refresh_btn.text = "🔄 Refresh"
	list_header.add_child(refresh_btn)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	account_tab.add_child(scroll)

	accounts_list = VBoxContainer.new()
	scroll.add_child(accounts_list)

	refresh_btn.pressed.connect(_on_refresh_accounts_list.bind(accounts_list))
	_on_refresh_accounts_list(accounts_list)


func create_communication_tab(tab_container: TabContainer):
	"""Create Communication admin panel tab"""
	var comm_tab = VBoxContainer.new()
	comm_tab.name = "Communication"
	tab_container.add_child(comm_tab)

	var title = Label.new()
	title.text = "📢 Server Communication"
	title.add_theme_font_size_override("font_size", 16)
	comm_tab.add_child(title)

	var sep1 = HSeparator.new()
	comm_tab.add_child(sep1)

	# Server Announcement section
	var announce_label = Label.new()
	announce_label.text = "Broadcast Announcement to All Players:"
	comm_tab.add_child(announce_label)

	var announce_container = HBoxContainer.new()
	comm_tab.add_child(announce_container)

	var announce_input = LineEdit.new()
	announce_input.placeholder_text = "Enter announcement message..."
	announce_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	announce_container.add_child(announce_input)

	var announce_btn = Button.new()
	announce_btn.text = "Send Announcement"
	announce_btn.pressed.connect(_on_send_announcement.bind(announce_input))
	announce_container.add_child(announce_btn)

	var sep2 = HSeparator.new()
	comm_tab.add_child(sep2)

	# Private message section
	var pm_label = Label.new()
	pm_label.text = "Send Private Message to Player:"
	comm_tab.add_child(pm_label)

	var pm_container = HBoxContainer.new()
	comm_tab.add_child(pm_container)

	player_selector = OptionButton.new()
	player_selector.custom_minimum_size = Vector2(150, 0)
	pm_container.add_child(player_selector)

	var refresh_players_btn = Button.new()
	refresh_players_btn.text = "🔄"
	refresh_players_btn.pressed.connect(_on_refresh_player_selector.bind(player_selector))
	pm_container.add_child(refresh_players_btn)

	var chat_input = LineEdit.new()
	chat_input.placeholder_text = "Enter message..."
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pm_container.add_child(chat_input)

	var send_btn = Button.new()
	send_btn.text = "Send"
	send_btn.pressed.connect(_on_send_admin_chat.bind(player_selector, chat_input))
	pm_container.add_child(send_btn)

	# Don't refresh during initialization - player_manager not ready yet
	# Will be populated when first player connects
	# _on_refresh_player_selector(player_selector)


func create_server_info_tab(tab_container: TabContainer):
	"""Create Server Info admin panel tab"""
	var info_tab = VBoxContainer.new()
	info_tab.name = "Server Info"
	tab_container.add_child(info_tab)

	var title = Label.new()
	title.text = "🗺️ Server Information"
	title.add_theme_font_size_override("font_size", 16)
	info_tab.add_child(title)

	var sep1 = HSeparator.new()
	info_tab.add_child(sep1)

	# Maps list section
	var maps_label = Label.new()
	maps_label.text = "Available Maps:"
	info_tab.add_child(maps_label)

	var maps_scroll = ScrollContainer.new()
	maps_scroll.custom_minimum_size = Vector2(0, 150)
	maps_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_tab.add_child(maps_scroll)

	var maps_list = VBoxContainer.new()
	maps_scroll.add_child(maps_list)

	var refresh_maps_btn = Button.new()
	refresh_maps_btn.text = "🔄 Refresh Maps"
	refresh_maps_btn.pressed.connect(_on_refresh_maps_list.bind(maps_list))
	info_tab.add_child(refresh_maps_btn)

	var sep2 = HSeparator.new()
	info_tab.add_child(sep2)

	# Database stats section
	var db_label = Label.new()
	db_label.text = "Database Statistics:"
	info_tab.add_child(db_label)

	server_stats_label = Label.new()
	server_stats_label.text = "Waiting for server initialization..."
	info_tab.add_child(server_stats_label)

	var refresh_db_btn = Button.new()
	refresh_db_btn.text = "🔄 Refresh Stats"
	refresh_db_btn.pressed.connect(_on_refresh_database_stats.bind(server_stats_label))
	info_tab.add_child(refresh_db_btn)

	_on_refresh_maps_list(maps_list)
	# Don't refresh stats during initialization - managers not ready yet
	# Will be updated once server is fully initialized
	# _on_refresh_database_stats(server_stats_label)


# ========== ADMIN BUTTON HANDLERS ==========

func _on_admin_create_account(username_input: LineEdit, password_input: LineEdit):
	"""Admin panel - create account"""
	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()

	if username.is_empty() or password.is_empty():
		server_world.log_message("[ADMIN] ERROR: Username and password required")
		return

	server_world.log_message("[ADMIN] Creating account: %s" % username)

	# Use game database to create account
	var result = GameDatabase.create_account(username, password)
	if result:
		server_world.log_message("[ADMIN] ✅ Account created successfully")
		username_input.clear()
		password_input.clear()
		_on_refresh_accounts_list(accounts_list)
	else:
		server_world.log_message("[ADMIN] ❌ Failed to create account (may already exist)")


func _on_refresh_accounts_list(accounts_list_container: VBoxContainer):
	"""Refresh the accounts list display"""
	# Clear existing list
	for child in accounts_list_container.get_children():
		child.queue_free()

	var accounts_dir = "res://data/accounts/"
	var dir = DirAccess.open(accounts_dir)

	if not dir:
		var error_label = Label.new()
		error_label.text = "No accounts directory found"
		accounts_list_container.add_child(error_label)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var account_count = 0

	while file_name != "":
		if file_name.ends_with(".json"):
			var account_name = file_name.replace(".json", "")
			var account_row = HBoxContainer.new()
			accounts_list_container.add_child(account_row)

			var name_label = Label.new()
			name_label.text = account_name
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			account_row.add_child(name_label)

			var view_btn = Button.new()
			view_btn.text = "View"
			view_btn.pressed.connect(_on_view_account_details.bind(account_name))
			account_row.add_child(view_btn)

			var delete_btn = Button.new()
			delete_btn.text = "Delete"
			delete_btn.modulate = Color(1.0, 0.5, 0.5)
			delete_btn.pressed.connect(_on_delete_account.bind(account_name, accounts_list_container))
			account_row.add_child(delete_btn)

			account_count += 1

		file_name = dir.get_next()

	dir.list_dir_end()

	if account_count == 0:
		var empty_label = Label.new()
		empty_label.text = "No accounts found"
		accounts_list_container.add_child(empty_label)


func _on_view_account_details(account_name: String):
	"""View account details"""
	server_world.log_message("[ADMIN] Viewing account: %s" % account_name)

	var account_file = "res://data/accounts/" + account_name + ".json"
	if FileAccess.file_exists(account_file):
		var file = FileAccess.open(account_file, FileAccess.READ)
		var content = file.get_as_text()
		file.close()

		server_world.log_message("Account data: %s" % content)
	else:
		server_world.log_message("[ADMIN] ERROR: Account file not found")


func _on_delete_account(account_name: String, accounts_list_container: VBoxContainer):
	"""Delete an account (admin function)"""
	server_world.log_message("[ADMIN] Deleting account: %s" % account_name)

	var account_file = "res://data/accounts/" + account_name + ".json"
	if FileAccess.file_exists(account_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(account_file))
		server_world.log_message("[ADMIN] ✅ Account deleted")
		_on_refresh_accounts_list(accounts_list_container)
	else:
		server_world.log_message("[ADMIN] ❌ Account file not found")


func _on_send_announcement(announce_input: LineEdit):
	"""Broadcast server announcement to all players"""
	var message = announce_input.text.strip_edges()

	if message.is_empty():
		return

	server_world.log_message("[ADMIN] Broadcasting announcement: %s" % message)

	# Log to debug console chat tab
	if server_world.debug_console:
		server_world.debug_console.add_chat("SERVER", message, "server")

	# Send to all connected players
	if server_world.network_handler and server_world.player_manager:
		for peer_id in server_world.player_manager.connected_players:
			server_world.network_handler.broadcast_chat_to_peer(peer_id, "[SERVER]", message)

	announce_input.clear()


func _on_send_admin_chat(player_sel: OptionButton, chat_input: LineEdit):
	"""Send private message to specific player"""
	if player_sel.selected == -1:
		server_world.log_message("[ADMIN] ERROR: No player selected")
		return

	var message = chat_input.text.strip_edges()
	if message.is_empty():
		return

	var peer_id = player_sel.get_item_metadata(player_sel.selected)
	var player_name = player_sel.get_item_text(player_sel.selected)

	server_world.log_message("[ADMIN] Sending message to %s: %s" % [player_name, message])

	# Log to debug console chat tab
	if server_world.debug_console:
		server_world.debug_console.add_chat("ADMIN → %s" % player_name, message, "admin")

	if server_world.network_handler:
		server_world.network_handler.broadcast_chat_to_peer(peer_id, "[ADMIN]", message)

	chat_input.clear()


func _on_refresh_player_selector(player_sel: OptionButton):
	"""Update dropdown with current online players"""
	player_sel.clear()

	if not server_world.player_manager or server_world.player_manager.connected_players.is_empty():
		player_sel.add_item("(No players online)")
		player_sel.disabled = true
		return

	player_sel.disabled = false
	for peer_id in server_world.player_manager.connected_players:
		var player = server_world.player_manager.connected_players[peer_id]
		var char_name = player.get("character_name", "Unknown")
		player_sel.add_item("%s (ID: %d)" % [char_name, peer_id])
		player_sel.set_item_metadata(player_sel.item_count - 1, peer_id)


func _on_refresh_maps_list(maps_list_container: VBoxContainer):
	"""Refresh the maps list display"""
	# Clear existing list
	for child in maps_list_container.get_children():
		child.queue_free()

	var maps_dir = "res://maps/"
	var dir = DirAccess.open(maps_dir)

	if not dir:
		var error_label = Label.new()
		error_label.text = "No maps directory found"
		maps_list_container.add_child(error_label)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var map_count = 0

	while file_name != "":
		if file_name.ends_with(".tmx"):
			var map_label = Label.new()
			map_label.text = "• " + file_name
			maps_list_container.add_child(map_label)
			map_count += 1

		file_name = dir.get_next()

	dir.list_dir_end()

	if map_count == 0:
		var empty_label = Label.new()
		empty_label.text = "No TMX maps found"
		maps_list_container.add_child(empty_label)


func _on_refresh_database_stats(stats_label: Label):
	"""Refresh database statistics display"""
	var stats_text = ""

	# Count accounts
	var accounts_dir = "res://data/accounts/"
	var accounts_count = 0
	var dir = DirAccess.open(accounts_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				accounts_count += 1
			file_name = dir.get_next()
		dir.list_dir_end()

	stats_text += "Total Accounts: %d\n" % accounts_count
	var player_count = server_world.player_manager.connected_players.size() if server_world.player_manager else 0
	stats_text += "Online Players: %d\n" % player_count
	stats_text += "Active NPCs: %d" % server_world.get_server_npcs().size()

	stats_label.text = stats_text


func update_server_stats():
	"""Auto-update server stats when called by server_world"""
	if server_stats_label:
		_on_refresh_database_stats(server_stats_label)
