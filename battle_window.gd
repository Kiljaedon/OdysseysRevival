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

# Result Popup References
@onready var result_popup = $ResultPopup
@onready var result_title = $ResultPopup/PopupContent/ResultTitle
@onready var xp_label = $ResultPopup/PopupContent/XPLabel
@onready var gold_label = $ResultPopup/PopupContent/GoldLabel
@onready var continue_button = $ResultPopup/PopupContent/ContinueButton

# UI Toggle Button
@onready var hide_ui_button = $HideUIButton
@onready var layout_buttons_container = $UIPanel/UIArea/LayoutButtons

# Target Cursor
@onready var target_cursor = $TargetCursor

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
# PERFECTLY CALCULATED for symmetry and proper spacing
const DEFAULT_POSITIONS = {
	# LEFT SIDE (EnemyArea) - Front row of 3, Back row of 3
	# Enemies face RIGHT toward player/allies
	# Local coords within 600px wide EnemyArea - SYMMETRIC layout
	"enemy_panel_1": {"position": Vector2(365, 50), "size": Vector2(170, 290)},    # Front top
	"enemy_panel_2": {"position": Vector2(365, 210), "size": Vector2(170, 290)},   # Front middle
	"enemy_panel_3": {"position": Vector2(365, 370), "size": Vector2(170, 290)},   # Front bottom
	"enemy_panel_4": {"position": Vector2(65, 50), "size": Vector2(170, 290)},     # Back top
	"enemy_panel_5": {"position": Vector2(65, 210), "size": Vector2(170, 290)},    # Back middle
	"enemy_panel_6": {"position": Vector2(65, 370), "size": Vector2(170, 290)},    # Back bottom

	# RIGHT SIDE (PlayerArea/Allies) - Front row of 3, Back row of 3 (MIRRORED)
	# Player/Allies face LEFT toward enemies
	# Local coords within 300px wide PlayerArea - Properly spaced with margins
	"ally_panel_1": {"position": Vector2(15, 50), "size": Vector2(170, 320)},      # Front top
	"ally_panel_2": {"position": Vector2(15, 210), "size": Vector2(170, 320)},     # Front middle
	"ally_panel_3": {"position": Vector2(15, 370), "size": Vector2(170, 320)},     # Front bottom
	"ally_panel_4": {"position": Vector2(115, 50), "size": Vector2(170, 320)},     # Back top
	"ally_panel_5": {"position": Vector2(115, 210), "size": Vector2(170, 320)},    # Back middle
	"ally_panel_6": {"position": Vector2(115, 370), "size": Vector2(170, 320)},    # Back bottom

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
var turn_timer: float = 0.0
const TURN_TIME_LIMIT: float = 10.0  # 10 seconds per turn
var is_player_defending: bool = false  # Player is in defensive stance (takes 50% damage)
var is_animating_attack: bool = false  # Prevent position enforcement during attack animations

# First strike system
var player_initiated: bool = true  # Who started the battle? true = player attacked first, false = enemy ambushed

# Manual positioning system
var selected_panel: Panel = null
var all_battle_panels: Array = []

# Keyboard navigation
var selected_button_index: int = 0
var action_buttons: Array = []

# UI visibility toggle
var ui_elements_hidden: bool = true  # Start with UI hidden (clean battle view)

# Floating HP/MP/Energy overlays for gameplay mode (combined bars)
var enemy_stat_overlays: Array = []
var ally_stat_overlays: Array = []

func _ready():
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

	# Connect result popup button
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)

	# Connect hide UI button
	if hide_ui_button:
		hide_ui_button.pressed.connect(_on_hide_ui_pressed)

	# Setup manual positioning system
	setup_manual_positioning()

	# Setup battle
	setup_battle()

	# Link enemy panels to character data for animation cycling
	# All characters face DOWN by default
	enemy_panel_1.character_data = enemy_squad[0] if enemy_squad.size() > 0 else {}
	enemy_panel_1.battle_window = self
	enemy_panel_1.current_direction = "down"
	enemy_panel_1.apply_character_animation("walk_down_1")
	enemy_panel_1.gui_input.connect(_on_enemy_panel_clicked.bind(0))

	enemy_panel_2.character_data = enemy_squad[1] if enemy_squad.size() > 1 else {}
	enemy_panel_2.battle_window = self
	enemy_panel_2.current_direction = "down"
	enemy_panel_2.apply_character_animation("walk_down_1")
	enemy_panel_2.gui_input.connect(_on_enemy_panel_clicked.bind(1))

	enemy_panel_3.character_data = enemy_squad[2] if enemy_squad.size() > 2 else {}
	enemy_panel_3.battle_window = self
	enemy_panel_3.current_direction = "down"
	enemy_panel_3.apply_character_animation("walk_down_1")
	enemy_panel_3.gui_input.connect(_on_enemy_panel_clicked.bind(2))

	enemy_panel_4.character_data = enemy_squad[3] if enemy_squad.size() > 3 else {}
	enemy_panel_4.battle_window = self
	enemy_panel_4.current_direction = "down"
	enemy_panel_4.apply_character_animation("walk_down_1")
	enemy_panel_4.gui_input.connect(_on_enemy_panel_clicked.bind(3))

	enemy_panel_5.character_data = enemy_squad[4] if enemy_squad.size() > 4 else {}
	enemy_panel_5.battle_window = self
	enemy_panel_5.current_direction = "down"
	enemy_panel_5.apply_character_animation("walk_down_1")
	enemy_panel_5.gui_input.connect(_on_enemy_panel_clicked.bind(4))

	enemy_panel_6.character_data = enemy_squad[5] if enemy_squad.size() > 5 else {}
	enemy_panel_6.battle_window = self
	enemy_panel_6.current_direction = "down"
	enemy_panel_6.apply_character_animation("walk_down_1")
	enemy_panel_6.gui_input.connect(_on_enemy_panel_clicked.bind(5))

	# Link ally panels to ally squad data (player is ally[0] = Ally1Panel)
	# All characters face DOWN by default
	ally_panel_1.character_data = ally_squad[0] if ally_squad.size() > 0 else {}  # THIS IS THE PLAYER
	ally_panel_1.battle_window = self
	ally_panel_1.current_direction = "down"
	ally_panel_1.apply_character_animation("walk_down_1")
	ally_panel_1.gui_input.connect(_on_ally_panel_clicked.bind(0))

	ally_panel_2.character_data = ally_squad[1] if ally_squad.size() > 1 else {}
	ally_panel_2.battle_window = self
	ally_panel_2.current_direction = "down"
	ally_panel_2.apply_character_animation("walk_down_1")
	ally_panel_2.gui_input.connect(_on_ally_panel_clicked.bind(1))

	ally_panel_3.character_data = ally_squad[2] if ally_squad.size() > 2 else {}
	ally_panel_3.battle_window = self
	ally_panel_3.current_direction = "down"
	ally_panel_3.apply_character_animation("walk_down_1")
	ally_panel_3.gui_input.connect(_on_ally_panel_clicked.bind(2))

	ally_panel_4.character_data = ally_squad[3] if ally_squad.size() > 3 else {}
	ally_panel_4.battle_window = self
	ally_panel_4.current_direction = "down"
	ally_panel_4.apply_character_animation("walk_down_1")
	ally_panel_4.gui_input.connect(_on_ally_panel_clicked.bind(3))

	ally_panel_5.character_data = ally_squad[4] if ally_squad.size() > 4 else {}
	ally_panel_5.battle_window = self
	ally_panel_5.current_direction = "down"
	ally_panel_5.apply_character_animation("walk_down_1")
	ally_panel_5.gui_input.connect(_on_ally_panel_clicked.bind(4))

	ally_panel_6.character_data = ally_squad[5] if ally_squad.size() > 5 else {}
	ally_panel_6.battle_window = self
	ally_panel_6.current_direction = "down"
	ally_panel_6.apply_character_animation("walk_down_1")
	ally_panel_6.gui_input.connect(_on_ally_panel_clicked.bind(5))

	# Force perfect grid alignment on startup (ignore old saves with incorrect positions)
	auto_align_all_panels()
	# Don't lock panels - let enforce_panel_alignment() in _process() handle it every frame

	# ALSO enforce alignment immediately in physics process to catch early frame issues
	call_deferred("enforce_panel_alignment")

	# Create floating HP/MP overlays for gameplay mode
	create_floating_overlays()

	# Apply default UI hidden state
	call_deferred("apply_ui_visibility")

