extends Control

@onready var grid_container: GridContainer = $UI/SpriteGridPanel/Content/SpriteGrid/GridContainer
@onready var scroll_container: ScrollContainer = $UI/SpriteGridPanel/Content/SpriteGrid
@onready var character_name: LineEdit = $UI/CharacterPanel/Content/PreviewRow/NameSection/CharacterName
@onready var current_frames_label: Label = $UI/CharacterPanel/Content/PreviewRow/PreviewSection/CurrentFrames
@onready var animation_preview: TextureRect = $UI/CharacterPanel/Content/PreviewRow/PreviewSection/PreviewBackground/AnimationPreview
@onready var class_list: OptionButton = $UI/CharacterPanel/Content/ClassList
@onready var npc_list: OptionButton = $UI/CharacterPanel/Content/NPCList
@onready var delete_class_button: Button = $UI/CharacterPanel/Content/DeleteClassButton
@onready var delete_npc_button: Button = $UI/CharacterPanel/Content/DeleteNPCButton
@onready var status_label: Label = $UI/StatusLabel
@onready var page_label: Label = $UI/SpriteGridPanel/Content/PageNavigation/PageLabel
@onready var class_button: Button = $UI/CharacterPanel/Content/PreviewRow/NameSection/TypeButtons/SetClassTypeButton
@onready var npc_button: Button = $UI/CharacterPanel/Content/PreviewRow/NameSection/TypeButtons/SetNPCTypeButton
@onready var class_list_label: Label = $UI/CharacterPanel/Content/ClassListLabel
@onready var npc_list_label: Label = $UI/CharacterPanel/Content/NPCListLabel
@onready var control_panel: VBoxContainer = $UI/StatsPanel/Content
@onready var current_role_label: Label = $UI/CombatRolePanel/Content/CurrentRoleLabel
@onready var role_dropdown: OptionButton = $UI/CombatRolePanel/Content/RoleDropdown
@onready var role_description: Label = $UI/CombatRolePanel/Content/RoleDescription
@onready var add_role_button: Button = $UI/CombatRolePanel/Content/AddRoleButton
@onready var save_button: Button = $UI/CharacterPanel/Content/PreviewRow/NameSection/SaveCharacterButton

# Stat display labels (created programmatically)
var stat_display_container: VBoxContainer = null
var element_option: OptionButton = null
var ai_option: OptionButton = null
var min_level_spin: SpinBox = null
var max_level_spin: SpinBox = null
var xp_spin: SpinBox = null
var gold_spin: SpinBox = null
var selected_combat_role: String = ""  # Track currently selected role
var level_spin: SpinBox = null
var str_spin: SpinBox = null
var dex_spin: SpinBox = null
var int_spin: SpinBox = null
var vit_spin: SpinBox = null
var wis_spin: SpinBox = null
var cha_spin: SpinBox = null
var total_label: Label = null
var hp_label: Label = null
var mp_label: Label = null
var ep_label: Label = null
var hp_spin: SpinBox = null
var mp_spin: SpinBox = null
var ep_spin: SpinBox = null
var edit_mode_button: Button = null
var is_edit_mode: bool = false
var manual_hp: int = -1  # -1 means use calculated value
var manual_mp: int = -1
var manual_ep: int = -1
var desc_text: TextEdit = null
var upload_button: Button = null

var sprite_regions: Array[Dictionary] = []  # List of sprite regions (row, col, atlas_index)
var atlas_textures: Array[Texture2D] = []  # Loaded atlas sheets
var sprite_cache: Dictionary = {}  # Cache for created AtlasTextures
var loaded_buttons: Dictionary = {}  # Track which buttons have loaded textures
var current_animation: String = ""
var character_data: Dictionary = {}
var current_type: String = "class"  # "class" or "npc"

# Row selection for sprite assignment
var selection_start: int = -1
var selected_sprites: Array = []  # Changed from Array[int] to Array (stores Dictionaries now)

# Pagination
var current_page: int = 0
var rows_per_page: int = 50
var total_pages: int = 0

const CHARACTER_ROWS = 644  # All rows - includes characters and tiles (user can choose what to use)
const SPRITE_SIZE = 32  # Each sprite is 32x32 pixels
const COLS_PER_ROW = 12  # 12 sprites per row
const ROWS_PER_ATLAS = 512  # sprites_part1 = rows 0-511, sprites_part2 = rows 512-643
const PREVIEW_COL = 3  # Column 3 = walk_down_1 (down-facing sprite)

# BLACK LINE FIX: Crop edges to remove black border artifacts
# Set to 0 to disable cropping (sprites will be full 32x32)
# Set to 1 to crop 1px from all edges (sprites will be 30x30 from center of 32x32 region)
const CROP_EDGE = 0  # Disabled - user reported clipping at bottom

var animation_names: Array = [
	"walk_up_1", "walk_up_2", "attack_up",
	"walk_down_1", "walk_down_2", "attack_down",
	"walk_left_1", "walk_left_2", "attack_left",
	"walk_right_1", "walk_right_2", "attack_right"
]

var is_initialized: bool = false

func _ready():
	print("=== ODYSSEY SPRITE MAKER (V2) STARTED ===")

	# Initialize character data immediately
	character_data = {
		"name": "",
		"animations": {}
	}

	# Create Refresh Button manually (Emergency Fix)
	var refresh_btn = Button.new()
	refresh_btn.text = "↻ Refresh Lists"
	refresh_btn.pressed.connect(func():
		print("[SpriteMaker] Manual Refresh Triggered")
		
		# Try to recover UI if missing
		if not stat_display_container:
			print("[SpriteMaker] Recovering missing UI...")
			create_stat_display_ui()
			
		populate_class_list()
		populate_npc_list()
	)
	# Add to TitleBar
	var title_hbox = $UI/TitleBar/HBoxContainer
	if title_hbox:
		title_hbox.add_child(refresh_btn)
		# Move to be 2nd item (after title)
		title_hbox.move_child(refresh_btn, 1)

	for anim in animation_names:
		character_data.animations[anim] = []

	# Admin authentication check
	if GameState.admin_level < 1:
		print("[SpriteMaker] Access denied: Admin privileges required")
		var error_panel = PanelContainer.new()
		error_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(error_panel)

		var error_vbox = VBoxContainer.new()
		error_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		error_panel.add_child(error_vbox)

		var spacer1 = Control.new()
		spacer1.custom_minimum_size = Vector2(0, 100)
		error_vbox.add_child(spacer1)

		var error_label = Label.new()
		error_label.text = "ACCESS DENIED"
		error_label.add_theme_font_size_override("font_size", 48)
		error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_vbox.add_child(error_label)

		var message_label = Label.new()
		message_label.text = "Sprite Maker requires admin privileges.\nPlease log in with an admin account."
		message_label.add_theme_font_size_override("font_size", 24)
		message_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_vbox.add_child(message_label)

		var spacer2 = Control.new()
		spacer2.custom_minimum_size = Vector2(0, 50)
		error_vbox.add_child(spacer2)

		var back_button = Button.new()
		back_button.text = "Back to Menu"
		back_button.custom_minimum_size = Vector2(200, 50)
		back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://source/common/main.tscn"))
		error_vbox.add_child(back_button)

		return  # Stop initialization

	create_stat_display_ui()
	populate_class_list()
	populate_npc_list()

	# Populate combat role dropdown
	if role_dropdown:
		role_dropdown.add_item("Melee - Full damage front row, 50% back row (25% min)", 0)
		role_dropdown.add_item("Ranged - Full damage back row, 50% front row", 1)
		role_dropdown.add_item("Caster - Full damage both rows, 20% extra damage taken", 2)
		role_dropdown.add_item("Hybrid - 80% damage both rows, 20% extra damage taken", 3)
		role_dropdown.item_selected.connect(_on_role_dropdown_selected)
		print("✓ Combat role dropdown populated")

	# Connect Add button
	if add_role_button:
		add_role_button.pressed.connect(_on_add_role_pressed)
		print("✓ Combat role Add button connected")

	# Initialize with no role selected
	update_combat_role_display()
	print("✓ Combat role system initialized")

	# Enable mouse input for grid container
	grid_container.mouse_filter = Control.MOUSE_FILTER_PASS

	# Set initial button states
	update_type_buttons()

	# Create upload button next to save button
	create_upload_button()

	# Start visibility checking
	set_process(true)
	
	# Auto-populate lists (Deferred to ensure UI is ready)
	call_deferred("populate_class_list")
	call_deferred("populate_npc_list")
	
	print("=== SPRITE MAKER READY ===")

