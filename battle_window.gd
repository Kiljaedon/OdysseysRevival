extends Control

# Atlas textures for sprite loading
var sprite_atlas_textures: Array = []
const SPRITE_SIZE = 32
const ROWS_PER_ATLAS = 322
const COLS_PER_ROW = 12

# UI References - Enemies (6 total)
@onready var enemy_sprites = [
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel1/EnemyUnit1/EnemySprite1,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel2/EnemyUnit2/EnemySprite2,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel3/EnemyUnit3/EnemySprite3,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel4/EnemyUnit4/EnemySprite4,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel5/EnemyUnit5/EnemySprite5,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel6/EnemyUnit6/EnemySprite6
]
@onready var enemy_names = [
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel1/EnemyUnit1/EnemyName1,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel2/EnemyUnit2/EnemyName2,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel3/EnemyUnit3/EnemyName3,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel4/EnemyUnit4/EnemyName4,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel5/EnemyUnit5/EnemyName5,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel6/EnemyUnit6/EnemyName6
]
@onready var enemy_hp_bars = [
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel1/EnemyUnit1/EnemyHPBar1,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel2/EnemyUnit2/EnemyHPBar2,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel3/EnemyUnit3/EnemyHPBar3,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel4/EnemyUnit4/EnemyHPBar4,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel5/EnemyUnit5/EnemyHPBar5,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel6/EnemyUnit6/EnemyHPBar6
]
@onready var enemy_hp_labels = [
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel1/EnemyUnit1/EnemyHPLabel1,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel2/EnemyUnit2/EnemyHPLabel2,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel3/EnemyUnit3/EnemyHPLabel3,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel4/EnemyUnit4/EnemyHPLabel4,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel5/EnemyUnit5/EnemyHPLabel5,
	$BattleContainer/CombatArea/EnemyArea/EnemyPanel6/EnemyUnit6/EnemyHPLabel6
]

# UI References - Allies (6 total)
@onready var ally_sprites = [
	$BattleContainer/CombatArea/PlayerArea/Ally1Panel/Ally1Unit/Ally1Sprite,
	$BattleContainer/CombatArea/PlayerArea/Ally2Panel/Ally2Unit/Ally2Sprite,
	$BattleContainer/CombatArea/PlayerArea/Ally3Panel/Ally3Unit/Ally3Sprite,
	$BattleContainer/CombatArea/PlayerArea/Ally4Panel/Ally4Unit/Ally4Sprite,
	$BattleContainer/CombatArea/PlayerArea/Ally5Panel/Ally5Unit/Ally5Sprite,
	$BattleContainer/CombatArea/PlayerArea/Ally6Panel/Ally6Unit/Ally6Sprite
]
@onready var ally_names = [
	$BattleContainer/CombatArea/PlayerArea/Ally1Panel/Ally1Unit/Ally1Name,
	$BattleContainer/CombatArea/PlayerArea/Ally2Panel/Ally2Unit/Ally2Name,
	$BattleContainer/CombatArea/PlayerArea/Ally3Panel/Ally3Unit/Ally3Name,
	$BattleContainer/CombatArea/PlayerArea/Ally4Panel/Ally4Unit/Ally4Name,
	$BattleContainer/CombatArea/PlayerArea/Ally5Panel/Ally5Unit/Ally5Name,
	$BattleContainer/CombatArea/PlayerArea/Ally6Panel/Ally6Unit/Ally6Name
]
@onready var ally_hp_bars = [
	$BattleContainer/CombatArea/PlayerArea/Ally1Panel/Ally1Unit/Ally1HPBar,
	$BattleContainer/CombatArea/PlayerArea/Ally2Panel/Ally2Unit/Ally2HPBar,
	$BattleContainer/CombatArea/PlayerArea/Ally3Panel/Ally3Unit/Ally3HPBar,
	$BattleContainer/CombatArea/PlayerArea/Ally4Panel/Ally4Unit/Ally4HPBar,
	$BattleContainer/CombatArea/PlayerArea/Ally5Panel/Ally5Unit/Ally5HPBar,
	$BattleContainer/CombatArea/PlayerArea/Ally6Panel/Ally6Unit/Ally6HPBar
]
@onready var ally_hp_labels = [
	$BattleContainer/CombatArea/PlayerArea/Ally1Panel/Ally1Unit/Ally1HPLabel,
	$BattleContainer/CombatArea/PlayerArea/Ally2Panel/Ally2Unit/Ally2HPLabel,
	$BattleContainer/CombatArea/PlayerArea/Ally3Panel/Ally3Unit/Ally3HPLabel,
	$BattleContainer/CombatArea/PlayerArea/Ally4Panel/Ally4Unit/Ally4HPLabel,
	$BattleContainer/CombatArea/PlayerArea/Ally5Panel/Ally5Unit/Ally5HPLabel,
	$BattleContainer/CombatArea/PlayerArea/Ally6Panel/Ally6Unit/Ally6HPLabel
]
@onready var ally_mp_bars = [
	$BattleContainer/CombatArea/PlayerArea/Ally1Panel/Ally1Unit/Ally1MPBar,
	$BattleContainer/CombatArea/PlayerArea/Ally2Panel/Ally2Unit/Ally2MPBar,
	$BattleContainer/CombatArea/PlayerArea/Ally3Panel/Ally3Unit/Ally3MPBar,
	$BattleContainer/CombatArea/PlayerArea/Ally4Panel/Ally4Unit/Ally4MPBar,
	$BattleContainer/CombatArea/PlayerArea/Ally5Panel/Ally5Unit/Ally5MPBar,
	$BattleContainer/CombatArea/PlayerArea/Ally6Panel/Ally6Unit/Ally6MPBar
]
@onready var ally_mp_labels = [
	$BattleContainer/CombatArea/PlayerArea/Ally1Panel/Ally1Unit/Ally1MPLabel,
	$BattleContainer/CombatArea/PlayerArea/Ally2Panel/Ally2Unit/Ally2MPLabel,
	$BattleContainer/CombatArea/PlayerArea/Ally3Panel/Ally3Unit/Ally3MPLabel,
	$BattleContainer/CombatArea/PlayerArea/Ally4Panel/Ally4Unit/Ally4MPLabel,
	$BattleContainer/CombatArea/PlayerArea/Ally5Panel/Ally5Unit/Ally5MPLabel,
	$BattleContainer/CombatArea/PlayerArea/Ally6Panel/Ally6Unit/Ally6MPLabel
]

# UI References - Action Buttons
@onready var turn_info = $UIPanel/UIArea/TurnInfo
@onready var attack_button = $UIPanel/UIArea/ActionButtons/AttackButton
@onready var defend_button = $UIPanel/UIArea/ActionButtons/DefendButton
@onready var skills_button = $UIPanel/UIArea/ActionButtons/SkillsButton
@onready var items_button = $UIPanel/UIArea/ActionButtons/ItemsButton
@onready var save_layout_button = $UIPanel/UIArea/LayoutButtons/SaveLayoutButton
@onready var reset_layout_button = $UIPanel/UIArea/LayoutButtons/ResetLayoutButton
@onready var pause_button = $UIPanel/UIArea/LayoutButtons/PauseButton

# UI References - Draggable Panels
@onready var enemy_panel_1 = $BattleContainer/CombatArea/EnemyArea/EnemyPanel1
@onready var enemy_panel_2 = $BattleContainer/CombatArea/EnemyArea/EnemyPanel2
@onready var enemy_panel_3 = $BattleContainer/CombatArea/EnemyArea/EnemyPanel3
@onready var enemy_panel_4 = $BattleContainer/CombatArea/EnemyArea/EnemyPanel4
@onready var enemy_panel_5 = $BattleContainer/CombatArea/EnemyArea/EnemyPanel5
@onready var enemy_panel_6 = $BattleContainer/CombatArea/EnemyArea/EnemyPanel6
@onready var ally_panel_1 = $BattleContainer/CombatArea/PlayerArea/Ally1Panel
@onready var ally_panel_2 = $BattleContainer/CombatArea/PlayerArea/Ally2Panel
@onready var ally_panel_3 = $BattleContainer/CombatArea/PlayerArea/Ally3Panel
@onready var ally_panel_4 = $BattleContainer/CombatArea/PlayerArea/Ally4Panel
@onready var ally_panel_5 = $BattleContainer/CombatArea/PlayerArea/Ally5Panel
@onready var ally_panel_6 = $BattleContainer/CombatArea/PlayerArea/Ally6Panel
@onready var ui_panel = $UIPanel

