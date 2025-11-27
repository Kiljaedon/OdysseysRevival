extends Control
## Login Screen for Odysseys Revival
## Connects to server for authentication

const Log = preload("res://source/common/utils/logger.gd")

signal login_successful(username: String)

var username_input: LineEdit
var password_input: LineEdit
var login_button: Button
var create_account_button: Button
var back_button: Button
var status_label: Label
var server_env_dropdown: OptionButton

var client: WorldClient
var awaiting_response: bool = false

# Login cooldown system
var login_cooldown_time: float = 0.0
var cooldown_duration: float = 3.0  # 3 second cooldown after logout
var login_timeout_time: float = 0.0
var login_timeout_duration: float = 10.0  # 10 second timeout for login response


func _ready():
	create_ui()

	# Move ServerConnection to /root so RPCs can find it at the same path as server
	# Check if already at root from previous scene
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if not server_conn:
		# Not at root yet, try to get from our scene
		server_conn = get_node_or_null("ServerConnection")
		if server_conn:
			remove_child(server_conn)
			get_tree().root.add_child(server_conn)
			Log.debug("Moved ServerConnection to /root", "Auth")
		else:
			Log.warn("ServerConnection not found in scene or root!", "Auth")
	else:
		Log.debug("ServerConnection already at /root (reusing)", "Auth")

	# Check if there's a logout cooldown active
	var last_logout_time = GameState.get("last_logout_time")
	if last_logout_time != null:
		var time_since_logout = Time.get_ticks_msec() / 1000.0 - last_logout_time
		if time_since_logout < cooldown_duration:
			login_cooldown_time = cooldown_duration - time_since_logout
			Log.debug("Cooldown active: %.1f seconds remaining" % login_cooldown_time, "Auth")
		GameState.set("last_logout_time", null)  # Clear it

	connect_to_server()


func _process(delta: float):
	# Handle login cooldown countdown
	if login_cooldown_time > 0:
		login_cooldown_time -= delta
		var seconds_remaining = ceil(login_cooldown_time)
		show_status("Please wait %d seconds before logging in..." % seconds_remaining, Color.YELLOW)
		login_button.disabled = true
		create_account_button.disabled = true

		if login_cooldown_time <= 0:
			login_cooldown_time = 0
			# Re-enable buttons if connected
			if client and client.is_connected_to_server:
				show_status("✅ Connected to server", Color.GREEN)
				login_button.disabled = false
				create_account_button.disabled = false

	# Handle login timeout
	if awaiting_response:
		login_timeout_time += delta
		if login_timeout_time >= login_timeout_duration:
			Log.warn("Login request timed out after %d seconds" % login_timeout_duration, "Auth")
			awaiting_response = false
			login_timeout_time = 0
			show_error("Login request timed out. Server may be offline.")
			login_button.disabled = false
			create_account_button.disabled = false


func _input(event: InputEvent):
	"""Handle Enter key to activate focused button"""
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		var viewport = get_viewport()
		if not viewport:
			return

		var focused = viewport.gui_get_focus_owner()

		# If a button has focus, activate it
		if focused == login_button and not login_button.disabled:
			_on_login_pressed()
			viewport.set_input_as_handled()
		elif focused == create_account_button and not create_account_button.disabled:
			_on_create_account_pressed()
			viewport.set_input_as_handled()
		elif focused == back_button:
			_on_back_pressed()
			viewport.set_input_as_handled()
		# If username or password field has focus, move to login button
		elif focused == username_input or focused == password_input:
			login_button.grab_focus()
			viewport.set_input_as_handled()


