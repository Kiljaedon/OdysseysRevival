class_name SpriteMakerStats extends RefCounted
## Handles stat UI creation, calculations, and editing for Sprite Maker

signal stats_changed(stats: Dictionary)

# UI References (created programmatically)
var stat_display_container: VBoxContainer = null
var element_option: OptionButton = null
var ai_option: OptionButton = null
var min_level_spin: SpinBox = null
var max_level_spin: SpinBox = null
var xp_spin: SpinBox = null
var gold_spin: SpinBox = null
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
var desc_text: TextEdit = null

# State
var is_edit_mode: bool = false
var manual_hp: int = -1
var manual_mp: int = -1
var manual_ep: int = -1
var current_type: String = "class"

# Combat Role UI (existing in scene)
var current_role_label: Label = null
var role_dropdown: OptionButton = null
var role_description: Label = null
var add_role_button: Button = null
var selected_combat_role: String = ""

# NPC Role System
var npc_role_option: OptionButton = null
var npc_role_config_container: VBoxContainer = null
var selected_npc_role: String = "Generic"
var npc_role_data: Dictionary = {}
var is_non_combatant: bool = false
var non_combatant_check: CheckBox = null

# Role-specific UI elements
var vendor_item_list: TextEdit = null
var quest_id_list: TextEdit = null
var trainer_skill_list: TextEdit = null
var innkeeper_cost_spin: SpinBox = null
var dialogue_text: TextEdit = null

# Combat stat containers (for hiding when non-combatant)
var combat_stats_container: VBoxContainer = null


func initialize(control_panel: VBoxContainer, role_label: Label, role_drop: OptionButton, role_desc: Label, add_btn: Button) -> bool:
	if not control_panel:
		push_error("[StatsPanel] Missing control_panel reference")
		return false

	current_role_label = role_label
	role_dropdown = role_drop
	role_description = role_desc
	add_role_button = add_btn

	# Connect role UI signals if available
	if role_dropdown:
		role_dropdown.item_selected.connect(_on_role_dropdown_selected)
	if add_role_button:
		add_role_button.pressed.connect(_on_add_role_pressed)

	create_stat_display_ui(control_panel)
	return true


func set_type(type: String):
	current_type = type
	_update_npc_role_visibility()