func apply_ui_visibility():
	"""Apply the current UI visibility state (called at startup)"""
	# Call the toggle function which will apply the current ui_elements_hidden state
	_on_hide_ui_pressed()

func create_floating_overlays():
	"""Create small combined HP/MP/Energy bars that float over character sprites"""
	# Create enemy stat overlays (HP + MP + Energy - same as allies)
	for i in range(6):
		var overlay = create_combined_stat_overlay(false)  # enemies also get all bars
		enemy_stat_overlays.append(overlay)
		add_child(overlay)
		overlay.visible = false

	# Create ally stat overlays (HP + MP + Energy)
	for i in range(6):
		var overlay = create_combined_stat_overlay(false)  # allies = all bars
		ally_stat_overlays.append(overlay)
		add_child(overlay)
		overlay.visible = false

func create_combined_stat_overlay(is_enemy: bool) -> VBoxContainer:
	"""Create a compact combined HP/MP/Energy bar overlay"""
	var container = VBoxContainer.new()
	container.z_index = 300
	container.add_theme_constant_override("separation", 1)  # 1px spacing between bars

	# HP Bar (always show)
	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(50, 6)  # Smaller: 50x6
	hp_bar.size = Vector2(50, 6)
	hp_bar.show_percentage = false
	var hp_style = StyleBoxFlat.new()
	hp_style.bg_color = Color(0, 0.8, 0, 1)  # Green
	hp_bar.add_theme_stylebox_override("fill", hp_style)
	container.add_child(hp_bar)

	# MP Bar (only for allies)
	if not is_enemy:
		var mp_bar = ProgressBar.new()
		mp_bar.custom_minimum_size = Vector2(50, 5)  # Smaller: 50x5
		mp_bar.size = Vector2(50, 5)
		mp_bar.show_percentage = false
		var mp_style = StyleBoxFlat.new()
		mp_style.bg_color = Color(0, 0.5, 1, 1)  # Blue
		mp_bar.add_theme_stylebox_override("fill", mp_style)
		container.add_child(mp_bar)

		# Energy Bar (only for allies)
		var energy_bar = ProgressBar.new()
		energy_bar.custom_minimum_size = Vector2(50, 5)  # Smaller: 50x5
		energy_bar.size = Vector2(50, 5)
		energy_bar.show_percentage = false
		var energy_style = StyleBoxFlat.new()
		energy_style.bg_color = Color(1, 0.8, 0, 1)  # Yellow/Gold
		energy_bar.add_theme_stylebox_override("fill", energy_style)
		container.add_child(energy_bar)

	return container

func _process(delta):
	"""Process turn timer countdown"""
	if is_player_turn and not is_paused:
		turn_timer -= delta
		update_turn_timer_display()

		# Auto-skip when timer runs out
		if turn_timer <= 0:
			auto_skip_turn()

	# Update floating overlay positions if UI is hidden (in case sprites move)
	if ui_elements_hidden:
		update_floating_overlay_positions()

	# Enforce alignment only when not animating attacks
	if not is_animating_attack:
		enforce_panel_alignment()

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
	# Allow G key for grid alignment even when not player turn
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		auto_align_all_panels()
		print("✓ Force aligned all panels to grid (pressed G)")
		get_viewport().set_input_as_handled()
		return

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

	# Calculate turn order based on DEX (with first strike)
	calculate_turn_order()

