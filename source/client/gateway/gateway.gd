extends Control


# Helper class
const CredentialsUtils = preload("res://source/common/utils/credentials_utils.gd")
const GatewayApi = preload("res://source/common/network/gateway_api.gd")

@export var world_server: WorldClient

var account_id: int
var account_name: String
var token: int = randi()

var current_world_id: int
var selected_skin: String = ""

var login_btn: Button
var create_account_btn: Button
var exit_btn: Button

@onready var main_panel: PanelContainer = $MainPanel
# @onready var login_panel: PanelContainer = $LoginPanel
# @onready var popup_panel: PanelContainer = $PopupPanel

@onready var http_request: HTTPRequest = $HTTPRequest

func _ready() -> void:
	# The button signals are connected in the .tscn file.
	fix_background_letterboxing()
	style_title_screen()
	setup_keyboard_navigation()

	# Show Admin Dashboard if in Editor
	if OS.has_feature("editor"):
		create_admin_dashboard()


func _input(event: InputEvent):
	"""Handle Enter key to activate focused button"""
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		var viewport = get_viewport()
		if not viewport:
			return

		var focused = viewport.gui_get_focus_owner()

		if focused and focused is Button:
			focused.pressed.emit()
			viewport.set_input_as_handled()


func setup_keyboard_navigation():
	"""Setup keyboard navigation for Gateway buttons"""
	# Defer navigation setup to happen after style_title_screen adds the server button
	call_deferred("_setup_keyboard_navigation_deferred")


func _setup_keyboard_navigation_deferred():
	"""Deferred keyboard navigation setup after all buttons are added"""
	var button_container = main_panel.get_node_or_null("VBoxContainer/VBoxContainer")
	if not button_container:
		print("[Gateway] ERROR: Button container not found")
		return

	# Hide Development Tools button in Production builds
	var guest_button = button_container.get_node_or_null("GuestButton")
	if guest_button:
		if not OS.has_feature("editor") and not OS.is_debug_build():
			guest_button.hide()
			print("[Gateway] Hiding Development Tools for Production Build")

	var buttons = []
	for child in button_container.get_children():
		if child is Button and child.visible:
			buttons.append(child)
			child.focus_mode = Control.FOCUS_ALL
	
	if buttons.size() > 0:
		# Setup linear navigation chain for all buttons
		for i in range(buttons.size()):
			if i > 0:
				buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[i - 1])
			if i < buttons.size() - 1:
				buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[i + 1])

		# Set initial focus to first button (usually Login)
		buttons[0].call_deferred("grab_focus")

		print("[Gateway] OK: Keyboard navigation enabled for %d buttons" % buttons.size())
	else:
		print("[Gateway] ERROR: No visible buttons found")


func fix_background_letterboxing() -> void:
	"""Add a desert-colored background fill to replace black letterboxing"""
	print("[Gateway] 🎨 Fixing background letterboxing...")

	# Find the Background TextureRect
	var background = get_node_or_null("Background")
	if background:
		# Create a ColorRect to fill behind the texture with desert sand color
		var bg_fill = ColorRect.new()
		bg_fill.name = "BackgroundFill"
		bg_fill.color = Color(0.82, 0.65, 0.42, 1.0)  # Sandy desert color
		bg_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_fill.z_index = -1  # Put it behind everything

		# Add it as a child to the root (Gateway node)
		add_child(bg_fill)
		move_child(bg_fill, 0)  # Move to first position (behind Background)

		print("[Gateway] ✅ Desert-colored background fill added")


