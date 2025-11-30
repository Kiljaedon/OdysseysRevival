extends "res://draggable_panel.gd"

@onready var name_label = $Content/Columns/ProfileCol/InfoBox/NameLabel
@onready var class_label = $Content/Columns/ProfileCol/InfoBox/ClassLabel
@onready var element_label = $Content/Columns/ProfileCol/InfoBox/ElementLabel
@onready var portrait = $Content/Columns/ProfileCol/PortraitFrame/Portrait

@onready var hp_label = $Content/Columns/StatsCol/VitalsBox/HPLabel
@onready var hp_bar = $Content/Columns/StatsCol/VitalsBox/HPBar
@onready var mp_label = $Content/Columns/StatsCol/VitalsBox/MPLabel
@onready var mp_bar = $Content/Columns/StatsCol/VitalsBox/MPBar
@onready var xp_label = $Content/Columns/StatsCol/VitalsBox/XPLabel
@onready var xp_bar = $Content/Columns/StatsCol/VitalsBox/XPBar

@onready var str_label = $Content/Columns/StatsCol/AttributesBox/StrLabel
@onready var dex_label = $Content/Columns/StatsCol/AttributesBox/DexLabel
@onready var int_label = $Content/Columns/StatsCol/AttributesBox/IntLabel
@onready var vit_label = $Content/Columns/StatsCol/AttributesBox/VitLabel
@onready var wis_label = $Content/Columns/StatsCol/AttributesBox/WisLabel
@onready var cha_label = $Content/Columns/StatsCol/AttributesBox/ChaLabel

var multiplayer_manager: MultiplayerManager = null

func _ready():
	super._ready() # Call DraggablePanel _ready
	
	# Start hidden
	visible = false
	panel_title = "CHARACTER SHEET"
	
	# Find multiplayer manager
	# If we are in DevUI, parent is DevUI, grandparent is DevClient
	var dev_client = get_tree().root.find_child("DevClient", true, false)
	if dev_client:
		multiplayer_manager = dev_client.get_node_or_null("MultiplayerManager")

func toggle():
	visible = !visible
	if visible:
		# Center on screen if first open
		if position == Vector2.ZERO:
			position = (get_viewport_rect().size - size) / 2
		update_ui()

func update_ui():
	if not multiplayer_manager:
		return

	var data = multiplayer_manager.current_character_data
	if data.is_empty():
		return

	# Profile
	name_label.text = data.get("name", "Unknown")
	var level = data.get("level", 1)
	var cls = data.get("class_name", "Warrior")
	class_label.text = "Level %d %s" % [level, cls]
	element_label.text = "Element: " + data.get("element", "None")
	
	# Stats
	var stats = data.get("stats", {})
	str_label.text = "STR: %d" % stats.get("str", 10)
	dex_label.text = "DEX: %d" % stats.get("dex", 10)
	int_label.text = "INT: %d" % stats.get("int", 10)
	vit_label.text = "VIT: %d" % stats.get("vit", 10)
	wis_label.text = "WIS: %d" % stats.get("wis", 10)
	cha_label.text = "CHA: %d" % stats.get("cha", 10)
	
	# Vitals
	var hp = data.get("hp", 100)
	var max_hp = data.get("max_hp", 100)
	hp_label.text = "HP: %d / %d" % [hp, max_hp]
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	
	var mp = data.get("mp", 50)
	var max_mp = data.get("max_mp", 50)
	mp_label.text = "MP: %d / %d" % [mp, max_mp]
	mp_bar.max_value = max_mp
	mp_bar.value = mp
	
	# XP
	var xp = data.get("xp", 0)
	var next_level_xp = level * 100
	xp_label.text = "XP: %d / %d" % [xp, next_level_xp]
	xp_bar.max_value = next_level_xp
	xp_bar.value = xp