func set_battle_initiator(player_attacked_first: bool):
	"""Called from world map to set who initiated combat"""
	player_initiated = player_attacked_first
	if player_attacked_first:
		print("🗡️ Player initiated combat - your fastest ally gets first strike!")
	else:
		print("👹 Enemy ambush - their fastest unit gets first strike!")
	# Recalculate turn order with new initiator
	if turn_order.size() > 0:
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
	"""Calculate turn order based on DEX stat with first strike system"""
	turn_order.clear()

	# Build list of all combatants
	var all_units: Array = []

	# Add player
	var player_dex = 10
	if player_character.has("base_stats") and player_character.base_stats.has("dex"):
		player_dex = player_character.base_stats.dex
	all_units.append({"type": "player", "data": player_character, "dex": player_dex, "is_ally": true})

	# Add allies
	for ally in ally_squad:
		if ally != player_character:  # Don't add player twice
			var ally_dex = 10
			if ally.has("base_stats") and ally.base_stats.has("dex"):
				ally_dex = ally.base_stats.dex
			all_units.append({"type": "ally", "data": ally, "dex": ally_dex, "is_ally": true})

	# Add enemies
	for enemy in enemy_squad:
		var enemy_dex = 10
		if enemy.has("base_stats") and enemy.base_stats.has("dex"):
			enemy_dex = enemy.base_stats.dex
		all_units.append({"type": "enemy", "data": enemy, "dex": enemy_dex, "is_ally": false})

	# FIRST STRIKE SYSTEM
	var first_striker = null
	var remaining_units: Array = []

	if player_initiated:
		# Player attacked first - fastest ALLY goes first
		var fastest_ally = null
		var fastest_dex = -1
		for unit in all_units:
			if unit.is_ally and unit.dex > fastest_dex:
				fastest_ally = unit
				fastest_dex = unit.dex

		if fastest_ally:
			first_striker = fastest_ally
			print("⚔️ FIRST STRIKE: %s attacks first! (Player initiated)" % fastest_ally.data.get("character_name", "Ally"))

		# Add remaining units
		for unit in all_units:
			if unit != first_striker:
				remaining_units.append(unit)
	else:
		# Enemy ambushed - fastest ENEMY goes first
		var fastest_enemy = null
		var fastest_dex = -1
		for unit in all_units:
			if not unit.is_ally and unit.dex > fastest_dex:
				fastest_enemy = unit
				fastest_dex = unit.dex

		if fastest_enemy:
			first_striker = fastest_enemy
			print("💀 AMBUSH: %s attacks first! (Enemy initiated)" % fastest_enemy.data.get("character_name", "Enemy"))

		# Add remaining units
		for unit in all_units:
			if unit != first_striker:
				remaining_units.append(unit)

	# Sort remaining units by DEX
	remaining_units.sort_custom(func(a, b): return a.dex > b.dex)

	# Build final turn order: first striker + sorted remaining
	if first_striker:
		turn_order.append(first_striker)
	turn_order.append_array(remaining_units)

	print("Turn order calculated:")
	for i in range(turn_order.size()):
		var unit = turn_order[i]
		var prefix = "  "
		if i == 0 and first_striker:
			prefix = "⚡ "  # First strike marker
		print(prefix, unit.data.get("character_name", "Unknown"), " (DEX: ", unit.dex, ")")

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

	# Update overlay if UI is hidden
	if ui_elements_hidden and index < enemy_stat_overlays.size():
		var hp_bar = enemy_stat_overlays[index].get_child(0)  # HP bar is first child
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp

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

	# Update combined overlay if UI is hidden
	if ui_elements_hidden and index < ally_stat_overlays.size():
		var hp_bar = ally_stat_overlays[index].get_child(0)  # HP bar
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp

		var mp_bar = ally_stat_overlays[index].get_child(1)  # MP bar
		mp_bar.max_value = max_mp
		mp_bar.value = current_mp

		# Energy bar - placeholder for now (100/100)
		var energy_bar = ally_stat_overlays[index].get_child(2)  # Energy bar
		energy_bar.max_value = 100
		energy_bar.value = 100

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

	# Show first strike message on first turn only
	if current_turn_index == 0:
		var first_name = current_unit.data.get("character_name", "Unknown")
		if current_unit.is_ally:
			print("⚡ FIRST STRIKE: %s" % first_name)
		else:
			print("💀 AMBUSH: %s" % first_name)

	# ONLY player character is controlled by player, NPCs auto-battle
	if current_unit.type == "player":
		start_player_turn()
	elif current_unit.type == "ally":
		start_ally_npc_turn(current_unit)
	else:
		start_enemy_turn(current_unit)

func start_player_turn():
	"""Start PLAYER CHARACTER's turn (only one you control)"""
	is_player_turn = true
	turn_timer = TURN_TIME_LIMIT
	update_turn_timer_display()

	# Clear defend state from previous turn (if player wasn't attacked)
	if is_player_defending:
		print("🛡️ Defense expired (new turn started)")
		is_player_defending = false

	# Enable action buttons (player only - NPCs auto-battle)
	attack_button.disabled = false
	defend_button.disabled = false
	skills_button.disabled = false
	items_button.disabled = false

	# Select first button for keyboard navigation
	selected_button_index = 0
	update_button_selection()

	print("🎮 YOUR TURN - 10 seconds to decide!")

func update_turn_timer_display():
	"""Update turn info with timer countdown"""
	if is_player_turn:
		turn_info.text = "Your Turn! Time: %.1f seconds" % turn_timer
	else:
		turn_info.text = "Enemy Turn..."

func auto_skip_turn():
	"""Auto-skip player turn when timer runs out"""
	print("Turn timer expired - auto-skipping")
	turn_info.text = "Time's up! Turn skipped."
	is_player_turn = false
	clear_enemy_highlights()
	is_selecting_target = false

	# Disable buttons
	attack_button.disabled = true
	defend_button.disabled = true
	skills_button.disabled = true
	items_button.disabled = true

	# Advance to next turn after delay
	await get_tree().create_timer(1.0).timeout
	current_turn_index += 1
	start_next_turn()

func start_ally_npc_turn(ally_unit: Dictionary):
	"""Start NPC ally's turn (auto-battle)"""
	is_player_turn = false
	var ally_name = ally_unit.data.get("character_name", "Ally")
	turn_info.text = ally_name + " is acting..."

	# Disable action buttons
	attack_button.disabled = true
	defend_button.disabled = true
	skills_button.disabled = true
	items_button.disabled = true

	# Clear button focus
	for button in action_buttons:
		if button:
			button.release_focus()

	print(ally_name, "'s turn (NPC ally)")

	# Execute ally AI after short delay
	await get_tree().create_timer(0.8).timeout
	execute_ally_npc_ai(ally_unit)

func execute_ally_npc_ai(ally_unit: Dictionary):
	"""NPC allies attack enemies (simple AI: attack weakest enemy)"""
	# Find weakest alive enemy
	var target_enemy_index = -1
	var lowest_hp = 999999

	for i in range(enemy_squad.size()):
		if enemy_squad[i].hp > 0 and enemy_squad[i].hp < lowest_hp:
			lowest_hp = enemy_squad[i].hp
			target_enemy_index = i

	if target_enemy_index == -1:
		# No valid targets
		print("  No enemies to attack!")
		current_turn_index += 1
		start_next_turn()
		return

	# Find which ally index this is
	var ally_index = -1
	for i in range(ally_squad.size()):
		if ally_squad[i] == ally_unit.data:
			ally_index = i
			break

	# Show ally attack animation (facing left toward enemies)
	if ally_index >= 0:
		await play_attack_animation(ally_sprites[ally_index], ally_unit.data, "attack_left", enemy_sprites[target_enemy_index])

	# Calculate and apply damage
	var damage = calculate_damage(ally_unit.data, enemy_squad[target_enemy_index], ally_index, target_enemy_index, false)
	enemy_squad[target_enemy_index].hp -= damage
	enemy_squad[target_enemy_index].hp = max(0, enemy_squad[target_enemy_index].hp)

	# Update enemy UI
	var max_hp = 100
	if enemy_squad[target_enemy_index].has("derived_stats"):
		max_hp = enemy_squad[target_enemy_index].derived_stats.get("max_hp", 100)

	animate_hp_bar(enemy_hp_bars[target_enemy_index], enemy_squad[target_enemy_index].hp, max_hp)
	update_hp_bar_color(enemy_hp_bars[target_enemy_index], enemy_squad[target_enemy_index].hp, max_hp)
	update_enemy_ui(target_enemy_index)

	print("Ally dealt ", damage, " damage to ", enemy_squad[target_enemy_index].get("character_name", "Enemy"))

	# Check if enemy defeated
	if enemy_squad[target_enemy_index].hp <= 0:
		turn_info.text += " Enemy defeated!"

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
	await get_tree().create_timer(1.0).timeout
	current_turn_index += 1
	start_next_turn()

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
	# Player is ally index 0 (Ally1)
	var player_ally_index = 0

	# Find which enemy index this is
	var enemy_index = -1
	for i in range(enemy_squad.size()):
		if enemy_squad[i] == enemy_unit.data:
			enemy_index = i
			break

	# Show attack animation (facing right toward player)
	if enemy_index >= 0:
		await play_attack_animation(enemy_sprites[enemy_index], enemy_unit.data, "attack_right", ally_sprites[player_ally_index])

	# Enemy attacks player with range system
	var damage = calculate_damage(enemy_unit.data, player_character, enemy_index, player_ally_index, true)

	# Apply defense reduction if player is defending
	var original_damage = damage
	if is_player_defending:
		damage = int(damage * 0.5)  # Reduce damage by 50%
		print("🛡️ Defense reduced damage from %d to %d" % [original_damage, damage])
		is_player_defending = false  # Clear defend state after taking damage

	player_character.hp -= damage
	player_character.hp = max(0, player_character.hp)

	# Show damage with defend indicator if applicable
	if original_damage != damage:
		turn_info.text = enemy_unit.data.get("character_name", "Enemy") + " attacks for " + str(damage) + " damage! (Defense reduced from " + str(original_damage) + ")"
	else:
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