func style_title_screen() -> void:
	"""Apply Kenney RPG styling to the title screen"""
	print("[Gateway] 🎨 Applying Kenney RPG styling to title screen...")

	# Style the main panel with brown RPG texture
	if main_panel:
		var panel_texture = load("res://assets/ui/kenney/rpg-expansion/panel_brown.png")
		if panel_texture:
			print("[Gateway] ✅ Panel texture loaded")
			var stylebox = StyleBoxTexture.new()
			stylebox.texture = panel_texture
			stylebox.texture_margin_left = 16
			stylebox.texture_margin_top = 16
			stylebox.texture_margin_right = 16
			stylebox.texture_margin_bottom = 16
			stylebox.content_margin_left = 20
			stylebox.content_margin_top = 20
			stylebox.content_margin_right = 20
			stylebox.content_margin_bottom = 20
			main_panel.add_theme_stylebox_override("panel", stylebox)
		else:
			print("[Gateway] ❌ ERROR: Panel texture failed to load")

	# Style the title label with gold color and outline
	var title_label = main_panel.get_node_or_null("VBoxContainer/Label")
	if title_label:
		print("[Gateway] ✅ Styling title label")
		title_label.add_theme_font_size_override("font_size", 42)
		title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))  # Gold
		title_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
		title_label.add_theme_constant_override("outline_size", 3)

	# Style the buttons with Kenney RPG textures
	var button_container = main_panel.get_node_or_null("VBoxContainer/VBoxContainer")
	if button_container:
		for child in button_container.get_children():
			if child is Button:
				style_rpg_button(child)


func style_rpg_button(button: Button) -> void:
	"""Apply Kenney RPG button styling to a button"""
	var normal_texture = load("res://assets/ui/kenney/rpg-expansion/buttonLong_brown.png")
	var pressed_texture = load("res://assets/ui/kenney/rpg-expansion/buttonLong_brown_pressed.png")

	if normal_texture:
		print("[Gateway] ✅ Button texture loaded for: ", button.text)
		var stylebox_normal = StyleBoxTexture.new()
		stylebox_normal.texture = normal_texture
		stylebox_normal.texture_margin_left = 16
		stylebox_normal.texture_margin_top = 16
		stylebox_normal.texture_margin_right = 16
		stylebox_normal.texture_margin_bottom = 16
		stylebox_normal.content_margin_left = 10
		stylebox_normal.content_margin_right = 10
		button.add_theme_stylebox_override("normal", stylebox_normal)

		# Hover state
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



