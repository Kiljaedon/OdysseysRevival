extends Control
## Character Creator Screen for Odysseys Revival
## Allows players to create new characters with name, class, element and stat selection

signal character_created(character_data: Dictionary)

var username: String = ""
var client: Node = null
var awaiting_response: bool = false

# Available classes
var available_classes: Array = ["Warrior", "Mage", "Cleric", "Rogue", "Commander"]
var selected_class: String = "Warrior"

# Available elements
var available_elements: Array = ["None", "Fire", "Water", "Earth", "Wind"]
var selected_element: String = "None"

# Bonus points to allocate on top of class base stats
const BONUS_POINTS: int = 20
var bonus_points_remaining: int = BONUS_POINTS

# Class base stats loaded from JSON
var class_base_stats: Dictionary = {
	"Warrior": {"STR": 18, "DEX": 12, "INT": 8, "VIT": 15, "WIS": 8, "CHA": 10},
	"Mage": {"STR": 7, "DEX": 10, "INT": 18, "VIT": 8, "WIS": 15, "CHA": 10},
	"Cleric": {"STR": 8, "DEX": 10, "INT": 14, "VIT": 12, "WIS": 18, "CHA": 11},
	"Rogue": {"STR": 13, "DEX": 18, "INT": 10, "VIT": 10, "WIS": 8, "CHA": 12},
	"Commander": {"STR": 14, "DEX": 12, "INT": 10, "VIT": 13, "WIS": 10, "CHA": 18}
}

# Current stat values (base + bonus allocated)
var stat_values: Dictionary = {}
var stat_spinboxes: Dictionary = {}
var bonus_points_label: Label
var total_points_label: Label
var derived_stats_label: Label

# UI References
var name_input: LineEdit
var class_buttons: Dictionary = {}
var element_option: OptionButton
var create_button: Button
var back_button: Button
var status_label: Label
var class_description_label: Label
var sprite_preview: TextureRect

# Class descriptions
var class_descriptions: Dictionary = {
	"Warrior": "A mighty fighter specializing in physical combat and defense.",
	"Mage": "A wielder of elemental magic with powerful offensive spells.",
	"Cleric": "A healer who supports allies and channels divine power.",
	"Rogue": "A swift fighter who excels at agility and precision strikes.",
	"Commander": "A tactical leader who inspires and strengthens allies."
}

# Element colors for visual feedback
var element_colors: Dictionary = {
	"None": Color(0.9, 0.85, 0.7),
	"Fire": Color(1.0, 0.4, 0.2),
	"Water": Color(0.3, 0.6, 1.0),
	"Earth": Color(0.6, 0.4, 0.2),
	"Wind": Color(0.5, 0.9, 0.5)
}


func _ready():
	# Register in group for easy lookup (avoids fragile script path searches)
	add_to_group("character_creator")

	load_class_stats_from_json()
	create_ui()
	apply_class_base_stats("Warrior")
	update_class_selection("Warrior")
	update_stats_display()


func load_class_stats_from_json():
	"""Load base stats from class JSON files"""
	for cls_name in available_classes:
		var json_path = "res://characters/classes/%s.json" % cls_name
		if not FileAccess.file_exists(json_path):
			continue

		var file = FileAccess.open(json_path, FileAccess.READ)
		if not file:
			continue

		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			if data.has("base_stats"):
				var base = data.base_stats
				class_base_stats[cls_name] = {
					"STR": int(base.get("str", 10)),
					"DEX": int(base.get("dex", 10)),
					"INT": int(base.get("int", 10)),
					"VIT": int(base.get("vit", 10)),
					"WIS": int(base.get("wis", 10)),
					"CHA": int(base.get("cha", 10))
				}
				print("[CharCreator] Loaded %s stats: %s" % [cls_name, class_base_stats[cls_name]])
		file.close()


func apply_class_base_stats(cls_name: String):
	"""Apply base stats for the selected class, reset bonus points"""
	var base = class_base_stats.get(cls_name, class_base_stats["Warrior"])

	# Copy base stats as current stats
	stat_values = base.duplicate()

	# Reset bonus points
	bonus_points_remaining = BONUS_POINTS

	# Update spinbox minimums and values
	for stat_name in stat_spinboxes:
		var spinbox = stat_spinboxes[stat_name]
		spinbox.min_value = base[stat_name]  # Can't go below class base
		spinbox.max_value = base[stat_name] + BONUS_POINTS  # Can add up to all bonus points
		spinbox.value = base[stat_name]  # Start at base