func create_stat_display_ui(control_panel: VBoxContainer):
	"""Create UI elements to display and edit character stats"""
	print("[StatsPanel] Creating Stat UI...")

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

	# Combat stats container (can be hidden for non-combatants)
	combat_stats_container = VBoxContainer.new()
	combat_stats_container.name = "CombatStatsContainer"
	stat_display_container.add_child(combat_stats_container)

	# Element dropdown
	var element_label = Label.new()
	element_label.text = "Element:"
	combat_stats_container.add_child(element_label)

	element_option = OptionButton.new()
	element_option.add_item("None", 0)
	element_option.add_item("Fire", 1)
	element_option.add_item("Water", 2)
	element_option.add_item("Earth", 3)
	element_option.add_item("Wind", 4)
	element_option.item_selected.connect(_on_element_changed)
	combat_stats_container.add_child(element_option)

	# Level
	var level_label = Label.new()
	level_label.text = "Level (1-50):"
	combat_stats_container.add_child(level_label)

	level_spin = SpinBox.new()
	level_spin.min_value = 1
	level_spin.max_value = 50
	level_spin.value = 1
	level_spin.value_changed.connect(_on_stats_changed)
	combat_stats_container.add_child(level_spin)

	# Base stats
	var base_title = Label.new()
	base_title.text = "Base Stats (5-20):"
	base_title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	combat_stats_container.add_child(base_title)

	# Create grid for stat spinboxes
	var stat_grid = GridContainer.new()
	stat_grid.columns = 2
	combat_stats_container.add_child(stat_grid)

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
	combat_stats_container.add_child(total_label)

	# Derived stats
	var derived_header = HBoxContainer.new()
	combat_stats_container.add_child(derived_header)

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
	combat_stats_container.add_child(hp_label)

	hp_spin = SpinBox.new()
	hp_spin.min_value = 1
	hp_spin.max_value = 9999
	hp_spin.value = 100
	hp_spin.visible = false
	hp_spin.value_changed.connect(_on_manual_stat_changed)
	combat_stats_container.add_child(hp_spin)

	# MP - Label and SpinBox
	mp_label = Label.new()
	mp_label.text = "MP: 0"
	combat_stats_container.add_child(mp_label)

	mp_spin = SpinBox.new()
	mp_spin.min_value = 0
	mp_spin.max_value = 9999
	mp_spin.value = 50
	mp_spin.visible = false
	mp_spin.value_changed.connect(_on_manual_stat_changed)
	combat_stats_container.add_child(mp_spin)

	# EP - Label and SpinBox
	ep_label = Label.new()
	ep_label.text = "EP: 0"
	combat_stats_container.add_child(ep_label)

	ep_spin = SpinBox.new()
	ep_spin.min_value = 0
	ep_spin.max_value = 9999
	ep_spin.value = 30
	ep_spin.visible = false
	ep_spin.value_changed.connect(_on_manual_stat_changed)
	combat_stats_container.add_child(ep_spin)

	# Separator
	var ai_sep = HSeparator.new()
	combat_stats_container.add_child(ai_sep)

	# AI & Spawning Header
	var ai_title = Label.new()
	ai_title.text = "COMBAT AI & SPAWNING:"
	ai_title.add_theme_color_override("font_color", Color(0.5, 1.0, 1.0))
	combat_stats_container.add_child(ai_title)

	# AI Archetype Dropdown
	var ai_label = Label.new()
	ai_label.text = "AI Archetype:"
	combat_stats_container.add_child(ai_label)

	ai_option = OptionButton.new()
	ai_option.add_item("AGGRESSIVE (Focus weakest)", 0)
	ai_option.add_item("DEFENSIVE (Heal/Guard)", 1)
	ai_option.add_item("TACTICAL (Focus Casters)", 2)
	ai_option.add_item("CHAOTIC (Random)", 3)
	combat_stats_container.add_child(ai_option)

	# Level Range
	var lvl_range_label = Label.new()
	lvl_range_label.text = "Spawn Level Range:"
	combat_stats_container.add_child(lvl_range_label)

	var lvl_grid = GridContainer.new()
	lvl_grid.columns = 2
	combat_stats_container.add_child(lvl_grid)

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
	combat_stats_container.add_child(reward_sep)

	var reward_title = Label.new()
	reward_title.text = "REWARDS (Loot):"
	reward_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	combat_stats_container.add_child(reward_title)

	var reward_grid = GridContainer.new()
	reward_grid.columns = 2
	combat_stats_container.add_child(reward_grid)

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

	# Description header (stays visible for all)
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

	# NPC Role Section (only visible for NPCs)
	_create_npc_role_ui(stat_display_container)

	print("[StatsPanel] Stat display UI created SUCCESSFULLY")


func _create_npc_role_ui(container: VBoxContainer):
	"""Create NPC Role selection and config UI"""
	# Separator
	var role_sep = HSeparator.new()
	role_sep.name = "NPCRoleSeparator"
	container.add_child(role_sep)

	# NPC Role Header
	var role_title = Label.new()
	role_title.name = "NPCRoleTitle"
	role_title.text = "NPC ROLE:"
	role_title.add_theme_color_override("font_color", Color(1.0, 0.6, 1.0))
	container.add_child(role_title)

	# NPC Role Dropdown
	npc_role_option = OptionButton.new()
	npc_role_option.name = "NPCRoleDropdown"
	npc_role_option.add_item("Generic", 0)
	npc_role_option.add_item("Vendor", 1)
	npc_role_option.add_item("Quest Giver", 2)
	npc_role_option.add_item("Trainer", 3)
	npc_role_option.add_item("Innkeeper", 4)
	npc_role_option.item_selected.connect(_on_npc_role_selected)
	container.add_child(npc_role_option)

	# Non-combatant checkbox
	non_combatant_check = CheckBox.new()
	non_combatant_check.name = "NonCombatantCheck"
	non_combatant_check.text = "Non-Combatant (invulnerable, no stats)"
	non_combatant_check.toggled.connect(_on_non_combatant_toggled)
	container.add_child(non_combatant_check)

	# Config container (shows role-specific options)
	npc_role_config_container = VBoxContainer.new()
	npc_role_config_container.name = "NPCRoleConfig"
	container.add_child(npc_role_config_container)

	# Dialogue (common to all roles)
	var dialogue_label = Label.new()
	dialogue_label.text = "Dialogue (one line per interaction):"
	npc_role_config_container.add_child(dialogue_label)

	dialogue_text = TextEdit.new()
	dialogue_text.custom_minimum_size = Vector2(0, 50)
	dialogue_text.placeholder_text = "Hello traveler!\nHow can I help you?"
	npc_role_config_container.add_child(dialogue_text)

	# Update visibility based on current type
	_update_npc_role_visibility()