func do_request(
	method: HTTPClient.Method,
	path: String,
	payload: Dictionary,
) -> Dictionary:
	if http_request.get_http_client_status() == HTTPClient.Status.STATUS_CONNECTED:
		return {"error": ""}
	
	var custom_headers: PackedStringArray
	custom_headers.append("Content-Type: application/json")
	
	var error: Error = http_request.request(
		path,
		custom_headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if error != OK:
		push_error("An error occurred in the HTTP request.")
		return {ok=false, error="request_error", code=error}
	
	var args: Array = await http_request.request_completed
	var result: int = args[0]
	if result != OK:
		print("ERROR?, TIMEOUT?")
		return {"error": 1}
	
	var response_code: int = args[1]
	var headers: PackedStringArray = args[2]
	var body: PackedByteArray = args[3]
	
	var data = JSON.parse_string(body.get_string_from_ascii())
	if data is Dictionary:
		return data
	return {"error": 1}


func _on_login_button_pressed() -> void:
	# Redirect to new server-based login screen
	print("Redirecting to login screen...")
	SceneNavigation.goto_login()


func _on_login_login_button_pressed() -> void:
	# ... (Keep existing login logic for now as it uses GatewayAPI, planned for Phase 2) ...
	var account_name_edit: LineEdit = $LoginPanel/VBoxContainer/VBoxContainer/VBoxContainer/LineEdit
	var password_edit: LineEdit = $LoginPanel/VBoxContainer/VBoxContainer/VBoxContainer2/LineEdit
	
	var username: String = account_name_edit.text
	var password: String = password_edit.text
	
	var login_button: Button = $LoginPanel/VBoxContainer/VBoxContainer/LoginButton
	login_button.disabled = true
	if (
		CredentialsUtils.validate_username(username).code != CredentialsUtils.UsernameError.OK
		or CredentialsUtils.validate_password(password).code != CredentialsUtils.UsernameError.OK
	):
		login_button.disabled = false
		return

	var d: Dictionary = await do_request(
		HTTPClient.Method.METHOD_POST,
		GatewayApi.login(),
		{"u": username, "p": password,
		GatewayApi.KEY_TOKEN_ID: token}
	)
	if d.has("error"):
		login_button.disabled = false
		return
	main_panel.hide()
	$LoginPanel.hide()
	populate_worlds(d.get("w", {}))
	
	fill_connection_info(d["a"]["name"], d["a"]["id"])
	$WorldSelection.show()

func _on_guest_button_pressed() -> void:
	show_development_tools()

func show_development_tools():
	# Hide main panel and show development tools
	if main_panel:
		main_panel.hide()

	# Create development tools panel if it doesn't exist
	if not has_node("DevelopmentTools"):
		create_development_tools_panel()

	$DevelopmentTools.show()

func create_development_tools_panel():
	# Create the development tools panel
	var dev_panel = Control.new()
	dev_panel.name = "DevelopmentTools"
	dev_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dev_panel)

	# Create a CenterContainer to properly center the panel
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dev_panel.add_child(center_container)

	# Create background panel
	var panel_container = PanelContainer.new()
	panel_container.custom_minimum_size = Vector2(380, 520)
	center_container.add_child(panel_container)

	# Apply Kenney RPG panel styling
	var panel_texture = load("res://assets/ui/kenney/rpg-expansion/panel_brown.png")
	if panel_texture:
		var stylebox = StyleBoxTexture.new()
		stylebox.texture = panel_texture
		stylebox.texture_margin_left = 16
		stylebox.texture_margin_top = 16
		stylebox.texture_margin_right = 16
		stylebox.texture_margin_bottom = 16
		stylebox.content_margin_left = 20
		stylebox.content_margin_top = 20
		stylebox.content_margin_right = 20
		stylebox.content_margin_bottom = 20
		panel_container.add_theme_stylebox_override("panel", stylebox)

	# Create vertical layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_container.add_child(vbox)

	# Title label with gold styling
	var title_label = Label.new()
	title_label.text = "Development Tools"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))  # Gold
	title_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
	title_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title_label)

	# Add a small spacer after title
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Sprite Creator button
	var sprite_creator_button = Button.new()
	sprite_creator_button.text = "Sprite Creator"
	sprite_creator_button.custom_minimum_size = Vector2(300, 49)
	sprite_creator_button.pressed.connect(_on_sprite_creator_pressed)
	style_rpg_button(sprite_creator_button)
	vbox.add_child(sprite_creator_button)

	# Tiled Map Editor button
	var tiled_button = Button.new()
	tiled_button.text = "Map Editor"
	tiled_button.custom_minimum_size = Vector2(300, 49)
	tiled_button.pressed.connect(_on_tiled_editor_pressed)
	style_rpg_button(tiled_button)
	vbox.add_child(tiled_button)

	# Art Studio button
	var art_studio_button = Button.new()
	art_studio_button.text = "Art Studio"
	art_studio_button.custom_minimum_size = Vector2(300, 49)
	art_studio_button.pressed.connect(_on_art_studio_pressed)
	style_rpg_button(art_studio_button)
	vbox.add_child(art_studio_button)

	# Map Linker button (new tool for connecting maps)
	var map_linker_button = Button.new()
	map_linker_button.text = "Map Linker"
	map_linker_button.custom_minimum_size = Vector2(300, 49)
	map_linker_button.pressed.connect(_on_map_linker_pressed)
	style_rpg_button(map_linker_button)
	vbox.add_child(map_linker_button)

	# Push to Remote Server button
	var push_remote_button = Button.new()
	push_remote_button.text = "Push to Remote Server"
	push_remote_button.custom_minimum_size = Vector2(300, 49)
	push_remote_button.pressed.connect(_on_push_remote_pressed)
	style_rpg_button(push_remote_button)
	vbox.add_child(push_remote_button)

	# Add spacer before back button
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(spacer2)

	# Back button
	var back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(300, 49)
	back_button.pressed.connect(_on_dev_tools_back_pressed)
	style_rpg_button(back_button)
	vbox.add_child(back_button)