func create_ui():
	Log.debug("Creating UI with Kenney RPG styling...", "UI")

	# Background - use desert texture like title screen (stretched to fill)
	var bg_texture = TextureRect.new()
	bg_texture.texture = load("res://assets/sprites/gui/backgrounds/desert.png")
	bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_texture.stretch_mode = TextureRect.STRETCH_SCALE  # Stretch to fill entire screen
	bg_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_texture)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	# Title - styled with RPG aesthetics
	var title = Label.new()
	title.text = "ODYSSEYS REVIVAL"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))  # Gold color
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Login to Continue"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Server Environment Selector
	var env_container = HBoxContainer.new()
	env_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(env_container)

	var env_label = Label.new()
	env_label.text = "Server: "
	env_label.add_theme_font_size_override("font_size", 14)
	env_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	env_container.add_child(env_label)

	server_env_dropdown = OptionButton.new()
	server_env_dropdown.custom_minimum_size = Vector2(180, 35)
	server_env_dropdown.add_item("Local (Development)", ConfigManager.ServerEnvironment.LOCAL)
	server_env_dropdown.add_item("Remote (Odyssey)", ConfigManager.ServerEnvironment.REMOTE)
	# Set current selection from config
	var current_env = ConfigManager.get_server_environment()
	server_env_dropdown.select(current_env)
	server_env_dropdown.item_selected.connect(_on_server_env_changed)
	env_container.add_child(server_env_dropdown)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# RPG Panel Container
	var panel_container = PanelContainer.new()
	var panel_texture = load("res://assets/ui/kenney/rpg-expansion/panel_brown.png")
	if panel_texture:
		var stylebox = StyleBoxTexture.new()
		stylebox.texture = panel_texture
		stylebox.texture_margin_left = 16
		stylebox.texture_margin_top = 16
		stylebox.texture_margin_right = 16
		stylebox.texture_margin_bottom = 16
		panel_container.add_theme_stylebox_override("panel", stylebox)
	else:
		Log.error("Panel texture failed to load!", "UI")
	panel_container.custom_minimum_size = Vector2(450, 0)
	vbox.add_child(panel_container)

	# Inner VBox for panel content
	var panel_vbox = VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 12)
	panel_container.add_child(panel_vbox)

	# Add some padding at the top
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 10)
	panel_vbox.add_child(top_spacer)

	# Username
	var username_label = Label.new()
	username_label.text = "Username:"
	username_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	panel_vbox.add_child(username_label)

	username_input = LineEdit.new()
	username_input.custom_minimum_size = Vector2(0, 45)
	username_input.placeholder_text = "Enter username..."
	username_input.text_changed.connect(_on_input_changed)
	panel_vbox.add_child(username_input)

	# Password
	var password_label = Label.new()
	password_label.text = "Password:"
	password_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	panel_vbox.add_child(password_label)

	password_input = LineEdit.new()
	password_input.custom_minimum_size = Vector2(0, 45)
	password_input.secret = true
	password_input.placeholder_text = "Enter password..."
	password_input.text_submitted.connect(_on_password_submitted)
	password_input.text_changed.connect(_on_input_changed)
	panel_vbox.add_child(password_input)

	# Status label
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.modulate = Color.RED
	status_label.add_theme_font_size_override("font_size", 14)
	panel_vbox.add_child(status_label)

	# Spacer before buttons
	var button_spacer = Control.new()
	button_spacer.custom_minimum_size = Vector2(0, 5)
	panel_vbox.add_child(button_spacer)

	# Styled buttons
	login_button = create_styled_button("Login")
	login_button.disabled = true  # Disabled until connected
	login_button.pressed.connect(_on_login_pressed)
	panel_vbox.add_child(login_button)

	create_account_button = create_styled_button("Create Account")
	create_account_button.disabled = true  # Disabled until connected
	create_account_button.pressed.connect(_on_create_account_pressed)
	panel_vbox.add_child(create_account_button)

	# Back button
	back_button = create_styled_button("Back to Menu")
	back_button.pressed.connect(_on_back_pressed)
	panel_vbox.add_child(back_button)

	# Add some padding at the bottom
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 10)
	panel_vbox.add_child(bottom_spacer)

	# Setup keyboard navigation
	setup_focus_navigation()