func _on_npc_role_selected(index: int):
	"""Handle NPC role dropdown selection"""
	match index:
		0: selected_npc_role = "Generic"
		1: selected_npc_role = "Vendor"
		2: selected_npc_role = "Quest Giver"
		3: selected_npc_role = "Trainer"
		4: selected_npc_role = "Innkeeper"

	print("[StatsPanel] NPC Role selected: %s (index %d)" % [selected_npc_role, index])

	# Auto-check non-combatant for service NPCs
	if non_combatant_check:
		var should_be_non_combatant = (selected_npc_role != "Generic")
		non_combatant_check.button_pressed = should_be_non_combatant
		is_non_combatant = should_be_non_combatant
		_update_combat_stats_visibility()

	_rebuild_role_config_ui()


func _rebuild_role_config_ui():
	"""Rebuild the role-specific config UI based on selected role"""
	if not npc_role_config_container:
		print("[StatsPanel] ERROR: npc_role_config_container is null")
		return

	print("[StatsPanel] Rebuilding role config UI for: %s" % selected_npc_role)

	# Clear existing config (except dialogue which is always shown)
	for child in npc_role_config_container.get_children():
		if child.name.begins_with("RoleConfig_"):
			child.queue_free()

	# Wait a frame for cleanup then create new UI
	if npc_role_config_container.get_tree():
		await npc_role_config_container.get_tree().process_frame

	match selected_npc_role:
		"Vendor":
			print("[StatsPanel] Creating Vendor config...")
			_create_vendor_config()
		"Quest Giver":
			print("[StatsPanel] Creating Quest Giver config...")
			_create_quest_giver_config()
		"Trainer":
			print("[StatsPanel] Creating Trainer config...")
			_create_trainer_config()
		"Innkeeper":
			print("[StatsPanel] Creating Innkeeper config...")
			_create_innkeeper_config()
		_:
			print("[StatsPanel] Generic role - no extra config needed")


func _create_vendor_config():
	"""Create vendor-specific config UI"""
	var vendor_sep = HSeparator.new()
	vendor_sep.name = "RoleConfig_VendorSep"
	npc_role_config_container.add_child(vendor_sep)

	var vendor_label = Label.new()
	vendor_label.name = "RoleConfig_VendorLabel"
	vendor_label.text = "Shop Inventory (item_id:price per line):"
	vendor_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	npc_role_config_container.add_child(vendor_label)

	vendor_item_list = TextEdit.new()
	vendor_item_list.name = "RoleConfig_VendorItems"
	vendor_item_list.custom_minimum_size = Vector2(0, 80)
	vendor_item_list.placeholder_text = "potion:50\nantidote:30\nsword_iron:200"
	npc_role_config_container.add_child(vendor_item_list)

	# Restore saved data if exists
	if npc_role_data.has("vendor_items"):
		vendor_item_list.text = npc_role_data.vendor_items