func is_front_row(panel_index: int, is_enemy: bool) -> bool:
	"""Determine if a panel is in the front row based on formation"""
	# Front row = panels 1, 2, 3 (indices 0, 1, 2)
	# Back row = panels 4, 5, 6 (indices 3, 4, 5)
	return panel_index < 3

func get_character_attack_type(character_data: Dictionary) -> String:
	"""Determine combat role based on character's combat_role tag"""
	# Use new combat_role field if available
	if character_data.has("combat_role"):
		var role = character_data.combat_role.to_lower()

		if "melee" in role:
			return "melee"
		elif "ranged" in role:
			return "ranged"
		elif "caster" in role:
			return "caster"
		elif "hybrid" in role:
			return "hybrid"

	# Fallback to old class_template system for backward compatibility
	if character_data.has("class_template"):
		var char_class = character_data.class_template.to_lower()

		# Pure melee classes
		var melee_classes = ["warrior", "knight", "paladin", "berserker", "monk", "fighter"]
		# Ranged classes
		var ranged_classes = ["archer", "ranger", "gunner", "sniper", "hunter"]
		# Magic classes
		var magic_classes = ["mage", "wizard", "sorcerer", "cleric", "priest", "shaman", "warlock"]

		for melee in melee_classes:
			if melee in char_class:
				return "melee"
		for ranged in ranged_classes:
			if ranged in char_class:
				return "ranged"
		for magic in magic_classes:
			if magic in char_class:
				return "caster"

	# Default to melee if nothing specified
	return "melee"

func calculate_range_penalty(attacker_data: Dictionary, attacker_index: int, defender_index: int, is_attacker_enemy: bool, is_defender_enemy: bool) -> float:
	"""Calculate damage multiplier based on combat role and position"""
	var combat_role = get_character_attack_type(attacker_data)
	var attacker_front = is_front_row(attacker_index, is_attacker_enemy)
	var defender_front = is_front_row(defender_index, is_defender_enemy)

	var penalty_multiplier = 1.0

	match combat_role:
		"caster":
			# CASTER: Full damage from any position
			# Front row = melee attacks, Back row = spell casting
			# Both are 100% effective
			return 1.0

		"hybrid":
			# HYBRID: 80% damage from any position (jack of all trades)
			# Can melee OR range but neither is perfect
			penalty_multiplier = 0.8
			print("  ⚖️ Hybrid versatility penalty: 0.8x")
			return penalty_multiplier

		"ranged":
			# RANGED: Full damage from back row, 50% if forced to melee in front
			if attacker_front:
				# Ranged fighter using melee in front row = 50% penalty
				penalty_multiplier = 0.5
				print("  🏹 Ranged using melee penalty: 0.5x")
			# Attacking from back row = full damage regardless of target
			return penalty_multiplier

		"melee":
			# MELEE: Full damage in front row, penalties for back row positioning
			# Melee attacker in BACK ROW = 50% penalty
			if not attacker_front:
				penalty_multiplier *= 0.5
				print("  📍 Back row melee penalty: 0.5x")

			# Attacking BACK ROW defender = additional 50% penalty
			if not defender_front:
				penalty_multiplier *= 0.5
				print("  🎯 Targeting back row penalty: 0.5x")

			# Hard floor: minimum 25% damage (0.25x)
			penalty_multiplier = max(0.25, penalty_multiplier)
			return penalty_multiplier

	# Default fallback
	return 1.0

func calculate_damage(attacker: Dictionary, defender: Dictionary, attacker_index: int = -1, defender_index: int = -1, is_attacker_enemy: bool = false) -> int:
	"""Calculate damage using STAT_SYSTEM.md formulas with range penalties and defensive modifiers"""
	var attacker_str = 10
	var defender_vit = 10

	if attacker.has("base_stats"):
		attacker_str = attacker.base_stats.get("str", 10)
	if defender.has("base_stats"):
		defender_vit = defender.base_stats.get("vit", 10)

	# Physical Damage = (STR * 2) - (VIT / 2)
	var base_damage = (attacker_str * 2) - int(defender_vit / 2.0)

	# Apply offensive range penalty (attacker's combat role)
	if attacker_index >= 0 and defender_index >= 0:
		var is_defender_enemy = !is_attacker_enemy  # Opposite teams
		var range_multiplier = calculate_range_penalty(attacker, attacker_index, defender_index, is_attacker_enemy, is_defender_enemy)
		base_damage = int(base_damage * range_multiplier)

		# Log offensive penalty info
		if range_multiplier < 1.0:
			var attack_type = get_character_attack_type(attacker)
			var attacker_name = attacker.get("character_name", "Unknown")
			print("  ⚔️ ", attacker_name, " (", attack_type, ") offensive penalty: ", range_multiplier, "x")

	# Apply defensive modifier (defender's combat role)
	var defender_role = get_character_attack_type(defender)
	var defensive_multiplier = get_defensive_modifier(defender_role)
	if defensive_multiplier != 1.0:
		base_damage = int(base_damage * defensive_multiplier)
		var defender_name = defender.get("character_name", "Unknown")
		print("  🛡️ ", defender_name, " (", defender_role, ") defensive modifier: ", defensive_multiplier, "x (takes ", int((defensive_multiplier - 1.0) * 100), "% extra damage)")

	# Minimum 1 damage
	return max(1, base_damage)

func get_defensive_modifier(combat_role: String) -> float:
	"""Get defensive damage multiplier based on combat role"""
	match combat_role:
		"caster":
			# Casters are weak defensively - take 20% extra damage
			return 1.2
		"hybrid":
			# Hybrids are weak defensively - take 20% extra damage
			return 1.2
		"melee":
			# Melee fighters have normal defense
			return 1.0
		"ranged":
			# Ranged fighters have normal defense
			return 1.0
	return 1.0

