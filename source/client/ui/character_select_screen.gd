extends Control
## Character Selection Screen for Odysseys Revival
## Shows all characters for an account, allows create/delete/select

signal character_selected(character_data: Dictionary)

var username: String = ""
var characters: Array = []
var initial_characters: Array = []  # Characters loaded from server
var client: WorldClient  # Server connection passed from login screen
var awaiting_response: bool = false
var deleting_character_id: String = ""  # Track which character is being deleted

var character_list: VBoxContainer
var create_button: Button
var status_label: Label


func _ready():
	# Register in group for easy lookup (avoids fragile script path searches)
	add_to_group("character_select_screen")

	create_ui()

	# Move ServerConnection to /root so RPCs can find it at the same path as server
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if not server_conn:
		server_conn = get_node_or_null("ServerConnection")
		if server_conn:
			remove_child(server_conn)
			get_tree().root.add_child(server_conn)
		else:
			print("[CLIENT] ERROR: ServerConnection not found in scene or root!")

	# Get client from GameState (login screen stored it there)
	if not client:
		client = GameState.world_client

	if not client:
		print("[CLIENT] ERROR: No world_client reference from GameState!")

	# Load username and characters from GameState
	if not username or username.is_empty():
		username = GameState.select_username

	if not characters or characters.is_empty():
		characters = GameState.select_characters
		if not characters or characters.is_empty():
			print("[CLIENT] ERROR: Characters array is empty after loading from GameState!")

	# Only clear username - DO NOT clear select_characters (character_creator needs it to append)
	GameState.select_username = ""

	# Display characters (only once, deferred to ensure UI is ready)
	call_deferred("display_characters")


func setup(p_username: String):
	username = p_username
	load_characters()


func create_ui():
	print("[CharacterSelect] 🎨 Creating UI with Kenney RPG styling...")

	# Background - use desert texture like other screens
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

	# Title - styled with gold color and outline
	var title = Label.new()
	title.text = "SELECT CHARACTER"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))  # Gold
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Character list container with scroll
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 400)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	character_list = VBoxContainer.new()
	character_list.add_theme_constant_override("separation", 15)
	character_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(character_list)
	
	# Status label
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.modulate = Color.RED
	vbox.add_child(status_label)
	
	# Buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 10)
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_hbox)
	
	create_button = create_styled_button("Create New Character")
	create_button.custom_minimum_size = Vector2(250, 60)
	create_button.pressed.connect(_on_create_character_pressed)
	button_hbox.add_child(create_button)

	var logout_button = create_styled_button("Logout")
	logout_button.custom_minimum_size = Vector2(150, 60)
	logout_button.pressed.connect(_on_logout_pressed)
	button_hbox.add_child(logout_button)


func load_characters():
	# Characters already loaded from server
	display_characters()


func display_characters():
	"""Display the characters list"""
	# Clear existing list
	if character_list:
		for child in character_list.get_children():
			child.queue_free()

	if characters == null or characters.is_empty():
		print("[CharSelect] No characters found")
		var empty_label = Label.new()
		empty_label.text = "No characters yet. Create one to begin your journey!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		character_list.add_child(empty_label)
		status_label.text = ""
		return

	# Display each character
	print("[CharSelect] Displaying %d characters" % characters.size())
	for character in characters:
		var char_panel = create_character_panel(character)
		character_list.add_child(char_panel)

	# Disable create button if at max characters
	create_button.disabled = (characters.size() >= 6)
	if create_button.disabled:
		status_label.text = "Maximum 6 characters per account"
		status_label.modulate = Color.YELLOW
	else:
		status_label.text = ""


func create_character_panel(character: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 100)

	# Style panel with Kenney brown RPG texture
	var panel_texture = load("res://assets/ui/kenney/rpg-expansion/panel_brown.png")
	if panel_texture:
		var stylebox = StyleBoxTexture.new()
		stylebox.texture = panel_texture
		stylebox.texture_margin_left = 16
		stylebox.texture_margin_top = 16
		stylebox.texture_margin_right = 16
		stylebox.texture_margin_bottom = 16
		stylebox.content_margin_left = 15
		stylebox.content_margin_top = 15
		stylebox.content_margin_right = 15
		stylebox.content_margin_bottom = 15
		panel.add_theme_stylebox_override("panel", stylebox)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)

	# Left side: Sprite + Character info together
	var left_hbox = HBoxContainer.new()
	left_hbox.add_theme_constant_override("separation", 15)
	left_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_hbox)

	# Character sprite preview (to the left of name) - with error handling
	var sprite_container = CenterContainer.new()
	sprite_container.custom_minimum_size = Vector2(80, 80)
	left_hbox.add_child(sprite_container)

	var sprite_display = TextureRect.new()
	sprite_display.custom_minimum_size = Vector2(64, 64)
	sprite_display.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	sprite_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Load character sprite - wrapped in error handling so panel still creates if sprite fails
	var char_class = character.get("class_name", "cleric").to_lower()
	var sprite_loaded = false

	# Try to load sprite, but don't break if it fails
	var class_json_path = "res://characters/classes/%s.json" % char_class
	if FileAccess.file_exists(class_json_path):
		var file = FileAccess.open(class_json_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()

			var json = JSON.new()
			if json.parse(json_string) == OK:
				var class_data = json.data
				if class_data.has("animations") and class_data.animations.has("walk_down_1"):
					var anim_data = class_data.animations.walk_down_1
					if anim_data.size() > 0:
						var sprite_path = ""

						if anim_data[0].has("sprite_file"):
							sprite_path = "res://character_sprites/" + anim_data[0].sprite_file
						elif anim_data[0].has("row") and anim_data[0].has("col"):
							var row = anim_data[0].row
							var col = anim_data[0].col
							var index = row * 12 + col
							sprite_path = "res://character_sprites/char_%04d_r%03d_c%02d.png" % [index, row, col]

						if sprite_path != "" and ResourceLoader.exists(sprite_path):
							sprite_display.texture = load(sprite_path)
							sprite_loaded = true

	sprite_container.add_child(sprite_display)

	# Character info (next to sprite)
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 5)
	left_hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = character.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))  # Gold
	info_vbox.add_child(name_label)

	var class_label = Label.new()
	var char_level = int(character.get("level", 1))  # Convert to integer to remove decimals
	class_label.text = "Class: " + char_class.capitalize() + " | Level: " + str(char_level)
	class_label.add_theme_font_size_override("font_size", 16)
	class_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	info_vbox.add_child(class_label)

	# Buttons (right side)
	var button_vbox = VBoxContainer.new()
	button_vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(button_vbox)

	var select_button = create_styled_button("Enter World")
	select_button.custom_minimum_size = Vector2(150, 35)
	select_button.pressed.connect(_on_character_selected.bind(character))
	button_vbox.add_child(select_button)

	var delete_button = create_styled_button("Delete")
	delete_button.custom_minimum_size = Vector2(150, 35)
	delete_button.pressed.connect(_on_delete_character.bind(character))
	button_vbox.add_child(delete_button)

	return panel