func _create_quest_giver_config():
	"""Create quest giver-specific config UI"""
	var quest_sep = HSeparator.new()
	quest_sep.name = "RoleConfig_QuestSep"
	npc_role_config_container.add_child(quest_sep)

	var quest_label = Label.new()
	quest_label.name = "RoleConfig_QuestLabel"
	quest_label.text = "Quest IDs (one per line):"
	quest_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.8))
	npc_role_config_container.add_child(quest_label)

	quest_id_list = TextEdit.new()
	quest_id_list.name = "RoleConfig_QuestList"
	quest_id_list.custom_minimum_size = Vector2(0, 80)
	quest_id_list.placeholder_text = "quest_intro_01\nquest_fetch_herbs\nquest_defeat_boss"
	npc_role_config_container.add_child(quest_id_list)

	if npc_role_data.has("quest_ids"):
		quest_id_list.text = npc_role_data.quest_ids


func _create_trainer_config():
	"""Create trainer-specific config UI"""
	var trainer_sep = HSeparator.new()
	trainer_sep.name = "RoleConfig_TrainerSep"
	npc_role_config_container.add_child(trainer_sep)

	var trainer_label = Label.new()
	trainer_label.name = "RoleConfig_TrainerLabel"
	trainer_label.text = "Teachable Skills (skill_id:cost per line):"
	trainer_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	npc_role_config_container.add_child(trainer_label)

	trainer_skill_list = TextEdit.new()
	trainer_skill_list.name = "RoleConfig_TrainerSkills"
	trainer_skill_list.custom_minimum_size = Vector2(0, 80)
	trainer_skill_list.placeholder_text = "fireball:100\nheal:150\ndefend:50"
	npc_role_config_container.add_child(trainer_skill_list)

	if npc_role_data.has("trainer_skills"):
		trainer_skill_list.text = npc_role_data.trainer_skills


func _create_innkeeper_config():
	"""Create innkeeper-specific config UI"""
	var inn_sep = HSeparator.new()
	inn_sep.name = "RoleConfig_InnSep"
	npc_role_config_container.add_child(inn_sep)

	var inn_label = Label.new()
	inn_label.name = "RoleConfig_InnLabel"
	inn_label.text = "Rest Cost (gold):"
	inn_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	npc_role_config_container.add_child(inn_label)

	innkeeper_cost_spin = SpinBox.new()
	innkeeper_cost_spin.name = "RoleConfig_InnCost"
	innkeeper_cost_spin.min_value = 0
	innkeeper_cost_spin.max_value = 9999
	innkeeper_cost_spin.value = npc_role_data.get("inn_cost", 50)
	npc_role_config_container.add_child(innkeeper_cost_spin)

	var spawn_label = Label.new()
	spawn_label.name = "RoleConfig_SpawnLabel"
	spawn_label.text = "Sets spawn point: Yes"
	spawn_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	npc_role_config_container.add_child(spawn_label)


func _update_npc_role_visibility():
	"""Show/hide NPC role UI based on current type"""
	var show_npc_ui = (current_type == "npc")

	# Find and update visibility of NPC role elements
	if stat_display_container:
		var sep = stat_display_container.find_child("NPCRoleSeparator", false)
		if sep: sep.visible = show_npc_ui
		var title = stat_display_container.find_child("NPCRoleTitle", false)
		if title: title.visible = show_npc_ui
		if npc_role_option: npc_role_option.visible = show_npc_ui
		if npc_role_config_container: npc_role_config_container.visible = show_npc_ui


func _set_npc_role_dropdown(role: String):
	"""Set NPC role dropdown to match the given role"""
	if not npc_role_option:
		return

	match role:
		"Generic": npc_role_option.selected = 0
		"Vendor": npc_role_option.selected = 1
		"Quest Giver": npc_role_option.selected = 2
		"Trainer": npc_role_option.selected = 3
		"Innkeeper": npc_role_option.selected = 4
		_: npc_role_option.selected = 0


func _on_non_combatant_toggled(pressed: bool):
	"""Handle non-combatant checkbox toggle"""
	is_non_combatant = pressed
	_update_combat_stats_visibility()
	print("[StatsPanel] Non-combatant: %s" % is_non_combatant)


func _update_combat_stats_visibility():
	"""Show/hide combat stats based on non-combatant setting"""
	if combat_stats_container:
		combat_stats_container.visible = not is_non_combatant