func create_admin_dashboard():
	var admin_container = VBoxContainer.new()
	# Move to Center Right to avoid bottom clipping
	admin_container.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	admin_container.offset_left = -220   # Width of container + margin
	admin_container.offset_top = -125    # Center vertically (half of approx height)
	admin_container.offset_right = -20   # Margin from right edge
	admin_container.offset_bottom = 125  # Height
	admin_container.alignment = BoxContainer.ALIGNMENT_CENTER
	admin_container.add_theme_constant_override("separation", 10)
	add_child(admin_container)
	
	# 1. Push Player Client (Production)
	var push_player_btn = Button.new()
	push_player_btn.text = "Push Player Client"
	push_player_btn.custom_minimum_size = Vector2(180, 40)
	push_player_btn.add_theme_font_size_override("font_size", 12)
	push_player_btn.pressed.connect(_on_push_player_client_pressed)
	style_rpg_button(push_player_btn)
	admin_container.add_child(push_player_btn)

	# 2. Push Dev Client
	var push_dev_btn = Button.new()
	push_dev_btn.text = "Push Dev Client"
	push_dev_btn.custom_minimum_size = Vector2(180, 40)
	push_dev_btn.add_theme_font_size_override("font_size", 12)
	push_dev_btn.pressed.connect(_on_push_dev_client_pressed)
	style_rpg_button(push_dev_btn)
	admin_container.add_child(push_dev_btn)

	# 3. Push Server Update
	var push_server_btn = Button.new()
	push_server_btn.text = "Push Server Update"
	push_server_btn.custom_minimum_size = Vector2(180, 40)
	push_server_btn.add_theme_font_size_override("font_size", 12)
	push_server_btn.pressed.connect(_on_push_server_pressed)
	style_rpg_button(push_server_btn)
	admin_container.add_child(push_server_btn)

	# 3. Start Local Server - Launch separate Godot instance
	var start_local_btn = Button.new()
	start_local_btn.text = "Start Local Server"
	start_local_btn.custom_minimum_size = Vector2(180, 40)
	start_local_btn.add_theme_font_size_override("font_size", 12)
	start_local_btn.pressed.connect(_on_start_local_server_pressed)
	style_rpg_button(start_local_btn)
	admin_container.add_child(start_local_btn)

	# 4. Copy Player Link
	var copy_player_link_btn = Button.new()
	copy_player_link_btn.text = "Copy Player Link"
	copy_player_link_btn.custom_minimum_size = Vector2(180, 40)
	copy_player_link_btn.add_theme_font_size_override("font_size", 12)
	copy_player_link_btn.pressed.connect(_on_copy_player_link_pressed)
	style_rpg_button(copy_player_link_btn)
	admin_container.add_child(copy_player_link_btn)

	# 5. Copy Dev Link
	var copy_dev_link_btn = Button.new()
	copy_dev_link_btn.text = "Copy Dev Link"
	copy_dev_link_btn.custom_minimum_size = Vector2(180, 40)
	copy_dev_link_btn.add_theme_font_size_override("font_size", 12)
	copy_dev_link_btn.pressed.connect(_on_copy_dev_link_pressed)
	style_rpg_button(copy_dev_link_btn)
	admin_container.add_child(copy_dev_link_btn)

func _on_push_player_client_pressed():
	print("Pushing Player Client...")
	var project_path = ProjectSettings.globalize_path("res://")
	DeveloperToolsService.deploy_client_production(project_path)

func _on_push_dev_client_pressed():
	print("Pushing Dev Client...")
	var project_path = ProjectSettings.globalize_path("res://")
	DeveloperToolsService.deploy_client_dev(project_path)

func _on_push_server_pressed():
	print("Pushing Server Update...")
	var project_path = ProjectSettings.globalize_path("res://")
	DeveloperToolsService.deploy_to_remote(project_path)

func _on_start_local_server_pressed():
	print("Launching Local Server...")
	var godot_path = OS.get_executable_path()
	var project_path = ProjectSettings.globalize_path("res://")
	var args = ["--path", project_path, "res://source/server/server_world.tscn"]
	OS.create_process(godot_path, args)