# Default panel positions (for reset) - 2 rows of 3 mirrored formation (6v6)
# NOTE: Positions are LOCAL to parent container (EnemyArea or PlayerArea), not global viewport
const DEFAULT_POSITIONS = {
	# LEFT SIDE (EnemyArea) - Front row of 3, Back row of 3
	# Enemies face RIGHT toward player/allies
	# Local coords within 600px wide EnemyArea
	"enemy_panel_1": {"position": Vector2(240, 60), "size": Vector2(170, 290)},    # Front top
	"enemy_panel_2": {"position": Vector2(240, 220), "size": Vector2(170, 290)},   # Front middle
	"enemy_panel_3": {"position": Vector2(240, 380), "size": Vector2(170, 290)},   # Front bottom
	"enemy_panel_4": {"position": Vector2(60, 60), "size": Vector2(170, 290)},     # Back top
	"enemy_panel_5": {"position": Vector2(60, 220), "size": Vector2(170, 290)},    # Back middle
	"enemy_panel_6": {"position": Vector2(60, 380), "size": Vector2(170, 290)},    # Back bottom

	# RIGHT SIDE (PlayerArea/Allies) - Front row of 3, Back row of 3 (MIRRORED)
	# Player/Allies face LEFT toward enemies
	# Local coords within 300px wide PlayerArea (mirrored from enemy positions)
	"ally_panel_1": {"position": Vector2(10, 60), "size": Vector2(170, 320)},      # Front top (closer to enemies)
	"ally_panel_2": {"position": Vector2(10, 220), "size": Vector2(170, 320)},     # Front middle
	"ally_panel_3": {"position": Vector2(10, 380), "size": Vector2(170, 320)},     # Front bottom
	"ally_panel_4": {"position": Vector2(120, 60), "size": Vector2(170, 320)},     # Back top (further from enemies, x+170=290 fits in 300px)
	"ally_panel_5": {"position": Vector2(120, 220), "size": Vector2(170, 320)},    # Back middle
	"ally_panel_6": {"position": Vector2(120, 380), "size": Vector2(170, 320)},    # Back bottom

	"ui_panel": {"position": Vector2(300, 500), "size": Vector2(680, 180)}
}

# Battle data
var player_character: Dictionary = {}
var enemy_squad: Array = []
var ally_squad: Array = []
var turn_order: Array = []
var current_turn_index: int = 0
var is_player_turn: bool = false
var is_paused: bool = true  # Start paused for manual positioning

# Manual positioning system
var selected_panel: Panel = null
var all_battle_panels: Array = []

# Keyboard navigation
var selected_button_index: int = 0
var action_buttons: Array = []

func _ready():
	print("Battle window initialized")

	# Load atlas textures
	load_sprite_atlases()

	# Connect action buttons
	if attack_button:
		attack_button.pressed.connect(_on_attack_pressed)
	if defend_button:
		defend_button.pressed.connect(_on_defend_pressed)
	if skills_button:
		skills_button.pressed.connect(_on_skills_pressed)
	if items_button:
		items_button.pressed.connect(_on_items_pressed)

	# Setup action buttons array for keyboard navigation
	action_buttons = [attack_button, defend_button, skills_button, items_button]

	# Connect save layout button
	if save_layout_button:
		save_layout_button.pressed.connect(_on_save_layout_pressed)

	# Connect reset layout button
	if reset_layout_button:
		reset_layout_button.pressed.connect(_on_reset_layout_pressed)

	# Connect pause button
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
		update_pause_button_text()

	# Setup manual positioning system
	setup_manual_positioning()

	# Setup battle
	setup_battle()

	# Link enemy panels to character data for animation cycling
	# Enemies on LEFT side face RIGHT toward player/allies
	enemy_panel_1.character_data = enemy_squad[0] if enemy_squad.size() > 0 else {}
	enemy_panel_1.battle_window = self
	enemy_panel_1.current_direction = "right"
	enemy_panel_1.apply_character_animation("walk_right_1")
	enemy_panel_2.character_data = enemy_squad[1] if enemy_squad.size() > 1 else {}
	enemy_panel_2.battle_window = self
	enemy_panel_2.current_direction = "right"
	enemy_panel_2.apply_character_animation("walk_right_1")
	enemy_panel_3.character_data = enemy_squad[2] if enemy_squad.size() > 2 else {}
	enemy_panel_3.battle_window = self
	enemy_panel_3.current_direction = "right"
	enemy_panel_3.apply_character_animation("walk_right_1")
	enemy_panel_4.character_data = enemy_squad[3] if enemy_squad.size() > 3 else {}
	enemy_panel_4.battle_window = self
	enemy_panel_4.current_direction = "right"
	enemy_panel_4.apply_character_animation("walk_right_1")
	enemy_panel_5.character_data = enemy_squad[4] if enemy_squad.size() > 4 else {}
	enemy_panel_5.battle_window = self
	enemy_panel_5.current_direction = "right"
	enemy_panel_5.apply_character_animation("walk_right_1")
	enemy_panel_6.character_data = enemy_squad[5] if enemy_squad.size() > 5 else {}
	enemy_panel_6.battle_window = self
	enemy_panel_6.current_direction = "right"
	enemy_panel_6.apply_character_animation("walk_right_1")

	# Link ally panels to ally squad data (includes player as ally[4])
	# Player/Allies on RIGHT side face LEFT toward enemies
	ally_panel_1.character_data = ally_squad[0] if ally_squad.size() > 0 else {}
	ally_panel_1.battle_window = self
	ally_panel_1.current_direction = "left"
	ally_panel_1.apply_character_animation("walk_left_1")
	ally_panel_2.character_data = ally_squad[1] if ally_squad.size() > 1 else {}
	ally_panel_2.battle_window = self
	ally_panel_2.current_direction = "left"
	ally_panel_2.apply_character_animation("walk_left_1")
	ally_panel_3.character_data = ally_squad[2] if ally_squad.size() > 2 else {}
	ally_panel_3.battle_window = self
	ally_panel_3.current_direction = "left"
	ally_panel_3.apply_character_animation("walk_left_1")
	ally_panel_4.character_data = ally_squad[3] if ally_squad.size() > 3 else {}
	ally_panel_4.battle_window = self
	ally_panel_4.current_direction = "left"
	ally_panel_4.apply_character_animation("walk_left_1")
	ally_panel_5.character_data = ally_squad[4] if ally_squad.size() > 4 else {}
	ally_panel_5.battle_window = self
	ally_panel_5.current_direction = "left"
	ally_panel_5.apply_character_animation("walk_left_1")
	ally_panel_6.character_data = ally_squad[5] if ally_squad.size() > 5 else {}
	ally_panel_6.battle_window = self
	ally_panel_6.current_direction = "left"
	ally_panel_6.apply_character_animation("walk_left_1")

	# Reset to default layout (ignore old saves with incorrect positions)
	reset_battle_layout()

func load_sprite_atlases():
	"""Load sprite atlas textures for character rendering"""
	var atlas1 = load("res://assets-odyssey/sprites_part1.png")
	var atlas2 = load("res://assets-odyssey/sprites_part2.png")

	if atlas1 and atlas2:
		sprite_atlas_textures.append(atlas1)
		sprite_atlas_textures.append(atlas2)
		print("✓ Loaded sprite atlases")
	else:
		print("ERROR: Could not load sprite atlases")