var is_selecting_target: bool = false
var selected_action: String = ""  # "attack", "heal", "buff", "debuff"
var can_target_allies: bool = false  # True for heals/buffs, false for attacks
var selected_target_index: int = -1  # Currently selected target (-1 = none)

func _on_attack_pressed():
	"""Player confirms attack on selected target"""
	if not is_player_turn:
		return

	# If no target selected, show message
	if selected_target_index < 0:
		turn_info.text = "Click an enemy to select target first!"
		return

	# Store target index before clearing
	var target = selected_target_index

	# Clear selection
	clear_enemy_highlights()
	hide_target_cursor()
	selected_target_index = -1

	# Execute attack on stored target
	execute_player_attack(target)

func _on_enemy_panel_clicked(event: InputEvent, enemy_index: int):
	"""Handle clicks on enemy panels - shows selection cursor"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if enemy is alive
		if enemy_index < enemy_squad.size() and enemy_squad[enemy_index].hp > 0:
			# Select this enemy (show cursor)
			selected_target_index = enemy_index
			show_target_cursor(enemy_panels_array()[enemy_index])
			turn_info.text = "Target: %s - Choose action (Attack, Skills, Items)" % enemy_squad[enemy_index].get("character_name", "Enemy")

func enemy_panels_array() -> Array:
	"""Return array of enemy panels"""
	return [enemy_panel_1, enemy_panel_2, enemy_panel_3, enemy_panel_4, enemy_panel_5, enemy_panel_6]

func show_target_cursor(target_panel: Panel):
	"""Show selection cursor over target panel"""
	if not target_cursor or not target_panel:
		return

	# Position cursor at target's global position
	target_cursor.global_position = target_panel.global_position
	target_cursor.size = target_panel.size
	target_cursor.visible = true

	print("🎯 Target cursor shown over panel at: ", target_panel.global_position)

func hide_target_cursor():
	"""Hide selection cursor"""
	if target_cursor:
		target_cursor.visible = false

func clear_enemy_highlights():
	"""Remove yellow highlights from enemy HP bars"""
	for hp_bar in enemy_hp_bars:
		if hp_bar:
			hp_bar.modulate = Color.WHITE

func _on_ally_panel_clicked(event: InputEvent, ally_index: int):
	"""Handle clicks on ally panels for heal/buff targeting (future feature)"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_selecting_target and can_target_allies:
			# Check if ally is alive
			if ally_index < ally_squad.size() and ally_squad[ally_index].hp > 0:
				clear_ally_highlights()
				is_selecting_target = false
				# Execute heal/buff (placeholder for when elemental trees are implemented)
				var target_name = ally_squad[ally_index].get("character_name", "Ally")
				turn_info.text = "Selected ally: " + target_name + " (Heal/Buff not yet implemented)"
				print("🎯 Selected ally for healing/buffing: ", target_name)
				# TODO: Implement heal/buff execution when elemental tree system is ready

func clear_ally_highlights():
	"""Remove green highlights from ally HP bars"""
	for hp_bar in ally_hp_bars:
		if hp_bar:
			hp_bar.modulate = Color.WHITE

func execute_player_attack(enemy_index: int):
	"""Execute player attack on enemy"""
	var enemy = enemy_squad[enemy_index]
	var player_ally_index = 0  # Player is Ally1

	# Show player attack animation (facing left toward enemies)
	await play_attack_animation(ally_sprites[player_ally_index], player_character, "attack_left", enemy_sprites[enemy_index])

	# Calculate and apply damage with range system
	var damage = calculate_damage(player_character, enemy, player_ally_index, enemy_index, false)
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
	"""Player chooses to defend - reduces damage taken by 50% until next turn"""
	if not is_player_turn or is_selecting_target:
		return

	is_player_turn = false
	is_player_defending = true

	# Clear any target selection
	clear_enemy_highlights()
	is_selecting_target = false

	# Show defend animation
	var player_ally_index = 0  # Player is Ally1
	turn_info.text = "You take a defensive stance! (Damage reduced by 50%)"
	print("🛡️ Player is defending - damage reduced by 50%")

	# Disable action buttons
	attack_button.disabled = true
	defend_button.disabled = true
	skills_button.disabled = true
	items_button.disabled = true

	# Flash player sprite to indicate defending
	if ally_sprites[player_ally_index]:
		ally_sprites[player_ally_index].modulate = Color(0.5, 0.5, 1.0)  # Blue tint
		await get_tree().create_timer(0.5).timeout
		ally_sprites[player_ally_index].modulate = Color.WHITE

	# Next turn after delay
	await get_tree().create_timer(0.5).timeout
	current_turn_index += 1
	start_next_turn()

func _on_skills_pressed():
	"""Player chooses to use skills (placeholder)"""
	turn_info.text = "Skills menu (Not implemented yet)"

func _on_items_pressed():
	"""Player chooses to use items (placeholder)"""
	turn_info.text = "Items menu (Not implemented yet)"