func create_stat_display_ui():
	"""Create UI elements to display and edit character stats"""
	print("[SpriteMaker] Creating Stat UI...")
	
	if not control_panel:
		print("[SpriteMaker] ERROR: control_panel is null!")
		return

	# Create scrollable container for stats
	var scroll = ScrollContainer.new()
	scroll.name = "StatScrollContainer"
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	control_panel.add_child(scroll)

	# Create container for stats inside scroll
	stat_display_container = VBoxContainer.new()
	stat_display_container.name = "StatDisplayContainer"
	stat_display_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stat_display_container)

	# Add separator
	var separator = HSeparator.new()
	stat_display_container.add_child(separator)

	# Title
	var title = Label.new()
	title.text = "CHARACTER STATS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_display_container.add_child(title)

	# Element dropdown
	var element_label = Label.new()
	element_label.text = "Element:"
	stat_display_container.add_child(element_label)

	element_option = OptionButton.new()
	element_option.add_item("None", 0)
	element_option.add_item("Fire", 1)
	element_option.add_item("Water", 2)
	element_option.add_item("Earth", 3)
	element_option.add_item("Wind", 4)
	element_option.item_selected.connect(_on_element_changed)
	stat_display_container.add_child(element_option)

	# Level
	var level_label = Label.new()
	level_label.text = "Level (1-50):"
	stat_display_container.add_child(level_label)

	level_spin = SpinBox.new()
	level_spin.min_value = 1
	level_spin.max_value = 50
	level_spin.value = 1
	level_spin.value_changed.connect(_on_stats_changed)
	stat_display_container.add_child(level_spin)

	# Base stats
	var base_title = Label.new()
	base_title.text = "Base Stats (5-20):"
	base_title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	stat_display_container.add_child(base_title)

	# Create grid for stat spinboxes
	var stat_grid = GridContainer.new()
	stat_grid.columns = 2
	stat_display_container.add_child(stat_grid)

	# STR
	var str_label = Label.new()
	str_label.text = "STR:"
	stat_grid.add_child(str_label)
	str_spin = SpinBox.new()
	str_spin.min_value = 5
	str_spin.max_value = 20
	str_spin.value = 10
	str_spin.value_changed.connect(_on_stats_changed)
	stat_grid.add_child(str_spin)

	# DEX
	var dex_label = Label.new()
	dex_label.text = "DEX:"
	stat_grid.add_child(dex_label)
	dex_spin = SpinBox.new()
	dex_spin.min_value = 5
	dex_spin.max_value = 20
	dex_spin.value = 10
	dex_spin.value_changed.connect(_on_stats_changed)
	stat_grid.add_child(dex_spin)

	# INT
	var int_label = Label.new()
	int_label.text = "INT:"
	stat_grid.add_child(int_label)
	int_spin = SpinBox.new()
	int_spin.min_value = 5
	int_spin.max_value = 20
	int_spin.value = 10
	int_spin.value_changed.connect(_on_stats_changed)
	stat_grid.add_child(int_spin)

	# VIT
	var vit_label = Label.new()
	vit_label.text = "VIT:"
	stat_grid.add_child(vit_label)
	vit_spin = SpinBox.new()
	vit_spin.min_value = 5
	vit_spin.max_value = 20
	vit_spin.value = 10
	vit_spin.value_changed.connect(_on_stats_changed)
	stat_grid.add_child(vit_spin)

	# WIS
	var wis_label = Label.new()
	wis_label.text = "WIS:"
	stat_grid.add_child(wis_label)
	wis_spin = SpinBox.new()
	wis_spin.min_value = 5
	wis_spin.max_value = 20
	wis_spin.value = 10
	wis_spin.value_changed.connect(_on_stats_changed)
	stat_grid.add_child(wis_spin)

	# CHA
	var cha_label = Label.new()
	cha_label.text = "CHA:"
	stat_grid.add_child(cha_label)
	cha_spin = SpinBox.new()
	cha_spin.min_value = 5
	cha_spin.max_value = 20
	cha_spin.value = 10
	cha_spin.value_changed.connect(_on_stats_changed)
	stat_grid.add_child(cha_spin)

	# Total stats label
	total_label = Label.new()
	total_label.text = "Total: 60"
	total_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	stat_display_container.add_child(total_label)

	# Derived stats
	var derived_header = HBoxContainer.new()
	stat_display_container.add_child(derived_header)

	var derived_title = Label.new()
	derived_title.text = "Derived Stats:"
	derived_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	derived_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	derived_header.add_child(derived_title)

	edit_mode_button = Button.new()
	edit_mode_button.text = "Edit"
	edit_mode_button.custom_minimum_size = Vector2(60, 0)
	edit_mode_button.pressed.connect(_on_edit_mode_toggled)
	derived_header.add_child(edit_mode_button)

	# HP - Label (auto-calculated) and SpinBox (manual edit)
	hp_label = Label.new()
	hp_label.text = "HP: 0"
	stat_display_container.add_child(hp_label)

	hp_spin = SpinBox.new()
	hp_spin.min_value = 1
	hp_spin.max_value = 9999
	hp_spin.value = 100
	hp_spin.visible = false
	hp_spin.value_changed.connect(_on_manual_stat_changed)
	stat_display_container.add_child(hp_spin)

	# MP - Label and SpinBox
	mp_label = Label.new()
	mp_label.text = "MP: 0"
	stat_display_container.add_child(mp_label)

	mp_spin = SpinBox.new()
	mp_spin.min_value = 0
	mp_spin.max_value = 9999
	mp_spin.value = 50
	mp_spin.visible = false
	mp_spin.value_changed.connect(_on_manual_stat_changed)
	stat_display_container.add_child(mp_spin)

	# EP - Label and SpinBox
	ep_label = Label.new()
	ep_label.text = "EP: 0"
	stat_display_container.add_child(ep_label)

	ep_spin = SpinBox.new()
	ep_spin.min_value = 0
	ep_spin.max_value = 9999
	ep_spin.value = 30
	ep_spin.visible = false
	ep_spin.value_changed.connect(_on_manual_stat_changed)
	stat_display_container.add_child(ep_spin)

	# Separator
	var ai_sep = HSeparator.new()
	stat_display_container.add_child(ai_sep)

	# AI & Spawning Header
	var ai_title = Label.new()
	ai_title.text = "COMBAT AI & SPAWNING:"
	ai_title.add_theme_color_override("font_color", Color(0.5, 1.0, 1.0)) # Cyan
	stat_display_container.add_child(ai_title)

	# AI Archetype Dropdown
	var ai_label = Label.new()
	ai_label.text = "AI Archetype:"
	stat_display_container.add_child(ai_label)

	ai_option = OptionButton.new()
	ai_option.add_item("AGGRESSIVE (Focus weakest)", 0)
	ai_option.add_item("DEFENSIVE (Heal/Guard)", 1)
	ai_option.add_item("TACTICAL (Focus Casters)", 2)
	ai_option.add_item("CHAOTIC (Random)", 3)
	stat_display_container.add_child(ai_option)

	# Level Range
	var lvl_range_label = Label.new()
	lvl_range_label.text = "Spawn Level Range:"
	stat_display_container.add_child(lvl_range_label)

	var lvl_grid = GridContainer.new()
	lvl_grid.columns = 2
	stat_display_container.add_child(lvl_grid)

	var min_lbl = Label.new()
	min_lbl.text = "Min:"
	lvl_grid.add_child(min_lbl)
	
	min_level_spin = SpinBox.new()
	min_level_spin.min_value = 1
	min_level_spin.max_value = 50
	min_level_spin.value = 1
	lvl_grid.add_child(min_level_spin)

	var max_lbl = Label.new()
	max_lbl.text = "Max:"
	lvl_grid.add_child(max_lbl)

	max_level_spin = SpinBox.new()
	max_level_spin.min_value = 1
	max_level_spin.max_value = 50
	max_level_spin.value = 1
	lvl_grid.add_child(max_level_spin)

	# Rewards Section
	var reward_sep = HSeparator.new()
	stat_display_container.add_child(reward_sep)

	var reward_title = Label.new()
	reward_title.text = "REWARDS (Loot):"
	reward_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4)) # Gold color
	stat_display_container.add_child(reward_title)

	var reward_grid = GridContainer.new()
	reward_grid.columns = 2
	stat_display_container.add_child(reward_grid)

	var xp_lbl = Label.new()
	xp_lbl.text = "XP Reward:"
	reward_grid.add_child(xp_lbl)

	xp_spin = SpinBox.new()
	xp_spin.min_value = 0
	xp_spin.max_value = 99999
	xp_spin.value = 50
	reward_grid.add_child(xp_spin)

	var gold_lbl = Label.new()
	gold_lbl.text = "Gold Reward:"
	reward_grid.add_child(gold_lbl)

	gold_spin = SpinBox.new()
	gold_spin.min_value = 0
	gold_spin.max_value = 99999
	gold_spin.value = 10
	reward_grid.add_child(gold_spin)

	# Description header
	var desc_sep = HSeparator.new()
	stat_display_container.add_child(desc_sep)

	var desc_title = Label.new()
	desc_title.text = "Description:"
	desc_title.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	stat_display_container.add_child(desc_title)

	desc_text = TextEdit.new()
	desc_text.custom_minimum_size = Vector2(0, 60)
	desc_text.placeholder_text = "Enter character description..."
	stat_display_container.add_child(desc_text)

	print("[SpriteMaker] Stat display UI created SUCCESSFULLY")