func _input(event: InputEvent):
	"""Handle keyboard input for battle actions"""
	if not is_player_turn:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			# WASD and Arrow key navigation
			KEY_A, KEY_LEFT, KEY_W, KEY_UP:
				# Move selection left/up
				selected_button_index = (selected_button_index - 1 + action_buttons.size()) % action_buttons.size()
				update_button_selection()
				get_viewport().set_input_as_handled()
			KEY_D, KEY_RIGHT, KEY_S, KEY_DOWN:
				# Move selection right/down
				selected_button_index = (selected_button_index + 1) % action_buttons.size()
				update_button_selection()
				get_viewport().set_input_as_handled()
			KEY_SPACE, KEY_ENTER:
				# Activate selected button (Space or Enter)
				if action_buttons[selected_button_index] and not action_buttons[selected_button_index].disabled:
					action_buttons[selected_button_index].emit_signal("pressed")
					get_viewport().set_input_as_handled()
			# Number keys 1-4 for direct selection
			KEY_1:
				if not attack_button.disabled:
					_on_attack_pressed()
			KEY_2:
				if not defend_button.disabled:
					_on_defend_pressed()
			KEY_3:
				if not skills_button.disabled:
					_on_skills_pressed()
			KEY_4:
				if not items_button.disabled:
					_on_items_pressed()

func update_button_selection():
	"""Update visual feedback for selected button"""
	for i in range(action_buttons.size()):
		if action_buttons[i]:
			if i == selected_button_index:
				action_buttons[i].grab_focus()
			else:
				action_buttons[i].release_focus()