func _on_copy_player_link_pressed():
	DisplayServer.clipboard_set("https://pub-bfb251fbb7f04473b6eb939aba7ccdfc.r2.dev/installers/OdysseyRevival.zip")
	print("Player Link Copied!")

func _on_copy_dev_link_pressed():
	DisplayServer.clipboard_set("https://pub-bfb251fbb7f04473b6eb939aba7ccdfc.r2.dev/installers/OdysseyDevClient.zip")
	print("Dev Link Copied!")

func _on_art_studio_pressed():
	DeveloperToolsService.launch_pixi_editor(ProjectSettings.globalize_path("res://"))

func _on_sprite_creator_pressed():
	print("Launching Odyssey Sprite Creator...")
	SceneNavigation.goto_sprite_maker()

func _on_tiled_editor_pressed():
	DeveloperToolsService.launch_tiled_editor(ProjectSettings.globalize_path("res://"))

func _on_map_linker_pressed():
	print("Launching Map Linker tool...")
	SceneNavigation.goto_map_linker()

func _on_push_remote_pressed():
	DeveloperToolsService.deploy_to_remote(ProjectSettings.globalize_path("res://"))

func _on_settings_pressed():
	print("Opening Server Settings...")
	SceneNavigation.goto_settings()

func _on_dev_tools_back_pressed():
	print("DEBUG: Returning from development tools. Showing main menu.")
	if has_node("DevelopmentTools"): $DevelopmentTools.hide()
	if has_node("EditorSelection"): $EditorSelection.hide()
	if has_node("MapEditorInstance"): $MapEditorInstance.hide()
	if has_node("GameMap"): $GameMap.hide()

	if main_panel:
		main_panel.show()

func load_test_character_scene():
	# Load Odyssey test scene with proper sprites and animation
	print("Loading Odyssey test scene...")
	SceneNavigation.goto_test_odyssey()


func _on_world_selected(world_id: int) -> void:
	$WorldSelection.hide()
	# popup_panel.display_waiting_popup()
	var d: Dictionary = await do_request(
		HTTPClient.Method.METHOD_POST,
		GatewayApi.world_characters(),
		{GatewayApi.KEY_WORLD_ID: world_id,
		GatewayApi.KEY_ACCOUNT_ID: account_id,
		GatewayApi.KEY_ACCOUNT_USERNAME: account_name,
		GatewayApi.KEY_TOKEN_ID: token}
	)
	if d.has("error"):
		$WorldSelection.show()
		return
	var container: HBoxContainer = $CharacterSelection/VBoxContainer/HBoxContainer
	for child: Node in container.get_children():
		child.queue_free()
	for character_id: String in d.get("data", {}):
		var new_button: Button = Button.new()
		new_button.custom_minimum_size = Vector2(150, 250)
		new_button.text = "%s\nClass: %s\nLevel: %d" % [
			d["data"][character_id]["name"],
			d["data"][character_id]["class"],
			d["data"][character_id]["level"],
		]
		new_button.pressed.connect(_on_character_selected.bind(world_id, character_id.to_int()))
		container.add_child(new_button)
	await get_tree().process_frame
	var child_count: int = container.get_child_count()
	while child_count < 3:
		var new_button: Button = Button.new()
		new_button.custom_minimum_size = Vector2(150, 250)
		new_button.text = "Create New Character"
		container.add_child(new_button)
		new_button.pressed.connect(_on_character_selected.bind(world_id, -1))
		child_count += 1
	# popup_panel.hide()
	$CharacterSelection.show()


func _on_character_selected(world_id: int, character_id: int) -> void:
	current_world_id = world_id
	if character_id == -1:
		$CharacterSelection.hide()
		var animated_sprite_2d: AnimatedSprite2D = $CharacterCreation/VBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer2/CenterContainer/Control/AnimatedSprite2D
		# DISABLED FOR CLIENT-FIRST DEVELOPMENT: animated_sprite_2d.play(&"run")
		var v_box_container: GridContainer = $CharacterCreation/VBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer
		for button: Button in v_box_container.get_children():
			button.pressed.connect(_on_skin_selected.bind(button))

		$CharacterCreation.show()
		return

	$CharacterSelection.hide()

	var d: Dictionary = await do_request(
		HTTPClient.Method.METHOD_POST,
		"http://127.0.0.1:8088/v1/world/enter",
		{"w-id": world_id, "c-id": character_id}
	)
	if d.has("error"):
		return
	world_server.connect_to_server(d["adress"], d["port"], d["token"])
	queue_free.call_deferred()

