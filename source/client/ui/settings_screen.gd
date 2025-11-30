extends Control
## Settings Screen - Server Configuration
## Simple paste-and-save interface for server connection

var config_input: TextEdit
var current_config_label: Label
var status_label: Label


func _ready():
	create_ui()


func create_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "⚙️ SERVER SETTINGS"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Configure server connection"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Current configuration display
	var current_panel = PanelContainer.new()
	vbox.add_child(current_panel)

	var current_vbox = VBoxContainer.new()
	current_vbox.add_theme_constant_override("separation", 10)
	current_panel.add_child(current_vbox)

	var current_title = Label.new()
	current_title.text = "Current Server Configuration:"
	current_title.add_theme_font_size_override("font_size", 16)
	current_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_vbox.add_child(current_title)

	current_config_label = Label.new()
	var config = ConfigManager.get_client_config()
	current_config_label.text = "Address: %s\nPort: %d" % [config.get("server_address", "127.0.0.1"), config.get("server_port", 8043)]
	current_config_label.add_theme_font_size_override("font_size", 18)
	current_config_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_config_label.modulate = Color.CYAN
	current_vbox.add_child(current_config_label)

	# Instructions
	var instructions = Label.new()
	instructions.text = "📋 Copy config from server, paste below, and click Save"
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.modulate = Color.YELLOW
	vbox.add_child(instructions)

	# Paste area
	var paste_label = Label.new()
	paste_label.text = "Paste Server Config JSON:"
	paste_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(paste_label)

	config_input = TextEdit.new()
	config_input.custom_minimum_size = Vector2(600, 150)
	config_input.placeholder_text = '{\n\t"server_address": "192.168.1.100",\n\t"server_port": 8043\n}'
	vbox.add_child(config_input)

	# Status label
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(status_label)

	# Buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 15)
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_hbox)

	var save_button = Button.new()
	save_button.text = "💾 Save Settings"
	save_button.custom_minimum_size = Vector2(200, 60)
	save_button.pressed.connect(_on_save_pressed)
	button_hbox.add_child(save_button)

	var back_button = Button.new()
	back_button.text = "Back to Menu"
	back_button.custom_minimum_size = Vector2(200, 60)
	back_button.pressed.connect(_on_back_pressed)
	button_hbox.add_child(back_button)


func _on_save_pressed():
	var pasted_text = config_input.text.strip_edges()

	if pasted_text.is_empty():
		show_status("❌ Please paste server config JSON", Color.RED)
		return

	# Parse JSON
	var json = JSON.new()
	var parse_result = json.parse(pasted_text)

	if parse_result != OK:
		show_status("❌ Invalid JSON format! Copy exactly from server.", Color.RED)
		print("[Settings] JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return

	var config_data = json.data

	# Validate required fields
	if not config_data.has("server_address") or not config_data.has("server_port"):
		show_status("❌ Missing required fields: server_address and server_port", Color.RED)
		return

	# Save the new config
	var new_config = {
		"server_address": config_data["server_address"],
		"server_port": config_data["server_port"]
	}

	if ConfigManager.save_client_config(new_config):
		# Update the display
		current_config_label.text = "Address: %s\nPort: %d" % [new_config["server_address"], new_config["server_port"]]
		show_status("✅ Settings saved successfully!", Color.GREEN)
		print("[Settings] Saved new server config: %s:%d" % [new_config["server_address"], new_config["server_port"]])

		# Clear the text input
		config_input.text = ""
	else:
		show_status("❌ Failed to save config file", Color.RED)


func _on_back_pressed():
	# Hide screen before transition to prevent visual artifacts
	visible = false
	get_tree().change_scene_to_file("res://source/common/main.tscn")


func show_status(message: String, color: Color):
	status_label.text = message
	status_label.modulate = color