func setup_battle():
	"""Initialize battle with 6v6 (player + 5 allies vs 6 enemies)"""
	# Load 6 random enemies
	load_enemy_squad()

	# Load 6 allies (player + 5 NPCs)
	load_ally_squad()

	# Calculate turn order based on DEX
	calculate_turn_order()

	# Update UI
	update_all_enemies_ui()
	update_all_allies_ui()

	# Don't start animations or turns when paused
	if not is_paused:
		start_next_turn()
	else:
		print("
========================================")
		print("DEBUG MODE - BATTLE PAUSED")
		print("========================================")
		print("No auto-attacks will occur")
		print("Click panels to position characters")
		print("Use WASD to move sprites")
		print("Use mouse wheel or -/+ to zoom")
		print("Click 'Save Layout' to record positions")
		print("Click 'Resume Battle' when ready to test combat")
		print("========================================
")
		turn_info.text = "DEBUG MODE: PAUSED"

func load_player_character():
	"""Load player character from temporary file"""
	var temp_file_path = "user://selected_character.json"

	if FileAccess.file_exists(temp_file_path):
		var file = FileAccess.open(temp_file_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			if json.parse(json_text) == OK:
				player_character = json.data

				# Initialize current HP/MP if not present
				if not player_character.has("hp"):
					if player_character.has("derived_stats"):
						player_character["hp"] = player_character.derived_stats.get("max_hp", 100)
					else:
						player_character["hp"] = 100
				if not player_character.has("mp"):
					if player_character.has("derived_stats"):
						player_character["mp"] = player_character.derived_stats.get("max_mp", 50)
					else:
						player_character["mp"] = 50

				print("✓ Loaded player character: ", player_character.get("character_name", "Unknown"))
			else:
				print("ERROR: Failed to parse player character JSON")
				create_default_player()
	else:
		print("WARN: No selected character found, using default")
		create_default_player()

func create_default_player():
	"""Create a default player for testing"""
	player_character = {
		"character_name": "Test Hero",
		"class_template": "Warrior",
		"type": "player",
		"element": "Fire",
		"level": 1,
		"base_stats": {
			"str": 15,
			"dex": 12,
			"int": 8,
			"vit": 14,
			"wis": 8,
			"cha": 10
		},
		"derived_stats": {
			"max_hp": 178,
			"max_mp": 108,
			"max_ep": 66
		},
		"animations": {}
	}
	# Set current HP/MP to max
	player_character["hp"] = player_character.derived_stats.get("max_hp", 178)
	player_character["mp"] = player_character.derived_stats.get("max_mp", 108)

func load_enemy_squad():
	"""Load 6 random NPCs from characters/npcs/ directory"""
	var npcs_dir = "res://characters/npcs/"
	var dir = DirAccess.open(npcs_dir)

	if not dir:
		print("ERROR: Could not open NPCs directory")
		return

	# Collect all NPC files
	var npc_files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			npc_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("Found ", npc_files.size(), " NPC files")

	# Select 6 random NPCs
	npc_files.shuffle()
	for i in range(min(6, npc_files.size())):
		var npc_path = npcs_dir + npc_files[i]
		var npc_data = load_character_file(npc_path)
		if npc_data:
			# Set current HP to max
			if npc_data.has("derived_stats"):
				npc_data["hp"] = npc_data.derived_stats.get("max_hp", 100)
				npc_data["mp"] = npc_data.derived_stats.get("max_mp", 50)
			else:
				npc_data["hp"] = 100
				npc_data["mp"] = 50
			enemy_squad.append(npc_data)
			print("  Loaded enemy: ", npc_data.get("character_name", "Unknown"))

func load_ally_squad():
	"""Load 6 allies: player character + 5 random NPCs"""
	# First, load the player character
	load_player_character()
	if player_character:
		ally_squad.append(player_character)
		print("  Loaded ally (player): ", player_character.get("character_name", "Unknown"))

	# Then load 5 random NPCs
	var npcs_dir = "res://characters/npcs/"
	var dir = DirAccess.open(npcs_dir)

	if not dir:
		print("ERROR: Could not open NPCs directory for allies")
		return

	# Collect all NPC files
	var npc_files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			npc_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("Found ", npc_files.size(), " NPC files for allies")

	# Select 5 random NPCs for remaining allies
	npc_files.shuffle()
	for i in range(min(5, npc_files.size())):
		var npc_path = npcs_dir + npc_files[i]
		var npc_data = load_character_file(npc_path)
		if npc_data:
			# Set current HP to max
			if npc_data.has("derived_stats"):
				npc_data["hp"] = npc_data.derived_stats.get("max_hp", 100)
				npc_data["mp"] = npc_data.derived_stats.get("max_mp", 50)
			else:
				npc_data["hp"] = 100
				npc_data["mp"] = 50
			ally_squad.append(npc_data)
			print("  Loaded ally (NPC): ", npc_data.get("character_name", "Unknown"))

func load_character_file(path: String) -> Dictionary:
	"""Load character data from JSON file"""
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) == OK:
		return json.data
	else:
		print("ERROR: Failed to parse ", path)
		return {}

func calculate_turn_order():
	"""Calculate turn order based on DEX stat (ATR system)"""
	turn_order.clear()

	# Add player
	var player_dex = 10
	if player_character.has("base_stats") and player_character.base_stats.has("dex"):
		player_dex = player_character.base_stats.dex
	turn_order.append({"type": "player", "data": player_character, "dex": player_dex})

	# Add enemies
	for enemy in enemy_squad:
		var enemy_dex = 10
		if enemy.has("base_stats") and enemy.base_stats.has("dex"):
			enemy_dex = enemy.base_stats.dex
		turn_order.append({"type": "enemy", "data": enemy, "dex": enemy_dex})

	# Sort by DEX (highest first)
	turn_order.sort_custom(func(a, b): return a.dex > b.dex)

	print("Turn order calculated:")
	for unit in turn_order:
		print("  ", unit.data.get("character_name", "Unknown"), " (DEX: ", unit.dex, ")")

func update_all_enemies_ui():
	"""Update all enemy UI displays"""
	for i in range(min(6, enemy_squad.size())):
		update_enemy_ui(i)

func update_enemy_ui(index: int):
	"""Update specific enemy UI"""
	if index >= enemy_squad.size():
		return

	var enemy = enemy_squad[index]

	# Name
	if enemy_names[index]:
		enemy_names[index].text = enemy.get("character_name", "Enemy")

	# HP Bar
	var max_hp = 100
	if enemy.has("derived_stats"):
		max_hp = enemy.derived_stats.get("max_hp", 100)
	var current_hp = enemy.get("hp", max_hp)
	if enemy_hp_bars[index]:
		enemy_hp_bars[index].max_value = max_hp
		enemy_hp_bars[index].value = current_hp
	if enemy_hp_labels[index]:
		enemy_hp_labels[index].text = "HP: %d / %d" % [current_hp, max_hp]

	# Load sprite
	load_character_sprite(enemy, enemy_sprites[index])

func update_all_allies_ui():
	"""Update all ally UI displays"""
	for i in range(min(6, ally_squad.size())):
		update_ally_ui(i)

func update_ally_ui(index: int):
	"""Update specific ally UI"""
	if index >= ally_squad.size():
		return

	var ally = ally_squad[index]

	# Name
	if ally_names[index]:
		ally_names[index].text = ally.get("character_name", "Ally")

	# HP Bar
	var max_hp = 100
	if ally.has("derived_stats"):
		max_hp = ally.derived_stats.get("max_hp", 100)
	var current_hp = ally.get("hp", max_hp)
	if ally_hp_bars[index]:
		ally_hp_bars[index].max_value = max_hp
		ally_hp_bars[index].value = current_hp
	if ally_hp_labels[index]:
		ally_hp_labels[index].text = "HP: %d / %d" % [current_hp, max_hp]

	# MP Bar
	var max_mp = 50
	if ally.has("derived_stats"):
		max_mp = ally.derived_stats.get("max_mp", 50)
	var current_mp = ally.get("mp", max_mp)
	if ally_mp_bars[index]:
		ally_mp_bars[index].max_value = max_mp
		ally_mp_bars[index].value = current_mp
	if ally_mp_labels[index]:
		ally_mp_labels[index].text = "MP: %d / %d" % [current_mp, max_mp]

	# Load sprite
	load_character_sprite(ally, ally_sprites[index])

func load_character_sprite(character: Dictionary, sprite_node: TextureRect):
	"""Load character sprite from animation data (walk_down_1 for idle)"""
	if not character.has("animations"):
		print("WARN: Character has no animations")
		return

	if not character.animations.has("walk_down_1"):
		print("WARN: Character missing walk_down_1 animation")
		return

	var walk_down_frames = character.animations["walk_down_1"]
	if walk_down_frames.size() == 0:
		print("WARN: walk_down_1 animation is empty")
		return

	# Get first frame of walk_down_1
	var frame_data = walk_down_frames[0]
	var atlas_index = frame_data.get("atlas_index", 0)
	var row = frame_data.get("row", 0)
	var col = frame_data.get("col", 0)

	# Create texture from atlas
	var texture = get_sprite_texture_from_coords(atlas_index, row, col)
	if texture:
		sprite_node.texture = texture
		print("✓ Loaded sprite for ", character.get("character_name", "Unknown"))
	else:
		print("ERROR: Failed to create sprite texture")

func get_sprite_texture_from_coords(atlas_index: int, row: int, col: int) -> Texture2D:
	"""Create texture from sprite atlas coordinates"""
	if atlas_index >= sprite_atlas_textures.size():
		print("ERROR: Invalid atlas index: ", atlas_index)
		return null

	var atlas_texture = sprite_atlas_textures[atlas_index]
	var local_row = row if row < ROWS_PER_ATLAS else row - ROWS_PER_ATLAS

	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = atlas_texture
	atlas_tex.region = Rect2(
		col * SPRITE_SIZE,
		local_row * SPRITE_SIZE,
		SPRITE_SIZE,
		SPRITE_SIZE
	)

	return atlas_tex

func start_next_turn():
	"""Start the next unit's turn"""
	# Don't start turns if paused
	if is_paused:
		return
	
	if current_turn_index >= turn_order.size():
		# Round complete, restart
		current_turn_index = 0
		print("=== New Round ===")

	var current_unit = turn_order[current_turn_index]

	if current_unit.type == "player":
		start_player_turn()
	else:
		start_enemy_turn(current_unit)

func start_player_turn():
	"""Start player's turn"""
	is_player_turn = true
	turn_info.text = "Your Turn! Choose an action:"

	# Enable action buttons
	attack_button.disabled = false
	defend_button.disabled = false
	skills_button.disabled = false
	items_button.disabled = false

	# Select first button for keyboard navigation
	selected_button_index = 0
	update_button_selection()

	print("Player's turn")

func start_enemy_turn(enemy_unit: Dictionary):
	"""Start enemy's turn"""
	is_player_turn = false
	var enemy_name = enemy_unit.data.get("character_name", "Enemy")
	turn_info.text = enemy_name + " is acting..."

	# Disable action buttons and clear focus
	attack_button.disabled = true
	defend_button.disabled = true
	skills_button.disabled = true
	items_button.disabled = true

	# Clear button focus
	for button in action_buttons:
		if button:
			button.release_focus()

	print(enemy_name, "'s turn")

	# Execute enemy AI after short delay
	await get_tree().create_timer(1.0).timeout
	execute_enemy_ai(enemy_unit)

func execute_enemy_ai(enemy_unit: Dictionary):
	"""Execute enemy AI (simple attack for now)"""
	# Player is now ally index 4 (Ally5)
	var player_ally_index = 4

	# Find which enemy index this is
	var enemy_index = -1
	for i in range(enemy_squad.size()):
		if enemy_squad[i] == enemy_unit.data:
			enemy_index = i
			break

	# Show attack animation (facing right toward player)
	if enemy_index >= 0:
		await play_attack_animation(enemy_sprites[enemy_index], enemy_unit.data, "attack_right", ally_sprites[player_ally_index])

	# Enemy attacks player
	var damage = calculate_damage(enemy_unit.data, player_character)
	player_character.hp -= damage
	player_character.hp = max(0, player_character.hp)

	turn_info.text = enemy_unit.data.get("character_name", "Enemy") + " attacks for " + str(damage) + " damage!"

	# Show damage number on player
	show_damage_number(ally_sprites[player_ally_index].global_position, damage)

	# Spawn impact particles at hit location
	spawn_impact_particles(ally_sprites[player_ally_index].global_position)

	# Hit flash effect
	play_hit_flash(ally_sprites[player_ally_index])

	# Screen shake (stronger for player damage)
	screen_shake(12.0, 0.3)

	# Animate HP bar update
	var max_hp = 100
	if player_character.has("derived_stats"):
		max_hp = player_character.derived_stats.get("max_hp", 100)
	animate_hp_bar(ally_hp_bars[player_ally_index], player_character.hp, max_hp)
	update_hp_bar_color(ally_hp_bars[player_ally_index], player_character.hp, max_hp)
	update_ally_ui(player_ally_index)

	print(enemy_unit.data.get("character_name", "Enemy"), " dealt ", damage, " damage to player")

	# Check if player defeated
	if player_character.hp <= 0:
		end_battle(false)
		return

	# Next turn after delay
	await get_tree().create_timer(1.5).timeout
	current_turn_index += 1
	start_next_turn()

func calculate_damage(attacker: Dictionary, defender: Dictionary) -> int:
	"""Calculate damage using STAT_SYSTEM.md formulas"""
	var attacker_str = 10
	var defender_vit = 10

	if attacker.has("base_stats"):
		attacker_str = attacker.base_stats.get("str", 10)
	if defender.has("base_stats"):
		defender_vit = defender.base_stats.get("vit", 10)

	# Physical Damage = (STR * 2) - (VIT / 2)
	var base_damage = (attacker_str * 2) - int(defender_vit / 2.0)

	# Minimum 1 damage
	return max(1, base_damage)

func _on_attack_pressed():
	"""Player chooses to attack"""
	if not is_player_turn:
		return

	# Attack first alive enemy
	for i in range(enemy_squad.size()):
		if enemy_squad[i].hp > 0:
			execute_player_attack(i)
			return

func execute_player_attack(enemy_index: int):
	"""Execute player attack on enemy"""
	var enemy = enemy_squad[enemy_index]
	var player_ally_index = 4  # Player is Ally5

	# Show player attack animation (facing left toward enemies)
	await play_attack_animation(ally_sprites[player_ally_index], player_character, "attack_left", enemy_sprites[enemy_index])

	# Calculate and apply damage
	var damage = calculate_damage(player_character, enemy)
	enemy.hp -= damage
	enemy.hp = max(0, enemy.hp)

	turn_info.text = "You attack " + enemy.get("character_name", "Enemy") + " for " + str(damage) + " damage!"

	# Show damage number on enemy
	show_damage_number(enemy_sprites[enemy_index].global_position, damage)

	# Spawn impact particles at hit location
	spawn_impact_particles(enemy_sprites[enemy_index].global_position)

	# Hit flash effect
	play_hit_flash(enemy_sprites[enemy_index])

	# Screen shake
	screen_shake(8.0, 0.2)

	# Animate HP bar update
	var max_hp = 100
	if enemy.has("derived_stats"):
		max_hp = enemy.derived_stats.get("max_hp", 100)
	animate_hp_bar(enemy_hp_bars[enemy_index], enemy.hp, max_hp)
	update_hp_bar_color(enemy_hp_bars[enemy_index], enemy.hp, max_hp)
	update_enemy_ui(enemy_index)

	print("Player dealt ", damage, " damage to ", enemy.get("character_name", "Enemy"))

	# Check if enemy defeated
	if enemy.hp <= 0:
		turn_info.text += " " + enemy.get("character_name", "Enemy") + " defeated!"

		# Check if all enemies defeated
		var all_dead = true
		for e in enemy_squad:
			if e.hp > 0:
				all_dead = false
				break

		if all_dead:
			await get_tree().create_timer(1.5).timeout
			end_battle(true)
			return

	# Next turn after delay
	await get_tree().create_timer(1.5).timeout
	current_turn_index += 1
	start_next_turn()

func _on_defend_pressed():
	"""Player chooses to defend (placeholder)"""
	turn_info.text = "You defend! (Not implemented yet)"
	await get_tree().create_timer(1.0).timeout
	current_turn_index += 1
	start_next_turn()

func _on_skills_pressed():
	"""Player chooses to use skills (placeholder)"""
	turn_info.text = "Skills menu (Not implemented yet)"

func _on_items_pressed():
	"""Player chooses to use items (placeholder)"""
	turn_info.text = "Items menu (Not implemented yet)"

func play_attack_animation(sprite_node: TextureRect, character: Dictionary, attack_direction: String = "attack_right", target_sprite: TextureRect = null):
	"""Play attack animation with both attacker and target sliding to center"""
	if not character.has("animations"):
		return

	# Get parent panels to move entire units
	var attacker_panel = sprite_node.get_parent().get_parent()  # Sprite -> VBox -> Panel
	var target_panel = target_sprite.get_parent().get_parent() if target_sprite else null
	if not target_panel:
		return

	# Get target character data from panel
	var target_character_data = {}
	if "character_data" in target_panel:
		target_character_data = target_panel.character_data

	# Store original positions
	var attacker_original_pos = attacker_panel.position
	var target_original_pos = target_panel.position

	# Calculate center point between attacker and target
	var attacker_center = attacker_panel.global_position + (attacker_panel.size / 2.0)
	var target_center = target_panel.global_position + (target_panel.size / 2.0)
	var middle_point_global = (attacker_center + target_center) / 2.0

	# Convert global middle point to local positions for each panel
	var parent_global_pos = attacker_panel.get_parent().global_position if attacker_panel.get_parent() else Vector2.ZERO
	var attacker_middle_pos = middle_point_global - parent_global_pos - (attacker_panel.size / 2.0)

	parent_global_pos = target_panel.get_parent().global_position if target_panel.get_parent() else Vector2.ZERO
	var target_middle_pos = middle_point_global - parent_global_pos - (target_panel.size / 2.0)

	# Space them 100px apart at center
	var direction = "right" if attack_direction.contains("right") else "left"
	var target_direction = "left" if direction == "right" else "right"  # Target faces opposite
	var spacing = 100.0
	if direction == "right":
		attacker_middle_pos.x -= spacing / 2.0
		target_middle_pos.x += spacing / 2.0
	else:
		attacker_middle_pos.x += spacing / 2.0
		target_middle_pos.x -= spacing / 2.0

	# Determine walk directions based on which side they're on
	# PlayerArea walks LEFT to approach, EnemyArea walks RIGHT to approach
	var attacker_is_left_side = attacker_panel.get_parent().name == "PlayerArea"
	var target_is_left_side = target_panel.get_parent().name == "PlayerArea"

	var attacker_approach_dir = "left" if attacker_is_left_side else "right"
	var target_approach_dir = "left" if target_is_left_side else "right"
	var attacker_return_dir = "right" if attacker_is_left_side else "left"
	var target_return_dir = "right" if target_is_left_side else "left"

	# ========================================
	# PHASE 1: WALK TO MIDDLE (ONLY WALK ANIMATIONS)
	# ========================================
	var tween_forward = create_tween()
	tween_forward.set_parallel(true)
	tween_forward.tween_property(attacker_panel, "position", attacker_middle_pos, 0.6).set_trans(Tween.TRANS_LINEAR)
	tween_forward.tween_property(target_panel, "position", target_middle_pos, 0.6).set_trans(Tween.TRANS_LINEAR)

	# Animate ONLY walk cycles - 6 frames at 0.1s each = 0.6s (walk_1, walk_2, walk_1, walk_2, walk_1, walk_2)
	for i in range(6):
		var frame_suffix = "_1" if i % 2 == 0 else "_2"

		# Attacker: PlayerArea walks LEFT, EnemyArea walks RIGHT
		var attacker_walk_anim = "walk_" + attacker_approach_dir + frame_suffix
		if character.animations.has(attacker_walk_anim):
			var walk_frames = character.animations[attacker_walk_anim]
			if walk_frames.size() > 0:
				var frame_data = walk_frames[0]
				var atlas_index = frame_data.get("atlas_index", 0)
				var row = frame_data.get("row", 0)
				var col = frame_data.get("col", 0)
				var walk_texture = get_sprite_texture_from_coords(atlas_index, row, col)
				if walk_texture:
					sprite_node.texture = walk_texture

		# Target: PlayerArea walks LEFT, EnemyArea walks RIGHT
		var target_walk_anim = "walk_" + target_approach_dir + frame_suffix
		if target_character_data.has("animations") and target_character_data.animations.has(target_walk_anim):
			var target_walk_frames = target_character_data.animations[target_walk_anim]
			if target_walk_frames.size() > 0:
				var frame_data = target_walk_frames[0]
				var atlas_index = frame_data.get("atlas_index", 0)
				var row = frame_data.get("row", 0)
				var col = frame_data.get("col", 0)
				var target_walk_texture = get_sprite_texture_from_coords(atlas_index, row, col)
				if target_walk_texture:
					target_sprite.texture = target_walk_texture

		await get_tree().create_timer(0.1).timeout

	# PAUSE when they meet in the middle
	await get_tree().create_timer(0.2).timeout

	# ========================================
	# PHASE 2: ATTACK SEQUENCE
	# ========================================
	# CHARGE-UP SEQUENCE: Spin animation (down -> left)
	# Frame 1: Face down
	if character.animations.has("walk_down_1"):
		var down_frames = character.animations["walk_down_1"]
		if down_frames.size() > 0:
			var frame_data = down_frames[0]
			var atlas_index = frame_data.get("atlas_index", 0)
			var row = frame_data.get("row", 0)
			var col = frame_data.get("col", 0)
			var down_texture = get_sprite_texture_from_coords(atlas_index, row, col)
			if down_texture:
				sprite_node.texture = down_texture
	await get_tree().create_timer(0.1).timeout

	# Frame 2: Face left
	if character.animations.has("walk_left_1"):
		var left_frames = character.animations["walk_left_1"]
		if left_frames.size() > 0:
			var frame_data = left_frames[0]
			var atlas_index = frame_data.get("atlas_index", 0)
			var row = frame_data.get("row", 0)
			var col = frame_data.get("col", 0)
			var left_texture = get_sprite_texture_from_coords(atlas_index, row, col)
			if left_texture:
				sprite_node.texture = left_texture
	await get_tree().create_timer(0.1).timeout

	# Charge pause
	await get_tree().create_timer(0.15).timeout

	# PHASE 2: Attack animation at peak
	if character.animations.has(attack_direction):
		var attack_frames = character.animations[attack_direction]
		if attack_frames.size() > 0:
			var frame_data = attack_frames[0]
			var atlas_index = frame_data.get("atlas_index", 0)
			var row = frame_data.get("row", 0)
			var col = frame_data.get("col", 0)
			var attack_texture = get_sprite_texture_from_coords(atlas_index, row, col)
			if attack_texture:
				sprite_node.texture = attack_texture

	# Show slash effect on target center
	if target_sprite:
		# Calculate center of target sprite
		var target_sprite_center = target_sprite.global_position + (target_sprite.size / 2.0)
		show_slash_effect(target_sprite_center)

	# HIT REACTION: Target spins from impact (down -> right -> up -> left)
	if target_character_data.has("animations"):
		# Frame 1: Face down
		if target_character_data.animations.has("walk_down_1"):
			var down_frames = target_character_data.animations["walk_down_1"]
			if down_frames.size() > 0:
				var frame_data = down_frames[0]
				var atlas_index = frame_data.get("atlas_index", 0)
				var row = frame_data.get("row", 0)
				var col = frame_data.get("col", 0)
				var down_texture = get_sprite_texture_from_coords(atlas_index, row, col)
				if down_texture:
					target_sprite.texture = down_texture
		await get_tree().create_timer(0.08).timeout

		# Frame 2: Face right
		if target_character_data.animations.has("walk_right_1"):
			var right_frames = target_character_data.animations["walk_right_1"]
			if right_frames.size() > 0:
				var frame_data = right_frames[0]
				var atlas_index = frame_data.get("atlas_index", 0)
				var row = frame_data.get("row", 0)
				var col = frame_data.get("col", 0)
				var right_texture = get_sprite_texture_from_coords(atlas_index, row, col)
				if right_texture:
					target_sprite.texture = right_texture
		await get_tree().create_timer(0.08).timeout

		# Frame 3: Face up
		if target_character_data.animations.has("walk_up_1"):
			var up_frames = target_character_data.animations["walk_up_1"]
			if up_frames.size() > 0:
				var frame_data = up_frames[0]
				var atlas_index = frame_data.get("atlas_index", 0)
				var row = frame_data.get("row", 0)
				var col = frame_data.get("col", 0)
				var up_texture = get_sprite_texture_from_coords(atlas_index, row, col)
				if up_texture:
					target_sprite.texture = up_texture
		await get_tree().create_timer(0.08).timeout

		# Frame 4: Face left
		if target_character_data.animations.has("walk_left_1"):
			var left_frames = target_character_data.animations["walk_left_1"]
			if left_frames.size() > 0:
				var frame_data = left_frames[0]
				var atlas_index = frame_data.get("atlas_index", 0)
				var row = frame_data.get("row", 0)
				var col = frame_data.get("col", 0)
				var left_texture = get_sprite_texture_from_coords(atlas_index, row, col)
				if left_texture:
					target_sprite.texture = left_texture
		await get_tree().create_timer(0.08).timeout

	# ========================================
	# PHASE 3: WALK BACK TO ORIGINAL POSITIONS (ONLY WALK ANIMATIONS)
	# ========================================
	var tween_back = create_tween()
	tween_back.set_parallel(true)
	tween_back.tween_property(attacker_panel, "position", attacker_original_pos, 0.6).set_trans(Tween.TRANS_LINEAR)
	tween_back.tween_property(target_panel, "position", target_original_pos, 0.6).set_trans(Tween.TRANS_LINEAR)

	# Animate ONLY walk cycles - 6 frames at 0.1s each = 0.6s (walk_1, walk_2, walk_1, walk_2, walk_1, walk_2)
	for i in range(6):
		var frame_suffix = "_1" if i % 2 == 0 else "_2"

		# Attacker: PlayerArea walks RIGHT to return, EnemyArea walks LEFT to return
		var attacker_return_anim = "walk_" + attacker_return_dir + frame_suffix
		if character.animations.has(attacker_return_anim):
			var walk_frames = character.animations[attacker_return_anim]
			if walk_frames.size() > 0:
				var frame_data = walk_frames[0]
				var atlas_index = frame_data.get("atlas_index", 0)
				var row = frame_data.get("row", 0)
				var col = frame_data.get("col", 0)
				var walk_texture = get_sprite_texture_from_coords(atlas_index, row, col)
				if walk_texture:
					sprite_node.texture = walk_texture

		# Target: PlayerArea walks RIGHT to return, EnemyArea walks LEFT to return
		var target_return_anim = "walk_" + target_return_dir + frame_suffix
		if target_character_data.has("animations") and target_character_data.animations.has(target_return_anim):
			var target_walk_frames = target_character_data.animations[target_return_anim]
			if target_walk_frames.size() > 0:
				var frame_data = target_walk_frames[0]
				var atlas_index = frame_data.get("atlas_index", 0)
				var row = frame_data.get("row", 0)
				var col = frame_data.get("col", 0)
				var target_walk_texture = get_sprite_texture_from_coords(atlas_index, row, col)
				if target_walk_texture:
					target_sprite.texture = target_walk_texture

		await get_tree().create_timer(0.1).timeout

	# Return both to idle sprites
	load_character_sprite(character, sprite_node)
	if target_character_data.has("animations"):
		load_character_sprite(target_character_data, target_sprite)

func show_damage_number(position: Vector2, damage: int):
	"""Show floating damage number that rises and fades"""
	var damage_label = Label.new()
	damage_label.text = str(damage)
	damage_label.add_theme_font_size_override("font_size", 32)
	damage_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Red color
	damage_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	damage_label.add_theme_constant_override("outline_size", 4)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	damage_label.position = position + Vector2(-30, -150)  # Above sprite
	damage_label.z_index = 100

	add_child(damage_label)

	# Create tween for floating and fading
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 100, 1.5)
	tween.tween_property(damage_label, "modulate:a", 0.0, 1.5)

	# Remove label after animation
	await get_tree().create_timer(1.5).timeout
	damage_label.queue_free()

func animate_hp_bar(hp_bar: ProgressBar, new_hp: float, max_hp: float):
	"""Smoothly animate HP bar to new value"""
	if not hp_bar:
		return

	var tween = create_tween()
	tween.tween_property(hp_bar, "value", new_hp, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func end_battle(victory: bool):
	"""End battle with victory or defeat"""
	if victory:
		turn_info.text = "VICTORY! You defeated all enemies!"
		print("=== VICTORY ===")
	else:
		turn_info.text = "DEFEAT! You were defeated..."
		print("=== DEFEAT ===")

	# Disable all buttons
	attack_button.disabled = true
	defend_button.disabled = true
	skills_button.disabled = true
	items_button.disabled = true

	# Return to dev client after delay
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://dev_client.tscn")

func _on_save_layout_pressed():
	"""Save battle UI layout to file"""
	save_manual_positions()
	print("Battle layout saved!")

func _on_reset_layout_pressed():
	"""Reset all panels to default positions"""
	reset_battle_layout()
	print("Battle layout reset to defaults!")

func save_battle_layout():
	"""Save panel positions and states to JSON file"""
	var layout_data = {
		"enemy_panel_1": enemy_panel_1.get_layout_data(),
		"enemy_panel_2": enemy_panel_2.get_layout_data(),
		"enemy_panel_3": enemy_panel_3.get_layout_data(),
		"enemy_panel_4": enemy_panel_4.get_layout_data(),
		"enemy_panel_5": enemy_panel_5.get_layout_data(),
		"enemy_panel_6": enemy_panel_6.get_layout_data(),
		"ally_panel_1": ally_panel_1.get_layout_data(),
		"ally_panel_2": ally_panel_2.get_layout_data(),
		"ally_panel_3": ally_panel_3.get_layout_data(),
		"ally_panel_4": ally_panel_4.get_layout_data(),
		"ally_panel_5": ally_panel_5.get_layout_data(),
		"ally_panel_6": ally_panel_6.get_layout_data(),
		"ui_panel": ui_panel.get_layout_data()
	}

	var save_path = "user://battle_layout.json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(layout_data, "\t")
		file.store_string(json_string)
		file.close()
		print("✓ Battle layout saved to: ", save_path)
	else:
		print("ERROR: Could not save battle layout")

func load_battle_layout():
	"""Load panel positions and states from latest choreography save"""
	var save_path = "user://battle_manual_positions.json"

	if not FileAccess.file_exists(save_path):
		print("No saved choreography found, using defaults")
		return

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_text) == OK:
			var all_saves = json.data

			# Load the LAST save (most recent)
			if all_saves.has("saves") and all_saves.saves.size() > 0:
				var latest_save = all_saves.saves[all_saves.saves.size() - 1]
				var panels = latest_save.panels

				# Apply to each panel
				if panels.has("EnemyPanel1"):
					enemy_panel_1.apply_layout_data(panels.EnemyPanel1)
				if panels.has("EnemyPanel2"):
					enemy_panel_2.apply_layout_data(panels.EnemyPanel2)
				if panels.has("EnemyPanel3"):
					enemy_panel_3.apply_layout_data(panels.EnemyPanel3)
				if panels.has("EnemyPanel4"):
					enemy_panel_4.apply_layout_data(panels.EnemyPanel4)
				if panels.has("EnemyPanel5"):
					enemy_panel_5.apply_layout_data(panels.EnemyPanel5)
				if panels.has("EnemyPanel6"):
					enemy_panel_6.apply_layout_data(panels.EnemyPanel6)
				if panels.has("Ally1Panel"):
					ally_panel_1.apply_layout_data(panels.Ally1Panel)
				if panels.has("Ally2Panel"):
					ally_panel_2.apply_layout_data(panels.Ally2Panel)
				if panels.has("Ally3Panel"):
					ally_panel_3.apply_layout_data(panels.Ally3Panel)
				if panels.has("Ally4Panel"):
					ally_panel_4.apply_layout_data(panels.Ally4Panel)
				if panels.has("Ally5Panel"):
					ally_panel_5.apply_layout_data(panels.Ally5Panel)
				if panels.has("Ally6Panel"):
					ally_panel_6.apply_layout_data(panels.Ally6Panel)

				print("✓ Loaded choreography save #", latest_save.save_number, " from ", latest_save.timestamp)
			else:
				print("No saves found in choreography file")
		else:
			print("ERROR: Failed to parse choreography JSON")
	else:
		print("ERROR: Could not open choreography file")

func reset_battle_layout():
	"""Reset all panels to their default positions and sizes"""
	# Reset enemy panels
	enemy_panel_1.position = DEFAULT_POSITIONS.enemy_panel_1.position
	enemy_panel_1.size = DEFAULT_POSITIONS.enemy_panel_1.size

	enemy_panel_2.position = DEFAULT_POSITIONS.enemy_panel_2.position
	enemy_panel_2.size = DEFAULT_POSITIONS.enemy_panel_2.size

	enemy_panel_3.position = DEFAULT_POSITIONS.enemy_panel_3.position
	enemy_panel_3.size = DEFAULT_POSITIONS.enemy_panel_3.size

	enemy_panel_4.position = DEFAULT_POSITIONS.enemy_panel_4.position
	enemy_panel_4.size = DEFAULT_POSITIONS.enemy_panel_4.size

	enemy_panel_5.position = DEFAULT_POSITIONS.enemy_panel_5.position
	enemy_panel_5.size = DEFAULT_POSITIONS.enemy_panel_5.size

	enemy_panel_6.position = DEFAULT_POSITIONS.enemy_panel_6.position
	enemy_panel_6.size = DEFAULT_POSITIONS.enemy_panel_6.size

	# Reset ally panels
	ally_panel_1.position = DEFAULT_POSITIONS.ally_panel_1.position
	ally_panel_1.size = DEFAULT_POSITIONS.ally_panel_1.size

	ally_panel_2.position = DEFAULT_POSITIONS.ally_panel_2.position
	ally_panel_2.size = DEFAULT_POSITIONS.ally_panel_2.size

	ally_panel_3.position = DEFAULT_POSITIONS.ally_panel_3.position
	ally_panel_3.size = DEFAULT_POSITIONS.ally_panel_3.size

	ally_panel_4.position = DEFAULT_POSITIONS.ally_panel_4.position
	ally_panel_4.size = DEFAULT_POSITIONS.ally_panel_4.size

	ally_panel_5.position = DEFAULT_POSITIONS.ally_panel_5.position
	ally_panel_5.size = DEFAULT_POSITIONS.ally_panel_5.size

	ally_panel_6.position = DEFAULT_POSITIONS.ally_panel_6.position
	ally_panel_6.size = DEFAULT_POSITIONS.ally_panel_6.size

	# Reset UI panel
	ui_panel.position = DEFAULT_POSITIONS.ui_panel.position
	ui_panel.size = DEFAULT_POSITIONS.ui_panel.size

	print("✓ All panels reset to default positions")

func spawn_impact_particles(hit_position: Vector2):
	"""Spawn particle effect at attack impact location"""
	var impact_scene = preload("res://effects/attack_impact.tscn")
	var particles_node = impact_scene.instantiate()
	if particles_node:
		particles_node.position = hit_position
		add_child(particles_node)
		# Find the CPUParticles2D child and start emission
		var particles = particles_node.get_node("Particles")
		if particles:
			particles.emitting = true
		print("Impact particles spawned at: ", hit_position)
	else:
		print("ERROR: Failed to instantiate particle scene")

func play_hit_flash(sprite_node: TextureRect):
	"""Flash sprite white when taking damage"""
	var original_modulate = sprite_node.modulate

	# Flash white
	sprite_node.modulate = Color(2.0, 2.0, 2.0, 1.0)
	await get_tree().create_timer(0.1).timeout

	# Return to normal
	sprite_node.modulate = original_modulate

func screen_shake(strength: float = 10.0, duration: float = 0.3):
	"""Shake the entire battle window"""
	var original_position = position
	var shake_timer = 0.0
	var shake_interval = 0.05

	while shake_timer < duration:
		# Random offset
		var offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		position = original_position + offset

		await get_tree().create_timer(shake_interval).timeout
		shake_timer += shake_interval

		# Reduce strength over time
		strength *= 0.8

	# Return to original position
	position = original_position

func update_hp_bar_color(hp_bar: ProgressBar, current_hp: float, max_hp: float):
	"""Update HP bar color based on HP percentage (green → yellow → red)"""
	var hp_percent = current_hp / max_hp if max_hp > 0 else 0.0

	var bar_color: Color
	if hp_percent > 0.6:
		# Green (healthy)
		bar_color = Color(0.2, 0.8, 0.2)
	elif hp_percent > 0.3:
		# Yellow (warning) - interpolate between green and yellow
		var t = (hp_percent - 0.3) / 0.3  # 0.0 to 1.0
		bar_color = Color(0.2, 0.8, 0.2).lerp(Color(0.9, 0.9, 0.2), 1.0 - t)
	else:
		# Red (danger) - interpolate between yellow and red
		var t = hp_percent / 0.3  # 0.0 to 1.0
		bar_color = Color(0.9, 0.9, 0.2).lerp(Color(0.9, 0.2, 0.2), 1.0 - t)

	# Apply color to HP bar
	if hp_bar:
		hp_bar.modulate = bar_color

func show_slash_effect(hit_position: Vector2):
	"""Display diagonal slash lines at impact point"""
	# Main slashes - 2 thin diagonal lines
	for i in range(2):
		var slash_line = Line2D.new()
		# Make slashes cover entire sprite area (150x150)
		var offset = Vector2(-75, -75) + Vector2(i * 30, i * 30)
		slash_line.add_point(hit_position + offset)
		slash_line.add_point(hit_position + offset + Vector2(150, 150))
		slash_line.width = 3
		slash_line.default_color = Color(1, 1 - (i * 0.4), 1 - (i * 0.4), 1)  # White to red gradient
		slash_line.z_index = 100
		add_child(slash_line)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(slash_line, "width", 6, 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(slash_line, "modulate:a", 0.0, 0.3)

		await get_tree().create_timer(0.3).timeout
		slash_line.queue_free()

	# Center emphasis slash - smaller, brighter
	var center_slash = Line2D.new()
	var center_offset = Vector2(-30, -30)
	center_slash.add_point(hit_position + center_offset)
	center_slash.add_point(hit_position + center_offset + Vector2(60, 60))
	center_slash.width = 4
	center_slash.default_color = Color(1, 1, 1, 1)  # Bright white
	center_slash.z_index = 101  # On top of other slashes
	add_child(center_slash)

	var center_tween = create_tween()
	center_tween.set_parallel(true)
	center_tween.tween_property(center_slash, "width", 8, 0.15).set_ease(Tween.EASE_OUT)
	center_tween.tween_property(center_slash, "modulate:a", 0.0, 0.25)

	await get_tree().create_timer(0.25).timeout
	center_slash.queue_free()

	spawn_blood_particles(hit_position)

func spawn_blood_particles(hit_position: Vector2):
	"""Create red particle burst on hit"""
	var particles = CPUParticles2D.new()
	particles.position = hit_position
	particles.z_index = 100
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 15
	particles.lifetime = 0.6
	particles.color = Color(0.8, 0.1, 0.1, 1)
	particles.color_ramp = create_blood_gradient()
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 400)
	particles.initial_velocity_min = 100
	particles.initial_velocity_max = 200
	particles.scale_amount_min = 2
	particles.scale_amount_max = 4
	add_child(particles)

	await get_tree().create_timer(0.8).timeout
	particles.queue_free()

func create_blood_gradient() -> Gradient:
	"""Create red to transparent gradient for blood particles"""
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.8, 0.1, 0.1, 1))
	gradient.set_color(1, Color(0.6, 0.0, 0.0, 0))
	return gradient