func setup_focus_navigation():
	"""Setup keyboard navigation with Tab, arrows, and Enter keys"""
	# Enable focus for all interactive elements
	username_input.focus_mode = Control.FOCUS_ALL
	password_input.focus_mode = Control.FOCUS_ALL
	login_button.focus_mode = Control.FOCUS_ALL
	create_account_button.focus_mode = Control.FOCUS_ALL
	back_button.focus_mode = Control.FOCUS_ALL

	# Setup focus neighbors for arrow key navigation
	# Username -> Password (down)
	username_input.focus_neighbor_bottom = username_input.get_path_to(password_input)

	# Password -> Username (up), Login button (down)
	password_input.focus_neighbor_top = password_input.get_path_to(username_input)
	password_input.focus_neighbor_bottom = password_input.get_path_to(login_button)

	# Login button -> Password (up), Create Account (down)
	login_button.focus_neighbor_top = login_button.get_path_to(password_input)
	login_button.focus_neighbor_bottom = login_button.get_path_to(create_account_button)

	# Create Account button -> Login (up), Back button (down)
	create_account_button.focus_neighbor_top = create_account_button.get_path_to(login_button)
	create_account_button.focus_neighbor_bottom = create_account_button.get_path_to(back_button)

	# Back button -> Create Account (up)
	back_button.focus_neighbor_top = back_button.get_path_to(create_account_button)

	# Set initial focus to username field
	username_input.call_deferred("grab_focus")


func connect_to_server():
	"""Connect to server for authentication"""
	# Load connection settings from config file
	var client_config = ConfigManager.get_client_config()
	var server_address = client_config.get("server_address", "127.0.0.1")
	var server_port = client_config.get("server_port", 9123)

	show_status("Connecting to %s:%d..." % [server_address, server_port], Color.YELLOW)
	Log.info("Connecting to %s:%d" % [server_address, server_port], "Network")

	# Clean up old world client if it exists
	if GameState.world_client:
		Log.debug("Cleaning up old world client connection...", "Network")
		GameState.world_client.close_connection()
		if GameState.world_client.get_parent():
			GameState.world_client.get_parent().remove_child(GameState.world_client)
		GameState.world_client.queue_free()
		GameState.world_client = null

	client = WorldClient.new()
	# Add client to root instead of login screen so it persists across scene changes
	get_tree().root.add_child(client)

	# Store in GameState so other screens can access it
	GameState.world_client = client

	# Connect to signals
	client.connection_changed.connect(_on_connection_changed)
	client.login_response_received.connect(_on_login_response_received)
	client.account_creation_response_received.connect(_on_account_creation_response_received)

	client.connect_to_server(server_address, server_port, "auth_token")


func _on_connection_changed(connected: bool):
	"""Handle connection status"""
	if connected:
		show_status("✅ Connected to server", Color.GREEN)
		Log.info("Connected to server, Peer ID: %d" % (client.peer_id if client else -1), "Network")

		# Validate inputs to enable/disable buttons appropriately
		_on_input_changed("")
	else:
		show_status("❌ Not connected - Server offline?", Color.RED)
		login_button.disabled = true
		create_account_button.disabled = true
		Log.warn("Connection lost!", "Network")


func _on_login_pressed():
	if awaiting_response:
		return

	# Check if cooldown is active
	if login_cooldown_time > 0:
		var seconds_remaining = ceil(login_cooldown_time)
		show_error("Please wait %d seconds before logging in" % seconds_remaining)
		return

	var username = username_input.text.strip_edges() if username_input and username_input.text != null else ""
	var password = password_input.text if password_input and password_input.text != null else ""

	if username == null or username.is_empty():
		show_error("Please enter a username")
		return

	if password == null or password.is_empty():
		show_error("Please enter a password")
		return
	
	# Send login request to server
	show_status("Logging in...", Color.YELLOW)
	awaiting_response = true
	login_timeout_time = 0.0  # Reset timeout timer
	login_button.disabled = true
	create_account_button.disabled = true

	Log.debug("Sending login request for user: %s" % username, "Auth")
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if not server_conn:
		server_conn = get_tree().root.get_node_or_null("ServerWorld/ServerConnection")
	if server_conn:
		server_conn.request_login.rpc_id(1, username, password)
	else:
		Log.error("ServerConnection not found!", "Auth")
		show_error("Connection error - please restart")


