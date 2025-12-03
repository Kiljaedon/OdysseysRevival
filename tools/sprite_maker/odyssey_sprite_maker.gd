extends Control
## Sprite Maker - Character/NPC editor with sprite selection and stats
## Coordinates: SpriteMakerGrid, SpriteMakerStats, SpriteMakerIO components

# UI References
@onready var grid_container: GridContainer = $UI/SpriteGridPanel/Content/SpriteGrid/GridContainer
@onready var scroll_container: ScrollContainer = $UI/SpriteGridPanel/Content/SpriteGrid
@onready var character_name: LineEdit = $UI/CharacterPanel/ScrollContainer/Content/PreviewRow/NameSection/CharacterName
@onready var current_frames_label: Label = $UI/CharacterPanel/ScrollContainer/Content/PreviewRow/PreviewSection/CurrentFrames
@onready var animation_preview: TextureRect = $UI/CharacterPanel/ScrollContainer/Content/PreviewRow/PreviewSection/PreviewBackground/AnimationPreview
@onready var class_list: OptionButton = $UI/CharacterPanel/ScrollContainer/Content/ClassList
@onready var npc_list: OptionButton = $UI/CharacterPanel/ScrollContainer/Content/NPCList
@onready var delete_class_button: Button = $UI/CharacterPanel/ScrollContainer/Content/DeleteClassButton
@onready var delete_npc_button: Button = $UI/CharacterPanel/ScrollContainer/Content/DeleteNPCButton
@onready var status_label: Label = $UI/StatusLabel
@onready var page_label: Label = $UI/SpriteGridPanel/Content/PageNavigation/PageLabel
@onready var class_button: Button = $UI/CharacterPanel/ScrollContainer/Content/PreviewRow/NameSection/TypeButtons/SetClassTypeButton
@onready var npc_button: Button = $UI/CharacterPanel/ScrollContainer/Content/PreviewRow/NameSection/TypeButtons/SetNPCTypeButton
@onready var class_list_label: Label = $UI/CharacterPanel/ScrollContainer/Content/ClassListLabel
@onready var npc_list_label: Label = $UI/CharacterPanel/ScrollContainer/Content/NPCListLabel
@onready var control_panel: VBoxContainer = $UI/StatsPanel/Content
@onready var current_role_label: Label = $UI/CharacterPanel/ScrollContainer/Content/CurrentRoleLabel
@onready var role_dropdown: OptionButton = $UI/CharacterPanel/ScrollContainer/Content/RoleDropdown
@onready var role_description: Label = $UI/CharacterPanel/ScrollContainer/Content/RoleDescription
@onready var add_role_button: Button = $UI/CharacterPanel/ScrollContainer/Content/AddRoleButton
@onready var save_button: Button = $UI/CharacterPanel/ScrollContainer/Content/PreviewRow/NameSection/SaveCharacterButton

# Components
var sprite_grid: SpriteMakerGrid
var stats_panel: SpriteMakerStats
var character_io: SpriteMakerIO

# State
var character_data: Dictionary = {}
var current_type: String = "class"
var current_animation: String = ""
var upload_button: Button = null
var is_initialized: bool = false

var animation_names: Array = [
	"walk_up_1", "walk_up_2", "attack_up",
	"walk_down_1", "walk_down_2", "attack_down",
	"walk_left_1", "walk_left_2", "attack_left",
	"walk_right_1", "walk_right_2", "attack_right"
]


func _ready():
	print("=== ODYSSEY SPRITE MAKER (V3-Refactored) STARTED ===")

	# Initialize character data
	character_data = {"name": "", "animations": {}}
	for anim in animation_names:
		character_data.animations[anim] = []

	# Admin check - bypass for local development
	print("[SpriteMaker] Admin level: %d" % GameState.admin_level)
	var is_local = ConfigManager.is_local_server() if ConfigManager else true
	if GameState.admin_level < 1 and not is_local:
		print("[SpriteMaker] ACCESS DENIED - admin_level < 1 and not local")
		_show_access_denied()
		return
	if is_local and GameState.admin_level < 1:
		print("[SpriteMaker] Local dev mode - bypassing admin check")

	# Initialize components
	_init_components()

	# Create refresh button
	_create_refresh_button()

	# Populate combat role dropdown
	_init_combat_role_dropdown()

	# Set initial button states
	update_type_buttons()

	# Create upload button
	_create_upload_button()

	# Auto-populate lists
	call_deferred("populate_class_list")
	call_deferred("populate_npc_list")

	set_process(true)
	print("=== SPRITE MAKER READY ===")