func create_upload_button():
	"""Create and position upload button next to save button"""
	if not save_button:
		print("[SpriteMaker] ERROR: SaveCharacterButton not found")
		return

	# Get the parent container of the save button
	var button_container = save_button.get_parent()

	# Create upload button
	upload_button = Button.new()
	_update_upload_button_text()
	upload_button.pressed.connect(_on_upload_button_pressed)

	# Add to same container (will be displayed below save button)
	button_container.add_child(upload_button)

	print("✓ Upload button created and connected")


func _update_upload_button_text():
	"""Update upload button - only enabled for local server"""
	if not upload_button:
		return

	if ConfigManager.is_local_server():
		upload_button.text = "Upload to Local Server"
		upload_button.disabled = false
		upload_button.tooltip_text = "Upload character data to local development server"
	else:
		upload_button.text = "Upload (Local Only)"
		upload_button.disabled = true
		upload_button.tooltip_text = "Uploads disabled - switch to Local server in login screen to enable"

func _on_element_changed(_index: int):
	"""Handle element selection change"""
	_on_stats_changed(0)

func _on_edit_mode_toggled():
	"""Toggle between calculated and manual stat editing"""
	is_edit_mode = !is_edit_mode

	if is_edit_mode:
		# Switch to manual edit mode
		edit_mode_button.text = "Auto"
		hp_label.visible = false
		mp_label.visible = false
		ep_label.visible = false
		hp_spin.visible = true
		mp_spin.visible = true
		ep_spin.visible = true

		# Set spinbox values to current calculated values if not manually set
		if manual_hp == -1:
			hp_spin.value = _calculate_hp()
		else:
			hp_spin.value = manual_hp

		if manual_mp == -1:
			mp_spin.value = _calculate_mp()
		else:
			mp_spin.value = manual_mp

		if manual_ep == -1:
			ep_spin.value = _calculate_ep()
		else:
			ep_spin.value = manual_ep
	else:
		# Switch back to auto-calculated mode
		edit_mode_button.text = "Edit"
		hp_label.visible = true
		mp_label.visible = true
		ep_label.visible = true
		hp_spin.visible = false
		mp_spin.visible = false
		ep_spin.visible = false

		# Update labels with calculated values
		_on_stats_changed(0)

func _on_manual_stat_changed(_value: float):
	"""Store manual stat overrides"""
	if is_edit_mode:
		manual_hp = int(hp_spin.value)
		manual_mp = int(mp_spin.value)
		manual_ep = int(ep_spin.value)

func _calculate_hp() -> int:
	"""Calculate HP from base stats"""
	if not str_spin: return 50
	
	var str_val = int(str_spin.value)
	var vit_val = int(vit_spin.value)
	var level = int(level_spin.value)
	
	# Player Formula (Class)
	if current_type == "class":
		# Formula: base 50 + vit*2.5 + str*1 + level*2.5
		return 50 + int(vit_val * 2.5) + (str_val * 1) + ((level - 1) * 2.5)
	else:
		# NPC Formula (Growth)
		# Base HP estimate at Lv1 = 50 + vit*2.5
		var base_hp = 50 + int(vit_val * 2.5)
		var multiplier = 1.0 + ((level - 1) * 0.10) # 10% per level
		return int(base_hp * multiplier)

func _calculate_mp() -> int:
	"""Calculate MP from base stats"""
	if not int_spin: return 50
	
	var int_val = int(int_spin.value)
	var wis_val = int(wis_spin.value)
	var level = int(level_spin.value)
	
	if current_type == "class":
		return 50 + (int_val * 5) + (wis_val * 2) + ((level - 1) * 3)
	else:
		# NPC Formula
		var base_mp = 50 + (int_val * 5)
		var multiplier = 1.0 + ((level - 1) * 0.05) # 5% per level
		return int(base_mp * multiplier)

func _calculate_ep() -> int:
	"""Calculate EP from base stats"""
	if not dex_spin:
		return 30
	var dex_val = int(dex_spin.value)
	var level = int(level_spin.value)
	return 30 + (dex_val * 3) + ((level - 1) * 2)

func _on_role_dropdown_selected(index: int):
	"""Update role description when dropdown selection changes"""
	if not role_description:
		return

	match index:
		0:  # Melee
			role_description.text = "Melee: Full damage in front row. 50% damage in back row. 25% damage minimum when back row attacks back row. Normal defense."
		1:  # Ranged
			role_description.text = "Ranged: Full damage in back row. 50% damage in front row (forced melee). Normal defense."
		2:  # Caster
			role_description.text = "Caster: Full damage from any position (can melee OR cast). Takes 20% EXTRA damage (weak defense)."
		3:  # Hybrid
			role_description.text = "Hybrid: 80% damage from any position (versatile). Takes 20% EXTRA damage (weak defense)."