func play_attack_animation(sprite_node: TextureRect, character: Dictionary, attack_direction: String = "attack_right", target_sprite: TextureRect = null):
	"""Play attack animation - melee rushes to target, ranged/caster stays in position"""
	is_animating_attack = true  # Disable position enforcement during animation

	if not character.has("animations"):
		is_animating_attack = false
		return

	# Get parent panels to move entire units
	var attacker_panel = sprite_node.get_parent().get_parent()  # Sprite -> VBox -> Panel
	var target_panel = target_sprite.get_parent().get_parent() if target_sprite else null
	if not target_panel:
		is_animating_attack = false
		return

	# Get target character data from panel
	var target_character_data = {}
	if "character_data" in target_panel:
		target_character_data = target_panel.character_data

	# Determine combat role and if character should move
	var attack_type = get_character_attack_type(character)

	# Find which panel index this is to check front/back row
	var attacker_index = -1
	if attacker_panel.get_parent().name == "PlayerArea":
		# Find in ally panels
		var ally_panels = [ally_panel_1, ally_panel_2, ally_panel_3, ally_panel_4, ally_panel_5, ally_panel_6]
		for i in range(ally_panels.size()):
			if ally_panels[i] == attacker_panel:
				attacker_index = i
				break
	else:
		# Find in enemy panels
		var enemy_panels = [enemy_panel_1, enemy_panel_2, enemy_panel_3, enemy_panel_4, enemy_panel_5, enemy_panel_6]
		for i in range(enemy_panels.size()):
			if enemy_panels[i] == attacker_panel:
				attacker_index = i
				break

	var is_front_row_attacker = is_front_row(attacker_index, attacker_panel.get_parent().name == "EnemyArea")

	# Melee always moves, Hybrid moves only if in front row
	var should_move_to_target = (attack_type == "melee") or (attack_type == "hybrid" and is_front_row_attacker)

	# Store original positions
	var attacker_original_pos = attacker_panel.position

	# Calculate attack position - small step forward from current position (not all the way to target)
	var attacker_on_right = attacker_panel.get_parent().name == "PlayerArea"
	var step_distance = 40.0  # Small step forward to show who's attacking

	# Start from current position and step forward
	var attack_pos = attacker_original_pos

	# Step toward opponent
	if attacker_on_right:
		attack_pos.x -= step_distance  # Step left toward enemies
	else:
		attack_pos.x += step_distance  # Step right toward allies

	# Determine walk directions
	var attacker_approach_dir = "left" if attacker_on_right else "right"
	var attacker_return_dir = "right" if attacker_on_right else "left"

	# ========================================
	# PHASE 1: APPROACH (MELEE OR HYBRID IN FRONT ROW)
	# ========================================
	if should_move_to_target:
		# Start movement tween - quick step forward
		var tween_forward = create_tween()
		tween_forward.set_parallel(false)
		tween_forward.tween_property(attacker_panel, "position", attack_pos, 0.25).set_trans(Tween.TRANS_LINEAR)

		# Animate walk cycle in parallel - 2 frames at 0.125s each = 0.25s
		for i in range(2):
			var frame_suffix = "_1" if i % 2 == 0 else "_2"
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
			await get_tree().create_timer(0.125).timeout

		# Wait for tween to complete (in case of timing mismatch)
		if tween_forward and tween_forward.is_running():
			await tween_forward.finished

	# ========================================
	# PHASE 2: ATTACK SEQUENCE
	# ========================================
	# Show attack animation
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

	await get_tree().create_timer(0.15).timeout

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
	# PHASE 3: RETURN (MELEE OR HYBRID IN FRONT ROW)
	# ========================================
	if should_move_to_target:
		# Start return tween - quick step back
		var tween_back = create_tween()
		tween_back.set_parallel(false)
		tween_back.tween_property(attacker_panel, "position", attacker_original_pos, 0.25).set_trans(Tween.TRANS_LINEAR)

		# Animate walk cycle in parallel - 2 frames at 0.125s each = 0.25s
		for i in range(2):
			var frame_suffix = "_1" if i % 2 == 0 else "_2"
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
			await get_tree().create_timer(0.125).timeout

		# Wait for tween to complete (in case of timing mismatch)
		if tween_back and tween_back.is_running():
			await tween_back.finished

	# Return both to idle (facing down)
	load_character_sprite(character, sprite_node)
	if target_character_data.has("animations"):
		load_character_sprite(target_character_data, target_sprite)

	is_animating_attack = false  # Re-enable position enforcement

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
	# Disable all buttons
	attack_button.disabled = true
	defend_button.disabled = true
	skills_button.disabled = true
	items_button.disabled = true

	if victory:
		turn_info.text = "VICTORY! You defeated all enemies!"
		print("=== VICTORY ===")

		# Calculate rewards
		var rewards = calculate_rewards()

		# Update popup text
		result_title.text = "VICTORY!"
		result_title.modulate = Color(0.2, 1.0, 0.2)  # Green
		xp_label.text = "XP Gained: " + str(rewards.xp)
		gold_label.text = "Gold Earned: " + str(rewards.gold)

		# Show popup
		result_popup.visible = true
	else:
		turn_info.text = "DEFEAT! You were defeated..."
		print("=== DEFEAT ===")

		# Update popup text
		result_title.text = "DEFEAT!"
		result_title.modulate = Color(1.0, 0.2, 0.2)  # Red
		xp_label.text = "XP Gained: 0"
		gold_label.text = "Gold Earned: 0"

		# Show popup
		result_popup.visible = true

func calculate_rewards() -> Dictionary:
	"""Calculate XP and gold rewards based on enemies defeated"""
	var total_xp = 0
	var total_gold = 0

	# Base rewards per enemy (can be customized per enemy later)
	for enemy in enemy_squad:
		# Base XP: 10-50 depending on enemy level/stats
		var enemy_level = 1
		if enemy.has("level"):
			enemy_level = enemy.level
		var base_xp = 10 + (enemy_level * 5)
		total_xp += base_xp

		# Base gold: 5-25 depending on enemy level
		var base_gold = 5 + (enemy_level * 2)
		total_gold += base_gold

	print("Rewards calculated: %d XP, %d Gold" % [total_xp, total_gold])
	return {"xp": total_xp, "gold": total_gold}

func _on_continue_button_pressed():
	"""Return to dev client when continue button is pressed"""
	result_popup.visible = false
	get_tree().change_scene_to_file("res://dev_client.tscn")

func _on_hide_ui_pressed():
	"""Toggle visibility of developer UI elements"""
	ui_elements_hidden = !ui_elements_hidden

	# Hide/show layout buttons
	if layout_buttons_container:
		layout_buttons_container.visible = !ui_elements_hidden

	# Hide/show title bars and lock buttons on all panels
	var panels = [
		enemy_panel_1, enemy_panel_2, enemy_panel_3,
		enemy_panel_4, enemy_panel_5, enemy_panel_6,
		ally_panel_1, ally_panel_2, ally_panel_3,
		ally_panel_4, ally_panel_5, ally_panel_6
	]

	for panel in panels:
		if panel and panel.has_node("TitleBar"):
			panel.get_node("TitleBar").visible = !ui_elements_hidden

		# When UI is hidden, panel background should be transparent
		if ui_elements_hidden:
			panel.self_modulate = Color(1, 1, 1, 0.0)
		else:
			panel.self_modulate = Color(1, 1, 1, 1.0)

	# Hide/show UIPanel background (keep action buttons and turn info visible)
	var ui_panel = get_node("UIPanel")
	if ui_panel:
		if ui_elements_hidden:
			ui_panel.self_modulate = Color(1, 1, 1, 0.0)  # Transparent background
		else:
			ui_panel.self_modulate = Color(1, 1, 1, 1.0)  # Visible background

	# Toggle between original bars and floating overlays
	if ui_elements_hidden:
		# Hide original HP/MP bars and labels
		for i in range(6):
			enemy_hp_bars[i].visible = false
			enemy_hp_labels[i].visible = false
			ally_hp_bars[i].visible = false
			ally_hp_labels[i].visible = false
			ally_mp_bars[i].visible = false
			ally_mp_labels[i].visible = false
			enemy_names[i].visible = false
			ally_names[i].visible = false

		# Show and position floating overlays
		update_floating_overlays()
		for i in range(6):
			enemy_stat_overlays[i].visible = true
			ally_stat_overlays[i].visible = true
	else:
		# Show original HP/MP bars and labels
		for i in range(6):
			enemy_hp_bars[i].visible = true
			enemy_hp_labels[i].visible = true
			ally_hp_bars[i].visible = true
			ally_hp_labels[i].visible = true
			ally_mp_bars[i].visible = true
			ally_mp_labels[i].visible = true
			enemy_names[i].visible = true
			ally_names[i].visible = true

		# Hide floating overlays
		for i in range(6):
			enemy_stat_overlays[i].visible = false
			ally_stat_overlays[i].visible = false

	print("UI elements %s" % ("hidden" if ui_elements_hidden else "shown"))