# ===== PAUSE SYSTEM =====
func _on_pause_pressed():
	"""Toggle battle pause for manual positioning"""
	is_paused = !is_paused
	update_pause_button_text()
	
	if is_paused:
		print("
========================================")
		print("BATTLE PAUSED - POSITIONING MODE")
		print("========================================")
		print("Click panels and use WASD to position sprites")
		print("Click 'Save Layout' when ready")
		print("Click 'Resume Battle' to continue combat")
		print("========================================
")
		turn_info.text = "PAUSED - Click Resume to start combat"
	else:
		print("
BATTLE RESUMED
")
		turn_info.text = "Battle resumed!"
		# Start the first turn when resuming
		if current_turn_index == 0 and turn_order.size() > 0:
			start_next_turn()

func update_pause_button_text():
	"""Update pause button text"""
	if pause_button:
		if is_paused:
			pause_button.text = "Resume Battle"
		else:
			pause_button.text = "Pause"

# ===== MANUAL POSITIONING SYSTEM =====
func setup_manual_positioning():
	"""Setup manual positioning system"""
	all_battle_panels = [
		enemy_panel_1, enemy_panel_2, enemy_panel_3, enemy_panel_4, enemy_panel_5, enemy_panel_6,
		ally_panel_1, ally_panel_2, ally_panel_3, ally_panel_4, ally_panel_5, ally_panel_6
	]

	for panel in all_battle_panels:
		if panel and panel.has_signal("panel_selected"):
			panel.panel_selected.connect(_on_panel_selected_manual)
		if panel and panel.has_signal("layout_changed"):
			panel.layout_changed.connect(_on_panel_layout_changed)

func _on_panel_selected_manual(panel: Panel):
	"""Handle panel selection - deselect others"""
	for p in all_battle_panels:
		if p != panel and p.has_method("deselect"):
			p.deselect()
	selected_panel = panel

func _on_panel_layout_changed():
	"""Panel was moved/resized/animated"""
	pass

func save_manual_positions():
	"""Save all panel positions - ACCUMULATES each save + captures screenshot"""
	var save_path = "user://battle_manual_positions.json"

	var all_saves = {"saves": []}
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				all_saves = json.data
			file.close()

	var save_number = all_saves.saves.size() + 1
	var new_save = {
		"save_number": save_number,
		"timestamp": Time.get_datetime_string_from_system(),
		"panels": {}
	}

	for panel in all_battle_panels:
		if panel and panel.has_method("get_layout_data"):
			new_save.panels[panel.name] = panel.get_layout_data()

	all_saves.saves.append(new_save)

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(all_saves, "	")
		file.store_string(json_string)
		file.close()

		# Capture screenshot of battle choreography
		var screenshot_saved = await capture_choreography_screenshot(save_number)

		print("
========================================")
		print("SAVE #", save_number, " RECORDED")
		print("========================================")
		print("Total saves: ", all_saves.saves.size())
		if screenshot_saved:
			print("📸 Screenshot saved: choreography_frame_%03d.png" % save_number)
		print("
Current position:")
		for panel_name in new_save.panels.keys():
			var panel_data = new_save.panels[panel_name]
			print("  ", panel_name, ":")
			print("    Position: (", panel_data.position.x, ", ", panel_data.position.y, ")")
			if panel_data.has("sprite_offset"):
				print("    Sprite offset: (", panel_data.sprite_offset.x, ", ", panel_data.sprite_offset.y, ")")
			if panel_data.has("sprite_scale"):
				print("    Sprite scale: ", panel_data.sprite_scale)
			if panel_data.has("current_direction"):
				print("    Direction: ", panel_data.current_direction)
		print("
All saves stored in: ", save_path)
		print("========================================
")
	else:
		print("ERROR: Could not save positions")

func capture_choreography_screenshot(frame_number: int) -> bool:
	"""Capture screenshot of current battle choreography frame"""
	# Wait one frame to ensure everything is rendered
	await get_tree().process_frame

	# Get the viewport image
	var img = get_viewport().get_texture().get_image()

	# Create choreography folder if it doesn't exist
	var choreography_dir = "user://battle_choreography/"
	if not DirAccess.dir_exists_absolute(choreography_dir):
		DirAccess.make_dir_absolute(choreography_dir)

	# Save with frame number (padded to 3 digits)
	var screenshot_path = choreography_dir + "choreography_frame_%03d.png" % frame_number
	var disk_path = ProjectSettings.globalize_path(screenshot_path)

	var error = img.save_png(disk_path)
	if error == OK:
		print("✓ Screenshot saved to: ", disk_path)
		return true
	else:
		print("ERROR: Failed to save screenshot: ", error)
		return false