func _on_create_account_pressed():
	if awaiting_response:
		return

	var username = username_input.text.strip_edges() if username_input and username_input.text != null else ""
	var password = password_input.text if password_input and password_input.text != null else ""

	if username == null or username.is_empty():
		show_error("Please enter a username")
		return

	if password == null or password.length() < 3:
		show_error("Password must be at least 3 characters")
		return

	# Send create account request to server
	show_status("Creating account...", Color.YELLOW)
	awaiting_response = true
	login_button.disabled = true
	create_account_button.disabled = true

	Log.debug("Creating account for user: %s" % username, "Auth")

	if client and client.is_connected_to_server:
		var server_conn = get_tree().root.get_node_or_null("ServerConnection")
		if not server_conn:
			server_conn = get_tree().root.get_node_or_null("ServerWorld/ServerConnection")
		if server_conn:
			server_conn.request_create_account.rpc_id(1, username, password)
		else:
			Log.error("ServerConnection not found!", "Auth")
			show_error("Connection error - please restart")
	else:
		Log.error("Not connected to server!", "Auth")
		show_error("Not connected to server")


func _on_password_submitted(_text: String):
	_on_login_pressed()


func _on_input_changed(_new_text: String):
	"""Called when username or password input changes"""
	# Check if both fields have content
	var has_username = username_input and username_input.text != null and not username_input.text.strip_edges().is_empty()
	var has_password = password_input and password_input.text != null and not password_input.text.strip_edges().is_empty()
	var inputs_valid = has_username and has_password

	# Enable/disable buttons based on inputs and connection state
	if client and client.is_connected_to_server and inputs_valid and login_cooldown_time <= 0 and not awaiting_response:
		login_button.disabled = false
		create_account_button.disabled = false
	else:
		# Keep disabled if: not connected, missing inputs, cooldown active, or awaiting response
		if not inputs_valid:
			login_button.disabled = true
			create_account_button.disabled = true


func _on_character_selected(character_data: Dictionary):
	"""Character selected, load game with multiplayer"""
	Log.info("Character selected: %s" % character_data.get("name", "Unknown"), "Auth")

	# Store character data globally for the client to use
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		game_state.set("current_username", username_input.text.strip_edges())
		game_state.set("current_character", character_data)

	# Hide screen before transition to prevent visual artifacts
	visible = false

	# Load the multiplayer client scene
	get_tree().change_scene_to_file("res://dev_client.tscn")


func _on_back_pressed():
	if client:
		client.close_connection()
	# Hide screen before transition to prevent visual artifacts
	visible = false
	get_tree().change_scene_to_file("res://source/common/main.tscn")


func _on_server_env_changed(index: int):
	"""Handle server environment dropdown change"""
	Log.info("Server environment changed to: %s" % ConfigManager.get_environment_name(index), "Network")

	# Update the config with new environment
	ConfigManager.set_server_environment(index)

	# Close existing connection if any
	if client:
		client.close_connection()
		if client.get_parent():
			client.get_parent().remove_child(client)
		client.queue_free()
		client = null
		GameState.world_client = null

	# Disable buttons while reconnecting
	login_button.disabled = true
	create_account_button.disabled = true

	# Reconnect to the new server
	connect_to_server()


# ========== SIGNAL HANDLERS FOR SERVER RESPONSES ==========

func _on_account_creation_response_received(success: bool, message: String):
	"""Server responded to account creation"""
	Log.info("Account creation response - Success: %s" % success, "Auth")
	awaiting_response = false
	login_button.disabled = false
	create_account_button.disabled = false

	if success:
		show_success(message + " You can now login.")
	else:
		show_error(message)