func _on_add_role_pressed():
	"""Assign selected combat role from dropdown (only one role allowed)"""
	if not role_dropdown:
		return

	var index = role_dropdown.selected
	match index:
		0:
			selected_combat_role = "Melee"
		1:
			selected_combat_role = "Ranged"
		2:
			selected_combat_role = "Caster"
		3:
			selected_combat_role = "Hybrid"
		_:
			return  # No valid selection

	update_combat_role_display()
	print("✓ Combat role set to: ", selected_combat_role)

func update_combat_role_display():
	"""Update UI to show currently selected combat role"""
	if current_role_label:
		if selected_combat_role == "":
			current_role_label.text = "Current Role: None"
		else:
			current_role_label.text = "Current Role: " + selected_combat_role

func _on_stats_changed(_value: float):
	"""Update derived stats when base stats change"""
	if not str_spin:
		return  # UI not ready yet

	var str_val = int(str_spin.value)
	var dex_val = int(dex_spin.value)
	var int_val = int(int_spin.value)
	var vit_val = int(vit_spin.value)
	var wis_val = int(wis_spin.value)
	var cha_val = int(cha_spin.value)

	# Calculate total
	var total = str_val + dex_val + int_val + vit_val + wis_val + cha_val
	total_label.text = "Total: %d (Typical: 60-80)" % total

	# Color code based on total
	if total < 60:
		total_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))  # Red
	elif total > 80:
		total_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))  # Orange
	else:
		total_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))  # Green

	# Update derived stats (only if not in edit mode)
	if not is_edit_mode:
		var hp = _calculate_hp()
		var mp = _calculate_mp()
		var ep = _calculate_ep()

		hp_label.text = "HP: %d" % hp
		mp_label.text = "MP: %d" % mp
		ep_label.text = "EP: %d" % ep

func _process(_delta):
	# Don't process if not visible (performance safeguard)
	if not visible:
		return

	# Lazy load sprites on first visibility
	if not is_initialized:
		is_initialized = true
		load_character_sprites()
		status_label.text = "Loading sprites..."

	# Check visible sprites every frame and load textures for visible buttons
	load_visible_sprites()

func update_selected_sprites_list():
	"""Update the list of selected sprites - selects entire row from clicked preview"""
	# Clear previous highlights
	for i in range(grid_container.get_child_count()):
		var button = grid_container.get_child(i)
		button.modulate = Color.WHITE

	selected_sprites.clear()
	if selection_start < 0:
		return

	# Get the row from the clicked preview sprite
	var region = sprite_regions[selection_start]
	var clicked_row = region["row"]

	# Build the full row's sprite indices (all 12 sprites from columns 0-11)
	for col in range(COLS_PER_ROW):
		var atlas_index = 0 if clicked_row < ROWS_PER_ATLAS else 1
		var local_row = clicked_row if clicked_row < ROWS_PER_ATLAS else clicked_row - ROWS_PER_ATLAS

		# Store the actual sprite data for all 12 sprites in the row
		selected_sprites.append({
			"row": clicked_row,
			"col": col,
			"atlas_index": atlas_index,
			"local_row": local_row
		})

	# Highlight the clicked preview sprite
	if selection_start < grid_container.get_child_count():
		var button = grid_container.get_child(selection_start)
		button.modulate = Color(0.5, 1.0, 0.5, 1.0)  # Green highlight

func load_character_sprites():
	status_label.text = "Loading atlas textures..."

	# Load the two sprite atlas sheets
	atlas_textures.clear()
	var atlas1 = load("res://assets-odyssey/sprites_part1.png")
	var atlas2 = load("res://assets-odyssey/sprites_part2.png")

	if not atlas1 or not atlas2:
		status_label.text = "ERROR: Could not load sprite atlas files (sprites_part1.png, sprites_part2.png)"
		return

	atlas_textures.append(atlas1)
	atlas_textures.append(atlas2)

	# Generate sprite region list - ONLY PREVIEW SPRITES (column 3 = walk_down_1)
	sprite_regions.clear()
	for row in range(CHARACTER_ROWS):
		# Only add the preview sprite (walk_down_1)
		var col = PREVIEW_COL
		var atlas_index = 0 if row < ROWS_PER_ATLAS else 1
		var local_row = row if row < ROWS_PER_ATLAS else row - ROWS_PER_ATLAS

		sprite_regions.append({
			"row": row,
			"col": col,
			"atlas_index": atlas_index,
			"local_row": local_row
		})

	# Calculate total pages (1 sprite per row now)
	total_pages = int(ceil(float(CHARACTER_ROWS) / float(rows_per_page)))
	current_page = 0

	display_sprite_grid()
	status_label.text = "Ready: " + str(CHARACTER_ROWS) + " characters available (showing preview sprites). Click to auto-assign."


func display_sprite_grid():
	# Clear existing sprites
	for child in grid_container.get_children():
		child.queue_free()

	loaded_buttons.clear()

	# Calculate page bounds
	var start_row = current_page * rows_per_page
	var end_row = min(start_row + rows_per_page, CHARACTER_ROWS)
	
	# Calculate sprite indices for this page
	var start_index = start_row * COLS_PER_ROW
	var end_index = end_row * COLS_PER_ROW

	# Create placeholder buttons only for current page - textures loaded on-demand
	for i in range(start_index, end_index):
		if i >= sprite_regions.size():
			break
			
		var region = sprite_regions[i]
		var sprite_button = TextureButton.new()
		sprite_button.custom_minimum_size = Vector2(64, 64)
		sprite_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		sprite_button.tooltip_text = "Row %d, Col %d" % [region.row, region.col]
		sprite_button.name = "SpriteButton" + str(i)

		# Store index for lazy loading
		sprite_button.set_meta("sprite_index", i)

		# Connect mouse events for selection
		sprite_button.gui_input.connect(_on_sprite_gui_input.bind(i))

		grid_container.add_child(sprite_button)

	var sprites_shown = end_index - start_index
	print("Created ", sprites_shown, " sprite buttons for page ", current_page + 1, " (rows ", start_row, "-", end_row - 1, ")")
	update_page_indicator()

func load_visible_sprites():
	"""Load textures only for sprites visible in the scroll viewport"""
	if not scroll_container:
		return

	var viewport_rect = scroll_container.get_global_rect()
	var scroll_position = scroll_container.scroll_vertical
	var visible_count = 0

	for button in grid_container.get_children():
		var sprite_index = button.get_meta("sprite_index", -1)
		if sprite_index == -1:
			continue

		# Check if button is visible in viewport
		var button_rect = button.get_global_rect()
		if viewport_rect.intersects(button_rect):
			visible_count += 1
			# Load texture if not already loaded
			if not loaded_buttons.has(sprite_index):
				var texture = get_sprite_texture(sprite_index)
				if texture:
					button.texture_normal = texture
					loaded_buttons[sprite_index] = true
		else:
			# Unload texture if scrolled out of view to save memory
			if loaded_buttons.has(sprite_index):
				button.texture_normal = null
				loaded_buttons.erase(sprite_index)

	# Update status every 60 frames (1 second at 60fps)
	if Engine.get_frames_drawn() % 60 == 0:
		status_label.text = "Loaded: %d/%d sprites visible. Scroll: Row %d-%d of %d" % [
			loaded_buttons.size(),
			sprite_regions.size(),
			int(scroll_position / 64),
			int((scroll_position + viewport_rect.size.y) / 64),
			CHARACTER_ROWS
		]