func create_ui():
	# Desert-colored background fill (matches Kenney UI theme)
	var bg_fill = ColorRect.new()
	bg_fill.color = Color(0.76, 0.6, 0.42)  # Sandy desert color matching the background
	bg_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_fill.z_index = -2
	add_child(bg_fill)

	# Background texture
	var bg_texture = TextureRect.new()
	bg_texture.texture = load("res://assets/sprites/gui/backgrounds/desert.png")
	bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_texture.z_index = -1
	add_child(bg_texture)

	# Main margin container for padding
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	# Center container - fills the screen and centers content
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	center.add_child(main_vbox)

	# Title
	var title = Label.new()
	title.text = "CREATE CHARACTER"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	# Main content panel - use smaller size that fits better
	var content_panel = PanelContainer.new()
	content_panel.custom_minimum_size = Vector2(780, 480)
	style_panel(content_panel)
	main_vbox.add_child(content_panel)

	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 15)
	content_panel.add_child(content_hbox)

	# Left column - Name, Class, Element, Preview
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	left_vbox.custom_minimum_size = Vector2(360, 0)
	content_hbox.add_child(left_vbox)

	# Character Name Section
	create_name_section(left_vbox)

	# Class Selection Section
	create_class_section(left_vbox)

	# Element Selection Section
	create_element_section(left_vbox)

	# Preview section
	create_preview_section(left_vbox)

	# Right column - Stats
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_vbox.custom_minimum_size = Vector2(340, 0)
	content_hbox.add_child(right_vbox)

	# Stats Section
	create_stats_section(right_vbox)

	# Status label at bottom of main panel
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(status_label)

	# Buttons row
	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 15)
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_hbox)

	back_button = create_styled_button("Back")
	back_button.custom_minimum_size = Vector2(130, 45)
	back_button.pressed.connect(_on_back_pressed)
	button_hbox.add_child(back_button)

	create_button = create_styled_button("Create Character")
	create_button.custom_minimum_size = Vector2(180, 45)
	create_button.pressed.connect(_on_create_pressed)
	button_hbox.add_child(create_button)


func create_name_section(parent: Control):
	var name_section = VBoxContainer.new()
	name_section.add_theme_constant_override("separation", 4)
	parent.add_child(name_section)

	var name_label = Label.new()
	name_label.text = "Character Name:"
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	name_section.add_child(name_label)

	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter character name..."
	name_input.custom_minimum_size = Vector2(320, 32)
	name_input.max_length = 20
	name_input.add_theme_font_size_override("font_size", 14)
	name_section.add_child(name_input)


func create_class_section(parent: Control):
	var class_section = VBoxContainer.new()
	class_section.add_theme_constant_override("separation", 6)
	parent.add_child(class_section)

	var class_title = Label.new()
	class_title.text = "Select Class:"
	class_title.add_theme_font_size_override("font_size", 16)
	class_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	class_section.add_child(class_title)

	# Class buttons in two rows
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	class_section.add_child(row1)

	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	class_section.add_child(row2)

	for i in range(available_classes.size()):
		var cls_name = available_classes[i]
		var btn = create_styled_button(cls_name)
		btn.custom_minimum_size = Vector2(100, 36)
		btn.pressed.connect(_on_class_selected.bind(cls_name))
		if i < 3:
			row1.add_child(btn)
		else:
			row2.add_child(btn)
		class_buttons[cls_name] = btn


func create_element_section(parent: Control):
	var element_section = HBoxContainer.new()
	element_section.add_theme_constant_override("separation", 8)
	parent.add_child(element_section)

	var element_label = Label.new()
	element_label.text = "Element:"
	element_label.add_theme_font_size_override("font_size", 16)
	element_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	element_section.add_child(element_label)

	element_option = OptionButton.new()
	element_option.custom_minimum_size = Vector2(110, 30)
	element_option.add_theme_font_size_override("font_size", 14)
	for i in range(available_elements.size()):
		element_option.add_item(available_elements[i], i)
	element_option.item_selected.connect(_on_element_selected)
	element_section.add_child(element_option)