func _on_login_response_received(success: bool, message: String, data: Dictionary):
	"""Server responded to login"""
	awaiting_response = false
	login_timeout_time = 0.0  # Reset timeout timer

	if not success:
		# Check if this is a server-side cooldown message
		if message.contains("wait") and message.contains("seconds"):
			# Extract the wait time from the message
			var regex = RegEx.new()
			regex.compile("(\\d+)\\s+seconds?")
			var result = regex.search(message)
			if result:
				var seconds = result.get_string(1).to_int()
				login_cooldown_time = float(seconds)
				Log.debug("Server cooldown active: %d seconds" % seconds, "Auth")
				show_status("Please wait %d seconds before logging in..." % seconds, Color.YELLOW)
			else:
				show_error(message)
		else:
			show_error(message)

		# Keep buttons disabled during cooldown, otherwise enable
		if login_cooldown_time > 0:
			login_button.disabled = true
			create_account_button.disabled = true
		else:
			login_button.disabled = false
			create_account_button.disabled = false
		return

	# Success! Extract data and go to character selection
	var username = data.get("username", "")
	var characters = data.get("characters", [])
	var admin_level = data.get("admin_level", 0)

	Log.info("Login successful for user: %s (%d characters)" % [username, characters.size()], "Auth")

	# Store login data in GameState for character select to use
	GameState.current_username = username
	GameState.select_username = username
	GameState.select_characters = characters
	GameState.admin_level = admin_level
	GameState.client = client

	# Hide this scene before transitioning to prevent visual artifacts
	visible = false

	# Change to character select scene
	get_tree().change_scene_to_file("res://source/client/ui/character_select_screen.tscn")


func show_error(message: String):
	status_label.text = message
	status_label.modulate = Color.RED


func show_success(message: String):
	status_label.text = message
	status_label.modulate = Color.GREEN


func show_status(message: String, color: Color):
	status_label.text = message
	status_label.modulate = color


func create_styled_button(text: String) -> Button:
	"""Creates a professionally styled button using Kenney RPG assets"""
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 50)

	# Try to load Kenney RPG button textures
	var normal_texture = load("res://assets/ui/kenney/rpg-expansion/buttonLong_brown.png")
	var pressed_texture = load("res://assets/ui/kenney/rpg-expansion/buttonLong_brown_pressed.png")

	if normal_texture:
		var stylebox_normal = StyleBoxTexture.new()
		stylebox_normal.texture = normal_texture
		stylebox_normal.texture_margin_left = 16
		stylebox_normal.texture_margin_top = 16
		stylebox_normal.texture_margin_right = 16
		stylebox_normal.texture_margin_bottom = 16
		stylebox_normal.content_margin_left = 10
		stylebox_normal.content_margin_right = 10
		button.add_theme_stylebox_override("normal", stylebox_normal)

		# Use same texture for hover with slight color modulation
		var stylebox_hover = StyleBoxTexture.new()
		stylebox_hover.texture = normal_texture
		stylebox_hover.texture_margin_left = 16
		stylebox_hover.texture_margin_top = 16
		stylebox_hover.texture_margin_right = 16
		stylebox_hover.texture_margin_bottom = 16
		stylebox_hover.content_margin_left = 10
		stylebox_hover.content_margin_right = 10
		stylebox_hover.modulate_color = Color(1.1, 1.1, 1.1)  # Slightly brighter on hover
		button.add_theme_stylebox_override("hover", stylebox_hover)
	else:
		Log.error("Button texture failed to load for: %s" % text, "UI")

	if pressed_texture:
		var stylebox_pressed = StyleBoxTexture.new()
		stylebox_pressed.texture = pressed_texture
		stylebox_pressed.texture_margin_left = 16
		stylebox_pressed.texture_margin_top = 16
		stylebox_pressed.texture_margin_right = 16
		stylebox_pressed.texture_margin_bottom = 16
		stylebox_pressed.content_margin_left = 10
		stylebox_pressed.content_margin_right = 10
		button.add_theme_stylebox_override("pressed", stylebox_pressed)

	# Style button text to match RPG theme
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.8))

	return button