func get_sprite_texture(sprite_index: int) -> Texture2D:
	"""Create AtlasTexture from sprite region with caching"""
	if sprite_index < 0 or sprite_index >= sprite_regions.size():
		return null

	var region = sprite_regions[sprite_index]
	var cache_key = "%d_%d_%d" % [region.atlas_index, region.row, region.col]

	if not sprite_cache.has(cache_key):
		# Create new AtlasTexture
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = atlas_textures[region.atlas_index]

		# Calculate pixel position in the atlas
		var x = region.col * SPRITE_SIZE
		var y = region.local_row * SPRITE_SIZE

		# Apply edge crop to remove black border artifacts (if enabled)
		atlas_tex.region = Rect2(
			x + CROP_EDGE,                    # Crop left edge
			y + CROP_EDGE,                    # Crop top edge
			SPRITE_SIZE - (CROP_EDGE * 2),   # Reduce width
			SPRITE_SIZE - (CROP_EDGE * 2)    # Reduce height
		)
		sprite_cache[cache_key] = atlas_tex

	return sprite_cache[cache_key]

func _on_sprite_gui_input(event: InputEvent, sprite_index: int):
	"""Handle mouse input on sprite buttons - click to auto-assign entire row"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Select entire row on click
			selection_start = sprite_index
			selected_sprites.clear()
			update_selected_sprites_list()

			var region = sprite_regions[sprite_index]

			# Auto-assign if we have a complete row (12 sprites)
			if selected_sprites.size() == 12:
				# Clear all animations
				for anim in character_data.animations:
					character_data.animations[anim].clear()

				# Assign in order: up1, up2, attack_up, down1, down2, attack_down, left1, left2, attack_left, right1, right2, attack_right
				var anim_order = [
					"walk_up_1", "walk_up_2", "attack_up",
					"walk_down_1", "walk_down_2", "attack_down",
					"walk_left_1", "walk_left_2", "attack_left",
					"walk_right_1", "walk_right_2", "attack_right"
				]

				for i in range(12):
					var sprite_data = selected_sprites[i]
					var anim_name = anim_order[i]

					# Create texture for this specific sprite
					var texture = get_sprite_texture_from_data(sprite_data)

					character_data.animations[anim_name].append({
						"atlas_index": sprite_data["atlas_index"],
						"row": sprite_data["row"],
						"col": sprite_data["col"],
						"texture": texture
					})

				# Update preview immediately
				update_character_preview()

				status_label.text = "Auto-assigned 12 sprites from row %d!" % region["row"]
				selected_sprites.clear()
				selection_start = -1
			else:
				status_label.text = "Selected %d sprites. Incomplete row." % selected_sprites.size()

func _on_sprite_single_click(sprite_index: int):
	"""Handle single sprite click to add to current animation"""
	if current_animation == "":
		status_label.text = "No animation selected"
		return

	var region = sprite_regions[sprite_index]
	var texture = get_sprite_texture(sprite_index)

	# Add to current animation with atlas region data
	character_data.animations[current_animation].append({
		"atlas_index": region.atlas_index,
		"row": region.row,
		"col": region.col,
		"texture": texture
	})

	update_frames_display()
	status_label.text = "Added sprite (r%d, c%d) to %s" % [region.row, region.col, current_animation]

func update_frames_display():
	if current_animation == "":
		current_frames_label.text = "Frames: 0"
		return

	var frame_count = character_data.animations[current_animation].size()
	current_frames_label.text = "Frames: " + str(frame_count)

func _on_save_character_pressed():
	var char_name = character_name.text.strip_edges()
	if char_name == "":
		status_label.text = "Enter character name first"
		return

	character_data.name = char_name

	# Determine save directory based on current type
	var save_dir = "res://characters/classes/" if current_type == "class" else "res://characters/npcs/"

	# Create directories if they don't exist
	if not DirAccess.dir_exists_absolute("res://characters/"):
		DirAccess.open("res://").make_dir("characters")
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.open("res://characters/").make_dir("classes" if current_type == "class" else "npcs")

	# Read stat values from UI
	var str_val = int(str_spin.value) if str_spin else 10
	var dex_val = int(dex_spin.value) if dex_spin else 10
	var int_val = int(int_spin.value) if int_spin else 10
	var vit_val = int(vit_spin.value) if vit_spin else 10
	var wis_val = int(wis_spin.value) if wis_spin else 10
	var cha_val = int(cha_spin.value) if cha_spin else 10
	var level = int(level_spin.value) if level_spin else 1

	# Get element from dropdown
	var element = "None"
	if element_option and element_option.selected >= 0:
		element = element_option.get_item_text(element_option.selected)

	# Use manual values if set, otherwise calculate
	var hp = manual_hp if manual_hp != -1 else _calculate_hp()
	var mp = manual_mp if manual_mp != -1 else _calculate_mp()
	var ep = manual_ep if manual_ep != -1 else _calculate_ep()

	# Calculate defensive and offensive stats
	var phys_def = int(vit_val * 0.5) + int(str_val * 0.2)
	var mag_def = int(wis_val * 0.8) + int(int_val * 0.2)
	var phys_dmg = (str_val * 2) + int(dex_val * 0.5)
	var mag_dmg = (int_val * 2.5) + int(wis_val * 0.5)

	# Get description
	var description = desc_text.text if desc_text else ""

	# Get combat role (use selected role or default to Melee)
	var combat_role = selected_combat_role if selected_combat_role != "" else "Melee"

	# Get AI and Spawning Data
	var ai_archetype = "AGGRESSIVE"
	if ai_option and ai_option.selected >= 0:
		var text = ai_option.get_item_text(ai_option.selected)
		ai_archetype = text.split(" ")[0] # Extract "AGGRESSIVE" from "AGGRESSIVE (Focus weakest)"

	var min_lvl = int(min_level_spin.value) if min_level_spin else 1
	var max_lvl = int(max_level_spin.value) if max_level_spin else 1

	var xp_reward = int(xp_spin.value) if xp_spin else 50
	var gold_reward = int(gold_spin.value) if gold_spin else 10

	# Save character data
	var save_data = {
		"character_name": char_name,
		"type": current_type,
		"element": element,
		"combat_role": combat_role,
		"ai_archetype": ai_archetype,
		"level_range": {
			"min": min_lvl,
			"max": max_lvl
		},
		"loot_table": {
			"xp_reward": xp_reward,
			"gold_reward": gold_reward,
			"items": []
		},
		"level": level,
		"xp": 0,
		"base_stats": {
			"str": str_val,
			"dex": dex_val,
			"int": int_val,
			"vit": vit_val,
			"wis": wis_val,
			"cha": cha_val
		},
		"derived_stats": {
			"max_hp": hp,
			"max_mp": mp,
			"max_ep": ep,
			"phys_def": phys_def,
			"mag_def": mag_def,
			"phys_dmg": phys_dmg,
			"mag_dmg": mag_dmg
		},
		"manual_stats": {
			"hp": manual_hp,
			"mp": manual_mp,
			"ep": manual_ep
		},
		"flavor_text": {
			"description": description,
			"backstory": ""
		},
		"created_date": Time.get_datetime_string_from_system(),
		"animations": {}
	}

	# Convert texture references to atlas coordinates for saving
	for anim_name in character_data.animations:
		save_data.animations[anim_name] = []
		for frame in character_data.animations[anim_name]:
			save_data.animations[anim_name].append({
				"atlas_index": frame.atlas_index,
				"row": frame.row,
				"col": frame.col
			})

	# Save to JSON
	var json_string = JSON.stringify(save_data, "\t")
	var save_path = save_dir + char_name + ".json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		status_label.text = "Saved " + current_type + ": " + char_name

		# Show animation summary
		print("Saved " + current_type + ": " + char_name)
		for anim in character_data.animations:
			var count = character_data.animations[anim].size()
			if count > 0:
				print("  " + anim + ": " + str(count) + " frames")

		# Refresh appropriate list
		if current_type == "class":
			populate_class_list()
		else:
			populate_npc_list()
	else:
		status_label.text = "ERROR: Could not save " + char_name

func _on_upload_button_pressed():
	"""Upload current character (Class or NPC) to LOCAL server only"""
	# SECURITY: Only allow uploads to local development server
	if not ConfigManager.is_local_server():
		print("[SpriteMaker] Upload blocked: Not connected to local server")
		_show_error("Uploads only allowed to local server (127.0.0.1)")
		return

	# Check if admin
	if GameState.admin_level < 1:
		print("[SpriteMaker] Upload failed: Not an admin")
		_show_error("Upload requires admin privileges")
		return

	# Get character name from input
	var char_name = character_name.text.strip_edges()
	if char_name.is_empty():
		_show_error("Character must have a name before uploading")
		return

	# Get character data (same data that would be saved)
	var upload_data = _prepare_character_data_for_upload(char_name)
	if upload_data.is_empty():
		_show_error("Failed to prepare character data for upload")
		return

	# Determine if this is a Class or NPC
	var character_type = current_type  # "class" or "npc"

	# Call appropriate RPC on server (local only)
	if character_type == "class":
		ServerConnection.upload_class.rpc(char_name, upload_data)
		print("[SpriteMaker] Uploading class to LOCAL server: %s" % char_name)
		_show_status("Uploading class '%s' to local server..." % char_name)
	else:  # npc
		ServerConnection.upload_npc.rpc(char_name, upload_data)
		print("[SpriteMaker] Uploading NPC to LOCAL server: %s" % char_name)
		_show_status("Uploading NPC '%s' to local server..." % char_name)

func _prepare_character_data_for_upload(char_name: String) -> Dictionary:
	"""Prepare character data for server upload - same format as save"""
	# Read stat values from UI
	var str_val = int(str_spin.value) if str_spin else 10
	var dex_val = int(dex_spin.value) if dex_spin else 10
	var int_val = int(int_spin.value) if int_spin else 10
	var vit_val = int(vit_spin.value) if vit_spin else 10
	var wis_val = int(wis_spin.value) if wis_spin else 10
	var cha_val = int(cha_spin.value) if cha_spin else 10
	var level = int(level_spin.value) if level_spin else 1

	# Get element from dropdown
	var element = "None"
	if element_option and element_option.selected >= 0:
		element = element_option.get_item_text(element_option.selected)

	# Use manual values if set, otherwise calculate
	var hp = manual_hp if manual_hp != -1 else _calculate_hp()
	var mp = manual_mp if manual_mp != -1 else _calculate_mp()
	var ep = manual_ep if manual_ep != -1 else _calculate_ep()

	# Calculate defensive and offensive stats
	var phys_def = int(vit_val * 0.5) + int(str_val * 0.2)
	var mag_def = int(wis_val * 0.8) + int(int_val * 0.2)
	var phys_dmg = (str_val * 2) + int(dex_val * 0.5)
	var mag_dmg = (int_val * 2.5) + int(wis_val * 0.5)

	# Get description
	var description = desc_text.text if desc_text else ""

	# Get combat role (use selected role or default to Melee)
	var combat_role = selected_combat_role if selected_combat_role != "" else "Melee"

	# Get AI and Spawning Data
	var ai_archetype = "AGGRESSIVE"
	if ai_option and ai_option.selected >= 0:
		var text = ai_option.get_item_text(ai_option.selected)
		ai_archetype = text.split(" ")[0]

	var min_lvl = int(min_level_spin.value) if min_level_spin else 1
	var max_lvl = int(max_level_spin.value) if max_level_spin else 1

	var xp_reward = int(xp_spin.value) if xp_spin else 50
	var gold_reward = int(gold_spin.value) if gold_spin else 10

	# Build upload data
	var upload_data = {
		"character_name": char_name,
		"type": current_type,
		"element": element,
		"combat_role": combat_role,
		"ai_archetype": ai_archetype,
		"level_range": {
			"min": min_lvl,
			"max": max_lvl
		},
		"loot_table": {
			"xp_reward": xp_reward,
			"gold_reward": gold_reward,
			"items": []
		},
		"level": level,
		"xp": 0,
		"base_stats": {
			"str": str_val,
			"dex": dex_val,
			"int": int_val,
			"vit": vit_val,
			"wis": wis_val,
			"cha": cha_val
		},
		"derived_stats": {
			"max_hp": hp,
			"max_mp": mp,
			"max_ep": ep,
			"phys_def": phys_def,
			"mag_def": mag_def,
			"phys_dmg": phys_dmg,
			"mag_dmg": mag_dmg
		},
		"manual_stats": {
			"hp": manual_hp,
			"mp": manual_mp,
			"ep": manual_ep
		},
		"flavor_text": {
			"description": description,
			"backstory": ""
		},
		"created_date": Time.get_datetime_string_from_system(),
		"animations": {}
	}

	# Convert texture references to atlas coordinates for upload
	for anim_name in character_data.animations:
		upload_data.animations[anim_name] = []
		for frame in character_data.animations[anim_name]:
			upload_data.animations[anim_name].append({
				"atlas_index": frame.atlas_index,
				"row": frame.row,
				"col": frame.col
			})

	return upload_data

func _show_error(message: String):
	"""Display error message to user"""
	print("[SpriteMaker] ERROR: %s" % message)
	if status_label:
		status_label.text = "ERROR: %s" % message
		status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func _show_status(message: String):
	"""Display status message to user"""
	print("[SpriteMaker] %s" % message)
	if status_label:
		status_label.text = message
		status_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))

func _on_load_character_pressed():
	var char_name = character_name.text.strip_edges()
	if char_name == "":
		status_label.text = "Enter character name to load"
		return

	var load_path = "res://characters/" + char_name + ".json"
	if not FileAccess.file_exists(load_path):
		status_label.text = "Character '" + char_name + "' not found"
		return

	var file = FileAccess.open(load_path, FileAccess.READ)
	if not file:
		status_label.text = "Could not open " + char_name
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		status_label.text = "Invalid character file: " + char_name
		return

	var save_data = json.data

	# Clear current data
	for anim in character_data.animations:
		character_data.animations[anim].clear()

	# Load character data
	character_data.name = save_data.get("character_name", char_name)
	current_type = save_data.get("type", "class")

	# Load stats into UI if available
	if save_data.has("base_stats"):
		var base_stats = save_data.base_stats
		if str_spin: str_spin.value = base_stats.get("str", 10)
		if dex_spin: dex_spin.value = base_stats.get("dex", 10)
		if int_spin: int_spin.value = base_stats.get("int", 10)
		if vit_spin: vit_spin.value = base_stats.get("vit", 10)
		if wis_spin: wis_spin.value = base_stats.get("wis", 10)
		if cha_spin: cha_spin.value = base_stats.get("cha", 10)

	# Load level
	if save_data.has("level") and level_spin:
		level_spin.value = save_data.level

	# Load element
	if save_data.has("element") and element_option:
		var element = save_data.element
		for i in range(element_option.item_count):
			if element_option.get_item_text(i) == element:
				element_option.selected = i
				break

	# Load combat role
	if save_data.has("combat_role"):
		selected_combat_role = save_data.combat_role
		update_combat_role_display()
		print("✓ Loaded combat role: ", selected_combat_role)
	else:
		selected_combat_role = ""
		update_combat_role_display()

	# Load AI Archetype
	if save_data.has("ai_archetype") and ai_option:
		var archetype = save_data.ai_archetype
		for i in range(ai_option.item_count):
			if ai_option.get_item_text(i).begins_with(archetype):
				ai_option.selected = i
				break
	
	# Load Level Range
	if save_data.has("level_range"):
		var range_data = save_data.level_range
		if min_level_spin: min_level_spin.value = range_data.get("min", 1)
		if max_level_spin: max_level_spin.value = range_data.get("max", 1)

	# Load Loot Table
	if save_data.has("loot_table"):
		var loot = save_data.loot_table
		if xp_spin: xp_spin.value = loot.get("xp_reward", 50)
		if gold_spin: gold_spin.value = loot.get("gold_reward", 10)

	# Load manual stats
	if save_data.has("manual_stats"):
		var manual_stats = save_data.manual_stats
		manual_hp = manual_stats.get("hp", -1)
		manual_mp = manual_stats.get("mp", -1)
		manual_ep = manual_stats.get("ep", -1)
		print("✓ Loaded manual stats: HP=%d, MP=%d, EP=%d" % [manual_hp, manual_mp, manual_ep])
	else:
		manual_hp = -1
		manual_mp = -1
		manual_ep = -1

	# Load description
	if save_data.has("flavor_text") and desc_text:
		var flavor = save_data.flavor_text
		desc_text.text = flavor.get("description", "")

	# Reconstruct animations with textures from atlas coordinates
	for anim_name in save_data.get("animations", {}):
		character_data.animations[anim_name] = []
		for frame_data in save_data.animations[anim_name]:
			# Get atlas coordinates from saved data
			var atlas_idx = frame_data.get("atlas_index", 0)
			var row = frame_data.get("row", 0)
			var col = frame_data.get("col", 0)

			# Create sprite data dictionary
			var sprite_data = {
				"atlas_index": atlas_idx,
				"row": row,
				"col": col,
				"local_row": row if row < ROWS_PER_ATLAS else row - ROWS_PER_ATLAS
			}

			# Get texture directly from sprite data
			var texture = get_sprite_texture_from_data(sprite_data)
			if texture:
				character_data.animations[anim_name].append({
					"atlas_index": atlas_idx,
					"row": row,
					"col": col,
					"texture": texture
				})

	update_frames_display()
	update_character_preview()
	status_label.text = "Loaded " + current_type + ": " + char_name

func populate_class_list():
	"""Scan characters/classes/ directory and populate the class dropdown"""
	print("[SpriteMaker] Populating Class List...")
	
	if not class_list:
		print("[SpriteMaker] ERROR: class_list OptionButton is null!")
		return

	class_list.clear()
	class_list.add_item("-- Select Class --", -1)
	class_list.select(0)

	var classes_dir = "res://characters/classes/"
	var dir = DirAccess.open(classes_dir)

	if not dir:
		print("[SpriteMaker] ERROR: Could not open directory: " + classes_dir)
		return

	var class_files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var cls_name = file_name.replace(".json", "")
			class_files.append(cls_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	# Sort alphabetically
	class_files.sort()

	# Add to dropdown
	for i in range(class_files.size()):
		class_list.add_item(class_files[i], i + 1) # ID is index + 1 because index 0 is header

	print("[SpriteMaker] Found " + str(class_files.size()) + " saved classes")

func populate_npc_list():
	"""Scan characters/npcs/ directory and populate the NPC dropdown"""
	print("[SpriteMaker] Populating NPC List...")
	
	if not npc_list:
		print("[SpriteMaker] ERROR: npc_list OptionButton is null!")
		return

	npc_list.clear()
	npc_list.add_item("-- Select NPC --", -1)
	npc_list.select(0)

	var npcs_dir = "res://characters/npcs/"
	var dir = DirAccess.open(npcs_dir)

	if not dir:
		print("[SpriteMaker] ERROR: Could not open directory: " + npcs_dir)
		return

	var npc_files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var npc_name = file_name.replace(".json", "")
			npc_files.append(npc_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	# Sort alphabetically
	npc_files.sort()

	# Add to dropdown
	for i in range(npc_files.size()):
		npc_list.add_item(npc_files[i], i + 1)

	print("[SpriteMaker] Found " + str(npc_files.size()) + " saved NPCs")

func _on_class_list_selected(index: int):
	"""Load class when selected from dropdown"""
	if index == 0:  # Skip the "-- Select Class --" option
		return

	var cls_name = class_list.get_item_text(index)
	character_name.text = cls_name
	current_type = "class"
	update_type_buttons()
	status_label.text = "Type: CLASS"

	# Load the class
	var load_path = "res://characters/classes/" + cls_name + ".json"
	load_character_from_path(load_path, cls_name)

func _on_npc_list_selected(index: int):
	"""Load NPC when selected from dropdown"""
	if index == 0:  # Skip the "-- Select NPC --" option
		return

	var npc_name = npc_list.get_item_text(index)
	character_name.text = npc_name
	current_type = "npc"
	update_type_buttons()
	status_label.text = "Type: NPC"

	# Load the NPC
	var load_path = "res://characters/npcs/" + npc_name + ".json"
	load_character_from_path(load_path, npc_name)

func load_character_from_path(load_path: String, char_name: String):
	"""Load character data from JSON file path"""
	if not FileAccess.file_exists(load_path):
		status_label.text = "Character '" + char_name + "' not found"
		return

	var file = FileAccess.open(load_path, FileAccess.READ)
	if not file:
		status_label.text = "Could not open " + char_name
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		status_label.text = "Invalid character file: " + char_name
		return

	var save_data = json.data

	# Clear current data
	for anim in character_data.animations:
		character_data.animations[anim].clear()

	# Load character data
	character_data.name = save_data.get("character_name", char_name)
	current_type = save_data.get("type", "class")

	# Load stats into UI if available
	if save_data.has("base_stats"):
		var base_stats = save_data.base_stats
		if str_spin: str_spin.value = base_stats.get("str", 10)
		if dex_spin: dex_spin.value = base_stats.get("dex", 10)
		if int_spin: int_spin.value = base_stats.get("int", 10)
		if vit_spin: vit_spin.value = base_stats.get("vit", 10)
		if wis_spin: wis_spin.value = base_stats.get("wis", 10)
		if cha_spin: cha_spin.value = base_stats.get("cha", 10)

	# Load level
	if save_data.has("level") and level_spin:
		level_spin.value = save_data.level

	# Load element
	if save_data.has("element") and element_option:
		var element = save_data.element
		for i in range(element_option.item_count):
			if element_option.get_item_text(i) == element:
				element_option.selected = i
				break

	# Load combat role
	if save_data.has("combat_role"):
		selected_combat_role = save_data.combat_role
		update_combat_role_display()
		print("✓ Loaded combat role: ", selected_combat_role)
	else:
		selected_combat_role = ""
		update_combat_role_display()

	# Load AI Archetype
	if save_data.has("ai_archetype") and ai_option:
		var archetype = save_data.ai_archetype
		for i in range(ai_option.item_count):
			if ai_option.get_item_text(i).begins_with(archetype):
				ai_option.selected = i
				break
	
	# Load Level Range
	if save_data.has("level_range"):
		var range_data = save_data.level_range
		if min_level_spin: min_level_spin.value = range_data.get("min", 1)
		if max_level_spin: max_level_spin.value = range_data.get("max", 1)

	# Load Loot Table
	if save_data.has("loot_table"):
		var loot = save_data.loot_table
		if xp_spin: xp_spin.value = loot.get("xp_reward", 50)
		if gold_spin: gold_spin.value = loot.get("gold_reward", 10)

	# Load manual stats
	if save_data.has("manual_stats"):
		var manual_stats = save_data.manual_stats
		manual_hp = manual_stats.get("hp", -1)
		manual_mp = manual_stats.get("mp", -1)
		manual_ep = manual_stats.get("ep", -1)
		print("✓ Loaded manual stats: HP=%d, MP=%d, EP=%d" % [manual_hp, manual_mp, manual_ep])
	else:
		manual_hp = -1
		manual_mp = -1
		manual_ep = -1

	# Load description
	if save_data.has("flavor_text") and desc_text:
		var flavor = save_data.flavor_text
		desc_text.text = flavor.get("description", "")

	# Reconstruct animations with textures from atlas coordinates
	for anim_name in save_data.get("animations", {}):
		character_data.animations[anim_name] = []
		for frame_data in save_data.animations[anim_name]:
			# Get atlas coordinates from saved data
			var atlas_idx = frame_data.get("atlas_index", 0)
			var row = frame_data.get("row", 0)
			var col = frame_data.get("col", 0)

			# Create sprite data dictionary
			var sprite_data = {
				"atlas_index": atlas_idx,
				"row": row,
				"col": col,
				"local_row": row if row < ROWS_PER_ATLAS else row - ROWS_PER_ATLAS
			}

			# Get texture directly from sprite data
			var texture = get_sprite_texture_from_data(sprite_data)
			if texture:
				character_data.animations[anim_name].append({
					"atlas_index": atlas_idx,
					"row": row,
					"col": col,
					"texture": texture
				})

	update_frames_display()
	update_character_preview()
	status_label.text = "Loaded " + current_type + ": " + char_name

func update_character_preview():
	"""Update preview to show character's down-facing sprite"""
	# Try to get walk_down_1 animation
	if character_data.animations.has("walk_down_1") and character_data.animations["walk_down_1"].size() > 0:
		var frame = character_data.animations["walk_down_1"][0]
		if frame.has("texture"):
			animation_preview.texture = frame.texture
			var char_name = character_data.get("character_name", character_data.get("name", ""))
			current_frames_label.text = char_name
	else:
		# No animations loaded yet
		animation_preview.texture = null
		current_frames_label.text = "No Preview"