func create_preview_section(parent: Control):
	var preview_section = HBoxContainer.new()
	preview_section.add_theme_constant_override("separation", 10)
	parent.add_child(preview_section)

	# Sprite preview
	var sprite_container = PanelContainer.new()
	sprite_container.custom_minimum_size = Vector2(64, 64)
	preview_section.add_child(sprite_container)

	sprite_preview = TextureRect.new()
	sprite_preview.custom_minimum_size = Vector2(48, 48)
	sprite_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	sprite_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_container.add_child(sprite_preview)

	# Class description
	class_description_label = Label.new()
	class_description_label.custom_minimum_size = Vector2(250, 60)
	class_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	class_description_label.add_theme_font_size_override("font_size", 13)
	class_description_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	preview_section.add_child(class_description_label)


func create_stats_section(parent: Control):
	var stats_section = VBoxContainer.new()
	stats_section.add_theme_constant_override("separation", 5)
	parent.add_child(stats_section)

	var stats_title = Label.new()
	stats_title.text = "Allocate Bonus Stats:"
	stats_title.add_theme_font_size_override("font_size", 16)
	stats_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	stats_section.add_child(stats_title)

	# Bonus points remaining display
	var bonus_section = HBoxContainer.new()
	bonus_section.add_theme_constant_override("separation", 8)
	stats_section.add_child(bonus_section)

	var bonus_title = Label.new()
	bonus_title.text = "Bonus Points:"
	bonus_title.add_theme_font_size_override("font_size", 14)
	bonus_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	bonus_section.add_child(bonus_title)

	bonus_points_label = Label.new()
	bonus_points_label.text = "%d / %d" % [BONUS_POINTS, BONUS_POINTS]
	bonus_points_label.add_theme_font_size_override("font_size", 14)
	bonus_points_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	bonus_section.add_child(bonus_points_label)

	# Stat descriptions
	var stat_info: Dictionary = {
		"STR": "Strength - Physical damage",
		"DEX": "Dexterity - Agility and accuracy",
		"INT": "Intelligence - Magic power",
		"VIT": "Vitality - Health",
		"WIS": "Wisdom - Magic defense",
		"CHA": "Charisma - Leadership"
	}

	# Create stat rows
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 15)
	stats_grid.add_theme_constant_override("v_separation", 4)
	stats_section.add_child(stats_grid)

	var stat_order = ["STR", "DEX", "INT", "VIT", "WIS", "CHA"]
	for stat_name in stat_order:
		var stat_row = HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 5)
		stats_grid.add_child(stat_row)

		var stat_label = Label.new()
		stat_label.text = stat_name + ":"
		stat_label.custom_minimum_size = Vector2(40, 0)
		stat_label.add_theme_font_size_override("font_size", 14)
		stat_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		stat_label.tooltip_text = stat_info[stat_name]
		stat_row.add_child(stat_label)

		var spinbox = SpinBox.new()
		spinbox.min_value = 5
		spinbox.max_value = 40
		spinbox.value = 10
		spinbox.step = 1
		spinbox.custom_minimum_size = Vector2(65, 26)
		spinbox.value_changed.connect(_on_stat_changed.bind(stat_name))
		stat_row.add_child(spinbox)
		stat_spinboxes[stat_name] = spinbox

	# Total points display
	var total_section = HBoxContainer.new()
	total_section.add_theme_constant_override("separation", 8)
	stats_section.add_child(total_section)

	var total_label_title = Label.new()
	total_label_title.text = "Total Stats:"
	total_label_title.add_theme_font_size_override("font_size", 14)
	total_label_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	total_section.add_child(total_label_title)

	total_points_label = Label.new()
	total_points_label.text = "0"
	total_points_label.add_theme_font_size_override("font_size", 14)
	total_section.add_child(total_points_label)

	# Derived stats section
	var derived_title = Label.new()
	derived_title.text = "Derived Stats:"
	derived_title.add_theme_font_size_override("font_size", 14)
	derived_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	stats_section.add_child(derived_title)

	derived_stats_label = Label.new()
	derived_stats_label.text = "HP: 100  |  MP: 50  |  EP: 60"
	derived_stats_label.add_theme_font_size_override("font_size", 13)
	derived_stats_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	stats_section.add_child(derived_stats_label)

	# Randomize button
	var random_btn = create_styled_button("Randomize Bonus")
	random_btn.custom_minimum_size = Vector2(150, 32)
	random_btn.tooltip_text = "Randomly distribute the 20 bonus points"
	random_btn.pressed.connect(_on_randomize_stats)
	stats_section.add_child(random_btn)