func _on_element_changed(_index: int):
	_on_stats_changed(0)


func _on_edit_mode_toggled():
	is_edit_mode = !is_edit_mode

	if is_edit_mode:
		edit_mode_button.text = "Auto"
		hp_label.visible = false
		mp_label.visible = false
		ep_label.visible = false
		hp_spin.visible = true
		mp_spin.visible = true
		ep_spin.visible = true

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
		edit_mode_button.text = "Edit"
		hp_label.visible = true
		mp_label.visible = true
		ep_label.visible = true
		hp_spin.visible = false
		mp_spin.visible = false
		ep_spin.visible = false
		_on_stats_changed(0)


func _on_manual_stat_changed(_value: float):
	if is_edit_mode:
		manual_hp = int(hp_spin.value)
		manual_mp = int(mp_spin.value)
		manual_ep = int(ep_spin.value)


func _calculate_hp() -> int:
	if not str_spin: return 50

	var str_val = int(str_spin.value)
	var vit_val = int(vit_spin.value)
	var level = int(level_spin.value)

	if current_type == "class":
		return 50 + int(vit_val * 2.5) + (str_val * 1) + int((level - 1) * 2.5)
	else:
		var base_hp = 50 + int(vit_val * 2.5)
		var multiplier = 1.0 + ((level - 1) * 0.10)
		return int(base_hp * multiplier)


func _calculate_mp() -> int:
	if not int_spin: return 50

	var int_val = int(int_spin.value)
	var wis_val = int(wis_spin.value)
	var level = int(level_spin.value)

	if current_type == "class":
		return 50 + (int_val * 5) + (wis_val * 2) + ((level - 1) * 3)
	else:
		var base_mp = 50 + (int_val * 5)
		var multiplier = 1.0 + ((level - 1) * 0.05)
		return int(base_mp * multiplier)


func _calculate_ep() -> int:
	if not dex_spin:
		return 30
	var dex_val = int(dex_spin.value)
	var level = int(level_spin.value)
	return 30 + (dex_val * 3) + ((level - 1) * 2)


func _on_role_dropdown_selected(index: int):
	if not role_description:
		return

	match index:
		0:
			role_description.text = "Melee: Frontline tank. 120px range, 100% move speed. Flanking: Front 1.0x, Side 1.15x, Back 1.30x. Standard melee fighter."
		1:
			role_description.text = "Ranged: Kiting specialist. 350px range with projectiles, 115% move speed. Flanking: Front 1.0x, Side 0.90x, Back 0.80x. Penalized when surrounded - must maintain distance!"
		2:
			role_description.text = "Caster: Glass cannon mage. 280px range with magic projectiles, 90% move speed (slow). Flanking: 1.25x ALL directions (+25% always). High damage, doesn't care about positioning."
		3:
			role_description.text = "Hybrid: Skilled duelist. 180px range, 105% move speed. Flanking: Front 1.0x, Side 1.25x, Back 1.50x (+50%!). Enhanced flanking rewards skilled positioning."


func _on_add_role_pressed():
	if not role_dropdown:
		return

	var index = role_dropdown.selected
	match index:
		0:
			selected_combat_role = "melee"  # Lowercase to match combat system
		1:
			selected_combat_role = "ranged"
		2:
			selected_combat_role = "caster"
		3:
			selected_combat_role = "hybrid"
		_:
			return

	update_combat_role_display()
	print("[StatsPanel] Combat role set to: ", selected_combat_role)


func update_combat_role_display():
	if current_role_label:
		if selected_combat_role == "":
			current_role_label.text = "Current Role: None"
		else:
			current_role_label.text = "Current Role: " + selected_combat_role


