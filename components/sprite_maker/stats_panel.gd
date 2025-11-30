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
	ai_title.add_theme_color_override("font_color", Color(0.5, 1.0, 1.0))
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
	reward_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
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

	print("[StatsPanel] Stat display UI created SUCCESSFULLY")


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
			role_description.text = "Melee: Full damage in front row. 50% damage in back row. 25% damage minimum when back row attacks back row. Normal defense."
		1:
			role_description.text = "Ranged: Full damage in back row. 50% damage in front row (forced melee). Normal defense."
		2:
			role_description.text = "Caster: Full damage from any position (can melee OR cast). Takes 20% EXTRA damage (weak defense)."
		3:
			role_description.text = "Hybrid: 80% damage from any position (versatile). Takes 20% EXTRA damage (weak defense)."


func _on_add_role_pressed():
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

	return {
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
	_on_stats_changed(0)