func style_panel(panel: PanelContainer):
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
		panel.add_theme_stylebox_override("panel", stylebox)


func update_class_selection(cls_name: String):
	selected_class = cls_name

	# Update button visual states
	for btn_class in class_buttons:
		var btn = class_buttons[btn_class]
		if btn_class == cls_name:
			btn.modulate = Color(1.2, 1.2, 0.8)  # Highlight selected
		else:
			btn.modulate = Color(1, 1, 1)

	# Update description
	class_description_label.text = class_descriptions.get(cls_name, "")

	# Update sprite preview
	load_class_sprite(cls_name.to_lower())

	# Apply class base stats (only if spinboxes exist - not during initial UI creation)
	if stat_spinboxes.size() > 0:
		apply_class_base_stats(cls_name)
		update_stats_display()


func load_class_sprite(char_class: String):
	var class_json_path = "res://characters/classes/%s.json" % char_class
	if not FileAccess.file_exists(class_json_path):
		return

	var file = FileAccess.open(class_json_path, FileAccess.READ)
	if not file:
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		return

	var class_data = json.data
	if not class_data.has("animations") or not class_data.animations.has("walk_down_1"):
		return

	var anim_data = class_data.animations.walk_down_1
	if anim_data.size() == 0:
		return

	var sprite_path = ""
	if anim_data[0].has("sprite_file"):
		sprite_path = "res://character_sprites/" + anim_data[0].sprite_file
	elif anim_data[0].has("row") and anim_data[0].has("col"):
		var row = anim_data[0].row
		var col = anim_data[0].col
		var index = row * 12 + col
		sprite_path = "res://character_sprites/char_%04d_r%03d_c%02d.png" % [index, row, col]

	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		sprite_preview.texture = load(sprite_path)


func update_stats_display():
	# Calculate total and bonus points used
	var total = 0
	var bonus_used = 0
	var base = class_base_stats.get(selected_class, class_base_stats["Warrior"])

	for stat_name in stat_values:
		total += stat_values[stat_name]
		bonus_used += stat_values[stat_name] - base.get(stat_name, 10)

	bonus_points_remaining = BONUS_POINTS - bonus_used

	# Update bonus points label
	if bonus_points_label:
		bonus_points_label.text = "%d / %d" % [bonus_points_remaining, BONUS_POINTS]
		if bonus_points_remaining > 0:
			bonus_points_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))  # Green - points left
		elif bonus_points_remaining == 0:
			bonus_points_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))  # Normal - all used
		else:
			bonus_points_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Red - over limit

	# Update total stats label
	if total_points_label:
		total_points_label.text = "%d" % total
		total_points_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))

	# Calculate derived stats
	var hp = calculate_hp()
	var mp = calculate_mp()
	var ep = calculate_ep()
	if derived_stats_label:
		derived_stats_label.text = "HP: %d  |  MP: %d  |  EP: %d" % [hp, mp, ep]

	# Update spinbox max values based on remaining points
	for stat_name in stat_spinboxes:
		var spinbox = stat_spinboxes[stat_name]
		var base_val = base.get(stat_name, 10)
		var current_bonus_in_stat = stat_values[stat_name] - base_val
		# Max is current value + remaining points (can use all remaining)
		spinbox.max_value = stat_values[stat_name] + bonus_points_remaining


func calculate_hp() -> int:
	# HP = 50 + VIT*2.5 + STR*1
	return int(50 + stat_values["VIT"] * 2.5 + stat_values["STR"] * 1)


func calculate_mp() -> int:
	# MP = 50 + INT*5 + WIS*2
	return int(50 + stat_values["INT"] * 5 + stat_values["WIS"] * 2)


func calculate_ep() -> int:
	# EP = 30 + DEX*3
	return int(30 + stat_values["DEX"] * 3)


func _on_class_selected(cls_name: String):
	update_class_selection(cls_name)


func _on_element_selected(index: int):
	selected_element = available_elements[index]
	# Apply element color to the option button
	element_option.modulate = element_colors.get(selected_element, Color.WHITE)


func _on_stat_changed(value: float, stat_name: String):
	stat_values[stat_name] = int(value)
	update_stats_display()