func _init_components():
	"""Initialize all modular components"""
	print("[SpriteMaker] Initializing components...")
	print("[SpriteMaker] grid_container=%s, scroll_container=%s" % [grid_container, scroll_container])
	print("[SpriteMaker] control_panel=%s" % control_panel)

	# Sprite Grid
	sprite_grid = SpriteMakerGrid.new()
	print("[SpriteMaker] Created SpriteMakerGrid instance")
	if sprite_grid.initialize(grid_container, scroll_container):
		sprite_grid.sprite_row_selected.connect(_on_sprite_row_selected)
		sprite_grid.status_changed.connect(_on_component_status)
		print("[SpriteMaker] Grid component initialized OK")
	else:
		push_error("[SpriteMaker] Grid component FAILED to initialize")

	# Stats Panel
	stats_panel = SpriteMakerStats.new()
	print("[SpriteMaker] Created SpriteMakerStats instance")
	if stats_panel.initialize(control_panel, current_role_label, role_dropdown, role_description, add_role_button):
		stats_panel.set_type(current_type)
		print("[SpriteMaker] Stats component initialized OK")
	else:
		push_error("[SpriteMaker] Stats component FAILED to initialize")

	# Character IO
	character_io = SpriteMakerIO.new()
	print("[SpriteMaker] Created SpriteMakerIO instance")
	if character_io.initialize(stats_panel, sprite_grid):
		character_io.character_saved.connect(_on_character_saved)
		character_io.character_loaded.connect(_on_character_loaded)
		character_io.status_changed.connect(_on_component_status)
		character_io.error_occurred.connect(_on_component_error)
		print("[SpriteMaker] IO component initialized OK")
	else:
		push_error("[SpriteMaker] IO component FAILED to initialize")


func _process(_delta):
	if not visible:
		return

	# Skip if components not ready
	if not sprite_grid:
		return

	# First-time initialization
	if not is_initialized:
		is_initialized = true
		sprite_grid.load_character_sprites()
		status_label.text = "Loading sprites..."

	# Lazy load visible sprites
	sprite_grid.load_visible_sprites()


# === Signal Handlers ===

func _on_sprite_row_selected(row: int, sprite_data: Array):
	"""Handle sprite row selection from grid component"""
	# Auto-assign all 12 sprites to animations
	for anim in character_data.animations:
		character_data.animations[anim].clear()

	for i in range(min(12, sprite_data.size())):
		var data = sprite_data[i]
		var anim_name = animation_names[i]
		var texture = sprite_grid.get_sprite_texture_from_data(data)
		character_data.animations[anim_name].append({
			"atlas_index": data.atlas_index,
			"row": data.row,
			"col": data.col,
			"texture": texture
		})

	update_character_preview()
	status_label.text = "Auto-assigned 12 sprites from row %d!" % row


func _on_character_saved(char_name: String, char_type: String):
	"""Handle character save completion"""
	if char_type == "class":
		populate_class_list()
	else:
		populate_npc_list()


func _on_character_loaded(data: Dictionary, loaded_type: String):
	"""Handle character load completion"""
	character_data = data
	current_type = loaded_type
	update_type_buttons()
	update_character_preview()
	_update_frames_display()


func _on_component_status(message: String):
	"""Handle status messages from components"""
	if status_label:
		status_label.text = message


func _on_component_error(message: String):
	"""Handle error messages from components"""
	if status_label:
		status_label.text = "ERROR: " + message
		status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))


# === Button Handlers ===

func _on_save_character_pressed():
	var char_name = character_name.text.strip_edges()
	character_data.name = char_name
	character_io.save_character(char_name, current_type, character_data)


func _on_upload_button_pressed():
	var char_name = character_name.text.strip_edges()
	character_io.upload_character(char_name, current_type, character_data)


func _on_class_list_selected(index: int):
	if index == 0:
		return
	var cls_name = class_list.get_item_text(index)
	character_name.text = cls_name
	current_type = "class"
	stats_panel.set_type(current_type)
	update_type_buttons()
	var load_path = "res://characters/classes/%s.json" % cls_name
	character_io.load_character(load_path, cls_name)


func _on_npc_list_selected(index: int):
	if index == 0:
		return
	var npc_name = npc_list.get_item_text(index)
	character_name.text = npc_name
	current_type = "npc"
	stats_panel.set_type(current_type)
	update_type_buttons()
	var load_path = "res://characters/npcs/%s.json" % npc_name
	character_io.load_character(load_path, npc_name)


func _on_delete_class_pressed():
	var selected_index = class_list.selected
	if selected_index <= 0:
		status_label.text = "No class selected to delete"
		return
	var cls_name = class_list.get_item_text(selected_index)
	if character_io.delete_character(cls_name, "class"):
		populate_class_list()


func _on_delete_npc_pressed():
	var selected_index = npc_list.selected
	if selected_index <= 0:
		status_label.text = "No NPC selected to delete"
		return
	var npc_name = npc_list.get_item_text(selected_index)
	if character_io.delete_character(npc_name, "npc"):
		populate_npc_list()


func _on_set_class_type_pressed():
	current_type = "class"
	stats_panel.set_type(current_type)
	update_type_buttons()
	status_label.text = "Viewing: CLASSES"