func update_floating_overlays():
	"""Update positions and values of floating HP/MP/Energy overlays to match sprites"""
	# Update enemy stat overlays (HP only)
	for i in range(6):
		var hp_bar = enemy_stat_overlays[i].get_child(0)
		hp_bar.max_value = enemy_hp_bars[i].max_value
		hp_bar.value = enemy_hp_bars[i].value

	# Update ally stat overlays (HP + MP + Energy)
	for i in range(6):
		var hp_bar = ally_stat_overlays[i].get_child(0)
		hp_bar.max_value = ally_hp_bars[i].max_value
		hp_bar.value = ally_hp_bars[i].value

		var mp_bar = ally_stat_overlays[i].get_child(1)
		mp_bar.max_value = ally_mp_bars[i].max_value
		mp_bar.value = ally_mp_bars[i].value

		var energy_bar = ally_stat_overlays[i].get_child(2)
		energy_bar.max_value = 100
		energy_bar.value = 100  # Placeholder

	# Update positions
	update_floating_overlay_positions()

func update_floating_overlay_positions():
	"""Update positions of floating overlays to follow sprites"""
	# Center enemy stat overlays above sprites
	for i in range(6):
		var sprite_global_pos = enemy_sprites[i].global_position
		var sprite_size = enemy_sprites[i].size
		# Center horizontally: sprite center - half overlay width
		var centered_x = sprite_global_pos.x + (sprite_size.x / 2) - 25  # 25 = half of 50px width
		enemy_stat_overlays[i].position = Vector2(centered_x, sprite_global_pos.y - 10)

	# Center ally stat overlays above sprites
	for i in range(6):
		var sprite_global_pos = ally_sprites[i].global_position
		var sprite_size = ally_sprites[i].size
		# Center horizontally: sprite center - half overlay width
		var centered_x = sprite_global_pos.x + (sprite_size.x / 2) - 25  # 25 = half of 50px width
		ally_stat_overlays[i].position = Vector2(centered_x, sprite_global_pos.y - 20)

func _on_save_layout_pressed():
	"""Save battle UI layout to file"""
	save_manual_positions()
	print("Battle layout saved!")

func _on_reset_layout_pressed():
	"""Reset all panels to default positions and force perfect alignment"""
	auto_align_all_panels()  # Force perfect grid alignment
	# Don't lock - enforce_panel_alignment() runs every frame to maintain positions
	print("Battle layout reset to perfect grid alignment!")

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
	# MUST match auto_align_all_panels() and enforce_panel_alignment() EXACTLY
	# Both EnemyArea and PlayerArea are 600px wide for perfect symmetry
	const ENEMY_BACK_X = 65.0
	const ENEMY_FRONT_X = 265.0    # Moved 100px left toward center
	const ALLY_FRONT_X = 165.0     # Moved 100px right toward center
	const ALLY_BACK_X = 365.0
	const ROW_1_Y = 90.0
	const ROW_2_Y = 250.0
	const ROW_3_Y = 410.0

	# Use POSITION property (layout_mode = 0 uses position for visual rendering, not offset!)
	const PANEL_WIDTH = 170.0
	const ENEMY_HEIGHT = 290.0
	const ALLY_HEIGHT = 320.0

	# Reset enemy panels with EXACT positions
	enemy_panel_1.position = Vector2(ENEMY_FRONT_X, ROW_1_Y)
	enemy_panel_1.size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	enemy_panel_2.position = Vector2(ENEMY_FRONT_X, ROW_2_Y)
	enemy_panel_2.size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	enemy_panel_3.position = Vector2(ENEMY_FRONT_X, ROW_3_Y)
	enemy_panel_3.size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	enemy_panel_4.position = Vector2(ENEMY_BACK_X, ROW_1_Y)
	enemy_panel_4.size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	enemy_panel_5.position = Vector2(ENEMY_BACK_X, ROW_2_Y)
	enemy_panel_5.size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	enemy_panel_6.position = Vector2(ENEMY_BACK_X, ROW_3_Y)
	enemy_panel_6.size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	# Reset ally panels with EXACT positions
	ally_panel_1.position = Vector2(ALLY_FRONT_X, ROW_1_Y)
	ally_panel_1.size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

	ally_panel_2.position = Vector2(ALLY_FRONT_X, ROW_2_Y)
	ally_panel_2.size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

	ally_panel_3.position = Vector2(ALLY_FRONT_X, ROW_3_Y)
	ally_panel_3.size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

	ally_panel_4.position = Vector2(ALLY_BACK_X, ROW_1_Y)
	ally_panel_4.size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

	ally_panel_5.position = Vector2(ALLY_BACK_X, ROW_2_Y)
	ally_panel_5.size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

	ally_panel_6.position = Vector2(ALLY_BACK_X, ROW_3_Y)
	ally_panel_6.size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

	# Reset UI panel
	ui_panel.position = Vector2(300, 500)
	ui_panel.size = Vector2(680, 180)

	# Don't lock - enforce_panel_alignment() maintains positions every frame

	print("✓ All panels reset to default positions")

func auto_lock_all_panels():
	"""Lock all battle panels to prevent movement"""
	var panels = [
		enemy_panel_1, enemy_panel_2, enemy_panel_3,
		enemy_panel_4, enemy_panel_5, enemy_panel_6,
		ally_panel_1, ally_panel_2, ally_panel_3,
		ally_panel_4, ally_panel_5, ally_panel_6
	]

	for panel in panels:
		if panel and "is_locked" in panel:
			panel.is_locked = true
			panel.update_visual_state()