func _on_stats_changed(_value: float):
	if not str_spin:
		return

	var str_val = int(str_spin.value)
	var dex_val = int(dex_spin.value)
	var int_val = int(int_spin.value)
	var vit_val = int(vit_spin.value)
	var wis_val = int(wis_spin.value)
	var cha_val = int(cha_spin.value)

	var total = str_val + dex_val + int_val + vit_val + wis_val + cha_val
	total_label.text = "Total: %d (Typical: 60-80)" % total

	if total < 60:
		total_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	elif total > 80:
		total_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
	else:
		total_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))

	if not is_edit_mode:
		var hp = _calculate_hp()
		var mp = _calculate_mp()
		var ep = _calculate_ep()

		hp_label.text = "HP: %d" % hp
		mp_label.text = "MP: %d" % mp
		ep_label.text = "EP: %d" % ep

	# Emit stats changed signal
	stats_changed.emit(get_all_stats())


func get_all_stats() -> Dictionary:
	"""Return all current stat values as a dictionary"""
	var hp_value = manual_hp if is_edit_mode and manual_hp != -1 else _calculate_hp()
	var mp_value = manual_mp if is_edit_mode and manual_mp != -1 else _calculate_mp()
	var ep_value = manual_ep if is_edit_mode and manual_ep != -1 else _calculate_ep()

	var stats = {
		"element": element_option.selected if element_option else 0,
		"level": int(level_spin.value) if level_spin else 1,
		"str": int(str_spin.value) if str_spin else 10,
		"dex": int(dex_spin.value) if dex_spin else 10,
		"int": int(int_spin.value) if int_spin else 10,
		"vit": int(vit_spin.value) if vit_spin else 10,
		"wis": int(wis_spin.value) if wis_spin else 10,
		"cha": int(cha_spin.value) if cha_spin else 10,
		"hp": hp_value,
		"mp": mp_value,
		"ep": ep_value,
		"ai_archetype": ai_option.selected if ai_option else 0,
		"min_level": int(min_level_spin.value) if min_level_spin else 1,
		"max_level": int(max_level_spin.value) if max_level_spin else 1,
		"xp_reward": int(xp_spin.value) if xp_spin else 50,
		"gold_reward": int(gold_spin.value) if gold_spin else 10,
		"combat_role": selected_combat_role,
		"description": desc_text.text if desc_text else ""
	}

	# Add NPC role data if type is NPC
	if current_type == "npc":
		stats["npc_role"] = selected_npc_role
		stats["dialogue"] = dialogue_text.text if dialogue_text else ""
		stats["npc_role_data"] = _get_current_role_data()
		stats["is_non_combatant"] = is_non_combatant

	return stats


func _get_current_role_data() -> Dictionary:
	"""Collect role-specific data from UI elements"""
	var data = {}

	match selected_npc_role:
		"Vendor":
			if vendor_item_list:
				data["vendor_items"] = vendor_item_list.text
				data["inventory"] = _parse_vendor_items(vendor_item_list.text)
		"Quest Giver":
			if quest_id_list:
				data["quest_ids"] = quest_id_list.text
				data["quests"] = _parse_quest_ids(quest_id_list.text)
		"Trainer":
			if trainer_skill_list:
				data["trainer_skills"] = trainer_skill_list.text
				data["skills"] = _parse_trainer_skills(trainer_skill_list.text)
		"Innkeeper":
			if innkeeper_cost_spin:
				data["inn_cost"] = int(innkeeper_cost_spin.value)
				data["sets_spawn"] = true

	return data


func _parse_vendor_items(text: String) -> Array:
	"""Parse vendor item list into structured array"""
	var items = []
	for line in text.split("\n"):
		line = line.strip_edges()
		if line.is_empty():
			continue
		var parts = line.split(":")
		if parts.size() >= 2:
			items.append({"item_id": parts[0].strip_edges(), "price": int(parts[1])})
		else:
			items.append({"item_id": parts[0].strip_edges(), "price": 0})
	return items


func _parse_quest_ids(text: String) -> Array:
	"""Parse quest ID list into array"""
	var quests = []
	for line in text.split("\n"):
		line = line.strip_edges()
		if not line.is_empty():
			quests.append(line)
	return quests


func _parse_trainer_skills(text: String) -> Array:
	"""Parse trainer skill list into structured array"""
	var skills = []
	for line in text.split("\n"):
		line = line.strip_edges()
		if line.is_empty():
			continue
		var parts = line.split(":")
		if parts.size() >= 2:
			skills.append({"skill_id": parts[0].strip_edges(), "cost": int(parts[1])})
		else:
			skills.append({"skill_id": parts[0].strip_edges(), "cost": 0})
	return skills