func _on_randomize_stats():
	# Distribute all bonus points randomly among stats
	var base = class_base_stats.get(selected_class, class_base_stats["Warrior"])
	var stats_list = ["STR", "DEX", "INT", "VIT", "WIS", "CHA"]

	# Start with base values
	for stat in stats_list:
		stat_values[stat] = base[stat]

	# Distribute all bonus points randomly
	var remaining = BONUS_POINTS
	while remaining > 0:
		var stat = stats_list[randi() % stats_list.size()]
		stat_values[stat] += 1
		remaining -= 1

	# Update spinboxes
	for stat_name in stat_spinboxes:
		stat_spinboxes[stat_name].set_value_no_signal(stat_values[stat_name])

	update_stats_display()


func _on_create_pressed():
	if awaiting_response:
		return

	var char_name = name_input.text.strip_edges()

	# Validate name
	if char_name.is_empty():
		show_error("Please enter a character name")
		return

	if char_name.length() < 3:
		show_error("Name must be at least 3 characters")
		return

	if char_name.length() > 20:
		show_error("Name must be 20 characters or less")
		return

	# Check for valid characters (alphanumeric and spaces only)
	var valid_name = true
	for c in char_name:
		if not (c.is_valid_identifier() or c == " "):
			valid_name = false
			break

	if not valid_name:
		show_error("Name can only contain letters, numbers, and spaces")
		return

	# Validate bonus points (must not exceed the allowed amount)
	if bonus_points_remaining < 0:
		show_error("You've allocated too many bonus points!")
		return

	# Send to server
	awaiting_response = true
	status_label.text = "Creating character..."
	status_label.modulate = Color.YELLOW
	create_button.disabled = true

	var character_data = {
		"name": char_name,
		"class_name": selected_class,
		"element": selected_element,
		"stats": stat_values.duplicate()
	}

	print("[CharCreator] Creating character: %s (%s, %s)" % [char_name, selected_class, selected_element])
	print("[CharCreator] Stats: %s" % stat_values)

	# Send RPC to server
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if server_conn:
		server_conn.rpc_id(1, "request_create_character", username, character_data)
		_start_creation_timeout(char_name)
	else:
		show_error("Not connected to server")
		awaiting_response = false
		create_button.disabled = false


func _start_creation_timeout(char_name: String):
	await get_tree().create_timer(5.0).timeout
	if awaiting_response:
		print("[CharCreator] Server timeout - character creation may not be implemented on server")
		show_error("Server did not respond. Try again or use offline mode.")
		awaiting_response = false
		create_button.disabled = false


func _on_back_pressed():
	return_to_character_select()


func return_to_character_select():
	GameState.select_username = username
	if client:
		GameState.world_client = client
	visible = false
	get_tree().change_scene_to_file("res://source/client/ui/character_select_screen.tscn")


func show_error(message: String):
	status_label.text = message
	status_label.modulate = Color.RED


func show_success(message: String):
	status_label.text = message
	status_label.modulate = Color.GREEN


## Server response handler - called by ServerConnection RPC
func character_creation_response(success: bool, message: String, character_id):
	print("[CharCreator] Server response: success=%s, msg=%s, id=%s" % [success, message, character_id])
	awaiting_response = false
	create_button.disabled = false

	if success:
		show_success("Character created!")

		# Build character data for the signal
		var new_character = {
			"name": name_input.text.strip_edges(),
			"class_name": selected_class,
			"element": selected_element,
			"level": 1,
			"stats": stat_values.duplicate()
		}

		# Handle character_id which may be String or Dictionary
		if character_id is Dictionary:
			new_character.merge(character_id)
		else:
			new_character["character_id"] = str(character_id)

		# Add to GameState's character list
		if GameState.select_characters == null:
			GameState.select_characters = []
		GameState.select_characters.append(new_character)

		character_created.emit(new_character)

		await get_tree().create_timer(1.0).timeout
		return_to_character_select()
	else:
		show_error(message if message else "Failed to create character")


func create_styled_button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)

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

		var stylebox_hover = StyleBoxTexture.new()
		stylebox_hover.texture = normal_texture
		stylebox_hover.texture_margin_left = 16
		stylebox_hover.texture_margin_top = 16
		stylebox_hover.texture_margin_right = 16
		stylebox_hover.texture_margin_bottom = 16
		stylebox_hover.content_margin_left = 10
		stylebox_hover.content_margin_right = 10
		stylebox_hover.modulate_color = Color(1.1, 1.1, 1.1)
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

	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.8))

	return button