func _on_set_npc_type_pressed():
	current_type = "npc"
	stats_panel.set_type(current_type)
	update_type_buttons()
	status_label.text = "Viewing: NPCs"


func _on_next_page_pressed():
	sprite_grid.next_page()
	_update_page_indicator()


func _on_prev_page_pressed():
	sprite_grid.prev_page()
	_update_page_indicator()


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://source/common/main.tscn")


# === UI Updates ===

func update_type_buttons():
	"""Update CLASS/NPC button states and dropdown visibility"""
	if current_type == "class":
		class_button.button_pressed = true
		npc_button.button_pressed = false
		class_button.modulate = Color(0.5, 1.0, 0.5)
		npc_button.modulate = Color.WHITE
		class_list.visible = true
		npc_list.visible = false
		delete_class_button.visible = true
		delete_npc_button.visible = false
		class_list_label.visible = true
		npc_list_label.visible = false
	else:
		class_button.button_pressed = false
		npc_button.button_pressed = true
		class_button.modulate = Color.WHITE
		npc_button.modulate = Color(0.5, 1.0, 0.5)
		class_list.visible = false
		npc_list.visible = true
		delete_class_button.visible = false
		delete_npc_button.visible = true
		class_list_label.visible = false
		npc_list_label.visible = true


func update_character_preview():
	"""Update preview with walk_down_1 sprite"""
	if character_data.animations.has("walk_down_1") and character_data.animations["walk_down_1"].size() > 0:
		var frame = character_data.animations["walk_down_1"][0]
		if frame.has("texture"):
			animation_preview.texture = frame.texture
			current_frames_label.text = character_data.get("name", "")
	else:
		animation_preview.texture = null
		current_frames_label.text = "No Preview"


func _update_frames_display():
	if current_animation.is_empty():
		current_frames_label.text = "Frames: 0"
		return
	var frame_count = character_data.animations.get(current_animation, []).size()
	current_frames_label.text = "Frames: %d" % frame_count


func _update_page_indicator():
	var info = sprite_grid.get_page_info()
	if page_label:
		page_label.text = "Page %d/%d" % [info.current, info.total]
	if status_label:
		status_label.text = "Rows %d-%d of %d" % [info.start_row, info.end_row, info.total_rows]


# === List Population ===

func populate_class_list():
	if not class_list:
		return
	class_list.clear()
	class_list.add_item("-- Select Class --", -1)
	class_list.select(0)
	_populate_list_from_dir("res://characters/classes/", class_list)


func populate_npc_list():
	if not npc_list:
		return
	npc_list.clear()
	npc_list.add_item("-- Select NPC --", -1)
	npc_list.select(0)
	_populate_list_from_dir("res://characters/npcs/", npc_list)


func _populate_list_from_dir(dir_path: String, option_btn: OptionButton):
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			files.append(file_name.replace(".json", ""))
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for i in range(files.size()):
		option_btn.add_item(files[i], i + 1)


# === Initialization Helpers ===

func _show_access_denied():
	"""Show access denied screen for non-admins"""
	var error_panel = PanelContainer.new()
	error_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(error_panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	error_panel.add_child(vbox)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(spacer1)

	var title = Label.new()
	title.text = "ACCESS DENIED"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var msg = Label.new()
	msg.text = "Sprite Maker requires admin privileges.\nPlease log in with an admin account."
	msg.add_theme_font_size_override("font_size", 24)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(spacer2)

	var back_btn = Button.new()
	back_btn.text = "Back to Menu"
	back_btn.custom_minimum_size = Vector2(200, 50)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://source/common/main.tscn"))
	vbox.add_child(back_btn)


func _create_refresh_button():
	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(func():
		populate_class_list()
		populate_npc_list()
	)
	var title_hbox = $UI/TitleBar/HBoxContainer
	if title_hbox:
		title_hbox.add_child(refresh_btn)
		title_hbox.move_child(refresh_btn, 1)


func _create_upload_button():
	if not save_button:
		return
	var btn_container = save_button.get_parent()
	upload_button = Button.new()
	upload_button.pressed.connect(_on_upload_button_pressed)
	btn_container.add_child(upload_button)
	_update_upload_button_text()


func _update_upload_button_text():
	if not upload_button:
		return
	if ConfigManager.is_local_server():
		upload_button.text = "Upload to Local Server"
		upload_button.disabled = false
	else:
		upload_button.text = "Upload (Local Only)"
		upload_button.disabled = true


func _init_combat_role_dropdown():
	if role_dropdown:
		role_dropdown.add_item("Melee - 120 range, standard flanking, 100% speed", 0)
		role_dropdown.add_item("Ranged - 350 range, projectiles, 115% speed", 1)
		role_dropdown.add_item("Caster - 280 range, projectiles, 125% damage", 2)
		role_dropdown.add_item("Hybrid - 180 range, 105% speed, enhanced flanking", 3)