func auto_align_all_panels():
	"""Force all panels into perfect grid alignment based on container dimensions"""
	# WINDOW: 1280x720
	# Combat area layout: LeftSpacer(50) + EnemyArea(600) + MiddleSpacer(100) + PlayerArea(600) + RightSpacer(50)

	# PERFECT SYMMETRICAL LAYOUT - BOTH AREAS 600px WIDE:
	# Panel width: 170px
	# Panel height: Enemy=290px, Ally=320px

	# ENEMY AREA (600px wide):
	# Back column: x=65 (left side)
	# Front column: x=265 (moved even closer to center for tight formation)
	const ENEMY_BACK_X = 65.0     # Back row (further from allies)
	const ENEMY_FRONT_X = 265.0   # Front row (closer to allies) - moved 100px left

	# ALLY AREA (600px wide) - SYMMETRICAL SPACING:
	# Front column: x=165 (moved closer to center to face enemies)
	# Back column: x=365 (right side)
	const ALLY_FRONT_X = 165.0    # Front row (closer to enemies) - moved 100px right
	const ALLY_BACK_X = 365.0     # Back row (further from enemies)

	# VERTICAL POSITIONS - Positioned to clear top menus:
	# Start at y=90 for good spacing below action buttons
	# 3 rows with 160px spacing between each
	const ROW_1_Y = 90.0          # Top row
	const ROW_2_Y = 250.0         # Middle row (90 + 160)
	const ROW_3_Y = 410.0         # Bottom row (250 + 160)

	# EXACT sizes
	const ENEMY_SIZE = Vector2(170.0, 290.0)
	const ALLY_SIZE = Vector2(170.0, 320.0)

	# Use POSITION property (layout_mode = 0 uses position for visual rendering, not offset!)
	const PANEL_WIDTH = 170.0
	const ENEMY_HEIGHT = 290.0
	const ALLY_HEIGHT = 320.0

	# ===== ENEMY FRONT ROW =====
	enemy_panel_1.position = Vector2(ENEMY_FRONT_X, ROW_1_Y)
	enemy_panel_1.size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	enemy_panel_2.position = Vector2(ENEMY_FRONT_X, ROW_2_Y)
	enemy_panel_2.size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	enemy_panel_3.position = Vector2(ENEMY_FRONT_X, ROW_3_Y)
	enemy_panel_3.size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	# ===== ENEMY BACK ROW =====
	enemy_panel_4.position = Vector2(ENEMY_BACK_X, ROW_1_Y)
	enemy_panel_4.size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	enemy_panel_5.position = Vector2(ENEMY_BACK_X, ROW_2_Y)
	enemy_panel_5.size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	enemy_panel_6.position = Vector2(ENEMY_BACK_X, ROW_3_Y)
	enemy_panel_6.size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	# ===== ALLY FRONT ROW =====
	ally_panel_1.position = Vector2(ALLY_FRONT_X, ROW_1_Y)
	ally_panel_1.size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

	ally_panel_2.position = Vector2(ALLY_FRONT_X, ROW_2_Y)
	ally_panel_2.size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

	ally_panel_3.position = Vector2(ALLY_FRONT_X, ROW_3_Y)
	ally_panel_3.size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

	# ===== ALLY BACK ROW =====
	ally_panel_4.position = Vector2(ALLY_BACK_X, ROW_1_Y)
	ally_panel_4.size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

	ally_panel_5.position = Vector2(ALLY_BACK_X, ROW_2_Y)
	ally_panel_5.size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

	ally_panel_6.position = Vector2(ALLY_BACK_X, ROW_3_Y)
	ally_panel_6.size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

func enforce_panel_alignment():
	"""Silently enforce perfect alignment every frame to prevent any drift"""
	# MUST match auto_align_all_panels() constants EXACTLY
	# Both EnemyArea and PlayerArea are 600px wide for perfect symmetry
	const ENEMY_BACK_X = 65.0
	const ENEMY_FRONT_X = 265.0    # Moved 100px left toward center
	const ALLY_FRONT_X = 165.0     # Moved 100px right toward center
	const ALLY_BACK_X = 365.0
	const ROW_1_Y = 90.0
	const ROW_2_Y = 250.0
	const ROW_3_Y = 410.0

	const PANEL_WIDTH = 170.0
	const ENEMY_PANEL_HEIGHT = 290.0
	const ALLY_PANEL_HEIGHT = 320.0

	# First, disable dragging on all panels to prevent interference
	for panel in [enemy_panel_1, enemy_panel_2, enemy_panel_3, enemy_panel_4, enemy_panel_5, enemy_panel_6,
				  ally_panel_1, ally_panel_2, ally_panel_3, ally_panel_4, ally_panel_5, ally_panel_6]:
		if panel and "is_dragging" in panel:
			panel.is_dragging = false
		if panel and "is_resizing" in panel:
			panel.is_resizing = false

	# FORCE positions using POSITION property (layout_mode = 0 uses position, not offset!)
	if enemy_panel_1:
		enemy_panel_1.position = Vector2(ENEMY_FRONT_X, ROW_1_Y)
		enemy_panel_1.size = Vector2(PANEL_WIDTH, ENEMY_PANEL_HEIGHT)
	if enemy_panel_2:
		enemy_panel_2.position = Vector2(ENEMY_FRONT_X, ROW_2_Y)
		enemy_panel_2.size = Vector2(PANEL_WIDTH, ENEMY_PANEL_HEIGHT)
	if enemy_panel_3:
		enemy_panel_3.position = Vector2(ENEMY_FRONT_X, ROW_3_Y)
		enemy_panel_3.size = Vector2(PANEL_WIDTH, ENEMY_PANEL_HEIGHT)
	if enemy_panel_4:
		enemy_panel_4.position = Vector2(ENEMY_BACK_X, ROW_1_Y)
		enemy_panel_4.size = Vector2(PANEL_WIDTH, ENEMY_PANEL_HEIGHT)
	if enemy_panel_5:
		enemy_panel_5.position = Vector2(ENEMY_BACK_X, ROW_2_Y)
		enemy_panel_5.size = Vector2(PANEL_WIDTH, ENEMY_PANEL_HEIGHT)
	if enemy_panel_6:
		enemy_panel_6.position = Vector2(ENEMY_BACK_X, ROW_3_Y)
		enemy_panel_6.size = Vector2(PANEL_WIDTH, ENEMY_PANEL_HEIGHT)

	if ally_panel_1:
		ally_panel_1.position = Vector2(ALLY_FRONT_X, ROW_1_Y)
		ally_panel_1.size = Vector2(PANEL_WIDTH, ALLY_PANEL_HEIGHT)
	if ally_panel_2:
		ally_panel_2.position = Vector2(ALLY_FRONT_X, ROW_2_Y)
		ally_panel_2.size = Vector2(PANEL_WIDTH, ALLY_PANEL_HEIGHT)
	if ally_panel_3:
		ally_panel_3.position = Vector2(ALLY_FRONT_X, ROW_3_Y)
		ally_panel_3.size = Vector2(PANEL_WIDTH, ALLY_PANEL_HEIGHT)
	if ally_panel_4:
		ally_panel_4.position = Vector2(ALLY_BACK_X, ROW_1_Y)
		ally_panel_4.size = Vector2(PANEL_WIDTH, ALLY_PANEL_HEIGHT)
	if ally_panel_5:
		ally_panel_5.position = Vector2(ALLY_BACK_X, ROW_2_Y)
		ally_panel_5.size = Vector2(PANEL_WIDTH, ALLY_PANEL_HEIGHT)
	if ally_panel_6:
		ally_panel_6.position = Vector2(ALLY_BACK_X, ROW_3_Y)
		ally_panel_6.size = Vector2(PANEL_WIDTH, ALLY_PANEL_HEIGHT)

func spawn_impact_particles(hit_position: Vector2):
	"""Spawn particle effect at attack impact location"""
	# Check if impact effect exists before loading
	if not ResourceLoader.exists("res://effects/attack_impact.tscn"):
		return

	var impact_scene = load("res://effects/attack_impact.tscn")
	if not impact_scene:
		return

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