func _on_delete_class_pressed():
	"""Delete selected class"""
	var selected_index = class_list.selected
	if selected_index <= 0:  # 0 is the "-- Select Class --" option
		status_label.text = "No class selected to delete"
		return

	var cls_name = class_list.get_item_text(selected_index)
	var file_path = "res://characters/classes/" + cls_name + ".json"

	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		status_label.text = "Deleted class: " + cls_name
		populate_class_list()
	else:
		status_label.text = "Class file not found: " + cls_name

func _on_delete_npc_pressed():
	"""Delete selected NPC"""
	var selected_index = npc_list.selected
	if selected_index <= 0:  # 0 is the "-- Select NPC --" option
		status_label.text = "No NPC selected to delete"
		return

	var npc_name = npc_list.get_item_text(selected_index)
	var file_path = "res://characters/npcs/" + npc_name + ".json"

	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		status_label.text = "Deleted NPC: " + npc_name
		populate_npc_list()
	else:
		status_label.text = "NPC file not found: " + npc_name

func update_type_buttons():
	"""Update CLASS/NPC button visual states and show/hide appropriate dropdown"""
	if current_type == "class":
		class_button.button_pressed = true
		npc_button.button_pressed = false
		class_button.modulate = Color(0.5, 1.0, 0.5)  # Green highlight
		npc_button.modulate = Color.WHITE
		# Show class list, hide NPC list
		class_list.visible = true
		npc_list.visible = false
		delete_class_button.visible = true
		delete_npc_button.visible = false
		# Show/hide labels
		class_list_label.visible = true
		npc_list_label.visible = false
	else:
		class_button.button_pressed = false
		npc_button.button_pressed = true
		class_button.modulate = Color.WHITE
		npc_button.modulate = Color(0.5, 1.0, 0.5)  # Green highlight
		# Show NPC list, hide class list
		class_list.visible = false
		npc_list.visible = true
		delete_class_button.visible = false
		delete_npc_button.visible = true
		# Show/hide labels
		class_list_label.visible = false
		npc_list_label.visible = true