func _on_character_selected(character: Dictionary):
	# Safety check: Only allow character selection if we ARE the character select screen
	if self.name != "CharacterSelectScreen":
		print("[CharSelect] ERROR: _on_character_selected called but we're not CharacterSelectScreen! Ignoring.")
		return

	print("[CharSelect] Character selected: ", character.name)

	# Store data in GameState for dev_client to use
	GameState.current_username = username
	GameState.current_character = character

	# Pass the client connection to GameState so dev_client can reuse it
	if client:
		if client.get_parent() == self:
			remove_child(client)
		GameState.client = client

	# Hide this scene before transitioning to prevent visual artifacts
	visible = false

	# Load dev_client scene (the actual game)
	get_tree().change_scene_to_file("res://dev_client.tscn")

	character_selected.emit(character)


func _on_delete_character(character: Dictionary):
	if awaiting_response:
		return

	print("[CharSelect] Deleting character: ", character.name)

	status_label.text = "Deleting character..."
	status_label.modulate = Color.YELLOW
	awaiting_response = true
	deleting_character_id = character.character_id

	# Request deletion from server via ServerConnection RPC
	if client:
		var server_conn = get_tree().root.get_node_or_null("ServerConnection")
		if server_conn:
			server_conn.rpc_id(1, "request_delete_character", username, character.character_id)
		else:
			print("[CharSelect] ERROR: ServerConnection not found!")
			status_label.text = "Error: Connection lost"
			status_label.modulate = Color.RED
			awaiting_response = false
			deleting_character_id = ""
	else:
		print("[CharSelect] ERROR: No client connection!")
		status_label.text = "Error: Not connected"
		status_label.modulate = Color.RED
		awaiting_response = false
		deleting_character_id = ""


func _on_create_character_pressed():
	# Switch to character creation scene
	var creator_scene = load("res://character_creator.tscn")
	var creator = creator_scene.instantiate()

	# Set username and client BEFORE adding to tree
	creator.username = username

	# Pass client reference (client is at /root, not a child of this scene)
	if client:
		creator.client = client

	creator.character_created.connect(_on_character_created)

	get_tree().root.add_child(creator)
	queue_free()


func _on_character_created(new_character: Dictionary):
	# Character was created, add to list
	characters.append(new_character)
	display_characters()
	status_label.text = "Character created!"
	status_label.modulate = Color.GREEN


func _on_logout_pressed():
	print("[CharSelect] Logout requested")
	GameState.set("last_logout_time", Time.get_ticks_msec() / 1000.0)

	# Close connection and clean up WorldClient
	if client:
		client.close_connection()
		# Clean up client from /root before transitioning
		if client.get_parent() == get_tree().root:
			get_tree().root.remove_child(client)
		client.queue_free()
		GameState.world_client = null
		GameState.client = null

	# Clean up ServerConnection on logout (not during scene transitions!)
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if server_conn:
		print("[CharSelect] Cleaning up ServerConnection on logout")
		get_tree().root.remove_child(server_conn)
		server_conn.queue_free()

	visible = false
	get_tree().change_scene_to_file("res://source/client/ui/login_screen.tscn")


## ========== SERVER RESPONSE HANDLERS ==========

@rpc
func character_deletion_response(success: bool, message: String):
	"""Server responded to character deletion"""
	print("[CharSelect] Character deletion: success=%s" % success)
	awaiting_response = false

	if success:
		# Remove character from list
		var char_to_remove = null
		for character in characters:
			if character.get("character_id") == deleting_character_id:
				char_to_remove = character
				break

		if char_to_remove:
			characters.erase(char_to_remove)
		else:
			print("[CharSelect] ERROR: Could not find character with ID: ", deleting_character_id)

		deleting_character_id = ""
		display_characters()
		status_label.text = "Character deleted"
		status_label.modulate = Color.GREEN
	else:
		status_label.text = "Error: " + message
		status_label.modulate = Color.RED
		deleting_character_id = ""


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