func _on_skin_selected(button: Button):
	selected_skin = button.text.to_lower()
	# animated_sprite_2d logic disabled for now


func _on_create_character_button_pressed() -> void:
	var username_edit: LineEdit = $CharacterCreation/VBoxContainer/VBoxContainer/HBoxContainer2/LineEdit

	var create_button: Button = $CharacterCreation/VBoxContainer/VBoxContainer/CreateButton
	create_button.disabled = true
	
	var d: Dictionary = await do_request(
		HTTPClient.Method.METHOD_POST,
		GatewayApi.world_create_char(),
		{
			GatewayApi.KEY_TOKEN_ID: token,
			"data": {
				"name": username_edit.text,
				"class": selected_skin,
				
			},
			GatewayApi.KEY_ACCOUNT_USERNAME: account_name,
			GatewayApi.KEY_WORLD_ID: current_world_id
		}
	)
	if d.has("error"):
		return
	world_server.connect_to_server(
		d["data"]["address"],
		d["data"]["port"],
		d["data"]["auth-token"]
	)
	queue_free.call_deferred()


func create_account() -> void:
	var name_edit: LineEdit = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer/LineEdit
	var password_edit: LineEdit = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer2/LineEdit
	var password_repeat_edit: LineEdit = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer3/LineEdit

	if password_edit.text != password_repeat_edit.text:
		# await popup_panel.confirm_message("Passwords don't match")
		return
	
	var result: Dictionary
	result = CredentialsUtils.validate_username(name_edit.text)
	if result.code != CredentialsUtils.UsernameError.OK:
		# await popup_panel.confirm_message("Username:\n" + result.message)
		return
	result = CredentialsUtils.validate_password(password_edit.text)
	if result.code != CredentialsUtils.UsernameError.OK:
		# await popup_panel.confirm_message("Password:\n" + result.message)
		return
	
	main_panel.hide()
	$CreateAccountPanel.hide()
	# popup_panel.display_waiting_popup()

	var d: Dictionary = await do_request(
		HTTPClient.Method.METHOD_POST,
		GatewayApi.account_create(),
		{"u": name_edit.text, "p": password_edit.text,
		GatewayApi.KEY_TOKEN_ID: token}
	)
	if d.has("error"):
		# popup_panel.hide()
		$CreateAccountPanel.show()
		return
	fill_connection_info(d["a"]["name"], d["a"]["id"])
	populate_worlds(d.get("w", {}))
	# popup_panel.hide()
	$WorldSelection.show()


func _on_create_account_button_pressed() -> void:
	# Redirect to new login screen (same as Development Client button)
	print("Redirecting to login screen...")
	SceneNavigation.goto_login()


func populate_worlds(world_info: Dictionary) -> void:
	var container: HBoxContainer = $WorldSelection/VBoxContainer/HBoxContainer
	for child: Node in container.get_children():
			child.queue_free()
	for world_id: String in world_info:
		var new_button: Button = Button.new()
		new_button.custom_minimum_size = Vector2(150, 250)
		new_button.clip_text = true
		new_button.text = "%s\n\n%s" % [
			world_info[world_id].get("name", "name"),
			" \n".join(str(world_info[world_id]["info"]).split(", "))
		]
		new_button.pressed.connect(_on_world_selected.bind(world_id.to_int()))
		container.add_child(new_button)


func fill_connection_info(_account_name: String, _account_id: int) -> void:
	account_name = _account_name
	account_id = _account_id
	$ConnectionInfo.text = "Accout-name: %s\nAccount-ID: %s" % [
		account_name,
		account_id
	]