func reset_template():
	"""Reset character template to empty state"""
	# Clear character name
	character_name.text = ""
	
	# Clear all animations
	for anim in character_data.animations:
		character_data.animations[anim].clear()
	
	# Clear any selection
	selected_sprites.clear()
	selection_start = -1
	
	# Clear highlights
	for i in range(grid_container.get_child_count()):
		var button = grid_container.get_child(i)
		button.modulate = Color.WHITE
	
	# Update UI
	update_frames_display()
	update_character_preview()

func _on_set_class_type_pressed():
	"""Switch to class list view"""
	current_type = "class"
	update_type_buttons()
	status_label.text = "Viewing: CLASSES"

func _on_set_npc_type_pressed():
	"""Switch to NPC list view"""
	current_type = "npc"
	update_type_buttons()
	status_label.text = "Viewing: NPCs"

func _on_auto_assign_pressed():
	"""Auto-assign selected sprites to all 12 animation slots"""
	if selected_sprites.size() != 12:
		status_label.text = "Click a character sprite first to select it"
		return

	# Clear all animations
	for anim in character_data.animations:
		character_data.animations[anim].clear()

	# Assign in order: up1, up2, attack_up, down1, down2, attack_down, left1, left2, attack_left, right1, right2, attack_right
	var anim_order = [
		"walk_up_1", "walk_up_2", "attack_up",
		"walk_down_1", "walk_down_2", "attack_down",
		"walk_left_1", "walk_left_2", "attack_left",
		"walk_right_1", "walk_right_2", "attack_right"
	]

	for i in range(12):
		var sprite_data = selected_sprites[i]
		var anim_name = anim_order[i]

		# Create texture for this specific sprite
		var texture = get_sprite_texture_from_data(sprite_data)

		character_data.animations[anim_name].append({
			"atlas_index": sprite_data["atlas_index"],
			"row": sprite_data["row"],
			"col": sprite_data["col"],
			"texture": texture
		})

	# Clear highlights
	for i in range(grid_container.get_child_count()):
		var button = grid_container.get_child(i)
		button.modulate = Color.WHITE

	update_frames_display()
	status_label.text = "Auto-assigned 12 sprites to all animations from row %d!" % selected_sprites[0]["row"]
	selected_sprites.clear()
	selection_start = -1