func set_stats(data: Dictionary):
	"""Load stats from a dictionary into UI controls"""
	if element_option and data.has("element"):
		element_option.selected = data.element
	if level_spin and data.has("level"):
		level_spin.value = data.level
	if str_spin and data.has("str"):
		str_spin.value = data.str
	if dex_spin and data.has("dex"):
		dex_spin.value = data.dex
	if int_spin and data.has("int"):
		int_spin.value = data.int
	if vit_spin and data.has("vit"):
		vit_spin.value = data.vit
	if wis_spin and data.has("wis"):
		wis_spin.value = data.wis
	if cha_spin and data.has("cha"):
		cha_spin.value = data.cha
	if ai_option and data.has("ai_archetype"):
		ai_option.selected = data.ai_archetype
	if min_level_spin and data.has("min_level"):
		min_level_spin.value = data.min_level
	if max_level_spin and data.has("max_level"):
		max_level_spin.value = data.max_level
	if xp_spin and data.has("xp_reward"):
		xp_spin.value = data.xp_reward
	if gold_spin and data.has("gold_reward"):
		gold_spin.value = data.gold_reward
	if desc_text and data.has("description"):
		desc_text.text = data.description
	if data.has("combat_role"):
		selected_combat_role = data.combat_role
		update_combat_role_display()

	# Handle manual HP/MP/EP overrides
	if data.has("hp"):
		manual_hp = data.hp
	if data.has("mp"):
		manual_mp = data.mp
	if data.has("ep"):
		manual_ep = data.ep

	# Load NPC role data
	if data.has("npc_role"):
		selected_npc_role = data.npc_role
		_set_npc_role_dropdown(selected_npc_role)
	if data.has("dialogue") and dialogue_text:
		dialogue_text.text = data.dialogue
	if data.has("npc_role_data"):
		npc_role_data = data.npc_role_data
		_rebuild_role_config_ui()
	if data.has("is_non_combatant"):
		is_non_combatant = data.is_non_combatant
		if non_combatant_check:
			non_combatant_check.button_pressed = is_non_combatant
		_update_combat_stats_visibility()

	_on_stats_changed(0)


func reset():
	"""Reset all stats to defaults"""
	if element_option:
		element_option.selected = 0
	if level_spin:
		level_spin.value = 1
	if str_spin:
		str_spin.value = 10
	if dex_spin:
		dex_spin.value = 10
	if int_spin:
		int_spin.value = 10
	if vit_spin:
		vit_spin.value = 10
	if wis_spin:
		wis_spin.value = 10
	if cha_spin:
		cha_spin.value = 10
	if ai_option:
		ai_option.selected = 0
	if min_level_spin:
		min_level_spin.value = 1
	if max_level_spin:
		max_level_spin.value = 1
	if xp_spin:
		xp_spin.value = 50
	if gold_spin:
		gold_spin.value = 10
	if desc_text:
		desc_text.text = ""

	selected_combat_role = ""
	manual_hp = -1
	manual_mp = -1
	manual_ep = -1
	is_edit_mode = false

	if edit_mode_button:
		edit_mode_button.text = "Edit"
	if hp_label:
		hp_label.visible = true
	if mp_label:
		mp_label.visible = true
	if ep_label:
		ep_label.visible = true
	if hp_spin:
		hp_spin.visible = false
	if mp_spin:
		mp_spin.visible = false
	if ep_spin:
		ep_spin.visible = false

	update_combat_role_display()

	# Reset NPC role
	selected_npc_role = "Generic"
	npc_role_data = {}
	is_non_combatant = false
	if npc_role_option:
		npc_role_option.selected = 0
	if non_combatant_check:
		non_combatant_check.button_pressed = false
	if dialogue_text:
		dialogue_text.text = ""
	_rebuild_role_config_ui()
	_update_combat_stats_visibility()

	_on_stats_changed(0)