func get_sprite_texture_from_data(sprite_data: Dictionary) -> Texture2D:
	"""Create AtlasTexture from sprite data dictionary"""
	var cache_key = "%d_%d_%d" % [sprite_data["atlas_index"], sprite_data["row"], sprite_data["col"]]

	if not sprite_cache.has(cache_key):
		# Create new AtlasTexture
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = atlas_textures[sprite_data["atlas_index"]]

		# Calculate pixel position in the atlas
		var x = sprite_data["col"] * SPRITE_SIZE
		var y = sprite_data["local_row"] * SPRITE_SIZE

		# Apply edge crop to remove black border artifacts (if enabled)
		atlas_tex.region = Rect2(
			x + CROP_EDGE,
			y + CROP_EDGE,
			SPRITE_SIZE - (CROP_EDGE * 2),
			SPRITE_SIZE - (CROP_EDGE * 2)
		)
		sprite_cache[cache_key] = atlas_tex

	return sprite_cache[cache_key]

func update_page_indicator():
	"""Update page labels with page information"""
	var start_row = current_page * rows_per_page
	var end_row = min(start_row + rows_per_page, CHARACTER_ROWS)
	
	if page_label:
		page_label.text = "Page %d/%d" % [current_page + 1, total_pages]
	
	if status_label:
		status_label.text = "Showing rows %d-%d of %d total rows" % [start_row, end_row - 1, CHARACTER_ROWS]

func _on_next_page_pressed():
	"""Go to next page"""
	if current_page < total_pages - 1:
		current_page += 1
		display_sprite_grid()

func _on_prev_page_pressed():
	"""Go to previous page"""
	if current_page > 0:
		current_page -= 1
		display_sprite_grid()

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://source/common/main.tscn")
